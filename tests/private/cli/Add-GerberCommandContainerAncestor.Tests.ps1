BeforeAll {
    . (Join-Path $PSScriptRoot '../../TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Add-GerberCommandContainerAncestor' -Tag 'ActiveCommandTree' {
    It 'materializes arbitrary missing ancestors in parent-first order only once' {
        $commands = [System.Collections.Generic.List[object]]::new()
        $definitions = @([pscustomobject]@{ Name = 'generic nested leaf'; ParentName = 'generic nested'; OwnerName = 'Gerber.GenericPlugin' })
        Add-GerberCommandContainerAncestor -Commands $commands -Definitions $definitions
        Add-GerberCommandContainerAncestor -Commands $commands -Definitions $definitions
        $commands.Name | Should -Be @('generic', 'generic nested')
        $commands.IsContainer | Should -Be @($true, $true)
        $commands[0].Subcommands.Keys | Should -Be @('nested')
    }

    It 'leaves declared and standalone parents intact' {
        $commands = [System.Collections.Generic.List[object]]::new()
        $definitions = @([pscustomobject]@{ Name = 'generic'; ParentName = '' }, [pscustomobject]@{ Name = 'generic leaf'; ParentName = 'generic' })
        Add-GerberCommandContainerAncestor -Commands $commands -Definitions $definitions
        $commands.Count | Should -Be 0
    }

    It 'does not replace an existing Core catalog leaf with a synthesized intermediate container' {
        $commands = [System.Collections.Generic.List[object]]::new([object[]]@(Get-GerberCommandRegistry))
        $definition = [pscustomobject]@{ Name = 'secrets get nested'; Description = 'Nested'; Handler = {}; Subcommands = @{} }
        { Add-GerberOwnedCommandDefinitionList -RegisteredCommandList $commands -CommandDefinitionList @($definition) `
            -OwnerName Gerber.GenericPlugin -OwnerType Plugin } | Should -Throw '*already owned*'
        $commands.Name | Should -Not -Contain 'secrets get'
        $commands[0].Name | Should -Be 'tools'
    }

    It 'does not allow synthesized intermediates to bypass another plugin parent ownership' {
        $parent = ConvertTo-GerberOwnedCommandDefinition -OwnerName Gerber.OtherPlugin -OwnerType Plugin `
            -CommandDefinition ([pscustomobject]@{ Name = 'foreign'; Description = 'Foreign'; Handler = {}; Subcommands = @{} })
        $commands = [System.Collections.Generic.List[object]]::new([object[]]@($parent))
        $definition = [pscustomobject]@{ Name = 'foreign nested leaf'; Description = 'Leaf'; Handler = {}; Subcommands = @{} }
        { Add-GerberOwnedCommandDefinitionList -RegisteredCommandList $commands -CommandDefinitionList @($definition) `
            -OwnerName Gerber.GenericPlugin -OwnerType Plugin } | Should -Throw "*another plugin owner 'Gerber.OtherPlugin'*"
        $commands.Name | Should -Be @('foreign')
    }

    It 'inherits a plugin-owned ancestor boundary rather than turning it into a shared Core boundary' {
        $parent = ConvertTo-GerberOwnedCommandDefinition -OwnerName Gerber.GenericPlugin -OwnerType Plugin `
            -CommandDefinition ([pscustomobject]@{ Name = 'owned'; Description = 'Owned'; Handler = {}; Subcommands = @{} })
        $commands = [System.Collections.Generic.List[object]]::new([object[]]@($parent))
        $definition = [pscustomobject]@{ Name = 'owned nested leaf'; Description = 'Leaf'; Handler = {}; Subcommands = @{} }
        Add-GerberOwnedCommandDefinitionList -RegisteredCommandList $commands -CommandDefinitionList @($definition) `
            -OwnerName Gerber.GenericPlugin -OwnerType Plugin
        ($commands | Where-Object Name -EQ 'owned nested').OwnerType | Should -Be Plugin
        $other = [pscustomobject]@{ Name = 'owned nested other'; Description = 'Other'; Handler = {}; Subcommands = @{} }
        { Add-GerberOwnedCommandDefinitionList -RegisteredCommandList $commands -CommandDefinitionList @($other) `
            -OwnerName Gerber.OtherPlugin -OwnerType Plugin } | Should -Throw '*another plugin owner*'
    }
}
