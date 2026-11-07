BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    foreach ($path in @(
        'cli/Show-GerberUpdateView', 'cli/Read-GerberConfirmationPrompt', 'cli/Wait-GerberContinue',
        'cli/Read-GerberNumberedMenuPrompt', 'cli/Show-GerberCoreUpdateRestartChoice',
        'cli/Write-GerberScreenLine', 'cli/Write-GerberPromptTrace', 'cli/Start-GerberScreen',
        'update/Get-GerberCoreUpdateState', 'update/Invoke-GerberCoreUpdateInstall',
        'update/Show-GerberCoreUpdateSummary', 'update/Test-GerberUpdateInteractive', 'update/Format-GerberCoreUpdateOverview'
    )) { . "$root/src/private/$path.ps1" }
    function Resolve-GerberPluginUpdateStateList {
    }
    function Show-GerberUpdateBatchView {
        param($CoreState, $PluginItemList, $Interactive)
        $null = $CoreState, $PluginItemList, $Interactive
    }
}

Describe 'Show-GerberUpdateView' -Tag 'G4A7' {
    BeforeEach {
        $script:state = [pscustomobject]@{
            Status = 'Available'; Name = 'Gerber'; Installed = '0.1.0'; Available = '0.2.0'; Repository = 'Feed'
            Plan = [pscustomobject]@{ RequiresRepositoryTrust = $true; RequiresLicenseAcceptance = $true; Scope = 'AllUsers' }
            Credential = $null; Message = 'An update is available.'
        }
        Mock Get-GerberCoreUpdateState { $script:state }
        Mock Invoke-GerberCoreUpdateInstall {
            [pscustomobject]@{ Outcome = 'Installed'; VerificationStatus = 'Verified'; RecoveryStatus = 'NotRequired'; RestartRequired = $true }
        }
        Mock Show-GerberCoreUpdateSummary {}
        Mock Test-GerberUpdateInteractive { $true }
        Mock Read-GerberConfirmationPrompt { $false }
        Mock Wait-GerberContinue {}
        Mock Write-GerberScreenLine {}
        Mock Start-GerberScreen {}
        Mock Write-GerberPromptTrace {}
        Mock Read-GerberNumberedMenuPrompt { 'continue' }
        Mock Resolve-GerberPluginUpdateStateList {
            @()
        }
        Mock Show-GerberUpdateBatchView {
        }
    }

    AfterEach { Remove-Variable GerberStartupUpdateState -Scope Script -ErrorAction SilentlyContinue }

    Context 'explicit Core update workflow' {
        It 'delegates plugin rows with the single fresh Core state, including in noninteractive mode' -Tag 'G4A9UI' -ForEach @($true, $false) {
            $interactiveMode = $_
            Mock Test-GerberUpdateInteractive {
                $interactiveMode
            }
            Mock Resolve-GerberPluginUpdateStateList {
                [pscustomobject]@{
                    Kind = 'Plugin'; State = $script:state
                }
            }
            Show-GerberUpdateView
            Should -Invoke Get-GerberCoreUpdateState -Times 1
            Should -Invoke Show-GerberUpdateBatchView -Times 1 -ParameterFilter {
                [object]::ReferenceEquals($CoreState, $script:state) -and $PluginItemList.Count -eq 1 -and $Interactive -eq $interactiveMode
            }
            Should -Invoke Read-GerberConfirmationPrompt -Times 0
        }

        It 'discovers afresh on every invocation and defaults to cancel with explicit trust/license text' {
            Show-GerberUpdateView
            Show-GerberUpdateView
            Should -Invoke Get-GerberCoreUpdateState -Times 2
            Should -Invoke Read-GerberConfirmationPrompt -Times 2 -ParameterFilter {
                $ScreenTitle -eq '/update list' -and
                $PromptOptionSet.DefaultOption -eq 'cancel' -and $ScreenText -match 'trust' -and $ScreenText -match 'license'
            }
            Should -Invoke Invoke-GerberCoreUpdateInstall -Times 0
            Should -Invoke Read-GerberNumberedMenuPrompt -Times 0
            Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -match 'cancelled' }
        }

        It 'installs only the just-discovered live plan after explicit acceptance' {
            Mock Read-GerberConfirmationPrompt { $true }
            Show-GerberUpdateView
            Should -Invoke Invoke-GerberCoreUpdateInstall -Times 1 -ParameterFilter { [object]::ReferenceEquals($State, $script:state) }
            Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -match 'Restart PowerShell' }
            Should -Invoke Wait-GerberContinue -Times 0
            Should -Invoke Invoke-GerberCoreUpdateInstall -ParameterFilter { $PassThru }
            Should -Invoke Read-GerberNumberedMenuPrompt -Times 1
        }

        It 'keeps the compact overview and actual PMU scope visible in the confirmation' {
            Show-GerberUpdateView
            Should -Invoke Read-GerberConfirmationPrompt -Times 1 -ParameterFilter {
                $ScreenText -match 'Installed.*Available.*Repository' -and $ScreenText -match 'Scope: AllUsers'
            }
        }

        It 'shows no-update, discovery failure and no-matching-package outcomes without confirmation' -ForEach @('UpToDate', 'Unavailable', 'NoMatchingPackage', 'RestartRequired') {
            $script:state.Status = $_
            Show-GerberUpdateView
            Should -Invoke Show-GerberCoreUpdateSummary -Times 1
            Should -Invoke Read-GerberConfirmationPrompt -Times 0
            Should -Invoke Invoke-GerberCoreUpdateInstall -Times 0
        }

        It 'never prompts or installs with redirected/noninteractive input' -ForEach @('Available', 'RestartRequired') {
            $script:state.Status = $_
            Mock Test-GerberUpdateInteractive { $false }
            Show-GerberUpdateView
            Should -Invoke Read-GerberConfirmationPrompt -Times 0
            Should -Invoke Read-GerberNumberedMenuPrompt -Times 0
            Should -Invoke Wait-GerberContinue -Times 0
            Should -Invoke Invoke-GerberCoreUpdateInstall -Times 0
        }

        It 'preserves local Escape cancellation without installing' {
            Mock Read-GerberConfirmationPrompt { throw [System.OperationCanceledException]::new('Esc') }
            { Show-GerberUpdateView } | Should -Throw
            Should -Invoke Invoke-GerberCoreUpdateInstall -Times 0
        }

        It 'offers exit for discovery RestartRequired without installation' {
            $script:state.Status = 'RestartRequired'
            Mock Read-GerberNumberedMenuPrompt { 'exit' }
            @(Show-GerberUpdateView) | Should -Be @($true)
            Should -Invoke Invoke-GerberCoreUpdateInstall -Times 0
            Should -Invoke Wait-GerberContinue -Times 0
        }

        It 'offers exit only after verified successful installation' -ForEach @('Installed', 'AlreadyInstalled') {
            $outcome = $_
            Mock Invoke-GerberCoreUpdateInstall {
                [pscustomobject]@{ Outcome = $outcome; VerificationStatus = 'Verified'; RecoveryStatus = 'NotRequired'; RestartRequired = $true }
            }
            Mock Read-GerberConfirmationPrompt { $true }
            Mock Read-GerberNumberedMenuPrompt { 'exit' }
            @(Show-GerberUpdateView) | Should -Be @($true)
            Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -match "$outcome. Verification: Verified. Recovery: NotRequired." }
        }

        It 'does not offer exit for unsuccessful or unverified installation' -ForEach @(
            @{ outcome = 'Cancelled'; verification = 'Verified'; restart = $true }
            @{ outcome = 'WhatIf'; verification = 'Verified'; restart = $true }
            @{ outcome = 'Installed'; verification = 'Failed'; restart = $true }
            @{ outcome = 'Installed'; verification = 'Verified'; restart = $false }
        ) {
            Mock Read-GerberConfirmationPrompt { $true }
            Mock Invoke-GerberCoreUpdateInstall {
                [pscustomobject]@{ Outcome = $outcome; VerificationStatus = $verification; RecoveryStatus = 'NotRequired'; RestartRequired = $restart }
            }
            @(Show-GerberUpdateView).Count | Should -Be 0
            Should -Invoke Read-GerberNumberedMenuPrompt -Times 0
            Should -Invoke Wait-GerberContinue -Times 1
        }

        It 'preserves translated installation errors without an exit chooser' {
            Mock Read-GerberConfirmationPrompt { $true }
            Mock Invoke-GerberCoreUpdateInstall { 'Installation failed. Follow recovery guidance.' }
            @(Show-GerberUpdateView).Count | Should -Be 0
            Should -Invoke Read-GerberNumberedMenuPrompt -Times 0
            Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -match 'Installation failed' }
        }
    }
}
