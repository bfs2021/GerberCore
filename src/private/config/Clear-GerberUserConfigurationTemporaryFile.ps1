function Clear-GerberUserConfigurationTemporaryFile {
    [CmdletBinding()]
    param([AllowNull()][string]$Path)

    if (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path)) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    }
}
