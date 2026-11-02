# ActiveCommandTree.Tests.ps1 owns the cross-cutting publication, lifecycle and
# discovery contract: the published tree spans registration and shared catalogs.
BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/private/cli/Publish-GerberCommandRegistryState.ps1')
    . (Join-Path $PSScriptRoot '../../../src/private/cli/Select-GerberActiveCommandDefinitionList.ps1')
}

Describe 'Publish-GerberCommandRegistryState' -Tag 'ActiveCommandTree' {
    It 'publishes the active tree while preserving plugin and runtime metadata' {
        Mock Select-GerberActiveCommandDefinitionList { @([pscustomobject]@{ Name = 'active' }) }
        $builder = [pscustomobject]@{
            CommandList = [System.Collections.Generic.List[object]]::new()
            PluginList = [System.Collections.Generic.List[object]]::new()
            GerberVersion = [version]'1.0'
        }
        Publish-GerberCommandRegistryState -RegistryBuilder $builder
        $script:GerberCommandRegistryState.CommandList.Name | Should -Be @('active')
        $script:GerberCommandRegistryState.GerberVersion | Should -Be '1.0'
        $script:GerberCommandRegistryState.PluginList | Should -BeNullOrEmpty
    }
}
