function Format-GerberCoreUpdateOverview {
    param([object]$State)
    $row = [pscustomobject][ordered]@{
        Component = 'Core'; Name = $State.Name; Installed = $State.Installed
        Available = $State.Available; Repository = $State.Repository; Status = $State.Status
    }
    $text = ($row | Format-Table -AutoSize | Out-String).Trim()
    $channel = $State.PSObject.Properties['Channel']
    if ($null -ne $channel -and $channel.Value) {
        $text += "`n`nChannel: $(Get-GerberCoreUpdateChannelLabel $channel.Value)."
    }
    $text
}
