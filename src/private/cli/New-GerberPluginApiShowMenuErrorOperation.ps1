function New-GerberPluginApiShowMenuErrorOperation {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiShowMenuErrorOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param([string]$Message)

        Show-GerberMenuError -Message $Message
    }
}
