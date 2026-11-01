BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Clear-GerberUserConfigurationTemporaryFile' -Tag 'PluginJson' {
    It 'tolerates absent staging paths without touching other configuration' {
        $path = Join-Path $TestDrive 'existing.json'
        [System.IO.File]::WriteAllText($path, '{}')
        Clear-GerberUserConfigurationTemporaryFile -Path $null
        Clear-GerberUserConfigurationTemporaryFile -Path (Join-Path $TestDrive 'absent.tmp')
        [System.IO.File]::ReadAllText($path) | Should -Be '{}'
    }
}
