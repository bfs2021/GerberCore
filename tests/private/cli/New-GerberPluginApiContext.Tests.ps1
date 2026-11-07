BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberPluginApiSecretsTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'New-GerberPluginApiContext' -Tag 'PluginPlatform' {
    BeforeEach {
        $script:testPluginId = [guid]'977537c5-b7f5-4f2f-9dd4-5ec0e28d2618'
        Remove-Variable -Name GerberCredentialStore -Scope Script -ErrorAction SilentlyContinue
    }

    It 'creates the v1 plugin API context with the declared API version and capability set' {
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $context.ApiVersion | Should -Be '1'
        $context.PluginId | Should -Be $script:testPluginId
        $context.UI.ReadSubcommand | Should -BeOfType ([scriptblock])
        $context.UI.ShowTextBlock | Should -BeOfType ([scriptblock])
        $context.UI.ShowScreenLines | Should -BeOfType ([scriptblock])
        $context.UI.ReadNumberedMenuSelection | Should -BeOfType ([scriptblock])
        $context.UI.ReadNumberedMenuPrompt | Should -BeOfType ([scriptblock])
        $context.UI.ReadCheckboxMenuPrompt | Should -BeOfType ([scriptblock])
        $context.UI.ReadConfirmationPrompt | Should -BeOfType ([scriptblock])
        $context.UI.ReadCommand | Should -BeOfType ([scriptblock])
        $context.UI.ReadSecretText | Should -BeOfType ([scriptblock])
        $context.UI.StartScreen | Should -BeOfType ([scriptblock])
        $context.UI.WriteScreenLine | Should -BeOfType ([scriptblock])
        $context.UI.WriteProgressBar | Should -BeOfType ([scriptblock])
        $context.UI.WritePromptTrace | Should -BeOfType ([scriptblock])
        $context.UI.WaitForContinue | Should -BeOfType ([scriptblock])
        $context.Configuration.Read | Should -BeOfType ([scriptblock])
        $context.Configuration.Save | Should -BeOfType ([scriptblock])
        $context.PSObject.Properties.Name | Should -Not -Contain 'Ado'
        $context.Secrets.EnsureReady | Should -BeOfType ([scriptblock])
        $context.Secrets.Test | Should -BeOfType ([scriptblock])
        $context.Secrets.GetText | Should -BeOfType ([scriptblock])
        $context.Secrets.Set | Should -BeOfType ([scriptblock])
        $context.Secrets.Remove | Should -BeOfType ([scriptblock])
        $context.Clipboard.CopyText | Should -BeOfType ([scriptblock])
    }

    It 'fails clearly for an unsupported plugin API version' {
        {
            New-GerberPluginApiContext -ApiVersion '99' -PluginId $script:testPluginId
        } | Should -Throw "Gerber plugin API version '99' is not supported. Supported plugin API versions: 1."
    }

    It 'lets a plugin chooser preserve default Enter submission without changing existing callers' {
        Mock Get-GerberMenuSubcommand { 'chosen' }
        $api = New-GerberPluginApiContext -ApiVersion 1 -PluginId $script:testPluginId
        $command = [pscustomobject]@{ Arguments = @() }
        (& $api.UI.ReadSubcommand 'branch' $command @{ chosen = 'Choice' } $true) | Should -Be 'chosen'
        Should -Invoke Get-GerberMenuSubcommand -Times 1 -ParameterFilter { $AutoSelectFirstSuggestionOnSubmit }
    }

    It 'maps UI prompt operations to the shared Gerber helpers' {
        Mock Read-GerberSubcommandPrompt { '/tools plugin-tool option-b' }
        Mock Read-GerberNumberedMenuPrompt { 'value-2' }
        Mock Read-GerberCheckboxMenuPrompt { [pscustomobject]@{ SelectedItemList = @(); DeselectedItemList = @() } }
        Mock Read-GerberConfirmationPrompt { $true }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        (& $context.UI.ReadSubcommand 'tools plugin-tool' ([pscustomobject]@{ Arguments = @() }) ([ordered]@{ 'option-b' = 'Option B' })) | Should -Be 'option-b'
        (& $context.UI.ReadNumberedMenuSelection 'Prompt' '/tools plugin-tool option-b' 'Choose one' @(
                [pscustomobject]@{ Number = 1; Label = 'One'; Value = 'value-1'; PreviewText = '' }
                [pscustomobject]@{ Number = 2; Label = 'Two'; Value = 'value-2'; PreviewText = '' }
            )) | Should -Be 'value-2'
        (& $context.UI.ReadNumberedMenuPrompt 'Prompt' '/tools plugin-tool option-b' 'Choose one' @()) | Should -Be 'value-2'
        (& $context.UI.ReadCheckboxMenuPrompt ([pscustomobject]@{ Prompt = 'Prompt' })) | Should -Not -BeNullOrEmpty
        (& $context.UI.ReadConfirmationPrompt 'Confirm' 'Title' 'Body' ([pscustomobject]@{})) | Should -BeTrue

        Should -Invoke Read-GerberSubcommandPrompt -Times 1 -ParameterFilter { $CommandName -eq 'tools plugin-tool' }
        Should -Invoke Read-GerberNumberedMenuPrompt -Times 1 -ParameterFilter {
            $Prompt -eq 'Prompt' -and
            $ScreenTitle -eq '/tools plugin-tool option-b' -and
            $ScreenText -eq 'Choose one' -and
            $MenuItemList[1].Value -eq 'value-2'
        }
        Should -Invoke Read-GerberCheckboxMenuPrompt -Times 1 -ParameterFilter { $PromptRequest.Prompt -eq 'Prompt' }
        Should -Invoke Read-GerberConfirmationPrompt -Times 1 -ParameterFilter { $Prompt -eq 'Confirm' -and $ScreenTitle -eq 'Title' }
    }

    It 'maps UI rendering operations to the shared Gerber helpers' {
        Mock Show-GerberTextBlock {}
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}
        Mock Write-GerberProgressBar {}
        Mock Write-GerberPromptTrace {}
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        & $context.UI.ShowTextBlock 'Title' 'Body'
        & $context.UI.ShowScreenLines '/tools plugin-tool option-b' @('first', '', 'second')
        & $context.UI.StartScreen '/tools plugin-tool option-b'
        & $context.UI.WriteScreenLine 'line'
        & $context.UI.WriteProgressBar 1 2 'Prefix'
        & $context.UI.WritePromptTrace 'event' @{ ok = $true }

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Title -eq 'Title' -and $Text -eq 'Body' }
        Should -Invoke Start-GerberScreen -Times 2 -ParameterFilter { $Name -eq '/tools plugin-tool option-b' }
        Should -Invoke Write-GerberScreenLine -Times 4
        Should -Invoke Write-GerberProgressBar -Times 1 -ParameterFilter { $Current -eq 1 -and $Total -eq 2 -and $Prefix -eq 'Prefix' }
        Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter { $EventName -eq 'event' -and $Data.ok }
    }

    It 'allows plugins to render an empty text block body' {
        Mock Show-GerberTextBlock {}
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        { & $context.UI.ShowTextBlock 'Title' '' } | Should -Not -Throw

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter { $Title -eq 'Title' -and $Text -eq '' }
    }

    It 'maps UI command and secret operations to the shared Gerber helpers' {
        Mock Read-GerberCommand { 'typed-value' }
        Mock Read-GerberSecureValue {
            $secureValue = [System.Security.SecureString]::new()
            foreach ($character in 'secret-value'.ToCharArray()) {
                $secureValue.AppendChar($character)
            }

            $secureValue.MakeReadOnly()
            return $secureValue
        }
        Mock Wait-GerberContinue {}
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        (& $context.UI.ReadCommand 'Prompt' 'None' 'Buffered' $null $true) | Should -Be 'typed-value'
        (& $context.UI.ReadSecretText 'Plugin secret') | Should -Be 'secret-value'
        (& $context.UI.WaitForContinue) | Should -BeTrue

        Should -Invoke Read-GerberCommand -Times 1 -ParameterFilter { $Prompt -eq 'Prompt' -and $SuggestionMode -eq 'None' }
        Should -Invoke Read-GerberSecureValue -Times 1 -ParameterFilter { $Prompt -eq 'Plugin secret' }
        Should -Invoke Wait-GerberContinue -Times 1
    }

    It 'returns neutral UI results when Escape is used in plugin-driven prompts' {
        Mock Read-GerberSubcommandPrompt { throw (Get-GerberMenuEscapeException) }
        Mock Read-GerberNumberedMenuPrompt { throw (Get-GerberMenuEscapeException) }
        Mock Read-GerberSecureValue { throw (Get-GerberMenuEscapeException) }
        Mock Wait-GerberContinue { throw (Get-GerberMenuEscapeException) }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        (& $context.UI.ReadSubcommand 'tools plugin-tool' ([pscustomobject]@{ Arguments = @() }) ([ordered]@{})) | Should -Be ''
        (& $context.UI.ReadNumberedMenuSelection 'Prompt' '/tools plugin-tool option-b' 'Choose one' @()) | Should -BeNullOrEmpty
        (& $context.UI.ReadSecretText 'Plugin secret') | Should -BeNullOrEmpty
        (& $context.UI.WaitForContinue) | Should -BeFalse
    }

    It 'maps credential capability operations to the plugin GUID namespace' {
        $expectedIdentifier = 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tools:plugin-tool:secret:client-u'
        $store = [pscustomobject]@{
            Account = $expectedIdentifier
            Secret = 'stored-secret'
            LastService = $null
            LastReadAccount = $null
            LastWrittenAccount = $null
            LastRemovedAccount = $null
        }
        $store | Add-Member ScriptMethod GetAccounts { @($this.Account) }
        $store | Add-Member ScriptMethod Get {
            param($service, $account)
            $this.LastService = $service
            $this.LastReadAccount = $account
            if ($null -eq $this.Secret) {
                return $null
            }

            return [pscustomobject]@{ Password = $this.Secret }
        }
        $store | Add-Member ScriptMethod AddOrUpdate {
            param($service, $account, $secret)
            $this.LastService = $service
            $this.LastWrittenAccount = $account
            $this.Account = $account
            $this.Secret = $secret
        }
        $store | Add-Member ScriptMethod Remove {
            param($service, $account)
            $this.LastService = $service
            $this.LastRemovedAccount = $account
            $this.Secret = $null
            return $true
        }
        $script:GerberCredentialStore = $store
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        (& $context.Secrets.EnsureReady 'run a plugin action' '/tools plugin-tool option-a') | Should -BeTrue
        (& $context.Secrets.GetText @('tools', 'plugin-tool', 'secret', 'client-u')) | Should -Be 'stored-secret'
        $store.LastReadAccount | Should -Be $expectedIdentifier
        (& $context.Secrets.Test @('tools', 'plugin-tool', 'secret', 'client-u')) | Should -BeTrue
        & $context.Secrets.Set @('tools', 'plugin-tool', 'secret', 'client-u') 'new-secret'
        $store.LastService | Should -Be 'credentials'
        $store.LastWrittenAccount | Should -Be $expectedIdentifier
        $store.Secret | Should -Be 'new-secret'
        (& $context.Secrets.Remove @('tools', 'plugin-tool', 'secret', 'client-u')) | Should -BeTrue
        $store.LastRemovedAccount | Should -Be $expectedIdentifier
        $store.Secret | Should -BeNullOrEmpty
    }

    It 'keeps plugin secret callbacks bound to the Gerber module session state when invoked from an external module' {
        $store = Get-TestGerberPluginCredentialStore `
            -Account 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tools:plugin-tool:secret:client-u' `
            -Secret 'stored-secret'
        $script:GerberCredentialStore = $store
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId
        $result = Invoke-TestGerberPluginSecretsRoundTrip -Context $context

        $result.Ready | Should -BeTrue
        $result.Before | Should -Be 'stored-secret'
        $result.After | Should -Be 'updated-secret'
        $result.ExistsAfterRemove | Should -BeFalse
        $store.LastReadAccount | Should -Be 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tools:plugin-tool:secret:client-u'
        $store.LastWrittenAccount | Should -Be 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tools:plugin-tool:secret:client-u'
        $store.LastRemovedAccount | Should -Be 'gerber:plugin:977537c5-b7f5-4f2f-9dd4-5ec0e28d2618:tools:plugin-tool:secret:client-u'
    }

    It 'surfaces Gerber-specific secure storage errors for plugin secret readiness checks' {
        Mock Get-GerberCredentialInfo {
            throw [System.InvalidOperationException]::new(
                'Gerber could not initialize secure credential storage. Verify that secure credential storage is available for your user account, then try again.'
            )
        }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $errorText = $null
        try {
            & $context.Secrets.EnsureReady 'run a plugin action' '/tools plugin-tool option-a' | Out-Null
        } catch {
            $errorText = $_.Exception.ToString()
        }

        $errorText | Should -Match 'secure credential storage'
        $errorText | Should -Not -Match 'Devlooped'
    }

    It 'rejects empty secret path segment lists' {
        {
            Get-GerberPluginCredentialIdentifier -PluginId $script:testPluginId -PathSegmentList @()
        } | Should -Throw 'Gerber plugin API secret operations require at least one path segment.'
    }

    It 'maps the clipboard capability to shared Core infrastructure' {
        Mock Copy-GerberValueToClipboard { [pscustomobject]@{ Success = $true; Message = 'Copied.' } }
        $context = New-GerberPluginApiContext -ApiVersion '1' -PluginId $script:testPluginId

        $clipboardResult = & $context.Clipboard.CopyText 'token-value'

        $clipboardResult.Success | Should -BeTrue
        Should -Invoke Copy-GerberValueToClipboard -Times 1 -ParameterFilter { $Value -eq 'token-value' }
    }
}
