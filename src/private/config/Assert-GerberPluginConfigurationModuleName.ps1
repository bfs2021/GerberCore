function Assert-GerberPluginConfigurationModuleName {
    param([string]$ModuleName)

    if ($ModuleName -notmatch '^Gerber\.[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw [System.ArgumentException]::new('Plugin configuration requires a registered Gerber module name, not a file path.')
    }
}
