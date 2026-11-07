BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Test-GerberConfigurationTransitionValueEqual' -Tag 'PluginJson' {
    It 'distinguishes null and array ordering when checking transfer completeness' {
        (Test-GerberConfigurationTransitionValueEqual -First $null -Second @{}) | Should -BeFalse
        (Test-GerberConfigurationTransitionValueEqual -First @(1, 2) -Second @(2, 1)) | Should -BeFalse
        (Test-GerberConfigurationTransitionValueEqual -First $null -Second $null) | Should -BeTrue
    }
}
