function Format-GerberUpdateItemListOverview {
    param([object[]]$ItemList)
    $rows = @($ItemList | ForEach-Object {
        ConvertTo-GerberUpdateOverviewRow -Item $_
    })
    $untruncatedTableWidth = 4096
    $text = ($rows | Format-Table -AutoSize | Out-String -Width $untruncatedTableWidth).Trim()
    $channel = Format-GerberUpdateOverviewChannel -ItemList $ItemList
    if ($channel) {
        $text += "`n`n$channel"
    }
    $text
}

function ConvertTo-GerberUpdateOverviewRow {
    param([object]$Item)
    [pscustomobject][ordered]@{
        Component = $Item.Kind
        Name = $Item.State.Name
        Installed = $Item.State.Installed
        Available = $Item.State.Available
        Repository = $Item.State.Repository
        Status = $Item.State.Status
    }
}

function Format-GerberUpdateOverviewChannel {
    param([object[]]$ItemList)
    $core = $ItemList | Where-Object Kind -EQ 'Core' | Select-Object -First 1
    if ($null -eq $core) {
        return
    }
    $channel = $core.State.PSObject.Properties['Channel']
    if ($null -ne $channel -and $channel.Value) {
        "Channel: $(Get-GerberCoreUpdateChannelLabel $channel.Value)."
    }
}
