BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Test-GerberHttpTimeoutFailure' -Tag 'PluginPlatform' {
    It 'distinguishes transport timeout from ordinary cancellation and missing errors' {
        (Test-GerberHttpTimeoutFailure -Exception $null) | Should -BeFalse
        (Test-GerberHttpTimeoutFailure -Exception ([System.OperationCanceledException]::new())) | Should -BeFalse
        $nested = [System.Exception]::new('outer', [System.Threading.Tasks.TaskCanceledException]::new())
        (Test-GerberHttpTimeoutFailure -Exception $nested) | Should -BeTrue
    }
}
