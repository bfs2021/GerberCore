function New-GerberPluginApiContext {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$ApiVersion,

        [Parameter(Mandatory)]
        [guid]$PluginId,

        [string]$PluginModuleName = 'Gerber.Plugin'
    )
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiContext', 'Invoke')

    switch ([string]$ApiVersion) {
        '1' {
            return [pscustomobject][ordered]@{
                ApiVersion = '1'
                PluginId   = $PluginId
                Configuration = New-GerberPluginApiConfigurationCapability -ModuleName $PluginModuleName
                UI         = New-GerberPluginApiUiCapability
                Http       = New-GerberPluginApiHttpCapability
                Secrets    = New-GerberPluginApiSecretsCapability -PluginId $PluginId
                Clipboard  = New-GerberPluginApiClipboardCapability
            }
        }
        default {
            $supportedVersionList = Get-GerberSupportedPluginApiVersionList
            throw [System.InvalidOperationException]::new(
                "Gerber plugin API version '$ApiVersion' is not supported. Supported plugin API versions: $($supportedVersionList -join ', ')."
            )
        }
    }
}

function Get-GerberSupportedPluginApiVersionList {
    [OutputType([string[]])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('Get-GerberSupportedPluginApiVersionList', 'Invoke')

    return [string[]]@('1')
}

function New-GerberPluginApiUiCapability {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiUiCapability', 'Invoke')

    $capability = [pscustomobject][ordered]@{
        ReadSubcommand            = New-GerberPluginApiReadSubcommandOperation
        ShowTextBlock             = New-GerberPluginApiShowTextBlockOperation
        ShowScreenLines           = New-GerberPluginApiShowScreenLinesOperation
        ReadNumberedMenuSelection = New-GerberPluginApiReadNumberedMenuSelectionOperation
        ReadNumberedMenuPrompt    = New-GerberPluginApiReadNumberedMenuPromptOperation
        ReadCheckboxMenuPrompt    = New-GerberPluginApiReadCheckboxMenuPromptOperation
        ReadConfirmationPrompt    = New-GerberPluginApiReadConfirmationPromptOperation
        ReadCommand               = New-GerberPluginApiReadCommandOperation
        ReadSecretText            = New-GerberPluginApiReadSecretTextOperation
        StartScreen               = New-GerberPluginApiStartScreenOperation
        WriteScreenLine           = New-GerberPluginApiWriteScreenLineOperation
        WriteProgressBar          = New-GerberPluginApiWriteProgressBarOperation
        WritePromptTrace          = New-GerberPluginApiWritePromptTraceOperation
        WaitForContinue           = New-GerberPluginApiWaitForContinueOperation
    }
    foreach ($operation in (New-GerberPluginApiPlatformUiCapability).PSObject.Properties) {
        $capability | Add-Member -MemberType NoteProperty -Name $operation.Name -Value $operation.Value
    }
    return $capability
}

function New-GerberPluginApiReadSubcommandOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiReadSubcommandOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [string]$CommandName,
            [pscustomobject]$Command,
            [System.Collections.IDictionary]$SubcommandTable,
            [bool]$AutoSelectFirstSuggestionOnSubmit = $false
        )

        try {
            return Get-GerberMenuSubcommand -CommandName $CommandName -Command $Command -SubcommandTable $SubcommandTable -AutoSelectFirstSuggestionOnSubmit:$AutoSelectFirstSuggestionOnSubmit
        } catch {
            if (Test-GerberMenuEscapeException -Exception $_.Exception) {
                return ''
            }

            throw
        }
    }
}

function New-GerberPluginApiReadCommandOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiReadCommandOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [string]$Prompt,
            [string]$SuggestionMode,
            [string]$InputMode,
            [pscustomobject]$PromptContext,
            [bool]$TrimResult
        )

        return Read-GerberCommand `
            -Prompt $Prompt `
            -SuggestionMode $SuggestionMode `
            -InputMode $InputMode `
            -PromptContext $PromptContext `
            -TrimResult:$TrimResult
    }
}

function New-GerberPluginApiWriteProgressBarOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiWriteProgressBarOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [int]$Current,
            [int]$Total,
            [string]$Prefix,
            [switch]$OverwritePreviousRender
        )

        Write-GerberProgressBar `
            -Current $Current `
            -Total $Total `
            -Prefix $Prefix `
            -OverwritePreviousRender:$OverwritePreviousRender
    }
}

function New-GerberPluginApiWritePromptTraceOperation {
    [OutputType([scriptblock])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiWritePromptTraceOperation', 'Invoke')

    return Get-GerberModuleBoundScriptBlock -ScriptBlock {
        param(
            [string]$EventName,
            [System.Collections.IDictionary]$Data = @{}
        )

        Write-GerberPromptTrace -EventName $EventName -Data $Data
    }
}

function New-GerberPluginApiSecretsCapability {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [guid]$PluginId
    )
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiSecretsCapability', 'Invoke')

    $pluginIdLiteral = $PluginId.ToString()
    return [pscustomobject][ordered]@{
        EnsureReady = Get-GerberModuleBoundScriptBlock -ScriptBlock ([scriptblock]::Create(@'
            param(
                [string]$ActionLabel,
                [string]$ScreenTitle
            )

            $null = $ActionLabel, $ScreenTitle
            return Use-GerberCredentialStore
'@))
        Test       = Get-GerberModuleBoundScriptBlock -ScriptBlock ([scriptblock]::Create(@"
            param(
                [string[]]`$PathSegmentList
            )

            `$identifier = Get-GerberPluginCredentialIdentifier -PluginId ([guid]'$pluginIdLiteral') -PathSegmentList `$PathSegmentList
            return Test-GerberCredential -Identifier `$identifier
"@))
        GetText    = Get-GerberModuleBoundScriptBlock -ScriptBlock ([scriptblock]::Create(@"
            param(
                [string[]]`$PathSegmentList
            )

            `$identifier = Get-GerberPluginCredentialIdentifier -PluginId ([guid]'$pluginIdLiteral') -PathSegmentList `$PathSegmentList
            return Get-GerberCredential -Identifier `$identifier
"@))
        Set        = Get-GerberModuleBoundScriptBlock -ScriptBlock ([scriptblock]::Create(@"
            param(
                [string[]]`$PathSegmentList,
                [object]`$Secret
            )

            `$identifier = Get-GerberPluginCredentialIdentifier -PluginId ([guid]'$pluginIdLiteral') -PathSegmentList `$PathSegmentList
            Set-GerberCredential -Identifier `$identifier -Secret (ConvertTo-GerberSecretText -Value `$Secret)
"@))
        Remove     = Get-GerberModuleBoundScriptBlock -ScriptBlock ([scriptblock]::Create(@"
            param(
                [string[]]`$PathSegmentList
            )

            `$identifier = Get-GerberPluginCredentialIdentifier -PluginId ([guid]'$pluginIdLiteral') -PathSegmentList `$PathSegmentList
            return Remove-GerberCredential -Identifier `$identifier
"@))
    }
}

function New-GerberPluginApiClipboardCapability {
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $null = $PSCmdlet.ShouldProcess('New-GerberPluginApiClipboardCapability', 'Invoke')

    return [pscustomobject][ordered]@{
        CopyText = Get-GerberModuleBoundScriptBlock -ScriptBlock {
            param(
                [string]$Value
            )

            return Copy-GerberValueToClipboard -Value $Value
        }
    }
}
