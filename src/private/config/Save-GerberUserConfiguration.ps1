function Save-GerberUserConfiguration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Configuration
    )

    $configPath = Resolve-GerberUserConfigPath
    $null = Test-GerberUserConfiguration -Configuration $Configuration -Path $configPath
    if (-not $PSCmdlet.ShouldProcess($configPath, 'Save Gerber user configuration')) {
        return
    }

    $json = ConvertTo-GerberUserConfigurationJson -Configuration $Configuration
    Write-GerberJsonConfiguration -Path $configPath -Json $json
}
