BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'New-GerberPluginApiPlatformUiCapability' -Tag 'PluginPlatform' {
    It 'preserves interactive detection and distinct Escape exceptions' {
        Mock Test-GerberInteractivePromptAvailable { $false }
        $api = New-GerberPluginApiContext -ApiVersion 1 -PluginId ([guid]::NewGuid())
        (& $api.UI.IsInteractive) | Should -BeFalse
        $escape = & $api.UI.GetEscapeException
        (& $api.UI.IsEscapeException $escape) | Should -BeTrue
        (& $api.UI.IsEscapeException ([System.Exception]::new('failure'))) | Should -BeFalse
    }

    It 'returns secure input intact and propagates Escape instead of treating it as a missing PAT' {
        $script:secureInput = [securestring]::new()
        $script:secureInput.AppendChar('x')
        Mock Read-GerberSecureValue { $script:secureInput }
        $api = New-GerberPluginApiContext -ApiVersion 1 -PluginId ([guid]::NewGuid())
        (& $api.UI.ReadSecureValue 'PAT') | Should -BeOfType ([securestring])
        Mock Read-GerberSecureValue { throw (Get-GerberMenuEscapeException) }
        { & $api.UI.ReadSecureValue 'PAT' } | Should -Throw 'Go back to the previous Gerber menu.'
    }

    It 'renders styled text and recoverable errors through the existing shared UI' {
        Mock Get-GerberPromptColorPair { [pscustomobject]@{ ForegroundColor = 'White'; BackgroundColor = 'Black' } }
        Mock Write-GerberStyledPromptText {}
        Mock Show-GerberMenuError {}
        $api = New-GerberPluginApiContext -ApiVersion 1 -PluginId ([guid]::NewGuid())
        $style = [pscustomobject]@{ Mode = 'ReverseVideo' }
        & $api.UI.WriteStyledPromptText 'Selected' $style
        & $api.UI.ShowMenuError 'Recoverable'
        (& $api.UI.GetPromptColorPair).ForegroundColor | Should -Be 'White'
        Should -Invoke Write-GerberStyledPromptText -Times 1 -ParameterFilter { $Text -eq 'Selected' -and $Style.Mode -eq 'ReverseVideo' }
        Should -Invoke Show-GerberMenuError -Times 1 -ParameterFilter { $Message -eq 'Recoverable' }
    }
}
