BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Read-GerberJsonConfiguration' -Tag 'PluginJson' {
    It 'does not create a missing file and preserves a singleton JSON array' {
        $path = Join-Path $TestDrive 'Gerber.Example.json'
        Read-GerberJsonConfiguration -Path $path | Should -BeNullOrEmpty
        (Test-Path $path) | Should -BeFalse
        [System.IO.File]::WriteAllText($path, '["one"]')
        $result = Read-GerberJsonConfiguration -Path $path
        (ConvertTo-Json -InputObject $result -Compress) | Should -Be '["one"]'
    }

    It 'reports a read failure without including sensitive backend text' {
        $path = Join-Path $TestDrive 'unreadable.json'
        [System.IO.File]::WriteAllText($path, '{}')
        Mock Get-Content { throw [System.IO.IOException]::new('sensitive-backend-value') }
        { Read-GerberJsonConfiguration -Path $path } | Should -Throw '*could not read JSON*'
        try { Read-GerberJsonConfiguration -Path $path } catch {
            $_.Exception.ToString() | Should -Not -Match 'sensitive-backend-value'
        }
    }

    It 'preserves JSON timestamp strings without choosing a date schema' -ForEach @(
        @{ Value = '2026-01-01T00:00:00Z' }
        @{ Value = '2026-01-01T02:00:00+02:00' }
    ) {
        $path = Join-Path $TestDrive 'timestamp.json'
        [System.IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $Value))
        $result = Read-GerberJsonConfiguration -Path $path
        $result | Should -BeOfType ([string])
        $result | Should -BeExactly $Value
    }
}
