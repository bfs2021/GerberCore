BeforeAll {
    . (Join-Path $PSScriptRoot '../../TestHelpers/PluginUpdate.TestSupport.ps1')
}

Describe 'Test-GerberUpdateActivation' -Tag 'G4A9' {
    BeforeEach {
        Mock Get-GerberUpdateActivationPayload {
            @{
                CoreVersion = '0.3.0'
            }
        }
        Mock Invoke-GerberUpdateActivationProbe {
            [pscustomobject]@{
                Status  = 'Verified'
                Version = '0.3.0'
            }
        }
    }

    It 'returns the fresh-process result without importing modules in the parent' {
        $result = Test-GerberUpdateActivation -CoreVersion '0.3.0'
        $result.Status | Should -Be 'Verified'
        $result.Version | Should -Be '0.3.0'
        Should -Invoke Invoke-GerberUpdateActivationProbe -Times 1 -ParameterFilter {
            $Payload.CoreVersion -eq '0.3.0'
        }
    }

    It 'keeps failed probe preparation unverified and does not expose diagnostics' {
        Mock Get-GerberUpdateActivationPayload {
            throw 'private-provider-diagnostic'
        }
        $result = Test-GerberUpdateActivation
        $result.Status | Should -Be 'Unverified'
        ($result | ConvertTo-Json) | Should -Not -Match 'private-provider'
        Should -Invoke Invoke-GerberUpdateActivationProbe -Times 0
    }

    It 'preserves explicit interruption instead of treating it as an activation failure' {
        Mock Invoke-GerberUpdateActivationProbe {
            throw [OperationCanceledException]::new('cancel')
        }
        {
            Test-GerberUpdateActivation
        } | Should -Throw
    }
}
