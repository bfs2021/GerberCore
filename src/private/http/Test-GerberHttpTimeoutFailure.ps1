function Test-GerberHttpTimeoutFailure {
    [OutputType([bool])]
    [CmdletBinding()]
    param([AllowNull()][System.Exception]$Exception)

    if ($null -eq $Exception) {
        return $false
    }
    if ($Exception -is [System.Threading.Tasks.TaskCanceledException]) {
        return $true
    }
    return Test-GerberHttpTimeoutFailure -Exception $Exception.InnerException
}
