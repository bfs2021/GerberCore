BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberCoreCommandDefinitionList' -Tag 'G4A7' {
    BeforeEach {
        Mock Test-GerberUpdateInteractive { $true }
    }

    It 'returns the core root and nested command definitions in deterministic order' {
        $definitionList = @(Get-GerberCoreCommandDefinitionList)

        $definitionList.Name | Should -Be @(
            'tools',
            'plugins',
            'secrets',
            'update',
            'help',
            'exit',
            'tools create-uuid',
            'tools base-64',
            'plugins list',
            'plugins info',
            'plugins enable',
            'plugins disable',
            'plugins create',
            'update list',
            'update policy'
        )
    }

    It 'dispatches the root update command through the shared registry contract' {
        $definition = Get-GerberCoreCommandDefinitionList | Where-Object Name -EQ 'update'
        Mock Show-GerberRegisteredSubcommandMenu {}
        (& $definition.Handler ([pscustomobject]@{ Name = 'update'; Arguments = @() })) | Should -BeFalse
        Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 1 -ParameterFilter { $CommandName -eq 'update' }
        (Get-GerberRegisteredCommand -Name update).Subcommands.Keys | Should -Be @('list', 'policy')
    }

    It 'dispatches list through a discoverable leaf' {
        $definition = Get-GerberCoreCommandDefinitionList | Where-Object Name -EQ 'update list'
        $definition | Should -Not -BeNullOrEmpty
        Mock Show-GerberUpdateView {}
        (& $definition.Handler ([pscustomobject]@{ Name = 'update list'; Arguments = @() })) | Should -BeFalse
        Should -Invoke Show-GerberUpdateView -Times 1
    }

    It 'carries the update exit signal through leaf, update and root menu dispatch' {
        Mock Show-GerberUpdateView { $true }
        Mock Read-GerberSubcommandPrompt { throw 'Exit must not reopen the submenu' }
        $leaf = Get-GerberRegisteredCommand -Name 'update list'
        @(Invoke-GerberRegisteredCommand -CommandDefinition $leaf `
            -Command ([pscustomobject]@{ Arguments = @() })) | Should -Be @($true)
        $command = Resolve-GerberCommand -InputText '/update list' -ActionList (Get-GerberActionList)
        @(Invoke-GerberMenuCommand -Command $command) | Should -Be @($true)
    }

    It 'dispatches policy through a discoverable leaf' {
        $definition = Get-GerberCoreCommandDefinitionList | Where-Object Name -EQ 'update policy'
        $definition | Should -Not -BeNullOrEmpty
        Mock Show-GerberUpdatePolicyView {}
        (& $definition.Handler ([pscustomobject]@{ Name = 'update policy'; Arguments = @() })) | Should -BeFalse
        Should -Invoke Show-GerberUpdatePolicyView -Times 1
    }

    It 'routes resolved slash input through the root handler to policy rather than discovering updates' {
        Mock Show-GerberUpdatePolicyView {}
        Mock Show-GerberUpdateView { throw 'Policy must not discover updates' }
        Mock Read-GerberSubcommandPrompt { throw (Get-GerberMenuEscapeException) }
        $command = Resolve-GerberCommand -InputText '/update policy' -ActionList (Get-GerberActionList)
        Invoke-GerberMenuCommand -Command $command | Should -BeFalse
        Should -Invoke Show-GerberUpdatePolicyView -Times 1
        Should -Invoke Show-GerberUpdateView -Times 0
    }

    It 'exposes representative metadata and subcommand structure' {
        $definitionList = @(Get-GerberCoreCommandDefinitionList)
        $helpCommand = $definitionList | Where-Object Name -EQ 'help'
        $exitCommand = $definitionList | Where-Object Name -EQ 'exit'
        $pluginsCommand = $definitionList | Where-Object Name -EQ 'plugins'
        $pluginsListCommand = $definitionList | Where-Object Name -EQ 'plugins list'
        $pluginsInfoCommand = $definitionList | Where-Object Name -EQ 'plugins info'
        $createUuidCommand = $definitionList | Where-Object Name -EQ 'tools create-uuid'
        $base64Command = $definitionList | Where-Object Name -EQ 'tools base-64'

        $definitionList.Name | Should -Not -Contain 'repository'
        $definitionList.Name | Should -Not -Contain 'branch'
        $definitionList.Name | Should -Not -Contain 'list'
        $definitionList.Name | Should -Not -Contain 'pipelines'
        $pluginsCommand.Description | Should -Be 'Show Gerber plugin status and manage plugin activation'
        $pluginsCommand.Handler.ToString() | Should -Match 'Show-GerberPluginsView'
        $pluginsCommand.Subcommands.Count | Should -Be 0
        $helpCommand.Description | Should -Be 'Show the built-in command help'
        $helpCommand.Handler.ToString() | Should -Match 'Show-GerberHelpView'
        $exitCommand.Description | Should -Be 'Exit the interactive Gerber session'
        $pluginsListCommand.Description | Should -Be 'List discovered and persisted Gerber plugins'
        $pluginsInfoCommand.Description | Should -Be 'Show detailed plugin information by GUID or unique module name'
        $createUuidCommand.Description | Should -Be 'Generate a UUID and copy it to the clipboard when possible'
        $createUuidCommand.Subcommands.Count | Should -Be 0
        $base64Command.Subcommands.Keys | Should -Be @('encode', 'decode')
        $definitionList.Name | Should -Not -Contain 'repository create'
        $definitionList.Name | Should -Not -Contain 'pipelines tags'
    }

    It 'executes representative handler scriptblocks for help, exit, and registered subcommands' {
        $definitionList = @(Get-GerberCoreCommandDefinitionList)
        $toolsCommand = $definitionList | Where-Object Name -EQ 'tools'
        $pluginsCommand = $definitionList | Where-Object Name -EQ 'plugins'
        $helpCommand = $definitionList | Where-Object Name -EQ 'help'
        $exitCommand = $definitionList | Where-Object Name -EQ 'exit'
        $pluginsListCommand = $definitionList | Where-Object Name -EQ 'plugins list'
        $pluginsInfoCommand = $definitionList | Where-Object Name -EQ 'plugins info'
        $createUuidCommand = $definitionList | Where-Object Name -EQ 'tools create-uuid'
        $base64Command = $definitionList | Where-Object Name -EQ 'tools base-64'
        Mock Show-GerberToolsView {}
        Mock Show-GerberPluginsView {}
        Mock Show-GerberHelpView {}
        Mock Write-GerberScreenLine {}
        Mock Invoke-GerberPluginsListCommand {}
        Mock Invoke-GerberPluginsInfoCommand {}
        Mock Show-GerberCreateUuidTool {}
        Mock Show-GerberBase64Tool {}

        (& $toolsCommand.Handler ([pscustomobject]@{ Arguments = @() })) | Should -BeFalse
        (& $pluginsCommand.Handler ([pscustomobject]@{ Arguments = @() })) | Should -BeFalse
        (& $helpCommand.Handler) | Should -BeFalse
        (& $exitCommand.Handler) | Should -BeTrue
        (& $pluginsListCommand.Handler ([pscustomobject]@{ Arguments = @() })) | Should -BeFalse
        (& $pluginsInfoCommand.Handler ([pscustomobject]@{ Arguments = @('Gerber.TestPlugin') })) | Should -BeFalse
        (& $createUuidCommand.Handler ([pscustomobject]@{ Arguments = @() })) | Should -BeFalse
        (& $base64Command.Handler ([pscustomobject]@{ Arguments = @('encode') })) | Should -BeFalse

        Should -Invoke Show-GerberToolsView -Times 1
        Should -Invoke Show-GerberPluginsView -Times 1
        Should -Invoke Show-GerberHelpView -Times 1
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -eq 'Exiting Gerber.' }
        Should -Invoke Invoke-GerberPluginsListCommand -Times 1 -ParameterFilter { $Command.Arguments.Count -eq 0 }
        Should -Invoke Invoke-GerberPluginsInfoCommand -Times 1 -ParameterFilter { $Command.Arguments[0] -eq 'Gerber.TestPlugin' }
        Should -Invoke Show-GerberCreateUuidTool -Times 1
        Should -Invoke Show-GerberBase64Tool -Times 1 -ParameterFilter { $Command.Arguments[0] -eq 'encode' }
    }
}
Describe 'Shared update command descriptions' -Tag 'G4A9UI' {
    It 'describes Core and plugin updates and their shared policy without implying startup plugin discovery' {
        $definitions = @(Get-GerberCoreCommandDefinitionList)
        ($definitions | Where-Object Name -EQ 'update').Description | Should -Match 'Core and plugin'
        ($definitions | Where-Object Name -EQ 'update list').Description | Should -Match 'Core and.*plugin'
        ($definitions | Where-Object Name -EQ 'update policy').Description | Should -Match 'shared.*update channel'
    }
}
