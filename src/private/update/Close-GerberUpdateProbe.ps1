function Close-GerberUpdateProbe {
    param([System.Diagnostics.Process]$Process)
    try {
        if (-not $Process.HasExited) {
            $Process.Kill($true)
        }
    } catch [System.InvalidOperationException] {
        Write-Verbose 'Update probe already exited or could not start.'
    } finally {
        $Process.Dispose()
    }
}
