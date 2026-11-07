BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberPropertiesData' {
    It 'reads the shared Properties.json file into the expected generic top-level structure' {
        $result = Get-GerberPropertiesData

        $result | Should -BeOfType [hashtable]
        $result.Keys | Should -Not -Contain 'ado'
        $result.HttpConnectionTimeoutSeconds | Should -BeOfType ([System.ValueType])
        $result.HttpOperationTimeoutSeconds | Should -BeOfType ([System.ValueType])
        $result.HttpConnectionTimeoutSeconds | Should -BeGreaterThan 0
        $result.HttpOperationTimeoutSeconds | Should -BeGreaterThan 0
    }

    It 'keeps the bundled resource readable with the required generic sections' {
        $result = Get-GerberPropertiesData

        $result.Keys | Should -Contain 'HttpConnectionTimeoutSeconds'
        $result.Keys | Should -Contain 'HttpOperationTimeoutSeconds'
        $result.Keys | Should -Not -Contain 'patEnvironmentVariable'
    }

    It 'returns the project Properties.json path' {
        (Split-Path -Leaf (Get-GerberPropertiesPath)) | Should -Be 'Properties.json'
    }

    It 'wraps ArgumentException from invalid JSON content in InvalidDataException' {
        Mock Get-Content { throw [System.ArgumentException]::new('Invalid JSON format.') }

        { Get-GerberPropertiesData } | Should -Throw "*could not parse*"
    }

    It 'wraps InvalidOperationException from invalid JSON content in InvalidDataException' {
        Mock Get-Content { throw [System.InvalidOperationException]::new('Invalid JSON state.') }

        { Get-GerberPropertiesData } | Should -Throw "*could not parse*"
    }

    It 'throws FileNotFoundException when Properties.json cannot be located' {
        Mock Test-Path { $false }

        { Get-GerberPropertiesPath } | Should -Throw "*could not locate the settings file*"
    }
}
