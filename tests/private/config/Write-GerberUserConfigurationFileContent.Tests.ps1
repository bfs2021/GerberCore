BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Write-GerberUserConfigurationFileContent' -Tag 'PluginJson' {
    It 'never overwrites an existing staged file' {
        $path = Join-Path $TestDrive 'existing.tmp'
        [System.IO.File]::WriteAllText($path, 'original')
        { Write-GerberUserConfigurationFileContent -Path $path -Content 'replacement' } | Should -Throw
        [System.IO.File]::ReadAllText($path) | Should -Be 'original'
    }
}
