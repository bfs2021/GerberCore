function Get-GerberUserConfiguration {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param()

    $configPath = Resolve-GerberUserConfigPath
    Invoke-GerberLegacyConfigurationTransition -CorePath $configPath
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        return @{
            schemaVersion = 1
        }
    }

    try {
        $json = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop
    } catch [System.UnauthorizedAccessException] {
        throw [System.UnauthorizedAccessException]::new(
            "Gerber could not read user configuration file '$configPath'. Access was denied.",
            $_.Exception
        )
    } catch [System.IO.IOException] {
        throw [System.IO.IOException]::new(
            "Gerber could not read user configuration file '$configPath'. $($_.Exception.Message)",
            $_.Exception
        )
    }

    if ([string]::IsNullOrWhiteSpace($json)) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$configPath' is empty. Add a JSON object with 'schemaVersion': 1."
        )
    }

    Assert-GerberJsonConfigurationText -Json $json -Path $configPath

    if (-not (Test-GerberUserConfigurationJsonObjectText -Json $json)) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$configPath' must be a JSON object."
        )
    }

    try {
        $configuration = $json | ConvertFrom-Json -AsHashtable -Depth 100
    } catch [System.ArgumentException] {
        throw [System.IO.InvalidDataException]::new(
            "Gerber could not parse user configuration file '$configPath' as JSON.",
            $_.Exception
        )
    } catch [System.InvalidOperationException] {
        throw [System.IO.InvalidDataException]::new(
            "Gerber could not parse user configuration file '$configPath' as JSON.",
            $_.Exception
        )
    }

    $null = Test-GerberUserConfiguration -Configuration $configuration -Path $configPath
    return $configuration
}

function Test-GerberUserConfigurationJsonObjectText {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Json
    )

    return $Json.TrimStart().StartsWith('{')
}
