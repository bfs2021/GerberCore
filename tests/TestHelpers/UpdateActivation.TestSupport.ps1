function Initialize-TestActivationFixture {
    param([string]$Directory, [hashtable]$Metadata)
    $null = New-Item -ItemType Directory -Path $Directory -Force
    $path = Join-Path $Directory 'Gerber.ActivationFixture.psd1'
    $modulePath = Join-Path $Directory 'Gerber.ActivationFixture.psm1'
    Set-Content -LiteralPath $modulePath -Value (Get-TestActivationModuleText)
    New-ModuleManifest -Path $path -RootModule 'Gerber.ActivationFixture.psm1' -ModuleVersion '1.0.0' `
        -Guid '7dd21b37-e080-4240-b05f-ec727389035e' -FunctionsToExport 'Get-GerberPlugin' -PrivateData @{
        Gerber = '__GERBER_METADATA__'
    }
    Complete-TestActivationManifest $path $Metadata
    Get-TestActivationIdentity $path
}

function Get-TestActivationIdentity {
    param([string]$Path)
    [pscustomobject]@{
        Name    = 'Gerber.ActivationFixture'
        Guid    = '7dd21b37-e080-4240-b05f-ec727389035e'
        Version = '1.0.0'
        Path    = $Path
    }
}

function Get-TestActivationModuleText {
    @'
function Get-GerberPlugin {
    param($Gerber)
    [pscustomobject]@{
        Commands = @()
    }
}
Export-ModuleMember -Function Get-GerberPlugin
'@
}

function Complete-TestActivationManifest {
    param([string]$Path, [hashtable]$Metadata)
    $api = $Metadata.ApiVersion.Replace("'", "''")
    $minimum = $Metadata.MinimumGerberVersion.Replace("'", "''")
    $literal = @"
@{
    Plugin = `$true
    ApiVersion = '$api'
    MinimumGerberVersion = '$minimum'
}
"@
    $text = (Get-Content -LiteralPath $Path -Raw).Replace("'__GERBER_METADATA__'", $literal)
    Set-Content -LiteralPath $Path -Value $text
}

function Invoke-TestActivationWorker {
    param([object]$Payload, [string]$Worker)
    $json = $Payload | ConvertTo-Json -Depth 10 -Compress
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
    $errorPath = Join-Path $TestDrive 'worker-stderr.txt'
    $output = & (Join-Path $PSHOME 'pwsh') -NoLogo -NoProfile -NonInteractive -File $Worker -Payload $encoded 2> $errorPath
    if ($LASTEXITCODE -ne 0) {
        return [pscustomobject]@{
            Status  = 'WorkerUnavailable'
            Version = ''
        }
    }
    $output | ConvertFrom-Json
}
