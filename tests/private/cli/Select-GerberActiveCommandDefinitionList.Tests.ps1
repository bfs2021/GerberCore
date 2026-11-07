BeforeAll {
    . (Join-Path $PSScriptRoot '../../TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Select-GerberActiveCommandDefinitionList' -Tag 'ActiveCommandTree' {
    It 'prunes empty intermediate catalog containers without removing standalone string and catalog actions' {
        $command = ConvertTo-GerberOwnedCommandDefinition -OwnerName Gerber.Core -OwnerType Core `
            -CommandDefinition ([pscustomobject]@{ Name = 'generic'; Description = 'Generic'; Handler = {}; Subcommands = [ordered]@{
                empty = @{ Description = 'Empty'; IsContainer = $true; Subcommands = [ordered]@{
                    nested = @{ Description = 'Nested'; IsContainer = $true; Subcommands = [ordered]@{} }
                } }
                text = 'Standalone string action'
                action = @{ Description = 'Standalone catalog action'; Subcommands = [ordered]@{} }
            } })
        $result = @(Select-GerberActiveCommandDefinitionList -Commands @($command))
        $result.Name | Should -Be @('generic')
        $result[0].Subcommands.Keys | Should -Be @('text', 'action')
    }

    It 'accepts an empty registry' {
        @(Select-GerberActiveCommandDefinitionList -Commands @()).Count | Should -Be 0
    }
}
