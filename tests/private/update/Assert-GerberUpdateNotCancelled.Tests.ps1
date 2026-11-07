BeforeAll {
    . (Join-Path $PSScriptRoot '../../TestHelpers/PluginUpdate.TestSupport.ps1')
}

Describe 'Assert-GerberUpdateNotCancelled' -Tag 'G4A9' {
    It 'propagates explicit cancellation instead of turning it into a recoverable failure' {
        $errorRecord = [Management.Automation.ErrorRecord]::new(
            [OperationCanceledException]::new('cancel'), 'Cancel', 'OperationStopped', $null)
        {
            Assert-GerberUpdateNotCancelled $errorRecord
        } | Should -Throw '*cancel*'
    }

    It 'allows ordinary provider failures to be translated without emitting their text' {
        $errorRecord = [Management.Automation.ErrorRecord]::new(
            [InvalidOperationException]::new('private-token'), 'Provider', 'InvalidOperation', $null)
        @(Assert-GerberUpdateNotCancelled $errorRecord).Count | Should -Be 0
    }
}
