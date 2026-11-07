function Invoke-GerberUpdateProbe {
    param([object]$Request, [int]$TimeoutMilliseconds = 2000)
    $process = Initialize-GerberUpdateProbeProcess $Request
    try {
        $null = $process.Start()
        $output = $process.StandardOutput.ReadToEndAsync()
        return Receive-GerberUpdateProbe -Process $process -Output $output -TimeoutMilliseconds $TimeoutMilliseconds
    } catch [System.Management.Automation.PipelineStoppedException] {
        throw
    } catch {
        return Get-GerberUpdateProbeFailure 'Unavailable'
    } finally {
        Close-GerberUpdateProbe $process
    }
}

function Initialize-GerberUpdateProbeProcess {
    param([object]$Request)
    $scriptText = Get-GerberUpdateProbeCommand $Request
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'pwsh'))
    foreach ($argument in @('-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand',
            [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scriptText)))) {
        $startInfo.ArgumentList.Add($argument)
    }
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $process
}

function Get-GerberUpdateProbeCommand {
    param([object]$Request)
    $payload = @{
        Manifest = Join-Path $Request.Module.ModuleBase 'Gerber.psd1'
    } | ConvertTo-Json -Depth 8 -Compress
    $encodedPayload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))
    "`$payload = '$encodedPayload';`n" + (Get-GerberUpdateProbeScript)
}

function Receive-GerberUpdateProbe {
    param([System.Diagnostics.Process]$Process, [System.Threading.Tasks.Task[string]]$Output, [int]$TimeoutMilliseconds)
    $null = $Process.StandardError.ReadToEndAsync()
    if (-not (Wait-GerberUpdateProbeOutput -Process $Process -Output $Output -TimeoutMilliseconds $TimeoutMilliseconds)) {
        return Get-GerberUpdateProbeFailure 'TimedOut'
    }
    if ($Process.ExitCode -ne 0) {
        return Get-GerberUpdateProbeFailure 'Unavailable'
    }
    Read-GerberUpdateProbeSummary $Output.Result
}

function Read-GerberUpdateProbeSummary {
    param([string]$Text)
    $summary = $Text | ConvertFrom-Json -ErrorAction Stop
    if ($summary.Status -notin @('Available', 'UpToDate', 'RestartRequired', 'Unavailable', 'NoMatchingPackage')) {
        return Get-GerberUpdateProbeFailure 'Unavailable'
    }
    $summary | Select-Object Status, Name, Installed, Available, Repository, Message
}

function Get-GerberUpdateProbeFailure {
    param([string]$Status)
    [pscustomobject]@{
        Status = $Status
    }
}

function Get-GerberUpdateProbeScript {
    param()
    @'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$data = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json -AsHashtable
$module = Import-Module $data.Manifest -PassThru -ErrorAction Stop
& $module {
    param($module)
    $request = [pscustomobject]@{ Module = $module }
    Get-GerberCoreUpdateState -Request $request | Select-Object Status, Name, Installed, Available, Repository, Message | ConvertTo-Json -Compress
} $module
'@
}
