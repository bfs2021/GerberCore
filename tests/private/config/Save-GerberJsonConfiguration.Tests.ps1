BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Save-GerberJsonConfiguration' -Tag 'PluginJson' {
    It 'refuses serialization truncation while preserving the existing file' {
        $path = Join-Path $TestDrive 'Gerber.Example.json'
        [System.IO.File]::WriteAllText($path, '{"original":true}')
        $value = @{ leaf = 'deep' }
        foreach ($depth in 1..105) { $value = @{ child = $value } }
        { Save-GerberJsonConfiguration -Path $path -Value $value } | Should -Throw
        [System.IO.File]::ReadAllText($path) | Should -Be '{"original":true}'
    }
}
