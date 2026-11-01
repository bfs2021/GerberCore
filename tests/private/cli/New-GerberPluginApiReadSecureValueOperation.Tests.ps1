BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'New-GerberPluginApiReadSecureValueOperation' -Tag 'PluginPlatform' {
    It 'preserves the SecureString instance without converting or trimming its value' {
        $script:secret = [securestring]::new()
        foreach ($character in ' test-only '.ToCharArray()) { $script:secret.AppendChar($character) }
        Mock Read-GerberSecureValue { $script:secret }
        $result = & (New-GerberPluginApiReadSecureValueOperation) 'PAT'
        [object]::ReferenceEquals($result, $script:secret) | Should -BeTrue
    }
}
