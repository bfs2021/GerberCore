BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'New-GerberPluginApiHttpCapability' -Tag 'PluginPlatform' {
    It 'exposes platform timeouts without product configuration or credentials' {
        Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 20; OperationTimeoutSeconds = 30 } }
        $api = New-GerberPluginApiContext -ApiVersion 1 -PluginId ([guid]::NewGuid())
        (& $api.Http.GetConfiguration).OperationTimeoutSeconds | Should -Be 30
        $api.Http.PSObject.Properties.Name | Should -Not -Contain 'InvokeGet'
    }

    It 'preserves nested timeout and DNS hints without classifying arbitrary failures as timeouts' {
        $api = New-GerberPluginApiContext -ApiVersion 1 -PluginId ([guid]::NewGuid())
        $timeout = [System.Exception]::new('outer', [System.Threading.Tasks.TaskCanceledException]::new('timeout'))
        (& $api.Http.IsTimeoutFailure $timeout) | Should -BeTrue
        (& $api.Http.GetTransportFailureHint $timeout) | Should -Be 'Try again in a moment.'
        (& $api.Http.IsTimeoutFailure ([System.Exception]::new('other'))) | Should -BeFalse
        (& $api.Http.GetTransportFailureHint ([System.Exception]::new('No such host is known'))) | Should -Match 'DNS/VPN'
    }
}
