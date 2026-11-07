function New-GerberPluginApiReadSecureValueOperation {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiReadSecureValueOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param([string]$Prompt)

        Read-GerberSecureValue -Prompt $Prompt
    }
}
