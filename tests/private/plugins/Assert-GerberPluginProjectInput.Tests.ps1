BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Assert-GerberPluginProjectInput' -Tag 'PluginCreate' {
    It 'requires a useful description' {
        { Assert-GerberPluginProjectInput -Field Description -Value ' ' } | Should -Throw '*description*'
    }

    It 'accepts a namespace not present in the effective registry' {
        { Assert-GerberPluginProjectInput -Field Namespace -Value 'mycompany' } | Should -Not -Throw
    }

    It 'rejects a namespace already owned by an active plugin' {
        Mock Get-GerberCommandRegistry { [pscustomobject]@{ Name = 'mycompany hello' } }
        { Assert-GerberPluginProjectInput -Field Namespace -Value 'mycompany' } | Should -Throw '*already registered*'
    }

    It 'rejects a file used as destination parent' {
        $path = Join-Path $TestDrive 'file'
        Set-Content -LiteralPath $path -Value 'existing user file'
        { Assert-GerberPluginProjectInput -Field ParentPath -Value $path } | Should -Throw '*parent*'
        Get-Content $path | Should -Be 'existing user file'
    }

    Context 'repository input' -Tag 'PluginCreateRepository' {
        It 'rejects blank repository names with local recovery guidance' -ForEach @('', ' ') {
            { Assert-GerberPluginProjectInput -Field RepositoryName -Value $_ } | Should -Throw '*repository name*Esc*'
        }

        It 'accepts a custom repository display name' {
            { Assert-GerberPluginProjectInput -Field RepositoryName -Value 'ExampleFeed' } | Should -Not -Throw
        }

        It 'accepts <Value> for explicit creation metadata' -ForEach @(
            @{ Value = 'https://packages.example.org/feed' }
            @{ Value = 'REPLACE_WITH_REPOSITORY_URI' }
        ) {
            {
                Assert-GerberPluginProjectInput -Field RepositoryUri -Value $Value
            } | Should -Not -Throw
        }

        It 'rejects <Value> with recoverable input guidance' -ForEach @(
            @{ Value = '' }, @{ Value = 'relative-feed' }
            @{ Value = 'https://user:password@example.org/feed' }
            @{ Value = 'https://example.org/feed?token=secret' }, @{ Value = 'https://example.org/feed#fragment' }
        ) {
            {
                Assert-GerberPluginProjectInput -Field RepositoryUri -Value $Value
            } | Should -Throw '*absolute repository URI*Enter*Esc*'
        }
    }
}
