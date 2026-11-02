function Clear-GerberPluginSubcommandEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$CommandList,
        [Parameter(Mandatory)][pscustomobject]$OwnedCommand
    )

    if (-not $OwnedCommand.ParentName) { return }
    $parentCommand = $CommandList | Where-Object { $_.Name -ieq $OwnedCommand.ParentName } | Select-Object -First 1
    if ($null -ne $parentCommand) {
        $parentCommand.Subcommands.Remove($OwnedCommand.LeafName)
    }
}
