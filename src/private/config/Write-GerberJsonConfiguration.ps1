function Write-GerberJsonConfiguration {
    param([string]$Path, [string]$Json)

    $null = New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force -ErrorAction Stop
    $temporaryPath = Get-GerberUserConfigurationTemporaryPath -DestinationPath $Path
    try {
        Publish-GerberJsonConfigurationContent -Path $Path -TemporaryPath $temporaryPath -Json $Json
    } finally {
        Clear-GerberUserConfigurationTemporaryFile -Path $temporaryPath
    }
}

function Publish-GerberJsonConfigurationContent {
    param([string]$Path, [string]$TemporaryPath, [string]$Json)

    try {
        Write-GerberUserConfigurationFileContent -Path $TemporaryPath -Content $Json
        Protect-GerberUserConfigurationFile -Path $TemporaryPath
        Publish-GerberUserConfigurationTemporaryFile -SourcePath $TemporaryPath -DestinationPath $Path
    } catch [System.IO.IOException], [System.UnauthorizedAccessException] {
        throw [System.IO.IOException]::new("Gerber could not save JSON configuration file '$Path'. The previous file is preserved; check disk space and file access.")
    }
}
