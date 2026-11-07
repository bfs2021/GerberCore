function Get-GerberUserConfigurationTemporaryPath {
    [OutputType([string])]
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DestinationPath)

    return (Join-Path (Split-Path -Parent $DestinationPath) ([System.IO.Path]::GetRandomFileName() + '.tmp'))
}
