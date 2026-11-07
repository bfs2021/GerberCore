BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Protect-GerberUserConfigurationFile' -Tag 'PluginJson' {
    It 'removes group and other access on Unix' -Skip:$IsWindows {
        $path = Join-Path $TestDrive 'private.json'
        [System.IO.File]::WriteAllText($path, '{}')
        Protect-GerberUserConfigurationFile -Path $path
        [System.IO.File]::GetUnixFileMode($path) | Should -Be ([System.IO.UnixFileMode]'UserRead, UserWrite')
    }
}
