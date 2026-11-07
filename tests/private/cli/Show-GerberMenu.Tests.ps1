BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberActionList' -Tag 'G4A7' {
    It 'returns only the supported root commands' {
        Get-GerberActionList | Should -Be @('exit', 'help', 'plugins', 'update', 'secrets', 'tools')
    }

    Describe 'Show-GerberHomeScreen' -Tag 'G4A7' {
        It 'renders the startup availability after the root screen redraw' {
            Mock Write-GerberScreenLine {}
            Mock Show-GerberStartupUpdateNotification {}
            Show-GerberHomeScreen
            Should -Invoke Show-GerberStartupUpdateNotification -Times 1
        }
    }

    It 'sorts root commands case-insensitively with a deterministic secondary comparison' {
        Mock Get-GerberCommandRegistry {
            @(
                [pscustomobject]@{ Name = 'beta'; Description = 'Beta'; Handler = { param() $false }; Subcommands = [ordered]@{}; ParentName = $null }
                [pscustomobject]@{ Name = 'Alpha'; Description = 'Alpha'; Handler = { param() $false }; Subcommands = [ordered]@{}; ParentName = $null }
                [pscustomobject]@{ Name = 'alpha'; Description = 'alpha'; Handler = { param() $false }; Subcommands = [ordered]@{}; ParentName = $null }
            )
        }

        Get-GerberActionList | Should -Be @('Alpha', 'alpha', 'beta')
    }
}

Describe 'Read-GerberMenuLoopCommand' {
    It 'resolves a valid root command from the remaining action list' {
        Mock Read-GerberCommand { '/help' }
        Mock Get-GerberRootPromptContext { ConvertTo-GerberCommandPromptContext }

        $result = Read-GerberMenuLoopCommand -ActionList (Get-GerberActionList)

        $result.IsValid | Should -BeTrue
        $result.Name | Should -Be 'help'
    }

    It 'treats removed commands as normal unknown commands' -ForEach @('/config', '/git', '/http', '/status', '/test') {
        $inputText = $_
        Mock Read-GerberCommand { $inputText }
        Mock Get-GerberRootPromptContext { ConvertTo-GerberCommandPromptContext }

        $result = Read-GerberMenuLoopCommand -ActionList (Get-GerberActionList)

        $result.IsValid | Should -BeFalse
        $result.ErrorMessage | Should -Match "Unknown command '$inputText'"
    }
}

Describe 'Invoke-GerberMenuCommand' {
    It 'dispatches through the registered root command definition instead of a name switch' {
        $command = [pscustomobject]@{ Name = 'repository'; Arguments = @() }
        $definition = [pscustomobject]@{
            Name = 'repository'
            Description = 'Review pull requests and create repositories'
            Handler = { param() $false }
            Subcommands = [ordered]@{}
        }
        Mock Get-GerberRegisteredCommand { $definition }
        Mock Invoke-GerberRegisteredCommand { $false }

        $result = Invoke-GerberMenuCommand -Command $command

        $result | Should -BeFalse
        Should -Invoke Get-GerberRegisteredCommand -Times 1 -ParameterFilter { $Name -eq 'repository' }
        Should -Invoke Invoke-GerberRegisteredCommand -Times 1 -ParameterFilter {
            $CommandDefinition.Name -eq 'repository' -and $Command.Name -eq 'repository'
        }
    }

    It 'throws when no registered root command exists for the requested name' {
        Mock Get-GerberRegisteredCommand { $null }

        {
            Invoke-GerberMenuCommand -Command ([pscustomobject]@{ Name = 'unknown'; Arguments = @() })
        } | Should -Throw "Unknown Gerber root command 'unknown'."
    }
}

Describe 'Resolve-GerberMenuLoopException' {
    It 'traces the PowerShell error record stack for recoverable diagnostics' {
        Mock Show-GerberMenuError {}
        Mock Write-GerberPromptTrace {}
        try {
            throw [System.InvalidOperationException]::new('Traceable failure.')
        } catch {
            $errorRecord = $_
        }

        $result = Resolve-GerberMenuLoopException -ErrorRecord $errorRecord

        $result | Should -BeTrue
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter {
            $EventName -eq 'menu-loop-exception' -and
            $Data.ExceptionType -eq 'System.InvalidOperationException' -and
            $Data.ScriptStackTrace -match 'Show-GerberMenu.Tests.ps1'
        }
    }

    It 'keeps Gerber open for recoverable validation errors' {
        Mock Show-GerberMenuError {}

        $result = Resolve-GerberMenuLoopException -Exception ([System.IO.InvalidDataException]::new('Broken input.'))

        $result | Should -BeTrue
        Should -Invoke Show-GerberMenuError -Times 1 -ParameterFilter { $Message -eq 'Broken input.' }
    }

    It 'treats the shared escape exception as local back-navigation' {
        Mock Show-GerberMenuError {}

        $result = Resolve-GerberMenuLoopException -Exception (Get-GerberMenuEscapeException)

        $result | Should -BeTrue
        Should -Invoke Show-GerberMenuError -Times 0
    }

    It 'treats the shared root-navigation exception as local navigation instead of an error' {
        Mock Show-GerberMenuError {}
        Mock Request-GerberVisibleRootPrompt {}
        Mock Clear-GerberPendingConsoleInput {}
        $script:GerberPendingRootNavigationRequested = $true

        $result = Resolve-GerberMenuLoopException -Exception (Get-GerberMenuEscapeException)

        $result | Should -BeTrue
        Should -Invoke Show-GerberMenuError -Times 0
    }

    It 'returns false for stop exceptions without showing an error' {
        Mock Show-GerberMenuError {}

        $result = Resolve-GerberMenuLoopException -Exception ([System.OperationCanceledException]::new('Cancelled'))

        $result | Should -BeFalse
        Should -Invoke Show-GerberMenuError -Times 0
    }

    It 'shows a recoverable error and returns true for unhandled exceptions' {
        Mock Show-GerberMenuError {}

        $result = Resolve-GerberMenuLoopException -Exception ([System.InvalidOperationException]::new('Unexpected failure.'))

        $result | Should -BeTrue
        Should -Invoke Show-GerberMenuError -Times 1
    }
}

Describe 'Show-GerberMenu helper functions' -Tag 'ActiveCommandTree' {
    It 'starts the root menu without depending on the removed test session-state helper' {
        Mock Write-GerberMenuEscapeSequenceReset {}
        Mock Start-GerberScreen {}
        Mock Show-GerberHomeScreen {}
        Mock Invoke-GerberMenuLoopIteration { $true }

        { Show-GerberMenu } | Should -Not -Throw
        Should -Invoke Write-GerberMenuEscapeSequenceReset -Times 1
        Should -Invoke Invoke-GerberMenuLoopIteration -Times 1 -ParameterFilter {
            $ActionList -join ',' -eq 'exit,help,plugins,update,secrets,tools'
        }
    }

    It 'shows menu errors and swallows local escape during continue' {
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue { throw (Get-GerberMenuEscapeException) }

        { Show-GerberMenuError -Message 'Broken.' } | Should -Not -Throw
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Title -eq 'Error' -and $Text -eq 'Broken.' }
    }

    It 'unwraps wrapped exceptions down to the display exception' {
        $inner = [System.InvalidOperationException]::new('Inner failure.')
        $wrapped = [System.Management.Automation.RuntimeException]::new('Wrapper', $inner)

        (Get-GerberMenuDisplayException -Exception $wrapped).Message | Should -Be 'Inner failure.'
        (Test-GerberWrappedMenuException -Exception $wrapped) | Should -BeTrue
        (Test-GerberWrappedMenuException -Exception $inner) | Should -BeFalse
    }

    It 'detects stop exceptions for local termination' {
        (Test-GerberMenuStopException -Exception ([System.OperationCanceledException]::new('stop'))) | Should -BeTrue
        (Test-GerberMenuStopException -Exception ([System.InvalidOperationException]::new('continue'))) | Should -BeFalse
    }

    It 'formats recoverable menu errors with or without extra detail' {
        (Format-GerberMenuRecoverableError -Exception ([System.InvalidOperationException]::new('Bad input.'))) | Should -Match 'Bad input\.'
        (Format-GerberMenuRecoverableError -Exception ([System.InvalidOperationException]::new(''))) | Should -Be 'Gerber could not complete that action.'
    }

    It 'formats access-denied details through the shared path parser' {
        $exception = [System.UnauthorizedAccessException]::new("Access to the path '/repo/.gerber/config.json' is denied.")

        (Get-GerberMenuErrorDetail -Exception $exception) | Should -Be "Access to '/repo/.gerber/config.json' was denied. Check file or directory permissions and try again."
        (Format-GerberAccessDeniedMessage -Message 'Access denied.') | Should -Be 'Access was denied. Check file or directory permissions and try again.'
        (Get-GerberQuotedPath -Message "Access to '/repo/.gerber/config.json' is denied.") | Should -Be '/repo/.gerber/config.json'
        (Get-GerberQuotedPath -Message 'No quoted path here.') | Should -BeNullOrEmpty
    }

    It 'shows an error and stays in the loop when command resolution is invalid' {
        Mock Read-GerberMenuLoopCommand { [pscustomobject]@{ IsValid = $false; ErrorMessage = 'Unknown command.' } }
        Mock Show-GerberTextBlock {}
        Mock Wait-GerberContinue {}
        Mock Invoke-GerberMenuCommand {}

        $result = Invoke-GerberMenuLoopIteration -ActionList (Get-GerberActionList)

        $result | Should -BeFalse
        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Title -eq 'Error' -and $Text -eq 'Unknown command.' }
        Should -Invoke Invoke-GerberMenuCommand -Times 0
    }

    It 'delegates valid commands to the menu router' {
        Mock Read-GerberMenuLoopCommand { [pscustomobject]@{ IsValid = $true; Name = 'help'; Arguments = @() } }
        Mock Invoke-GerberMenuCommand { $true }

        (Invoke-GerberMenuLoopIteration -ActionList (Get-GerberActionList)) | Should -BeTrue
        Should -Invoke Invoke-GerberMenuCommand -Times 1 -ParameterFilter { $Command.Name -eq 'help' }
    }

    It 'writes the Gerber banner and a blank separator line' {
        Mock Write-GerberScreenLine {}

        Show-GerberHomeScreen

        Should -Invoke Write-GerberScreenLine -Times 2
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq 'Gerber - DevOps Multitool' }
    }

    It 'builds the root prompt context with slash-commands hint text' {
        $result = Get-GerberRootPromptContext

        $result.EmptyStateHintText | Should -Match '/ commands'
    }

    It 'returns an empty initial buffer when no pending root chooser restore exists' {
        Remove-Variable -Name 'GerberPendingRootPromptBuffer' -Scope Script -ErrorAction SilentlyContinue

        $result = Get-GerberRootPromptContext

        $result.InitialBuffer | Should -Be ''
    }

    It 'restores the visible root chooser once after a submenu back-navigation request' {
        $script:GerberPendingRootPromptBuffer = '/'

        $firstContext = Get-GerberRootPromptContext
        $secondContext = Get-GerberRootPromptContext

        $firstContext.InitialBuffer | Should -Be '/'
        $secondContext.InitialBuffer | Should -Be ''
    }

    It 'identifies PipelineStoppedException as a stop exception' {
        (Test-GerberMenuStopException -Exception ([System.Management.Automation.PipelineStoppedException]::new())) | Should -BeTrue
    }

    It 'stays in the loop when the exception handler returns true' {
        $script:showMenuExceptionCount = 0
        Mock Start-GerberScreen {}
        Mock Show-GerberHomeScreen {}
        Mock Invoke-GerberMenuLoopIteration {
            $script:showMenuExceptionCount++
            if ($script:showMenuExceptionCount -eq 1) {
                throw [System.IO.InvalidDataException]::new('Recoverable error')
            }
            return $true
        }
        Mock Resolve-GerberMenuLoopException { $true }

        { Show-GerberMenu } | Should -Not -Throw
        Should -Invoke Invoke-GerberMenuLoopIteration -Times 2
    }

    It 'rethrows the exception when the handler returns false' {
        Mock Start-GerberScreen {}
        Mock Show-GerberHomeScreen {}
        Mock Invoke-GerberMenuLoopIteration { throw [System.InvalidOperationException]::new('Fatal error') }
        Mock Resolve-GerberMenuLoopException { $false }

        { Show-GerberMenu } | Should -Throw
    }
}
