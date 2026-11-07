function Get-GerberUpdateBatchConsentText {
    param([object]$Batch)
    $lines = @($Batch.Items | ForEach-Object {
        Get-GerberUpdateItemConsentText -Item $_
    })
    ($lines -join "`n`n") + "`n`nInstall sequentially, Core first when required. Gerber will not hot reload components or roll back the batch. Cancel is the default."
}

function Get-GerberUpdateItemConsentText {
    param([object]$Item)
    $state = $Item.State
    $text = Format-GerberUpdateItemOverview -Item $Item
    $text += Get-GerberUpdateRequirementConsentText -Item $Item
    if ($null -ne $state.Plan) {
        $text += Get-GerberUpdatePlanConsentText -Plan $state.Plan
    }
    $text
}

function Get-GerberUpdateRequirementConsentText {
    param([object]$Item)
    $text = ''
    if ($Item.AutoAdded) {
        $text += "`nGerber automatically added this required Core update."
    }
    if ($Item.MinimumCore) {
        $text += "`nRequired Core: $($Item.MinimumCore)."
    }
    $text
}

function Get-GerberUpdatePlanConsentText {
    param([object]$Plan)
    $text = "`nSource: $($Plan.RepositoryUri). Scope: $($Plan.Scope)."
    if ($Plan.RequiresRepositoryTrust) {
        $text += ' Installing grants repository trust for this operation only.'
    }
    if ($Plan.RequiresLicenseAcceptance) {
        $text += ' Installing accepts this package license for this operation.'
    }
    $text
}
