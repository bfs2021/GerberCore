BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberHelpView' {
    It 'lists the remaining command surface and excludes removed placeholder commands' {
        $script:helpTitle = $null
        $script:helpText = $null
        Mock Show-GerberTextBlock {
            $script:helpTitle = $Title
            $script:helpText = $Text
        }
        Mock Wait-GerberContinue {}

        Show-GerberHelpView

        $script:helpTitle | Should -Be '/help'
        $script:helpText | Should -Match '/tools'
        $script:helpText | Should -Match '/list'
        $script:helpText | Should -Match '/repository Open the interactive repository menu'
        $script:helpText | Should -Not -Match '/repository create Create a new repository from template'
        $script:helpText | Should -Match '/plugins Show Gerber plugin status and manage plugin activation'
        $script:helpText | Should -Match '/plugins list List discovered and persisted Gerber plugins'
        $script:helpText | Should -Match '/plugins info Show detailed plugin information by GUID or unique module name'
        $script:helpText | Should -Match '/pipelines'
        $script:helpText | Should -Not -Match '/pipelines tags Open the pipeline tag submenu'
        $script:helpText | Should -Not -Match '/pipelines release'
        $script:helpText | Should -Not -Match '/pipelines tags delete'
        $script:helpText | Should -Not -Match '/pipelines tags update'
        $script:helpText | Should -Match '/secrets'
        $script:helpText | Should -Match '/tools create-uuid'
        $script:helpText | Should -Match '/tools base-64'
        $script:helpText | Should -Not -Match '/status'
        $script:helpText | Should -Not -Match '/git'
        $script:helpText | Should -Not -Match '/test'
        $script:helpText | Should -Not -Match '/http'
        $script:helpText | Should -Not -Match '/config'
        Should -Invoke Wait-GerberContinue -Times 1
    }

    It 'renders a registered neutral fixture leaf without Core owning its definition' {
        Mock Get-GerberCommandRegistry {
            @(
                @{ Name = 'repository'; Description = 'Manage repositories'; Subcommands = [ordered]@{} }
                @{ Name = 'repository inspect'; Description = 'Inspect the neutral fixture'; Subcommands = [ordered]@{} }
            )
        }
        Mock Show-GerberTextBlock { $script:helpText = $Text }
        Mock Wait-GerberContinue {}

        Show-GerberHelpView

        $script:helpText | Should -Match '/repository inspect Inspect the neutral fixture'
    }
}
