function Merge-GerberConfigurationTransitionData {
    param([object]$Existing, [object]$Incoming, [string]$Path)

    if ($Existing -is [System.Collections.IDictionary] -and $Incoming -is [System.Collections.IDictionary]) {
        return Merge-GerberConfigurationTransitionMap -Existing $Existing -Incoming $Incoming -Path $Path
    }
    if (Test-GerberConfigurationTransitionValueEqual -First $Existing -Second $Incoming) { return ,$Existing }
    throw [System.IO.InvalidDataException]::new("Configuration transition conflict at '$Path'. Originals were preserved. Merge the old config.json into the named destination files manually, then remove config.json only after verifying every setting.")
}

function Merge-GerberConfigurationTransitionMap {
    param([System.Collections.IDictionary]$Existing, [System.Collections.IDictionary]$Incoming, [string]$Path)

    $merged = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
    foreach ($key in $Existing.Keys) { $merged[$key] = $Existing[$key] }
    foreach ($key in $Incoming.Keys) {
        if ($merged.Contains($key)) {
            $merged[$key] = Merge-GerberConfigurationTransitionData -Existing $Existing[$key] -Incoming $Incoming[$key] -Path "$Path/$key"
        } else {
            $merged[$key] = $Incoming[$key]
        }
    }
    return $merged
}
