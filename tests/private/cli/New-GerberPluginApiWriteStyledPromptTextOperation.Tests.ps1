BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'New-GerberPluginApiWriteStyledPromptTextOperation' -Tag 'PluginPlatform' {
    It 'propagates rendering failures so product callers can handle recovery' {
        Mock Write-GerberStyledPromptText { throw [System.InvalidOperationException]::new('Rendering failed') }
        { & (New-GerberPluginApiWriteStyledPromptTextOperation) 'Choice' ([pscustomobject]@{ Mode = 'ReverseVideo' }) } |
            Should -Throw 'Rendering failed'
    }
}
