function Invoke-GerberUpdateActivationProbe {
    param([hashtable]$Payload, [int]$TimeoutMilliseconds = 15000)
    $process = [System.Diagnostics.Process]::new()
    try {
        $process.StartInfo = Get-GerberUpdateActivationStartInfo $Payload
        Receive-GerberUpdateActivationProbe -Process $process -CoreVersion $Payload.CoreVersion -TimeoutMilliseconds $TimeoutMilliseconds
    } catch {
        Assert-GerberUpdateNotCancelled $_
        Get-GerberUpdateActivationSummary -Status 'Unverified'
    } finally {
        Close-GerberUpdateProbe $process
    }
}

function Get-GerberUpdateActivationStartInfo {
    param([hashtable]$Payload)
    $json = $Payload | ConvertTo-Json -Depth 8 -Compress
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
    $info = [System.Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'pwsh'))
    foreach ($argument in @('-NoLogo', '-NoProfile', '-NonInteractive', '-File',
            (Get-GerberUpdateActivationWorkerPath), '-Payload', $encoded)) {
        $info.ArgumentList.Add($argument)
    }
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info
}

function Get-GerberUpdateActivationWorkerPath {
    param()
    foreach ($relative in @('resources/update', '../../resources/update')) {
        $path = Join-Path (Join-Path $PSScriptRoot $relative) 'Test-GerberUpdateActivationWorker.ps1'
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            return [IO.Path]::GetFullPath($path)
        }
    }
    throw [IO.FileNotFoundException]::new('The activation worker is missing. Rebuild or reinstall Gerber.')
}

function Receive-GerberUpdateActivationProbe {
    param([Diagnostics.Process]$Process, [string]$CoreVersion, [int]$TimeoutMilliseconds)
    $null = $Process.Start()
    $output = $Process.StandardOutput.ReadToEndAsync()
    $null = $Process.StandardError.ReadToEndAsync()
    if (-not (Wait-GerberUpdateProbeOutput -Process $Process -Output $output -TimeoutMilliseconds $TimeoutMilliseconds)) {
        return Get-GerberUpdateActivationSummary -Status 'Unverified'
    }
    if ($Process.ExitCode -ne 0) {
        return Get-GerberUpdateActivationSummary -Status 'Unverified'
    }
    Read-GerberUpdateActivationResponse $output.Result $CoreVersion
}
