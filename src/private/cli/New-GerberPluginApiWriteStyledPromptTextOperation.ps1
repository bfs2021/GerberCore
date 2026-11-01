function New-GerberPluginApiWriteStyledPromptTextOperation {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiWriteStyledPromptTextOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param([string]$Text, [pscustomobject]$Style)

        Write-GerberStyledPromptText -Text $Text -Style $Style
    }
}
