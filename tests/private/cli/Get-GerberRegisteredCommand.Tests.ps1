BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberRegisteredCommand' -Tag 'ActiveCommandTree' {
    It 'returns a registered root command by name from the effective registry' {
        $commandDefinition = Get-GerberRegisteredCommand -Name 'tools'

        $commandDefinition.Name | Should -Be 'tools'
        $commandDefinition.Description | Should -Be 'Open the interactive tools menu'
        $commandDefinition.OwnerName | Should -Be 'Gerber.Core'
    }

    It 'returns null for an unknown root command' {
        $commandDefinition = Get-GerberRegisteredCommand -Name 'unknown'

        $commandDefinition | Should -BeNullOrEmpty
    }
}
