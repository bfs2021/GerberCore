function Initialize-GerberTerminalConfigurationEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PromptTracePath
    )

    $runtimePath = Split-Path -Parent $PromptTracePath
    if (-not (Test-Path -LiteralPath $runtimePath -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $runtimePath -Force
    }

    $homePath = Join-Path $runtimePath 'home'
    $tempPath = Join-Path $runtimePath 'temp'
    $xdgConfigPath = Join-Path $runtimePath 'xdg-config'
    foreach ($path in @($homePath, $tempPath, $xdgConfigPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $path -Force
        }
    }

    $env:GERBER_CONFIG_PATH = Join-Path $runtimePath 'GerberCore.json'
    $env:HOME = $homePath
    $env:TEMP = $tempPath
    $env:TMP = $tempPath
    $env:TMPDIR = $tempPath
    $env:XDG_CONFIG_HOME = $xdgConfigPath
}
