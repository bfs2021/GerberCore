function Publish-GerberUserConfigurationTemporaryFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SourcePath, [Parameter(Mandatory)][string]$DestinationPath)

    if (-not (Test-Path -LiteralPath $DestinationPath -PathType Leaf)) {
        [System.IO.File]::Move($SourcePath, $DestinationPath)
    } elseif ($IsWindows) {
        [System.IO.File]::Replace($SourcePath, $DestinationPath, $null, $false)
    } else {
        [System.IO.File]::Move($SourcePath, $DestinationPath, $true)
    }
}
