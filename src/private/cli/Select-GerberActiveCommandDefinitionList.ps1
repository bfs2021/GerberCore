function Select-GerberActiveCommandDefinitionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param([AllowEmptyCollection()][object[]]$Commands)

    $active = [System.Collections.Generic.List[object]]::new($Commands)
    foreach ($command in @($Commands | Sort-Object { $_.Name.Length } -Descending)) {
        Complete-GerberCatalogContainerPruning -Table $command.Subcommands
        if ((Test-GerberCommandContainer -Definition $command) -and $command.Subcommands.Count -eq 0) {
            $null = $active.Remove($command)
            Clear-GerberPluginSubcommandEntry -CommandList $active.ToArray() -OwnedCommand $command
        }
    }
    return $active.ToArray()
}

function Complete-GerberCatalogContainerPruning {
    param([System.Collections.IDictionary]$Table)

    foreach ($name in @($Table.Keys)) {
        $entry = $Table[$name]
        if ($entry -is [string]) { continue }
        Complete-GerberCatalogContainerPruning -Table $entry.Subcommands
        if ((Test-GerberCommandContainer -Definition $entry) -and $entry.Subcommands.Count -eq 0) {
            $Table.Remove($name)
        }
    }
}
