function Show-GerberUpdatePolicyView {
    param()
    if (-not (Test-GerberUpdateInteractive)) {
        Write-GerberScreenLine -Text 'Open /update policy in an interactive Gerber session to change the shared Core and plugin update channel.'
        return
    }
    $policy = Resolve-GerberCoreUpdatePolicy
    $label = Get-GerberCoreUpdateChannelLabel $policy.Channel
    $items = @(Get-GerberCoreUpdatePolicyMenuItemList $policy.Channel)
    $selected = Read-GerberNumberedMenuPrompt -Prompt 'Core update channel (Esc to go back)' `
        -ScreenTitle '/update policy' -ScreenText "Current Core update policy: $label. Shared by Core and plugin checks in /update list; startup checks Core only." -MenuItemList $items
    Save-GerberCoreUpdatePolicySelection $selected
    Wait-GerberContinue
}

function Get-GerberCoreUpdatePolicyMenuItemList {
    param([string]$CurrentChannel)
    $channels = @($CurrentChannel) + @('Stable', 'IncludePrerelease' | Where-Object { $_ -cne $CurrentChannel })
    for ($index = 0; $index -lt $channels.Count; $index++) {
        [pscustomobject]@{
            Number = $index + 1; Value = $channels[$index]
            Label = Get-GerberCoreUpdateChannelLabel $channels[$index]
            PreviewText = 'Use this channel for Core startup checks and Core/plugin checks in /update list. Nothing will be installed.'
        }
    }
}

function Save-GerberCoreUpdatePolicySelection {
    param([string]$Channel)
    Write-GerberScreenLine
    try {
        $changed = Set-GerberCoreUpdateChannel -Channel $Channel
        $outcome = if ($changed) { 'saved' } else { 'unchanged' }
        Write-GerberScreenLine -Text "Core update policy ${outcome}: $(Get-GerberCoreUpdateChannelLabel $Channel)."
        Write-GerberScreenLine -Text 'Nothing was installed.'
        Write-GerberPromptTrace -EventName 'update-policy-saved' -Data @{ Channel = $Channel; Changed = $changed }
    } catch [System.IO.IOException] {
        Write-GerberCoreUpdatePolicySaveError
    } catch [System.UnauthorizedAccessException] {
        Write-GerberCoreUpdatePolicySaveError
    }
}

function Write-GerberCoreUpdatePolicySaveError {
    param()
    Write-GerberScreenLine -Text 'Gerber could not save the Core update policy. Check the user configuration path and write permissions, then retry. The active policy is unchanged.'
    Write-GerberPromptTrace -EventName 'update-policy-save-failed' -Data @{}
}
