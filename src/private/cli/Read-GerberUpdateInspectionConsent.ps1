function Read-GerberUpdateInspectionConsent {
    param([object[]]$SelectedItemList)
    $gated = @(Get-GerberUpdateInspectionConsentItemList -ItemList $SelectedItemList)
    if ($gated.Count -eq 0) {
        return
    }
    $text = Get-GerberUpdateInspectionConsentText -ItemList $gated
    $options = Get-GerberConfirmationPromptOptionSet -ActionLabel 'Inspect selected packages' -CancelLabel 'Cancel' -DefaultOption 'cancel'
    $accepted = Read-GerberConfirmationPrompt -Prompt 'Allow package inspection?' -ScreenTitle '/update list' -ScreenText $text -PromptOptionSet $options
    Write-GerberPromptTrace -EventName 'update-inspection-consent' -Data @{
        Accepted = $accepted; ComponentCount = $gated.Count
    }
    $accepted
}

function Get-GerberUpdateInspectionConsentItemList {
    param([object[]]$ItemList)
    $ItemList | Where-Object {
        $_.Kind -eq 'Plugin' -and $null -ne $_.State.Plan
    } | Where-Object {
        $_.State.Plan.RequiresRepositoryTrust -or $_.State.Plan.RequiresLicenseAcceptance
    }
}

function Get-GerberUpdateInspectionConsentText {
    param([object[]]$ItemList)
    $sources = @($ItemList | ForEach-Object {
        Get-GerberUpdateInspectionSourceText -Item $_
    }) -join "`n"
    "$sources`nTemporarily download selected packages to inspect required Core versions. No installation occurs. Consent is for this operation only; Cancel is the default."
}

function Get-GerberUpdateInspectionSourceText {
    param([object]$Item)
    $plan = $Item.State.Plan
    $text = "$($Item.State.Name): $($Item.State.Repository) ($($plan.RepositoryUri))."
    if ($plan.RequiresRepositoryTrust) {
        $text += ' Grant repository trust for inspection only.'
    }
    if ($plan.RequiresLicenseAcceptance) {
        $text += ' Accept this package license for inspection.'
    }
    $text
}
