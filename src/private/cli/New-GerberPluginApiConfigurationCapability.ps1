function New-GerberPluginApiConfigurationCapability {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$ModuleName)

    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiConfigurationCapability', 'Invoke')
    Assert-GerberPluginConfigurationModuleName -ModuleName $ModuleName
    $literal = $ModuleName.Replace("'", "''")
    return [pscustomobject]@{
        Read = Get-GerberModuleBoundScriptBlock -ScriptBlock ([scriptblock]::Create("Read-GerberJsonConfiguration -Path (Resolve-GerberPluginConfigPath -ModuleName '$literal')"))
        Save = Get-GerberModuleBoundScriptBlock -ScriptBlock ([scriptblock]::Create("param([AllowNull()][object]`$Value) Save-GerberJsonConfiguration -Path (Resolve-GerberPluginConfigPath -ModuleName '$literal') -Value `$Value"))
    }
}
