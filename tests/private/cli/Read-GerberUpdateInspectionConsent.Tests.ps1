BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $source = "$root/src/private/cli/Read-GerberUpdateInspectionConsent.ps1"
    if (Test-Path $source) {
        . $source
    }
    . "$root/src/private/cli/Read-GerberConfirmationPrompt.ps1"
    function Write-GerberPromptTrace {
        param($EventName, $Data)
        $null = $EventName, $Data
    }
}

Describe 'Read-GerberUpdateInspectionConsent' -Tag 'G4A9UI' {
    BeforeEach {
        $script:item = [pscustomobject]@{
            Kind = 'Plugin'
            State = [pscustomobject]@{
                Name = 'ExamplePlugin'; Repository = 'PrivateFeed'
                Plan = [pscustomobject]@{
                    RepositoryUri = 'https://example.test/v2'; RequiresRepositoryTrust = $true; RequiresLicenseAcceptance = $true
                }
            }
        }
        Mock Read-GerberConfirmationPrompt {
            $false
        }
        Mock Write-GerberPromptTrace {
        }
    }

    It 'requires explicit default-Cancel consent naming exact source and license before downloading inspection metadata' {
        Read-GerberUpdateInspectionConsent -SelectedItemList @($script:item) | Should -BeFalse
        Should -Invoke Read-GerberConfirmationPrompt -Times 1 -ParameterFilter {
            $PromptOptionSet.DefaultOption -eq 'cancel' -and $ScreenText -match 'ExamplePlugin' -and
            $ScreenText -match 'https://example.test/v2' -and $ScreenText -match 'license' -and
            $ScreenText -match 'download' -and $ScreenText -match 'No installation'
        }
    }

    It 'permits inspection only after acceptance' {
        Mock Read-GerberConfirmationPrompt {
            $true
        }
        Read-GerberUpdateInspectionConsent -SelectedItemList @($script:item) | Should -BeTrue
    }

    It 'does not prompt for plans without trust or license requirements' {
        $script:item.State.Plan.RequiresRepositoryTrust = $false
        $script:item.State.Plan.RequiresLicenseAcceptance = $false
        Read-GerberUpdateInspectionConsent -SelectedItemList @($script:item) | Should -BeNullOrEmpty
        Should -Invoke Read-GerberConfirmationPrompt -Times 0
    }
}
