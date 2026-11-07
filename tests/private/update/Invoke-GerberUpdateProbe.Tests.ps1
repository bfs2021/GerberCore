BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . "$root/src/private/update/Invoke-GerberUpdateProbe.ps1"
    . "$root/src/private/update/Close-GerberUpdateProbe.ps1"
    . "$root/src/private/update/Wait-GerberUpdateProbeOutput.ps1"
}

Describe 'Invoke-GerberUpdateProbe' -Tag 'G4A7' {
    BeforeEach {
        $script:request = [pscustomobject]@{
            Module     = [pscustomobject]@{
                ModuleBase = $TestDrive
            }
            Repository = 'IsolatedFeed'
            Policy     = @{
            }
        }
    }

    Context 'isolated startup process' {
        It 'serializes only module identity, never caller-selected repository policy or credentials' {
            $request.Repository = 'HostileFeed'
            $request.Policy = @{
                Channel = 'IncludePrerelease'
                Scope   = 'AllUsers'
            }
            $command = Get-GerberUpdateProbeCommand $request
            $encoded = [regex]::Match($command, '\$payload = ''([^'']+)''').Groups[1].Value
            $payloadText = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
            $payloadText | Should -Not -Match 'HostileFeed|IncludePrerelease|AllUsers|Repository|Policy|Credential'
            (Get-GerberUpdateProbeScript) | Should -Not -Match '\$data\.Repository|\$data\.Policy'
        }

        It 'terminates a slow child within a bounded budget without leaving it running' {
            $script:pidPath = Join-Path $TestDrive 'child.pid'
            Mock Get-GerberUpdateProbeScript {
                "[IO.File]::WriteAllText('$script:pidPath', [string]`$PID); Start-Sleep -Seconds 60"
            }
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            (Invoke-GerberUpdateProbe -Request $request -TimeoutMilliseconds 1500).Status | Should -Be 'TimedOut'
            $watch.Elapsed.TotalSeconds | Should -BeLessThan 4
            Test-Path -LiteralPath $script:pidPath | Should -BeTrue
            $childId = [int](Get-Content $script:pidPath -Raw)
            Start-Sleep -Milliseconds 200
            Get-Process -Id $childId -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'accepts only presentation fields from the noninteractive child' {
            Mock Get-GerberUpdateProbeScript {
                "'{`"Status`":`"Available`",`"Available`":`"0.2.0`",`"Plan`":`"stale`",`"Credential`":`"never retain`"}'"
            }
            $result = Invoke-GerberUpdateProbe -Request $request -TimeoutMilliseconds 2000
            $result.Status | Should -Be 'Available'
            $result.Available | Should -Be '0.2.0'
            $result.PSObject.Properties.Name | Should -Not -Contain 'Plan'
            $result.PSObject.Properties.Name | Should -Not -Contain 'Credential'
        }

        It 'contains offline child failure and malformed output without exposing stderr' -ForEach @(
            @{
                scriptText = "throw 'raw-secret-offline'"
            },
            @{
                scriptText = "'malformed raw-secret-output'"
            },
            @{
                scriptText = "'{`"Status`":`"Unconfigured`"}'"
            }
        ) {
            Mock Get-GerberUpdateProbeScript {
                $scriptText
            }
            $result = Invoke-GerberUpdateProbe -Request $request
            $result.Status | Should -Be 'Unavailable'
            ($result | ConvertTo-Json) | Should -Not -Match 'raw-secret'
        }
    }
}
