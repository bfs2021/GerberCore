function New-GerberPluginApiPlatformUiCapability {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiPlatformUiCapability', 'Invoke')

    return [pscustomobject]@{
        IsInteractive = Get-GerberModuleBoundScriptBlock -ScriptBlock { Test-GerberInteractivePromptAvailable }
        IsEscapeException = Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param([System.Exception]$Exception)
            Test-GerberMenuEscapeException -Exception $Exception
        }
        GetEscapeException = Get-GerberModuleBoundScriptBlock -ScriptBlock { Get-GerberMenuEscapeException }
        ReadSecureValue = New-GerberPluginApiReadSecureValueOperation
        WriteStyledPromptText = New-GerberPluginApiWriteStyledPromptTextOperation
        GetPromptColorPair = Get-GerberModuleBoundScriptBlock -ScriptBlock { Get-GerberPromptColorPair }
        ShowMenuError = New-GerberPluginApiShowMenuErrorOperation
    }
}
