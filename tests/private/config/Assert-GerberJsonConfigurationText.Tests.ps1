BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Assert-GerberJsonConfigurationText' -Tag 'PluginJson' {
    It 'accepts nested JSON throughout the supported serialization depth' {
        $json = ('[' * 70) + '1' + (']' * 70)
        { Assert-GerberJsonConfigurationText -Json $json -Path 'Gerber.Plugin.json' } | Should -Not -Throw
    }

    It 'reports malformed JSON without including configuration contents' {
        $errorRecord = $null
        try { Assert-GerberJsonConfigurationText -Json '{"private":"sensitive-value",' -Path 'Gerber.Plugin.json' }
        catch { $errorRecord = $_ }
        $errorRecord.Exception.Message | Should -Match 'Gerber.Plugin.json'
        $errorRecord.Exception.ToString() | Should -Not -Match 'sensitive-value'
    }
}
