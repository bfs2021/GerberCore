BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberConfigurationTransitionPlan' -Tag 'PluginJson' {
    It 'rejects a legacy scalar without creating destination files' {
        $path = Join-Path $TestDrive 'GerberCore.json'
        { Get-GerberConfigurationTransitionPlan -CorePath $path -Original 'scalar' } | Should -Throw '*JSON object*'
        (Get-ChildItem $TestDrive).Count | Should -Be 0
    }
}
