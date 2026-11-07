function Test-GerberCommandContainer {
    [OutputType([bool])]
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Definition)

    $property = $Definition.PSObject.Properties['IsContainer']
    if ($Definition -is [System.Collections.IDictionary]) {
        return $Definition.Contains('IsContainer') -and $Definition['IsContainer'] -eq $true
    }
    return $null -ne $property -and $property.Value -eq $true
}
