function New-GerberPluginApiHttpCapability {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiHttpCapability', 'Invoke')

    return [pscustomobject]@{
        GetConfiguration = Get-GerberModuleBoundScriptBlock -ScriptBlock { Get-GerberHttpConfiguration }
        GetTransportFailureHint = Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param([System.Exception]$Exception)
            Get-GerberHttpTransportFailureHint -Exception $Exception
        }
        IsTimeoutFailure = Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param([System.Exception]$Exception)
            Test-GerberHttpTimeoutFailure -Exception $Exception
        }
    }
}
