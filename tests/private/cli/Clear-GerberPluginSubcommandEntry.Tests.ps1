BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/private/cli/Clear-GerberPluginSubcommandEntry.ps1')
}

Describe 'Clear-GerberPluginSubcommandEntry' -Tag 'ActiveCommandTree' {
    It 'detaches only the removed child and tolerates absent parents and root definitions' {
        $parent = [pscustomobject]@{ Name = 'generic'; Subcommands = [ordered]@{ one = 'One'; two = 'Two' } }
        Clear-GerberPluginSubcommandEntry -CommandList @($parent) -OwnedCommand ([pscustomobject]@{ ParentName = 'generic'; LeafName = 'one' })
        $parent.Subcommands.Keys | Should -Be @('two')
        Clear-GerberPluginSubcommandEntry -CommandList @() -OwnedCommand ([pscustomobject]@{ ParentName = 'missing'; LeafName = 'one' })
        Clear-GerberPluginSubcommandEntry -CommandList @() -OwnedCommand ([pscustomobject]@{ ParentName = '' })
        $parent.Subcommands.Keys | Should -Be @('two')
    }
}
