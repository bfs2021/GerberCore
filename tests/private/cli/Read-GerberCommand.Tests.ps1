BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberPromptStateTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
    $script:rootPrompt = [string][char]0x276F
    $script:rootEmptyStateHintText = '/ commands ' + [string][char]0x00B7 + ' esc back'
}

Describe 'Read-GerberCommand' {
    It 'trims Read-Host fallback input by default' {
        Mock Clear-GerberPendingConsoleInput {}
        Mock Test-GerberInteractivePromptAvailable { $false }
        Mock Write-GerberHostPrompt {}
        Mock Read-Host { '  /help  ' }

        Read-GerberCommand | Should -Be '/help'
        Should -Invoke Write-GerberHostPrompt -Times 1 -ParameterFilter { $Prompt -eq $script:rootPrompt }
    }

    It 'falls back to Read-Host when interactive prompting fails' {
        Mock Clear-GerberPendingConsoleInput {}
        Mock Test-GerberInteractivePromptAvailable { $true }
        Mock Read-GerberInteractiveCommand { throw [System.InvalidOperationException]::new('Prompt failed.') }
        Mock Write-GerberConsoleLineBreak {}
        Mock Write-GerberHostPrompt {}
        Mock Read-Host { '/help' }

        Read-GerberCommand | Should -Be '/help'
        Should -Invoke Write-GerberConsoleLineBreak -Times 1
        Should -Invoke Write-GerberHostPrompt -Times 1 -ParameterFilter { $Prompt -eq $script:rootPrompt }
    }

    It 'propagates the shared escape exception from interactive prompting' {
        Mock Clear-GerberPendingConsoleInput {}
        Mock Test-GerberInteractivePromptAvailable { $true }
        Mock Read-GerberInteractiveCommand { throw (Get-GerberMenuEscapeException) }
        Mock Read-Host {}

        { Read-GerberCommand } | Should -Throw 'Go back to the previous Gerber menu.'
        Should -Invoke Read-Host -Times 0
    }

    It 'propagates root-navigation requests from interactive prompting without falling back to Read-Host' {
        Mock Clear-GerberPendingConsoleInput {}
        Mock Test-GerberInteractivePromptAvailable { $true }
        Mock Read-GerberInteractiveCommand {
            $exception = [System.InvalidOperationException]::new('Return to the Gerber root menu.')
            $exception.Data['GerberRootNavigation'] = $true
            throw $exception
        }
        Mock Read-Host {}

        { Read-GerberCommand } | Should -Throw 'Return to the Gerber root menu.'
        Should -Invoke Read-Host -Times 0
    }
}

Describe 'Read-GerberCommand helpers' {
    It 'enters the shared update submenu with list and policy choices' -Tag 'CoreUpdatePolicy' {
        $resolution = Resolve-GerberCommand -InputText '/update'
        $resolution.IsValid | Should -BeTrue
        (Test-GerberPromptSubcommandEntry -Resolution $resolution) | Should -BeTrue
        (Get-GerberRegisteredCommand -Name update).Subcommands.Keys | Should -Be @('list', 'policy')
    }
    It 'uses Gerber prompt formatting for host fallback input and can start on a fresh line' {
        Mock Write-GerberConsoleLineBreak {}
        Mock Write-GerberHostPrompt {}
        Mock Read-Host { '  /tools  ' }

        $result = Read-GerberHostPromptValue -Prompt $script:rootPrompt -TrimResult $true -StartOnFreshLine

        $result | Should -Be '/tools'
        Should -Invoke Write-GerberConsoleLineBreak -Times 1
        Should -Invoke Write-GerberHostPrompt -Times 1 -ParameterFilter { $Prompt -eq $script:rootPrompt }
    }

    It 'returns an empty subcommand table when no registered root command exists' {
        Mock Get-GerberRegisteredCommand { $null }

        $result = Get-GerberMenuSubcommandTable -CommandName 'unknown'

        $result.Count | Should -Be 0
    }

    It 'detects when the interactive prompt is unavailable because input is redirected' {
        Mock Test-GerberConsoleInputRedirected { $true }
        Mock Get-GerberInteractivePromptCursorPosition { throw 'Should not read cursor position when redirected.' }

        (Test-GerberInteractivePromptAvailable) | Should -BeFalse
    }

    It 'detects when the interactive prompt is available' {
        Mock Test-GerberConsoleInputRedirected { $false }
        Mock Get-GerberInteractivePromptCursorPosition { [pscustomobject]@{ Left = 0; Top = 0 } }

        (Test-GerberInteractivePromptAvailable) | Should -BeTrue
    }

    It 'returns false when cursor position throws during availability check' {
        Mock Test-GerberConsoleInputRedirected { $false }
        Mock Get-GerberInteractivePromptCursorPosition { throw 'No cursor available.' }

        (Test-GerberInteractivePromptAvailable) | Should -BeFalse
    }

    It 'initializes prompt state from prompt context values' {
        Mock Get-GerberConsoleCursorTop { 4 }
        $context = ConvertTo-GerberCommandPromptContext `
            -SuggestionCommandName 'tools' `
            -SubcommandTable ([ordered]@{ 'create-uuid' = 'Generate a UUID and copy it to the clipboard when possible' }) `
            -StaticSuggestionList @([pscustomobject]@{ DisplayText = '/help'; CompletionText = '/help' }) `
            -InitialBuffer '/tools ' `
            -InitialCursorIndex 2 `
            -PromptHintText '[create-uuid|base-64]' `
            -EmptyStateHintText $script:rootEmptyStateHintText `
            -AutoSelectFirstSuggestionOnSubmit $true

        $state = Initialize-GerberCommandPromptState -Prompt $script:rootPrompt -PromptContext $context

        $state.Prompt | Should -Be $script:rootPrompt
        $state.SuggestionCommandName | Should -Be 'tools'
        $state.SuggestionSubcommandTable.Keys | Should -Be @('create-uuid')
        $state.StaticSuggestionList[0].DisplayText | Should -Be '/help'
        $state.Buffer | Should -Be '/tools '
        $state.CursorIndex | Should -Be 2
        $state.PromptHintText | Should -Be '[create-uuid|base-64]'
        $state.EmptyStateHintText | Should -Be $script:rootEmptyStateHintText
        $state.AutoSelectFirstSuggestionOnSubmit | Should -BeTrue
        $state.PromptTop | Should -Be 4
    }

    It 'initializes prompt state using the default prompt context when none is provided' {
        Mock Get-GerberConsoleCursorTop { 0 }

        $state = Initialize-GerberCommandPromptState -Prompt $script:rootPrompt

        $state.Prompt | Should -Be $script:rootPrompt
        $state.PromptTop | Should -Be 0
    }

    It 'reads an interactive prompt until Enter submits the current buffer' {
        Mock Get-GerberConsoleCursorTop { 0 }
        Mock Show-GerberCommandPrompt {}
        Mock Read-GerberMenuConsoleKey { [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false) }
        Mock Write-GerberPromptTrace {}
        Mock Complete-GerberPrompt {}

        $result = Read-GerberInteractiveCommand -Prompt $script:rootPrompt -PromptContext (ConvertTo-GerberCommandPromptContext -InitialBuffer '/help')

        $result | Should -Be '/help'
        Should -Invoke Show-GerberCommandPrompt -Times 1
    }

    It 'throws the shared escape exception when Escape is pressed in the interactive prompt' {
        Mock Get-GerberConsoleCursorTop { 0 }
        Mock Show-GerberCommandPrompt {}
        Mock Read-GerberMenuConsoleKey { [System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false) }
        Mock Write-GerberPromptTrace {}

        { Read-GerberInteractiveCommand -Prompt $script:rootPrompt } | Should -Throw 'Go back to the previous Gerber menu.'
    }

    It 'processes a non-submit key and re-renders the prompt before the next key read' {
        $script:readKeyCallIndex = 0
        $keySequence = @(
            [System.ConsoleKeyInfo]::new('x', [System.ConsoleKey]::X, $false, $false, $false)
            [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
        )
        Mock Get-GerberConsoleCursorTop { 0 }
        Mock Show-GerberCommandPrompt {}
        Mock Write-GerberPromptTrace {}
        Mock Complete-GerberPrompt {}
        Mock Sync-GerberPromptSuggestion {}
        Mock Invoke-GerberCommandPromptKey {}
        Mock Read-GerberMenuConsoleKey {
            $key = $keySequence[$script:readKeyCallIndex]
            $script:readKeyCallIndex++
            return $key
        }
        $script:readKeyCallIndex = 0

        $null = Read-GerberInteractiveCommand -Prompt $script:rootPrompt -PromptContext (ConvertTo-GerberCommandPromptContext)

        Should -Invoke Invoke-GerberCommandPromptKey -Times 1
        Should -Invoke Show-GerberCommandPrompt -Times 2
    }

    It 're-renders the prompt and continues when Enter triggers subcommand scope entry' {
        Mock Get-GerberConsoleCursorTop { 0 }
        Mock Sync-GerberPromptSuggestion {}
        Mock Show-GerberCommandPrompt {}
        Mock Write-GerberPromptTrace {}
        Mock Complete-GerberPrompt {}
        Mock Read-GerberMenuConsoleKey {
            [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
        }

        $result = Read-GerberInteractiveCommand -Prompt $script:rootPrompt -PromptContext (ConvertTo-GerberCommandPromptContext -InitialBuffer '/tools')

        $result | Should -Be '/tools'
        Should -Invoke Show-GerberCommandPrompt -Times 2
    }

    It 'recognizes Escape keys for prompt cancellation' {
        (Test-GerberPromptEscapeRequested -Key ([System.ConsoleKeyInfo]::new([char]27, [System.ConsoleKey]::Escape, $false, $false, $false))) | Should -BeTrue
        (Test-GerberPromptEscapeRequested -Key ([System.ConsoleKeyInfo]::new('a', [System.ConsoleKey]::A, $false, $false, $false))) | Should -BeFalse
    }

    It 'returns a distinct root-navigation exception after a valid double Escape sequence' {
        Mock Receive-GerberEscapeContinuationKey {}
        Mock Request-GerberVisibleRootPrompt {}
        Mock Clear-GerberPendingConsoleInput {}
        $script:GerberPendingRootNavigationRequested = $true

        $exception = Get-GerberMenuEscapeException

        (Test-GerberRootNavigationException -Exception $exception) | Should -BeTrue
        (Test-GerberMenuEscapeException -Exception $exception) | Should -BeFalse
        Should -Invoke Receive-GerberEscapeContinuationKey -Times 1
        Should -Invoke Request-GerberVisibleRootPrompt -Times 1
        Should -Invoke Clear-GerberPendingConsoleInput -Times 1 -ParameterFilter { $Force }
        (Test-GerberPendingRootNavigationRequested) | Should -BeFalse
    }

    It 'upgrades a single Escape to root navigation when a continuation Escape arrives during transition handling' {
        Mock Request-GerberVisibleRootPrompt {}
        Mock Clear-GerberPendingConsoleInput {}
        Mock Receive-GerberEscapeContinuationKey {
            $script:GerberPendingRootNavigationRequested = $true
        }

        $exception = Get-GerberMenuEscapeException

        (Test-GerberRootNavigationException -Exception $exception) | Should -BeTrue
        Should -Invoke Receive-GerberEscapeContinuationKey -Times 1
        Should -Invoke Request-GerberVisibleRootPrompt -Times 1
    }

    It 'resolves initial cursor indexes against the buffer length' {
        (Resolve-GerberInitialCursorIndex -InitialBuffer 'tools' -InitialCursorIndex -1) | Should -Be 5
        (Resolve-GerberInitialCursorIndex -InitialBuffer 'tools' -InitialCursorIndex 2) | Should -Be 2
        (Resolve-GerberInitialCursorIndex -InitialBuffer 'tools' -InitialCursorIndex 99) | Should -Be 5
    }

    It 'returns submitted prompt values with optional trimming' {
        (Get-GerberPromptSubmittedValue -Value '  /help  ' -TrimResult $true) | Should -Be '/help'
        (Get-GerberPromptSubmittedValue -Value '  /help  ' -TrimResult $false) | Should -Be '  /help  '
    }

    It 'handles suggestion navigation keys' {
        $state = @{
            Buffer = '/'
            SuggestionIndex = 0
            SuggestionList = @(
                [pscustomobject]@{ DisplayText = '/exit'; CompletionText = '/exit' }
                [pscustomobject]@{ DisplayText = '/help'; CompletionText = '/help' }
            )
            SuggestionNavigationUsed = $false
        }
        Mock Write-GerberPromptTrace {}

        (Test-GerberHandledSuggestionKey -State $state -Key ([System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::DownArrow, $false, $false, $false))) | Should -BeTrue
        $state.SuggestionIndex | Should -Be 1
        $state.SuggestionNavigationUsed | Should -BeTrue
        (Test-GerberHandledSuggestionKey -State $state -Key ([System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::UpArrow, $false, $false, $false))) | Should -BeTrue
        $state.SuggestionIndex | Should -Be 0
    }

    It 'handles Tab as a suggestion completion key' {
        $state = @{
            Buffer = '/to'
            CursorIndex = 3
            SuggestionIndex = 0
            SuggestionList = @([pscustomobject]@{ DisplayText = '/tools'; CompletionText = '/tools' })
            SuggestionMode = 'Root'
            SuggestionNavigationUsed = $false
        }
        Mock Write-GerberPromptTrace {}

        $result = Test-GerberHandledSuggestionKey -State $state -Key ([System.ConsoleKeyInfo]::new([char]9, [System.ConsoleKey]::Tab, $false, $false, $false))

        $result | Should -BeTrue
        $state.Buffer | Should -Be '/tools'
    }

    It 'handles cursor movement keys' {
        $state = @{ Buffer = '/help'; CursorIndex = 3 }

        (Test-GerberHandledCursorKey -State $state -Key ([System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::LeftArrow, $false, $false, $false))) | Should -BeTrue
        $state.CursorIndex | Should -Be 2
        (Test-GerberHandledCursorKey -State $state -Key ([System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::RightArrow, $false, $false, $false))) | Should -BeTrue
        $state.CursorIndex | Should -Be 3
        (Test-GerberHandledCursorKey -State $state -Key ([System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::Home, $false, $false, $false))) | Should -BeTrue
        $state.CursorIndex | Should -Be 0
        (Test-GerberHandledCursorKey -State $state -Key ([System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::End, $false, $false, $false))) | Should -BeTrue
        $state.CursorIndex | Should -Be 5
    }

    It 'handles buffer editing keys' {
        $state = @{ Buffer = '/help'; CursorIndex = 5; InputMode = 'Buffered' }

        (Test-GerberHandledBufferKey -State $state -Key ([System.ConsoleKeyInfo]::new([char]8, [System.ConsoleKey]::Backspace, $false, $false, $false))) | Should -BeTrue
        $state.Buffer | Should -Be '/hel'
        (Test-GerberHandledBufferKey -State $state -Key ([System.ConsoleKeyInfo]::new('p', [System.ConsoleKey]::P, $false, $false, $false))) | Should -BeTrue
        $state.Buffer | Should -Be '/help'
        $state.CursorIndex = 1
        (Test-GerberHandledBufferKey -State $state -Key ([System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::Delete, $false, $false, $false))) | Should -BeTrue
        $state.Buffer | Should -Be '/elp'
    }

    It 'returns false from buffer key handler when InputMode is SelectionOnly' {
        $state = @{
            Buffer = '/help'
            CursorIndex = 5
            InputMode = 'SelectionOnly'
        }

        $result = Test-GerberHandledBufferKey -State $state -Key ([System.ConsoleKeyInfo]::new([char]8, [System.ConsoleKey]::Backspace, $false, $false, $false))

        $result | Should -BeFalse
    }

    It 'recognizes tab keys through both console representations' {
        (Test-GerberTabKey -Key ([System.ConsoleKeyInfo]::new([char]9, [System.ConsoleKey]::Tab, $false, $false, $false))) | Should -BeTrue
        (Test-GerberTabKey -Key ([System.ConsoleKeyInfo]::new('a', [System.ConsoleKey]::A, $false, $false, $false))) | Should -BeFalse
    }

    It 'edits and appends prompt characters directly' {
        $state = @{ Buffer = '/tools'; CursorIndex = 2 }

        (Edit-GerberPromptCharacterAtIndex -State $state -DeleteIndex 1) | Should -BeTrue
        $state.Buffer | Should -Be '/ools'
        $state.CursorIndex | Should -Be 1
        (Add-GerberPromptCharacter -State $state -Key ([System.ConsoleKeyInfo]::new('t', [System.ConsoleKey]::T, $false, $false, $false))) | Should -BeTrue
        $state.Buffer | Should -Be '/tools'
    }

    It 'returns false from Edit-GerberPromptCharacterAtIndex for out-of-bounds indexes' {
        $state = @{ Buffer = '/help'; CursorIndex = 2 }

        (Edit-GerberPromptCharacterAtIndex -State $state -DeleteIndex -1) | Should -BeFalse
    }

    It 'returns false from Add-GerberPromptCharacter for control characters' {
        $state = @{ Buffer = '/help'; CursorIndex = 5 }
        $controlKey = [System.ConsoleKeyInfo]::new([char]1, [System.ConsoleKey]::A, $false, $true, $false)

        (Add-GerberPromptCharacter -State $state -Key $controlKey) | Should -BeFalse
    }

    It 'applies prompt suggestions and updates the buffer' {
        $state = @{
            Buffer = '/to'
            CursorIndex = 3
            SuggestionIndex = 0
            SuggestionList = @([pscustomobject]@{ DisplayText = '/tools'; CompletionText = '/tools' })
            SuggestionMode = 'Root'
        }
        Mock Write-GerberPromptTrace {}

        (Complete-GerberPromptSuggestion -State $state) | Should -BeTrue
        $state.Buffer | Should -Be '/tools'
        $state.CursorIndex | Should -Be 6
    }

    It 'does not apply suggestions when none are available' {
        $state = @{
            Buffer = 'zzz'
            CursorIndex = 6
            SuggestionIndex = 0
            SuggestionList = @()
            SuggestionMode = 'None'
        }
        Mock Write-GerberPromptTrace {}

        (Complete-GerberPromptSuggestion -State $state) | Should -BeFalse
    }

    It 'chooses when submit should apply suggestions' {
        $selectionState = @{
            SuggestionList = @([pscustomobject]@{ DisplayText = '/help'; CompletionText = '/help' })
            SuggestionNavigationUsed = $true
            InputMode = 'SelectionOnly'
            Buffer = '/help'
        }
        $autoSelectState = @{
            SuggestionList = @([pscustomobject]@{ DisplayText = '/secrets list'; CompletionText = '/secrets list' })
            SuggestionNavigationUsed = $false
            AutoSelectFirstSuggestionOnSubmit = $true
            InitialBuffer = '/secrets '
            Buffer = '/secrets '
        }

        (Test-GerberShouldApplySuggestionOnSubmit -State $selectionState) | Should -BeTrue
        (Test-GerberShouldApplySuggestionOnSubmit -State $autoSelectState) | Should -BeTrue
        (Test-GerberPromptAutoSelectOnSubmit -State $autoSelectState) | Should -BeTrue
    }

    It 'returns false for auto-select when the initial buffered state is not reusable' -ForEach @(
        @{
            Name = 'the buffer differs from the initial buffer'
            State = @{
                AutoSelectFirstSuggestionOnSubmit = $true
                InitialBuffer = '/secrets '
                Buffer = '/secrets l'
                SuggestionList = @([pscustomobject]@{ CompletionText = '/secrets list' })
            }
        }
        @{
            Name = 'InitialBuffer is empty'
            State = @{
                AutoSelectFirstSuggestionOnSubmit = $true
                InitialBuffer = ''
                Buffer = ''
                SuggestionList = @([pscustomobject]@{ CompletionText = '/tools' })
            }
        }
    ) {
        param($Name, $State)
        $null = $Name

        (Test-GerberPromptAutoSelectOnSubmit -State $State) | Should -BeFalse
    }

    It 'handles selection-only auto-select submission states correctly' -ForEach @(
        @{
            Name = 'auto-selects the first item when submit is enabled and the buffer is empty'
            State = @{
                SuggestionList = @([pscustomobject]@{ DisplayText = '1. Export JSON'; CompletionText = 'json' })
                SuggestionNavigationUsed = $false
                InputMode = 'SelectionOnly'
                AutoSelectFirstSuggestionOnSubmit = $true
                Buffer = ''
            }
            AutoSelectExpected = $true
            SubmitExpected = $true
        }
        @{
            Name = 'does not auto-select the first item when the buffer has content'
            State = @{
                SuggestionList = @([pscustomobject]@{ DisplayText = '1. Export JSON'; CompletionText = 'json' })
                SuggestionNavigationUsed = $false
                InputMode = 'SelectionOnly'
                AutoSelectFirstSuggestionOnSubmit = $true
                Buffer = '1'
            }
            AutoSelectExpected = $false
            SubmitExpected = $false
        }
        @{
            Name = 'does not auto-select the first item when auto-select is disabled'
            State = @{
                SuggestionList = @([pscustomobject]@{ DisplayText = '1. Export JSON'; CompletionText = 'json' })
                SuggestionNavigationUsed = $false
                InputMode = 'SelectionOnly'
                AutoSelectFirstSuggestionOnSubmit = $false
                Buffer = ''
            }
            AutoSelectExpected = $false
            SubmitExpected = $false
        }
    ) {
        param($Name, $State, $AutoSelectExpected, $SubmitExpected)
        $null = $Name

        (Test-GerberSelectionOnlyAutoFirstSelect -State $State) | Should -Be $AutoSelectExpected
        (Test-GerberShouldApplySuggestionOnSubmit -State $State) | Should -Be $SubmitExpected
    }

    It 'returns false when selection submit cannot apply a suggestion' -ForEach @(
        @{
            Name = 'no suggestion can be completed'
            State = @{
                Buffer = 'zzz'
                CursorIndex = 3
                SuggestionIndex = 0
                SuggestionList = @([pscustomobject]@{ DisplayText = '/help'; CompletionText = '/help' })
                SuggestionNavigationUsed = $true
                InputMode = 'SelectionOnly'
            }
            ConfigureMocks = { }
        }
        @{
            Name = 'Complete-GerberPromptSuggestion fails to apply the selection'
            State = @{
                Buffer = '/tools'
                CursorIndex = 6
                SuggestionIndex = 0
                SuggestionList = @([pscustomobject]@{ DisplayText = '/tools'; CompletionText = '/tools' })
                SuggestionNavigationUsed = $true
                InputMode = 'SelectionOnly'
            }
            ConfigureMocks = { Mock Complete-GerberPromptSuggestion { $false } }
        }
    ) {
        param($Name, $State, $ConfigureMocks)
        $null = $Name

        Mock Write-GerberPromptTrace {}
        & $ConfigureMocks

        (Submit-GerberPromptSuggestion -State $State) | Should -BeFalse
    }

    It 'enters subcommand scope only for root submenu commands' {
        $state = @{
            Buffer = '/tools'
            CursorIndex = 6
            SuggestionIndex = 0
            SuggestionList = @()
            SuggestionMode = 'Root'
        }
        Mock Write-GerberPromptTrace {}

        (Enter-GerberPromptSubcommandScope -State $state) | Should -BeTrue
        $state.SuggestionMode | Should -Be 'Subcommand'
        $state.SuggestionCommandName | Should -Be 'tools'
        $state.Buffer | Should -Be '/tools '
        (Test-GerberPromptSubcommandEntry -Resolution (Resolve-GerberCommand -InputText '/help')) | Should -BeFalse
    }

    It 'returns false from subcommand scope entry when mode is not Root' {
        $state = @{
            Buffer = '/tools create-uuid'
            CursorIndex = 18
            SuggestionMode = 'Subcommand'
            SuggestionList = @()
            SuggestionIndex = 0
        }
        Mock Write-GerberPromptTrace {}

        (Enter-GerberPromptSubcommandScope -State $state) | Should -BeFalse
    }

    It 'returns false from subcommand scope entry when command is missing from the catalog' {
        $state = @{
            Buffer = '/tools'
            CursorIndex = 6
            SuggestionMode = 'Root'
            SuggestionList = @()
            SuggestionIndex = 0
        }
        Mock Resolve-GerberCommand { [pscustomobject]@{ IsValid = $true; Name = 'tools'; Arguments = @(); Suggestions = @() } }
        Mock Test-GerberPromptSubcommandEntry { $true }
        Mock Get-GerberRegisteredCommand { $null }
        Mock Write-GerberPromptTrace {}

        (Enter-GerberPromptSubcommandScope -State $state) | Should -BeFalse
    }

    It 'rejects subcommand entry when the resolution is not valid' {
        (Test-GerberPromptSubcommandEntry -Resolution (Resolve-GerberCommand -InputText 'zzz')) | Should -BeFalse
    }

    It 'rejects subcommand entry when the resolved command has no name' {
        $resolution = [pscustomobject]@{ IsValid = $true; Name = $null; Arguments = @(); Suggestions = @() }

        (Test-GerberPromptSubcommandEntry -Resolution $resolution) | Should -BeFalse
    }

    It 'rejects subcommand entry when the command is not in the catalog' {
        $resolution = [pscustomobject]@{ IsValid = $true; Name = 'unknown'; Arguments = @(); Suggestions = @() }
        Mock Get-GerberRegisteredCommand { $null }

        (Test-GerberPromptSubcommandEntry -Resolution $resolution) | Should -BeFalse
    }

    It 'routes prompt keys through the suggestion, cursor, and buffer handlers' {
        $state = @{
            Buffer = '/help'
            CursorIndex = 5
            SuggestionIndex = 0
            SuggestionList = @()
            SuggestionMode = 'Root'
        }
        Mock Sync-GerberPromptSuggestion {}

        Invoke-GerberCommandPromptKey -State $state -Key ([System.ConsoleKeyInfo]::new('x', [System.ConsoleKey]::X, $false, $false, $false))

        Should -Invoke Sync-GerberPromptSuggestion -Times 1
    }

    It 'returns the current index unchanged when there are no suggestions to cycle through' {
        (Move-GerberSuggestionSelection -CurrentIndex 0 -SuggestionCount 0 -Direction 'Next') | Should -Be 0
    }
}

Describe 'Invoke-GerberEnterSubmit' {
    It 'executes the highlighted nested action command from root search on Enter' {
        $enterKey = [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
        $state = @{
            Buffer = 'uuid'
            CursorIndex = 4
            SuggestionIndex = 0
            SuggestionList = @([pscustomobject]@{
                    DisplayText = '/tools create-uuid'
                    CompletionText = '/tools create-uuid'
                    PreviewText = 'Generate a GUID'
                })
            SuggestionMode = 'Root'
            SuggestionNavigationUsed = $false
            TrimResult = $true
        }
        Mock Write-GerberPromptTrace {}
        Mock Complete-GerberPrompt {}

        $result = Invoke-GerberEnterSubmit -State $state -Key $enterKey

        $result.ShouldContinue | Should -BeFalse
        $result.ShouldSubmit | Should -BeTrue
        $result.Value | Should -Be '/tools create-uuid'
    }

    It 'enters the tools submenu when Enter applies a highlighted root command suggestion' {
        $enterKey = [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
        $state = Get-GerberRootSuggestionSelectionState
        Mock Write-GerberPromptTrace {}
        Mock Complete-GerberPrompt {}

        $result = Invoke-GerberEnterSubmit -State $state -Key $enterKey

        $result.ShouldContinue | Should -BeTrue
        $result.ShouldSubmit | Should -BeFalse
        $state.SuggestionMode | Should -Be 'Subcommand'
        $state.SuggestionCommandName | Should -Be 'tools'
        $state.Buffer | Should -Be '/tools '
        $state.SuggestionList[0].DisplayText | Should -Be '/tools base-64'
    }

    It 'returns ShouldContinue=false and ShouldSubmit=false for non-Enter keys' {
        $state = @{
            Buffer = '/help'
            CursorIndex = 5
            SuggestionList = @()
            SuggestionMode = 'Root'
            SuggestionNavigationUsed = $false
            TrimResult = $true
        }
        Mock Write-GerberPromptTrace {}

        $result = Invoke-GerberEnterSubmit -State $state -Key ([System.ConsoleKeyInfo]::new('a', [System.ConsoleKey]::A, $false, $false, $false))

        $result.ShouldContinue | Should -BeFalse
        $result.ShouldSubmit | Should -BeFalse
    }

    It 'submits the buffer directly when Enter is pressed without a subcommand trigger' {
        $enterKey = [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
        $state = @{
            Buffer = '/help'
            CursorIndex = 5
            SuggestionIndex = 0
            SuggestionList = @()
            SuggestionMode = 'Root'
            SuggestionNavigationUsed = $false
            TrimResult = $true
        }
        Mock Write-GerberPromptTrace {}
        Mock Complete-GerberPrompt {}

        $result = Invoke-GerberEnterSubmit -State $state -Key $enterKey

        $result.ShouldSubmit | Should -BeTrue
        $result.Value | Should -Be '/help'
    }

    It 'returns ShouldContinue=true when Enter enters subcommand scope without a prior suggestion navigation' {
        $enterKey = [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
        $state = @{
            Buffer = '/tools'
            CursorIndex = 6
            SuggestionIndex = 0
            SuggestionList = @()
            SuggestionMode = 'Root'
            SuggestionNavigationUsed = $false
            TrimResult = $true
        }
        Mock Write-GerberPromptTrace {}
        Mock Sync-GerberPromptSuggestion {}

        $result = Invoke-GerberEnterSubmit -State $state -Key $enterKey

        $result.ShouldContinue | Should -BeTrue
        $result.ShouldSubmit | Should -BeFalse
        $state.SuggestionMode | Should -Be 'Subcommand'
    }

    It 'keeps Up and Down navigation cycling through root suggestions' {
        Move-GerberSuggestionSelection -CurrentIndex 0 -SuggestionCount 3 -Direction 'Next' | Should -Be 1
        Move-GerberSuggestionSelection -CurrentIndex 0 -SuggestionCount 3 -Direction 'Previous' | Should -Be 2
    }
}

Describe 'Sync-GerberPromptSuggestion' {
    It 'returns to the root suggestions after deleting back past a submenu prefix' {
        $state = @{
            Buffer = '/to'
            CursorIndex = 3
            SuggestionMode = 'Subcommand'
            SuggestionCommandName = 'tools'
            SuggestionSubcommandTable = [ordered]@{
                'create-uuid' = 'Generate a UUID and copy it to the clipboard when possible'
                'base-64' = 'Open the Base64 text utility'
            }
            InitialBuffer = '/tools '
            PromptHintText = '[create-uuid|base-64]'
            SuggestionIndex = 0
            SuggestionList = @()
            SuggestionNavigationUsed = $false
        }
        Mock Write-GerberPromptTrace {}

        Sync-GerberPromptSuggestion -State $state

        $state.SuggestionMode | Should -Be 'Root'
        $state.SuggestionCommandName | Should -BeNullOrEmpty
        $state.SuggestionList.DisplayText | Should -Contain '/tools'
    }

    It 'uses the static suggestion list without filtering when mode is Static' {
        $state = @{
            Buffer = 'anything'
            CursorIndex = 8
            SuggestionMode = 'Static'
            StaticSuggestionList = @([pscustomobject]@{ DisplayText = '/help'; CompletionText = '/help' })
            SuggestionIndex = 0
            SuggestionList = @()
            SuggestionNavigationUsed = $false
        }
        Mock Write-GerberPromptTrace {}

        Sync-GerberPromptSuggestion -State $state

        $state.SuggestionList | Should -Not -BeNullOrEmpty
    }
}
