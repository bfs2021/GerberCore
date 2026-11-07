BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $source = "$root/src/private/cli/Show-GerberUpdateBatchCompletion.ps1"
    if (Test-Path $source) {
        . $source
    }
    function Write-GerberScreenLine {
        param($Text)
        $null = $Text
    }
    function Write-GerberPromptTrace {
        param($EventName, $Data)
        $null = $EventName, $Data
    }
    function Wait-GerberContinue {
    }
    function Show-GerberUpdateBatchRestartChoice {
        param($Text)
        $null = $Text
    }
}

Describe 'Show-GerberUpdateBatchCompletion' -Tag 'G4A9UI' {
    BeforeEach {
        Mock Write-GerberScreenLine {
        }
        Mock Write-GerberPromptTrace {
        }
        Mock Wait-GerberContinue {
        }
        Mock Show-GerberUpdateBatchRestartChoice {
            $true
        }
    }

    It 'reports every actual outcome and keeps Installed truthful when activation fails' {
        $results = @(
            foreach ($outcome in @('Installed', 'Failed', 'Blocked', 'Cancelled')) {
                [pscustomobject]@{
                    Item = [pscustomobject]@{
                        State = [pscustomobject]@{
                            Name = $outcome
                        }
                    }
                    Outcome = $outcome; VerificationStatus = 'Verified'; RecoveryStatus = 'NotRequired'
                    ActivationStatus = 'Failed'; RestartRequired = $false; Message = 'Safe recovery advice.'
                }
            }
        )
        Show-GerberUpdateBatchCompletion -ResultList $results
        Should -Invoke Write-GerberScreenLine -Times 4 -ParameterFilter {
            $Text -match 'Activation: Failed' -and $Text -match 'Safe recovery advice'
        }
        Should -Invoke Write-GerberScreenLine -ParameterFilter {
            $Text -match 'Installed: Installed'
        }
        Should -Invoke Wait-GerberContinue -Times 1
    }

    It 'offers the existing restart choice only for verified installed results requesting restart' {
        $result = [pscustomobject]@{
            Item = [pscustomobject]@{
                State = [pscustomobject]@{
                    Name = 'ExamplePlugin'
                }
            }
            Outcome = 'Installed'; VerificationStatus = 'Verified'; RecoveryStatus = 'NotRequired'
            ActivationStatus = 'Verified'; RestartRequired = $true; Message = ''
        }
        Show-GerberUpdateBatchCompletion -ResultList @($result) | Should -BeTrue
        Should -Invoke Show-GerberUpdateBatchRestartChoice -Times 1 -ParameterFilter {
            $Text -match 'Restart PowerShell' -and $Text -match 'ExamplePlugin: Installed' -and $Text -match 'Activation: Verified'
        }
        Should -Invoke Wait-GerberContinue -Times 0
    }
}
