BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberRegisteredCommand' -Tag 'ActiveCommandTree' {
    BeforeEach {
        $script:receivedCoreCommand = $null
        $script:coreHandlerExtraArgumentCount = $null
    }

    It 'invokes the registered interactive root handlers and returns false' -ForEach @(
        @{ Name = 'tools'; MockTarget = 'Show-GerberToolsView' }
        @{ Name = 'secrets'; MockTarget = 'Show-GerberSecretsView' }
        @{ Name = 'help'; MockTarget = 'Show-GerberHelpView' }
    ) {
        param($Name, $MockTarget)

        Mock Show-GerberToolsView {}
        Mock Show-GerberSecretsView {}
        Mock Show-GerberHelpView {}

        $result = Invoke-GerberRegisteredCommand `
            -CommandDefinition (Get-GerberRegisteredCommand -Name $Name) `
            -Command ([pscustomobject]@{ Name = $Name; Arguments = @() })

        $result | Should -BeFalse
        Should -Invoke $MockTarget -Times 1
    }

    It 'dispatches a conditional shared container through generic navigation instead of its obsolete handler' {
        Mock Show-GerberRegisteredSubcommandMenu { $true }
        $definition = [pscustomobject]@{ Name = 'generic nested'; IsContainer = $true; Handler = { throw 'Obsolete handler' } }
        Invoke-GerberRegisteredCommand -CommandDefinition $definition -Command ([pscustomobject]@{ Arguments = @() }) | Should -BeTrue
        Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 1 -ParameterFilter {
            $CommandName -eq 'generic nested' -and $AutoSelectFirstSuggestionOnSubmit -and $PropagateExit
        }
    }

    It 'invokes the registered exit handler and returns true' {
        Mock Write-GerberScreenLine {}

        $result = Invoke-GerberRegisteredCommand `
            -CommandDefinition (Get-GerberRegisteredCommand -Name 'exit') `
            -Command ([pscustomobject]@{ Name = 'exit'; Arguments = @() })

        $result | Should -BeTrue
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq 'Exiting Gerber.' }
    }

    It 'throws when the command definition does not expose a handler scriptblock' {
        {
            Invoke-GerberRegisteredCommand `
                -CommandDefinition ([pscustomobject]@{ Name = 'broken'; Handler = 'Show-Broken'; Subcommands = [ordered]@{} }) `
                -Command ([pscustomobject]@{ Name = 'broken'; Arguments = @() })
        } | Should -Throw "Gerber command 'broken' does not define a valid handler scriptblock."
    }

    It 'returns false when the registered handler does not return a value' {
        $result = Invoke-GerberRegisteredCommand `
            -CommandDefinition ([pscustomobject]@{ Name = 'empty'; Handler = { param() }; Subcommands = [ordered]@{} }) `
            -Command ([pscustomobject]@{ Name = 'empty'; Arguments = @() })

        $result | Should -BeFalse
    }

    It 'throws when the registered handler returns an unsupported result type' {
        {
            Invoke-GerberRegisteredCommand `
                -CommandDefinition ([pscustomobject]@{ Name = 'broken'; Handler = { param() 'nope' }; Subcommands = [ordered]@{} }) `
                -Command ([pscustomobject]@{ Name = 'broken'; Arguments = @() })
        } | Should -Throw "Gerber command 'broken' returned an invalid handler result type 'System.String'."
    }

    It 'passes only the command to core handlers' {
        $commandDefinition = [pscustomobject]@{
            Name      = 'core-command'
            OwnerName = 'Gerber.Core'
            OwnerType = 'Core'
            Handler   = {
                param([pscustomobject]$Command)

                $script:receivedCoreCommand = $Command
                $script:coreHandlerExtraArgumentCount = $args.Count
                return $false
            }
            Subcommands = [ordered]@{}
        }
        $command = [pscustomobject]@{ Name = 'core-command'; Arguments = @() }

        $result = Invoke-GerberRegisteredCommand -CommandDefinition $commandDefinition -Command $command

        $result | Should -BeFalse
        $script:receivedCoreCommand | Should -Be $command
        $script:coreHandlerExtraArgumentCount | Should -Be 0
    }
}
