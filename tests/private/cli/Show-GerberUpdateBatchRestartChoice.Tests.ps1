BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $source = "$root/src/private/cli/Show-GerberUpdateBatchRestartChoice.ps1"
    if (Test-Path $source) {
        . $source
    }
    function Read-GerberNumberedMenuPrompt {
        param($Prompt, $ScreenTitle, $ScreenText, $MenuItemList)
        $null = $Prompt, $ScreenTitle, $ScreenText, $MenuItemList
    }
    function Write-GerberScreenLine {
        param($Text)
        $null = $Text
    }
    function Write-GerberPromptTrace {
        param($EventName, $Data)
        $null = $EventName, $Data
    }
    function Test-GerberMenuEscapeException {
        param($Exception)
        $Exception -is [OperationCanceledException]
    }
}

Describe 'Show-GerberUpdateBatchRestartChoice' -Tag 'G4A9UI' {
    BeforeEach {
        Mock Read-GerberNumberedMenuPrompt {
            'continue'
        }
        Mock Write-GerberScreenLine {
        }
        Mock Write-GerberPromptTrace {
        }
    }

    AfterEach {
        Remove-Variable GerberStartupUpdateState -Scope Script -ErrorAction SilentlyContinue
    }

    It 'defaults to Continue with component-neutral restart guidance and keeps a reminder' {
        @(Show-GerberUpdateBatchRestartChoice -Text 'Installed plugin.').Count | Should -Be 0
        Should -Invoke Read-GerberNumberedMenuPrompt -ParameterFilter {
            $MenuItemList[0].Value -eq 'continue' -and $ScreenText -match 'Restart PowerShell' -and
            $ScreenText -notmatch 'installed Core' -and $ScreenText -match 'does not restart PowerShell'
        }
        $script:GerberStartupUpdateState.Status | Should -Be 'RestartRequired'
    }

    It 'propagates Exit Gerber without restarting PowerShell' {
        Mock Read-GerberNumberedMenuPrompt {
            'exit'
        }
        Show-GerberUpdateBatchRestartChoice -Text 'Installed plugin.' | Should -BeTrue
        Should -Invoke Write-GerberScreenLine -ParameterFilter {
            $Text -match 'Exiting Gerber.*does not restart PowerShell'
        }
    }

    It 'treats shared Escape as Continue but preserves unexpected errors' {
        Mock Read-GerberNumberedMenuPrompt {
            throw [OperationCanceledException]::new('Esc')
        }
        @(Show-GerberUpdateBatchRestartChoice -Text 'Installed plugin.').Count | Should -Be 0
        Mock Read-GerberNumberedMenuPrompt {
            throw [InvalidOperationException]::new('unexpected')
        }
        {
            Show-GerberUpdateBatchRestartChoice -Text 'Installed plugin.'
        } | Should -Throw '*unexpected*'
    }
}
