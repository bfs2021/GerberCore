# Real registry, persistence and fixture modules jointly prove disable compensation.
BeforeAll {
    $supportPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers'
    . (Join-Path $supportPath 'GerberTestSupport.ps1')
    . (Join-Path $supportPath 'Initialize-GerberPluginActivationFixture.ps1')
    . (Join-Path $supportPath 'Clear-GerberPluginActivationFixture.ps1')
    . (Join-Path $supportPath 'Get-GerberRegistryTransactionSnapshot.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
    $script:unregisterPlugin = ${function:Unregister-GerberPlugin}
    $script:saveConfiguration = ${function:Save-GerberUserConfiguration}
}

Describe 'Disable-GerberPlugin' -Tag 'PluginTransactions' {
    BeforeEach {
        $script:activationFixture = Initialize-GerberPluginActivationFixture -StartPath $PSScriptRoot -TestDrivePath $TestDrive
        Mock Get-GerberDefaultPluginModulePathList { [string[]]@($script:activationFixture.ModuleRoot) }
        $null = Enable-GerberPlugin -Guid $script:testPluginGuid
        $null = Enable-GerberPlugin -Guid $script:secondPluginGuid
    }

    AfterEach {
        Clear-GerberPluginActivationFixture -Fixture $script:activationFixture
    }

    Context 'Persistence and runtime compensation' {
        It 'removes the plugin commands, preserves approval and persists the disabled state' {
            Disable-GerberPlugin -Guid $script:testPluginGuid

            Get-GerberRegisteredCommand -Name 'example' | Should -BeNullOrEmpty
            Get-GerberRegisteredCommand -Name 'example-two' | Should -Not -BeNullOrEmpty
            Get-GerberActionList | Should -Not -Contain 'example'
            Resolve-GerberCommand -InputText '/example' | ForEach-Object IsValid | Should -BeFalse
            $configuration = Get-GerberUserConfiguration
            @($configuration.plugins.approved) | Should -Contain $script:testPluginGuid
            @($configuration.plugins.declined) | Should -Not -Contain $script:testPluginGuid
            $configuration.plugins.associated.$($script:testPluginGuid).enabled | Should -BeFalse
        }

        It 'survives a registry reinitialization without loading the disabled plugin' {
            Disable-GerberPlugin -Guid $script:testPluginGuid
            Clear-GerberCommandRegistry

            $registry = @(Initialize-GerberCommandRegistry -PluginModulePathList @($script:activationFixture.ModuleRoot))

            $registry.Name | Should -Not -Contain 'example'
            $registry.Name | Should -Contain 'example-two'
        }

        It 'is a no-op for state when the plugin is already disabled' {
            Disable-GerberPlugin -Guid $script:testPluginGuid
            Disable-GerberPlugin -Guid $script:testPluginGuid

            (Get-GerberPluginLifecycleState -Guid $script:testPluginGuid).IsEnabled | Should -BeFalse
        }

        It 'keeps the plugin registered when the disabled state cannot be persisted' {
            $before = Get-GerberRegistryTransactionSnapshot
            $configuration = Get-Content -LiteralPath $env:GERBER_CONFIG_PATH -Raw
            Mock Save-GerberUserConfiguration { throw 'disk full' }

            { Disable-GerberPlugin -Guid $script:testPluginGuid } | Should -Throw '*disk full*'

            Get-GerberRegisteredCommand -Name 'example' | Should -Not -BeNullOrEmpty
            Get-GerberRegistryTransactionSnapshot | Should -Be $before
            Get-Content -LiteralPath $env:GERBER_CONFIG_PATH -Raw | Should -Be $configuration
            (Get-GerberPluginLifecycleState -Guid $script:secondPluginGuid).IsEnabled | Should -BeTrue
        }

        It 'restores runtime and configuration after <Failure> unregistration failure' -ForEach @(
            @{ Failure = 'immediate' }, @{ Failure = 'partial' }
        ) {
            $before = Get-GerberRegistryTransactionSnapshot
            $configuration = Get-Content -LiteralPath $env:GERBER_CONFIG_PATH -Raw
            if ($Failure -eq 'partial') {
                Mock Unregister-GerberPlugin {
                    & $script:unregisterPlugin -Guid $Guid
                    (Get-GerberRegisteredCommand -Name 'tools').Subcommands.Clear()
                    throw 'partial unregistration fault'
                }
            } else {
                Mock Unregister-GerberPlugin { throw 'immediate unregistration fault' }
            }

            { Disable-GerberPlugin -Guid $script:testPluginGuid } | Should -Throw '*unregistration fault*'

            Get-GerberRegistryTransactionSnapshot | Should -Be $before
            Get-Content -LiteralPath $env:GERBER_CONFIG_PATH -Raw | Should -Be $configuration
            (Get-GerberPluginLifecycleState -Guid $script:testPluginGuid).IsEnabled | Should -BeTrue
            (Get-GerberPluginLifecycleState -Guid $script:secondPluginGuid).IsEnabled | Should -BeTrue
        }

        It 'surfaces original and rollback failures explicitly' {
            Mock Unregister-GerberPlugin { throw 'original unregister fault' }
            Mock Save-GerberUserConfiguration {
                if ($Configuration.plugins.associated.$($script:testPluginGuid).enabled) {
                    throw 'rollback persistence fault'
                }
                & $script:saveConfiguration -Configuration $Configuration
            }

            { Disable-GerberPlugin -Guid $script:testPluginGuid } |
                Should -Throw '*original unregister fault*rollback*persistence fault*'
        }

        It 'restores configuration when persistence publishes and then throws' {
            $before = Get-GerberRegistryTransactionSnapshot
            $configuration = Get-Content -LiteralPath $env:GERBER_CONFIG_PATH -Raw
            Mock Set-GerberPluginAssociationState {
                $config = Get-GerberUserConfiguration
                $config.plugins.associated.$Guid.enabled = $false
                & $script:saveConfiguration -Configuration $config
                throw 'post-persistence fault'
            }

            { Disable-GerberPlugin -Guid $script:testPluginGuid } | Should -Throw '*post-persistence fault*'

            Get-GerberRegistryTransactionSnapshot | Should -Be $before
            Get-Content -LiteralPath $env:GERBER_CONFIG_PATH -Raw | Should -Be $configuration
        }
    }
}
