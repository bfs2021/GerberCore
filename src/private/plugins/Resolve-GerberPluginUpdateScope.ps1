function Resolve-GerberPluginUpdateScope {
    param([object]$Module)
    foreach ($entry in (Resolve-GerberPluginUpdateScopeRootMap).GetEnumerator()) {
        $expected = Join-Path (Join-Path $entry.Value $Module.Name) $Module.Version.ToString()
        $comparison = if ($IsWindows) {
            [StringComparison]::OrdinalIgnoreCase
        } else {
            [StringComparison]::Ordinal
        }
        if ([string]::Equals([IO.Path]::GetFullPath($Module.ModuleBase), [IO.Path]::GetFullPath($expected), $comparison)) {
            return $entry.Key
        }
    }
    throw [System.InvalidOperationException]::new('The plugin is not in a supported numeric CurrentUser or AllUsers installation. No other installation scope will be substituted.')
}
