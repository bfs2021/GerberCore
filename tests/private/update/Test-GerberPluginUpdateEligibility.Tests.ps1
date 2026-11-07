BeforeAll {
    . (Join-Path $PSScriptRoot '../../TestHelpers/PluginUpdate.TestSupport.ps1')
}

Describe 'Test-GerberPluginUpdateEligibility' -Tag 'G4A9' {
    It 'requires all installed association, approval and enabled conditions together' {
        $entry = Get-TestPluginUpdateEntry
        Test-GerberPluginUpdateEligibility $entry | Should -BeTrue
        $entry.IsAssociated = $false
        Test-GerberPluginUpdateEligibility $entry | Should -BeFalse
    }
}
