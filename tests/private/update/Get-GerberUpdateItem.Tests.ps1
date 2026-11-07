BeforeAll {
    . (Join-Path $PSScriptRoot '../../TestHelpers/PluginUpdate.TestSupport.ps1')
}

Describe 'Get-GerberUpdateItem' -Tag 'G4A9' {
    It 'retains the live Core state rather than copying or serializing its plan' {
        $state = Get-TestCoreUpdateState
        $item = Get-GerberUpdateItem $state
        [object]::ReferenceEquals($item.State, $state) | Should -BeTrue
        [object]::ReferenceEquals($item.State.Plan, $state.Plan) | Should -BeTrue
    }
}
