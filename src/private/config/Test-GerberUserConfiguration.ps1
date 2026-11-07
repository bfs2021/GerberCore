function Test-GerberUserConfiguration {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-GerberUserConfigurationRootObject -Configuration $Configuration)) {
        throw [System.IO.InvalidDataException]::new("Gerber user configuration file '$Path' must be a JSON object.")
    }

    $schemaVersion = Get-GerberUserConfigurationPropertyValue -Configuration $Configuration -PropertyName 'schemaVersion'
    if ($null -eq $schemaVersion) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' is missing the required 'schemaVersion' property."
        )
    }

    if (-not (Test-GerberUserConfigurationIntegerValue -Value $schemaVersion)) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber user configuration file '$Path' has an invalid 'schemaVersion' value. Expected an integer."
        )
    }

    if ([long]$schemaVersion -ne 1) {
        throw [System.IO.InvalidDataException]::new(
            "Unsupported schemaVersion '$schemaVersion' in Gerber user configuration file '$Path'. Gerber currently supports schemaVersion '1'."
        )
    }

    $null = Test-GerberPluginUserConfiguration -Configuration $Configuration -Path $Path
    $null = Test-GerberCoreUpdateConfiguration -Configuration $Configuration -Path $Path
    return $true
}

function Test-GerberUserConfigurationRootObject {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Configuration
    )

    return ($Configuration -is [System.Collections.IDictionary]) -or ($Configuration -is [pscustomobject])
}

function Get-GerberUserConfigurationPropertyValue {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    if ($Configuration -is [System.Collections.IDictionary]) {
        if ($Configuration.Contains($PropertyName)) {
            return $Configuration[$PropertyName]
        }

        return $null
    }

    $property = $Configuration.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Test-GerberUserConfigurationIntegerValue {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    return ($Value -is [byte]) -or
        ($Value -is [sbyte]) -or
        ($Value -is [int16]) -or
        ($Value -is [uint16]) -or
        ($Value -is [int32]) -or
        ($Value -is [uint32]) -or
        ($Value -is [int64]) -or
        ($Value -is [uint64])
}
