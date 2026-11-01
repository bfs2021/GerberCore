function Invoke-GerberLegacyConfigurationTransition {
    param([string]$CorePath)

    $legacyPath = Join-Path (Split-Path $CorePath -Parent) 'config.json'
    if ([string]::Equals($CorePath, $legacyPath, [System.StringComparison]::OrdinalIgnoreCase)) { return }
    if (-not (Test-Path -LiteralPath $legacyPath -PathType Leaf)) { return }
    $original = Read-GerberJsonConfiguration -Path $legacyPath
    $plan = Get-GerberConfigurationTransitionPlan -CorePath $CorePath -Original $original
    foreach ($item in $plan) { Save-GerberJsonConfiguration -Path $item.Path -Value $item.Value }
    Assert-GerberConfigurationTransitionComplete -Plan $plan -Original $original -LegacyPath $legacyPath
    Remove-Item -LiteralPath $legacyPath -ErrorAction Stop
}

function Assert-GerberConfigurationTransitionComplete {
    param([object[]]$Plan, [object]$Original, [string]$LegacyPath)

    $current = Read-GerberJsonConfiguration -Path $LegacyPath
    if (-not (Test-GerberConfigurationTransitionValueEqual -First $current -Second $Original)) {
        throw [System.IO.IOException]::new("Legacy configuration '$LegacyPath' changed during transition. The original file was retained; retry after checking the destination files.")
    }
    foreach ($item in $Plan) {
        $saved = Read-GerberJsonConfiguration -Path $item.Path
        if (-not (Test-GerberConfigurationTransitionValueEqual -First $saved -Second $item.Value)) {
            throw [System.IO.IOException]::new("Configuration transition could not verify '$($item.Path)'. The original config.json was retained.")
        }
    }
}
