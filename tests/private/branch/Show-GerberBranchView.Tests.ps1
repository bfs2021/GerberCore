BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Generic branch root menu' {
    It 'routes the supplied command to the registered subcommand menu without owning product actions' {
        Mock Show-GerberRegisteredSubcommandMenu {}
        $command = [pscustomobject]@{ Arguments = @() }
        Show-GerberBranchView -Command $command
        Should -Invoke Show-GerberRegisteredSubcommandMenu -Times 1 -ParameterFilter {
            $CommandName -eq 'branch' -and $Command -eq $command -and $AutoSelectFirstSuggestionOnSubmit
        }
        (Get-GerberCoreCommandDefinitionList | Where-Object Name -EQ branch).Subcommands.Count | Should -Be 0
    }
}
