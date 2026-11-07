function ConvertTo-GerberUserConfigurationJson {
    [OutputType([string])]
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Configuration)

    return (ConvertTo-Json -InputObject $Configuration -Depth 100 -WarningAction Stop)
}
