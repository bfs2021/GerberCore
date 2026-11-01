BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'ConvertTo-GerberUserConfigurationJson' -Tag 'PluginJson' {
    It 'serializes explicit null and unknown fields without adding platform metadata' {
        (ConvertTo-GerberUserConfigurationJson -Configuration $null) | Should -Be 'null'
        $json = ConvertTo-GerberUserConfigurationJson -Configuration @{ unknown = @(1, 2) }
        $value = ConvertFrom-Json -InputObject $json -AsHashtable
        $value.Keys | Should -Be @('unknown')
        $value.unknown | Should -Be @(1, 2)
    }
}
