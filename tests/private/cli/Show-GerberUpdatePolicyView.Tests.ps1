BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberUpdatePolicyView' -Tag 'CoreUpdatePolicy' {
    BeforeEach {
        Mock Test-GerberUpdateInteractive { $true }
        Mock Resolve-GerberCoreUpdatePolicy { @{ Channel = 'Stable' } }
        Mock Set-GerberCoreUpdateChannel { $true }
        Mock Read-GerberNumberedMenuPrompt { 'IncludePrerelease' }
        Mock Wait-GerberContinue { throw [OperationCanceledException]::new('test escape') }
        Mock Write-GerberScreenLine {}
        Mock Write-GerberPromptTrace {}
        Mock Get-GerberCoreUpdateState { throw 'Policy must not discover' }
        Mock Invoke-GerberCoreUpdateInstall { throw 'Policy must not install' }
    }

    Context 'safe shared chooser flow' {
        It 'explains the shared channel while preserving Core-only startup checks' -Tag 'G4A9UI' {
            Mock Wait-GerberContinue {
            }
            Show-GerberUpdatePolicyView
            Should -Invoke Read-GerberNumberedMenuPrompt -ParameterFilter {
                $Prompt -eq 'Core update channel (Esc to go back)' -and
                $ScreenText -match 'Core and plugin' -and $ScreenText -match 'startup checks Core only'
            }
        }

        It 'preselects the current channel, saves explicitly and does not discover or install' {
            { Show-GerberUpdatePolicyView } | Should -Throw '*test escape*'
            Should -Invoke Read-GerberNumberedMenuPrompt -Times 1 -ParameterFilter {
                $MenuItemList[0].Value -ceq 'Stable' -and $ScreenText -match 'Stable only'
            }
            Should -Invoke Set-GerberCoreUpdateChannel -Times 1 -ParameterFilter { $Channel -ceq 'IncludePrerelease' }
            Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -match 'saved: Include prereleases' }
            Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -match 'Nothing was installed' }
            Should -Invoke Get-GerberCoreUpdateState -Times 0
            Should -Invoke Invoke-GerberCoreUpdateInstall -Times 0
        }

        It 'returns to the parent menu after continuing with <Channel>' -ForEach @(
            @{ Channel = 'Stable' }
            @{ Channel = 'IncludePrerelease' }
        ) {
            $script:reads = 0
            $expectedChannel = $Channel
            Mock Resolve-GerberCoreUpdatePolicy { @{ Channel = $Channel } }
            Mock Read-GerberNumberedMenuPrompt {
                $script:reads++
                if ($script:reads -gt 1) { throw 'Policy chooser reopened after continue' }
                $Channel
            }
            Mock Wait-GerberContinue {}
            { Show-GerberUpdatePolicyView } | Should -Not -Throw
            Should -Invoke Read-GerberNumberedMenuPrompt -Times 1 -Exactly
            Should -Invoke Set-GerberCoreUpdateChannel -Times 1 -ParameterFilter { $Channel -ceq $expectedChannel }
            Should -Invoke Wait-GerberContinue -Times 1 -Exactly
        }

        It 'does not save when Escape cancels the chooser' {
            Mock Read-GerberNumberedMenuPrompt { throw [OperationCanceledException]::new('test escape') }
            { Show-GerberUpdatePolicyView } | Should -Throw '*test escape*'
            Should -Invoke Set-GerberCoreUpdateChannel -Times 0
        }

        It 'never opens a chooser or reads or writes configuration in noninteractive dispatch' {
            Mock Test-GerberUpdateInteractive { $false }
            Show-GerberUpdatePolicyView
            Should -Invoke Read-GerberNumberedMenuPrompt -Times 0
            Should -Invoke Resolve-GerberCoreUpdatePolicy -Times 0
            Should -Invoke Set-GerberCoreUpdateChannel -Times 0
            Should -Invoke Wait-GerberContinue -Times 0
        }

        It 'shows actionable save failure without a success message for <FailureType>' -ForEach @(
            @{ FailureType = [IO.IOException] }
            @{ FailureType = [UnauthorizedAccessException] }
        ) {
            Mock Set-GerberCoreUpdateChannel { throw $FailureType::new('fixture failure') }
            { Show-GerberUpdatePolicyView } | Should -Throw '*test escape*'
            Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -match 'could not save.*permissions' }
            Should -Invoke Write-GerberScreenLine -Times 0 -ParameterFilter { $Text -match 'saved:' }
        }
    }
}
