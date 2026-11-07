BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Resolve-GerberPluginConfigPath' -Tag 'PluginJson' {
    It 'refuses a plugin path that collides with the explicitly selected Core file' {
        Mock Resolve-GerberUserConfigPath { Join-Path $TestDrive 'Gerber.Example.json' }
        { Resolve-GerberPluginConfigPath -ModuleName 'Gerber.Example' } | Should -Throw '*Core*'
        (Test-Path (Join-Path $TestDrive 'Gerber.Example.json')) | Should -BeFalse
    }
}
