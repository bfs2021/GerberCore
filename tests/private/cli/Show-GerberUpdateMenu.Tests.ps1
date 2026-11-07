BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberUpdateMenu' -Tag 'CoreUpdatePolicy' {
    BeforeEach {
        Mock Test-GerberUpdateInteractive { $false }
        Mock Show-GerberRegisteredSubcommandMenu {}
        Mock Show-GerberUpdatePolicyView {}
        Mock Show-GerberUpdateView {}
        Mock Write-GerberScreenLine {}
    }

    Context 'shared menu and noninteractive dispatch' {
        It 'describes both Core and plugin discovery without prompting in noninteractive mode' -Tag 'G4A9UI' {
            Show-GerberUpdateMenu ([pscustomobject]@{
                Arguments = @()
            })
            Should -Invoke Write-GerberScreenLine -ParameterFilter {
                $Text -match 'Core and.*plugin' -and $Text -match 'shared channel'
            }
        }

        It 'uses the standard update submenu in an interactive session' {
            Mock Test-GerberUpdateInteractive { $true }
            Show-GerberUpdateMenu ([pscustomobject]@{ Arguments = @() })
            Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 1 -ParameterFilter {
                $CommandName -eq 'update' -and $AutoSelectFirstSuggestionOnSubmit
            }

            Should -Invoke Show-GerberUpdateView -Times 0
        }

        It 'propagates the shared menu exit signal without extra output' {
            Mock Test-GerberUpdateInteractive { $true }
            Mock Show-GerberRegisteredSubcommandMenu { $true }
            @(Show-GerberUpdateMenu ([pscustomobject]@{ Arguments = @('list') })) | Should -Be @($true)
            Should -Invoke Show-GerberRegisteredSubcommandMenu -ParameterFilter { $PropagateExit }
        }

        It 'does not open a parent chooser after noninteractive policy dispatch' {
            Show-GerberUpdateMenu ([pscustomobject]@{ Arguments = @('policy') })
            Should -Invoke Show-GerberUpdatePolicyView -Times 1
            Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 0
            Should -Invoke Show-GerberUpdateView -Times 0
        }

        It 'retains noninteractive discovery through list' {
            Show-GerberUpdateMenu ([pscustomobject]@{ Arguments = @('list') })
            Should -Invoke Show-GerberUpdateView -Times 1
            Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 0
        }

        It 'explains available actions without opening a noninteractive root chooser' {
            Show-GerberUpdateMenu ([pscustomobject]@{ Arguments = @() })
            Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter { $Text -match '/update list.* /update policy' }
            Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 0
            Should -Invoke Show-GerberUpdateView -Times 0
        }
    }
}
