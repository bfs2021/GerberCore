BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberUserConfigurationTemporaryPath' -Tag 'PluginJson' {
    It 'keeps concurrent staged writes distinct and beside the destination without creating files' {
        $destination = Join-Path $TestDrive 'GerberCore.json'
        $first = Get-GerberUserConfigurationTemporaryPath -DestinationPath $destination
        $second = Get-GerberUserConfigurationTemporaryPath -DestinationPath $destination
        $first | Should -Not -Be $second
        (Split-Path $first -Parent) | Should -Be $TestDrive
        (Test-Path $first) | Should -BeFalse
    }
}
