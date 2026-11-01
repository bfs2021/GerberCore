function Get-GerberConfigurationTransitionPlan {
    param([string]$CorePath, [object]$Original)

    if ($Original -isnot [System.Collections.IDictionary]) {
        throw [System.IO.InvalidDataException]::new('Legacy config.json must contain a JSON object. The file was retained.')
    }
    $core = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
    foreach ($key in $Original.Keys) { if ($key -cne 'ado') { $core[$key] = $Original[$key] } }
    $plan = @(New-GerberConfigurationTransitionItem -Path $CorePath -Incoming $core)
    if ($Original.Keys -ccontains 'ado') {
        $pluginPath = Resolve-GerberPluginConfigPath -ModuleName 'Gerber.AzureDevOps' -CorePath $CorePath
        $plan += New-GerberConfigurationTransitionItem -Path $pluginPath -Incoming ([ordered]@{ ado = $Original['ado'] })
    }
    return $plan
}

function New-GerberConfigurationTransitionItem {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Path, [object]$Incoming)

    $null = $PSCmdlet.ShouldProcess('New-GerberConfigurationTransitionItem', 'Invoke')
    $existing = Read-GerberJsonConfiguration -Path $Path
    $value = if (Test-Path -LiteralPath $Path) {
        Merge-GerberConfigurationTransitionData -Existing $existing -Incoming $Incoming -Path $Path
    } else { $Incoming }
    return [pscustomobject]@{ Path = $Path; Value = $value }
}
