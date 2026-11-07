BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Test-GerberUserConfiguration' {
    It 'accepts a hashtable with the supported schemaVersion' {
        { Test-GerberUserConfiguration -Configuration @{ schemaVersion = 1 } -Path '/tmp/config.json' } | Should -Not -Throw
    }

    It 'accepts a PSCustomObject root with the supported schemaVersion' {
        $configuration = [pscustomobject]@{
            schemaVersion = 1
            preferences = [pscustomobject]@{
                theme = 'dark'
            }
        }

        { Test-GerberUserConfiguration -Configuration $configuration -Path '/tmp/config.json' } | Should -Not -Throw
    }

    It 'rejects a missing schemaVersion value' {
        { Test-GerberUserConfiguration -Configuration @{ } -Path '/tmp/config.json' } | Should -Throw "*schemaVersion*"
    }

    It 'rejects a non-integer schemaVersion value' {
        { Test-GerberUserConfiguration -Configuration @{ schemaVersion = '1' } -Path '/tmp/config.json' } | Should -Throw "*integer*"
    }

    It 'rejects an unsupported schemaVersion value' {
        { Test-GerberUserConfiguration -Configuration @{ schemaVersion = 2 } -Path '/tmp/config.json' } | Should -Throw "*Unsupported schemaVersion '2'*"
    }

    It 'rejects a non-object root and identifies the file path' {
        { Test-GerberUserConfiguration -Configuration @('a', 'b') -Path '/tmp/config.json' } | Should -Throw "*'/tmp/config.json'*must be a JSON object*"
    }

    It 'delegates feature sections to their validators' -ForEach @(
        @{
            Configuration = @{ schemaVersion = 1; coreUpdates = @{ channel = 'Preview' } }
            ErrorMessage = '*coreUpdates.channel*Stable*IncludePrerelease*'
        }
        @{
            Configuration = @{
                schemaVersion = 1
                plugins = @{
                    associated = @{
                        invalid = @{
                            enabled = $true
                        }
                    }
                }
            }
            ErrorMessage = "*plugins.associated*valid GUID*"
        }
    ) {
        param($Configuration, $ErrorMessage)

        $configurationToTest = $Configuration
        { Test-GerberUserConfiguration -Configuration $configurationToTest -Path '/tmp/config.json' } |
            Should -Throw $ErrorMessage
    }

    It 'preserves unknown product fields without running ADO domain validation' {
        $configuration = @{ schemaVersion = 1; ado = @{ profiles = @{ example = 'plugin-owned' } } }
        { Test-GerberUserConfiguration -Configuration $configuration -Path 'GerberCore.json' } | Should -Not -Throw
        $configuration.ado.profiles.example | Should -Be 'plugin-owned'
    }
}
