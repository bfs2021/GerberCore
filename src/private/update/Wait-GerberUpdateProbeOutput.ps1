function Wait-GerberUpdateProbeOutput {
    param([Diagnostics.Process]$Process, [Threading.Tasks.Task[string]]$Output, [int]$TimeoutMilliseconds)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    if (-not $Process.WaitForExit($TimeoutMilliseconds)) {
        return $false
    }
    $remaining = [Math]::Max(0, $TimeoutMilliseconds - [int]$watch.ElapsedMilliseconds)
    $Output.Wait($remaining)
}
