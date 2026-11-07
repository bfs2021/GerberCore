function Read-GerberUpdateItemSelection {
    param([object[]]$ItemList)
    $options = @(Get-GerberUpdateCheckboxItemList -ItemList $ItemList)
    if ($options.Count -eq 0) {
        return
    }
    $request = Get-GerberUpdateSelectionRequest -ItemList $ItemList -Options $options
    $selection = Read-GerberCheckboxMenuPrompt -PromptRequest $request
    $selection.SelectedValueList
}

function Get-GerberUpdateSelectionRequest {
    param([object[]]$ItemList, [object[]]$Options)
    $overview = Format-GerberUpdateItemListOverview -ItemList $ItemList
    [pscustomobject]@{
        Prompt = 'Select updates'; ScreenTitle = '/update list'
        ScreenText = "$overview`n`nSelect installed components to update. Required Core updates are added before confirmation."
        ItemList = $Options; AllowEmptySelection = $true
    }
}

function Get-GerberUpdateCheckboxItemList {
    param([object[]]$ItemList)
    foreach ($item in $ItemList) {
        if ($item.State.Status -ne 'Available') {
            continue
        }
        [pscustomobject]@{
            Label = "$($item.State.Name): $($item.State.Installed) -> $($item.State.Available)"
            Description = "Repository: $($item.State.Repository)"
            Value = $item; IsSelected = $false
        }
    }
}
