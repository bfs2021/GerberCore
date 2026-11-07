BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Write-GerberJsonConfiguration' -Tag 'PluginJson' {
    It 'cleans a staged file after access failure and never exposes backend values' {
        $path = Join-Path $TestDrive 'Gerber.Example.json'
        [System.IO.File]::WriteAllText($path, '{}')
        Mock Protect-GerberUserConfigurationFile { throw [System.UnauthorizedAccessException]::new('sensitive-value') }
        try { Write-GerberJsonConfiguration -Path $path -Json '{"new":true}' }
        catch { $_.Exception.ToString() | Should -Not -Match 'sensitive-value' }
        [System.IO.File]::ReadAllText($path) | Should -Be '{}'
        @(Get-ChildItem $TestDrive -Filter '*.tmp') | Should -BeNullOrEmpty
    }
}
