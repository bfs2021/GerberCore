BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Assert-GerberPluginConfigurationModuleName' -Tag 'PluginJson' {
    It 'rejects names that could select another directory or the Core filename' -ForEach @(
        @{ Name = '../GerberCore' }
        @{ Name = 'Gerber.Other/../../GerberCore' }
        @{ Name = 'Gerber.Other\..\GerberCore' }
        @{ Name = 'GerberCore' }
    ) {
        { Assert-GerberPluginConfigurationModuleName -ModuleName $Name } | Should -Throw '*module name*'
    }
}
