# Cross-cutting registry publication, discovery and lifecycle behavior requires the real
# registry collaborators; built-module validation also runs this contract via Test-NovaBuild.
BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Active command tree' -Tag 'ActiveCommandTree' {
    BeforeEach {
        Clear-GerberCommandRegistry
        $script:builder = [pscustomobject]@{
            CommandList = [System.Collections.Generic.List[object]]::new()
            PluginList = [System.Collections.Generic.List[object]]::new()
            GerberVersion = [System.Management.Automation.SemanticVersion]::Parse('0.2.1')
        }
        Add-GerberOwnedCommandDefinitionList -RegisteredCommandList $builder.CommandList `
            -CommandDefinitionList (Get-GerberCoreCommandDefinitionList) -OwnerName Gerber.Core -OwnerType Core
    }

    It 'removes all four historical product roots without contributions and keeps standalone Core leaves' {
        Publish-GerberCommandRegistryState -RegistryBuilder $builder
        foreach ($root in @('branch', 'list', 'pipelines', 'repository')) {
            Get-GerberRegisteredCommand -Name $root | Should -BeNullOrEmpty
            Get-GerberActionList | Should -Not -Contain $root
        }
        Get-GerberActionList | Should -Contain help
        Get-GerberActionList | Should -Contain exit
        Get-GerberRegisteredCommand -Name 'tools create-uuid' | Should -Not -BeNullOrEmpty
    }

    It 'materializes only contributed ancestors and prunes a generic empty intermediate menu' {
        $definitions = @(
            [pscustomobject]@{ Name = 'repository alpha'; Description = 'Alpha'; Handler = { $false }; Subcommands = @{} }
            [pscustomobject]@{ Name = 'repository empty'; Description = 'Empty'; Handler = { throw 'Menu-only handler must not run' }; IsContainer = $true; Subcommands = @{} }
        )
        Add-GerberOwnedCommandDefinitionList -RegisteredCommandList $builder.CommandList `
            -CommandDefinitionList $definitions -OwnerName Gerber.GenericOnePlugin -OwnerType Plugin
        Publish-GerberCommandRegistryState -RegistryBuilder $builder
        Get-GerberActionList | Should -Contain repository
        Get-GerberActionList | Should -Not -Contain branch
        Get-GerberRegisteredCommand -Name 'repository empty' | Should -BeNullOrEmpty
        (Get-GerberRegisteredCommand -Name repository).Subcommands.Keys | Should -Be @('alpha')
    }

    It 'exposes only the contributed <Root> root across menu, suggestions, help and direct resolution' -ForEach @(
        @{ Root = 'branch' }, @{ Root = 'list' }, @{ Root = 'pipelines' }, @{ Root = 'repository' }
    ) {
        $definition = [pscustomobject]@{ Name = "$Root leaf"; Description = 'Generic leaf'; Handler = { $false }; Subcommands = @{} }
        Add-GerberOwnedCommandDefinitionList -RegisteredCommandList $builder.CommandList `
            -CommandDefinitionList @($definition) -OwnerName Gerber.GenericOnePlugin -OwnerType Plugin
        Publish-GerberCommandRegistryState -RegistryBuilder $builder
        $catalog = Get-GerberCommandCatalog -ActionList (Get-GerberActionList)
        $catalog[$Root].Subcommands.Keys | Should -Be @('leaf')
        (Resolve-GerberCommand "/$Root").Suggestions.DisplayText | Should -Be @("/$Root leaf")
        Get-GerberHelpRootCommandLineList | Should -Contain "  /$Root Open the /$Root menu"
        Get-GerberHelpNestedCommandLineList | Should -Contain "  /$Root leaf Generic leaf"
        (Resolve-GerberCommand "/$Root leaf").IsValid | Should -BeTrue
        foreach ($absent in @('branch', 'list', 'pipelines', 'repository') | Where-Object { $_ -ne $Root }) {
            $catalog.Keys | Should -Not -Contain $absent
            Get-GerberRegisteredCommand -Name $absent | Should -BeNullOrEmpty
            (Resolve-GerberCommand "/$absent").IsValid | Should -BeFalse
        }
    }

    It 'keeps a shared root for the other contributor, removes the last root and restores without duplicates' {
        foreach ($name in @('alpha', 'beta')) {
            $owner = "Gerber.Generic$name`Plugin"
            $definition = [pscustomobject]@{ Name = "repository $name"; Description = $name; Handler = { $false }; Subcommands = @{} }
            Add-GerberOwnedCommandDefinitionList -RegisteredCommandList $builder.CommandList `
                -CommandDefinitionList @($definition) -OwnerName $owner -OwnerType Plugin
            $builder.PluginList.Add([pscustomobject]@{ Name = $owner; Guid = $name })
        }
        Publish-GerberCommandRegistryState -RegistryBuilder $builder
        Unregister-GerberPlugin -Guid alpha
        (Get-GerberRegisteredCommand -Name repository).Subcommands.Keys | Should -Be @('beta')
        Get-GerberRegisteredCommand -Name 'repository alpha' | Should -BeNullOrEmpty
        Unregister-GerberPlugin -Guid beta
        Get-GerberRegisteredCommand -Name repository | Should -BeNullOrEmpty
        $restored = Copy-GerberPluginRegistrationBuilder -State (Get-GerberRegisteredCommandRegistryState)
        Add-GerberOwnedCommandDefinitionList -RegisteredCommandList $restored.CommandList `
            -CommandDefinitionList @([pscustomobject]@{ Name = 'repository beta'; Description = 'Beta'; Handler = { $false }; Subcommands = @{} }) `
            -OwnerName Gerber.GenericbetaPlugin -OwnerType Plugin
        Publish-GerberCommandRegistryState -RegistryBuilder $restored
        @(Get-GerberCommandRegistry | Where-Object Name -EQ repository).Count | Should -Be 1
        (Get-GerberRegisteredCommand -Name repository).Subcommands.Keys | Should -Be @('beta')
    }
}
