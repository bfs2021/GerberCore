function Resolve-GerberPluginConfigPath {
    param([string]$ModuleName, [string]$CorePath)

    Assert-GerberPluginConfigurationModuleName -ModuleName $ModuleName
    if ([string]::IsNullOrWhiteSpace($CorePath)) { $CorePath = Resolve-GerberUserConfigPath }
    $path = Join-Path (Split-Path $corePath -Parent) "$ModuleName.json"
    if ([string]::Equals($path, $corePath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw [System.InvalidOperationException]::new("Core configuration override points at plugin configuration '$ModuleName.json'. Select a separate Core file such as GerberCore.json.")
    }
    return $path
}
