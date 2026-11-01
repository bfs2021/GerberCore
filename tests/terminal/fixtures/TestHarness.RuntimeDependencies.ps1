function Import-GerberTerminalRuntimeDependency {
    param([string]$GerberRoot)
    $originalModulePath = $env:PSModulePath
    try {
        $env:PSModulePath = $env:GERBER_TERMINAL_RUNTIME_MODULE_PATH ?? $originalModulePath
        $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $GerberRoot 'dist/Gerber/Gerber.psd1')
        foreach ($requirement in $manifest.RequiredModules) {
            Import-Module -FullyQualifiedName $requirement -ErrorAction Stop
        }
    } finally {
        $env:PSModulePath = $originalModulePath
    }
}
