BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/private/shared/ConvertTo-GerberPluginRepositoryUri.ps1')
}

Describe 'ConvertTo-GerberPluginRepositoryUri' -Tag 'PluginCreateRepository', 'PluginCreateUriCharacterization' {
    Context 'shared absolute URI parsing' {
        It 'returns the known absolute URI unchanged without adding transport policy' -ForEach @(
            @{ Value = 'https://packages.example.org/v3/index.json' }
            @{ Value = 'http://packages.example.org/feed' }
            @{ Value = 'file:///tmp/packages' }
        ) {
            (ConvertTo-GerberPluginRepositoryUri -Value $Value).AbsoluteUri | Should -BeExactly $Value
        }

        It 'preserves invalid-URI exception behavior for <Value>' -ForEach @(
            @{ Value = '' }, @{ Value = $null }, @{ Value = 'relative/feed' }
            @{ Value = 'REPLACE_WITH_REPOSITORY_URI' }
        ) {
            {
                ConvertTo-GerberPluginRepositoryUri -Value $Value
            } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage 'The declared plugin repository URI is invalid.'
        }

        It 'preserves unsafe-component rejection for <Value>' -ForEach @(
            @{ Value = 'https://user:password@example.org/feed' }
            @{ Value = 'https://example.org/feed?token=secret' }
            @{ Value = 'https://example.org/feed#fragment' }
        ) {
            {
                ConvertTo-GerberPluginRepositoryUri -Value $Value
            } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage 'The declared repository URI must not contain credentials, query or fragment.'
        }
    }
}
