BeforeAll {
    . (Join-Path $PSScriptRoot '../../TestHelpers/PluginUpdate.TestSupport.ps1')
}

Describe 'Read-GerberUpdateActivationResponse' -Tag 'G4A9' {
    It 'accepts only a supported protocol and the intended full Core version' {
        $text = '{"Protocol":1,"Status":"Verified","Version":"0.3.0-preview1"}'
        $result = Read-GerberUpdateActivationResponse $text '0.3.0-preview1'
        $result.Status | Should -Be 'Verified'
        $result.Version | Should -Be '0.3.0-preview1'
    }

    It 'fails closed for malformed output, wrong versions and unknown statuses' -ForEach @(
        'provider-token-that-is-not-json',
        '{"Protocol":1,"Status":"Verified","Version":"0.2.0"}',
        '{"Protocol":2,"Status":"Verified","Version":"0.3.0"}',
        '{"Protocol":1,"Status":"Unknown","Version":"0.3.0"}'
    ) {
        $result = Read-GerberUpdateActivationResponse $_ '0.3.0'
        $result.Status | Should -Be 'Unverified'
        ($result | ConvertTo-Json) | Should -Not -Match 'provider-token'
    }
}
