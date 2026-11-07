function Format-GerberUpdateItemOverview {
    param([object]$Item)
    $state = $Item.State
    $text = "$($Item.Kind): $($state.Name) | Installed: $($state.Installed) | Available: $($state.Available) | Repository: $($state.Repository) | Status: $($state.Status). $($state.Message)"
    $channel = $state.PSObject.Properties['Channel']
    if ($null -ne $channel -and $channel.Value) {
        $text += "`nChannel: $(Get-GerberCoreUpdateChannelLabel $channel.Value)."
    }
    $text
}
