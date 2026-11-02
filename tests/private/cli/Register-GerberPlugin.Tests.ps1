# Registration boundary tests retain real nested catalogs and publication so failure
# snapshots prove atomicity and preserve flat/nested shared-table topology.
BeforeAll {
    $supportPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers'
    . (Join-Path $supportPath 'GerberTestSupport.ps1')
    . (Join-Path $supportPath 'Get-GerberPluginTransactionCommand.ps1')
    . (Join-Path $supportPath 'Get-GerberRegistryTransactionSnapshot.ps1')
    . (Join-Path $supportPath 'Get-GerberRegistryTransactionModuleList.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
    $script:publishRegistry = ${function:Publish-GerberCommandRegistryState}
    $script:addSubcommand = ${function:Add-GerberOwnedSubcommandDefinition}
}

Describe 'Register-GerberPlugin' -Tag 'PluginTransactions' {
    BeforeEach {
        Clear-GerberCommandRegistry
        $null = Initialize-GerberCommandRegistry -PluginModulePathList @()
        $script:moduleA, $script:moduleB = Get-GerberRegistryTransactionModuleList -StartPath $PSScriptRoot
        $script:definition = [pscustomobject]@{ Commands = @(Get-GerberPluginTransactionCommand 'repository shared') }
        Mock Get-GerberPluginDefinition { $script:definition }
    }

    AfterEach {
        Clear-GerberCommandRegistry
    }

    AfterAll {
        $null = Initialize-GerberCommandRegistry -PluginModulePathList @()
    }

    It 'rejects a cross-plugin parent atomically without ghost commands' {
        Register-GerberPlugin -PluginModule $script:moduleA
        $before = Get-GerberRegistryTransactionSnapshot
        $script:definition.Commands = @(Get-GerberPluginTransactionCommand 'repository shared child')

        { Register-GerberPlugin -PluginModule $script:moduleB } | Should -Throw '*parent*owner*'

        Get-GerberRegistryTransactionSnapshot | Should -Be $before
        Get-GerberRegisteredCommand -Name 'repository shared child' | Should -BeNullOrEmpty
        (Get-GerberRegisteredCommand -Name 'repository shared').Subcommands.Contains('child') | Should -BeFalse
    }

    It 'rejects a case-insensitive module-name collision before preparation or import' {
        Register-GerberPlugin -PluginModule $script:moduleA
        $before = Get-GerberRegistryTransactionSnapshot
        $script:moduleB.Name = 'gerber.a'
        Mock Import-Module { throw 'must not import' }
        Mock New-GerberPluginApiContext { throw 'must not initialize' }

        { Register-GerberPlugin -PluginModule $script:moduleB } | Should -Throw '*module name*'

        Should -Invoke Import-Module -Times 0 -Exactly
        Should -Invoke New-GerberPluginApiContext -Times 0 -Exactly
        Should -Invoke Get-GerberPluginDefinition -Times 1 -Exactly
        Get-GerberRegistryTransactionSnapshot | Should -Be $before
    }

    It 'preserves the complete registry on <Fault> failure' -ForEach @(
        @{ Fault = 'validation' }, @{ Fault = 'preparation' }, @{ Fault = 'publication' }, @{ Fault = 'post-publication' }
    ) {
        $before = Get-GerberRegistryTransactionSnapshot
        $script:definition.Commands = @(
            (Get-GerberPluginTransactionCommand 'repository probe'),
            (Get-GerberPluginTransactionCommand 'probe-root')
        )
        switch ($Fault) {
            'validation' {
                $script:definition.Commands += Get-GerberPluginTransactionCommand 'tools'
            }
            'preparation' {
                Mock Add-GerberOwnedSubcommandDefinition {
                    & $script:addSubcommand -RegisteredCommandList $RegisteredCommandList -OwnedCommandDefinition $OwnedCommandDefinition
                    throw 'preparation fault'
                }
            }
            'publication' { Mock Publish-GerberCommandRegistryState { throw 'publication fault' } }
            'post-publication' {
                Mock Publish-GerberCommandRegistryState {
                    & $script:publishRegistry -RegistryBuilder $RegistryBuilder
                    throw 'post-publication fault'
                }
            }
        }

        { Register-GerberPlugin -PluginModule $script:moduleA } | Should -Throw

        Get-GerberRegistryTransactionSnapshot | Should -Be $before
        Get-GerberRegisteredCommand -Name 'repository probe' | Should -BeNullOrEmpty
        (Resolve-GerberCommand '/repository probe').IsValid | Should -BeFalse
        Get-GerberActionList | Should -Not -Contain 'probe-root'
    }

    Context 'Shared command table topology' {
        It 'preserves shared nested tables and inline metadata across later same-plugin registration' {
            $inline = [ordered]@{ info = @{ Description = 'inline help'; Subcommands = [ordered]@{}; Marker = 'retained' } }
            $script:definition.Commands = @(
                (Get-GerberPluginTransactionCommand 'repository shared' -Subcommands $inline),
                (Get-GerberPluginTransactionCommand 'repository shared child')
            )
            Register-GerberPlugin -PluginModule $script:moduleA
            $script:definition.Commands = @(Get-GerberPluginTransactionCommand 'unrelated')
            Register-GerberPlugin -PluginModule $script:moduleB
            $parent = Get-GerberRegisteredCommand -Name 'repository shared'
            $child = Get-GerberRegisteredCommand -Name 'repository shared child'
            $core = Get-GerberRegisteredCommand -Name 'repository'

            [object]::ReferenceEquals($core.Subcommands.shared.Subcommands, $parent.Subcommands) | Should -BeTrue
            [object]::ReferenceEquals($parent.Subcommands.child.Subcommands, $child.Subcommands) | Should -BeTrue
            $parent.Subcommands.info.Marker | Should -Be 'retained'
            $builder = [pscustomobject]@{
                CommandList = [System.Collections.Generic.List[object]]::new([object[]]@(Get-GerberCommandRegistry))
                PluginList = [System.Collections.Generic.List[object]]::new([object[]]@($script:GerberCommandRegistryState.PluginList))
                GerberVersion = $script:GerberCommandRegistryState.GerberVersion
            }
            Add-GerberOwnedCommandDefinitionList -RegisteredCommandList $builder.CommandList `
                -CommandDefinitionList @(Get-GerberPluginTransactionCommand 'repository shared child grandchild') `
                -OwnerName $script:moduleA.Name -OwnerType Plugin
            Publish-GerberCommandRegistryState -RegistryBuilder $builder
            (Resolve-GerberCommand '/repository shared child grandchild').IsValid | Should -BeTrue
            (Resolve-GerberCommand '/repository shared child').IsValid | Should -BeTrue
            Invoke-GerberRegisteredCommand -CommandDefinition $child -Command ([pscustomobject]@{ Name = $child.Name }) | Should -BeTrue
            $before = Get-GerberRegistryTransactionSnapshot
            Mock Publish-GerberCommandRegistryState { throw 'publication fault' }
            $script:definition.Commands = @(Get-GerberPluginTransactionCommand 'repository probe')
            { Register-GerberPlugin -PluginModule $script:moduleB } | Should -Throw
            Get-GerberRegistryTransactionSnapshot | Should -Be $before
        }
    }
}
