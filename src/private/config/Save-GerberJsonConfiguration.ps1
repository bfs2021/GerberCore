function Save-GerberJsonConfiguration {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][AllowNull()][object]$Value)

    $null = Read-GerberJsonConfiguration -Path $Path
    $json = ConvertTo-GerberUserConfigurationJson -Configuration $Value
    Assert-GerberJsonConfigurationText -Json $json -Path $Path
    if ($PSCmdlet.ShouldProcess($Path, 'Save JSON configuration')) {
        Write-GerberJsonConfiguration -Path $Path -Json $json
    }
}
