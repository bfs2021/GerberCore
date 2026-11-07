function Show-GerberUpdateBatchRestartChoice {
    param([string]$Text)
    $guidance = 'Exiting Gerber does not restart PowerShell. Restart PowerShell, then run gerber to use installed components. Continuing keeps the current session; components have not reloaded.'
    $script:GerberStartupUpdateState = [pscustomobject]@{
        Status = 'RestartRequired'; Message = $guidance
    }
    $selection = Read-GerberUpdateBatchRestartSelection -Text "$Text`n`n$guidance"
    Write-GerberPromptTrace -EventName 'update-restart-choice' -Data @{
        Selection = $selection
    }
    if ($selection -eq 'exit') {
        Write-GerberScreenLine -Text "Exiting Gerber. $guidance"
        return $true
    }
}

function Read-GerberUpdateBatchRestartSelection {
    param([string]$Text)
    $items = @(Get-GerberUpdateBatchRestartMenuItemList)
    try {
        Read-GerberNumberedMenuPrompt -Prompt 'Update next step (Esc to continue)' -ScreenTitle '/update list' -ScreenText $Text -MenuItemList $items
    } catch {
        if (-not (Test-GerberMenuEscapeException -Exception $_.Exception)) {
            throw
        }
        'continue'
    }
}

function Get-GerberUpdateBatchRestartMenuItemList {
    param()
    [pscustomobject]@{
        Number = 1; Value = 'continue'; Label = 'Continue with current version'; PreviewText = 'Keep using this session. Restart PowerShell later to use installed components.'
    }
    [pscustomobject]@{
        Number = 2; Value = 'exit'; Label = 'Exit Gerber'; PreviewText = 'Return to PowerShell. Restart PowerShell yourself, then run gerber.'
    }
}
