function Read-GerberJsonConfiguration {
    [OutputType([object[]])]
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $json = Read-GerberJsonConfigurationText -Path $Path
    Assert-GerberJsonConfigurationText -Json $json -Path $Path
    return ,(ConvertFrom-GerberJsonConfiguration -Json $json)
}

function Read-GerberJsonConfigurationText {
    param([string]$Path)

    try {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    } catch [System.UnauthorizedAccessException] {
        throw [System.UnauthorizedAccessException]::new("Gerber could not read JSON configuration file '$Path'. Access was denied.")
    } catch [System.IO.IOException] {
        throw [System.IO.IOException]::new("Gerber could not read JSON configuration file '$Path'. Check file access and try again.")
    }
}
