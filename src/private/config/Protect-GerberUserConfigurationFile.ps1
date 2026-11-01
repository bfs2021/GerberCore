function Protect-GerberUserConfigurationFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not $IsWindows) {
        [System.IO.File]::SetUnixFileMode($Path, [System.IO.UnixFileMode]'UserRead, UserWrite')
    }
}
