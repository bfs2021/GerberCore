BeforeAll {
    $supportPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers'
    . (Join-Path $supportPath 'GerberTestSupport.ps1')
    . (Join-Path $supportPath 'Get-GerberPluginTransactionCommand.ps1')
    . (Join-Path $supportPath 'Get-GerberRegistryTransactionModuleList.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Add-GerberPluginToRegistryBuilder' -Tag 'PluginTransactions' {
    BeforeEach {
        Clear-GerberCommandRegistry
        $null = Initialize-GerberCommandRegistry -PluginModulePathList @()
        $script:moduleA, $null = Get-GerberRegistryTransactionModuleList -StartPath $PSScriptRoot
        Mock Get-GerberPluginDefinition {
            [pscustomobject]@{ Commands = @(Get-GerberPluginTransactionCommand 'repository staging') }
        }
    }

    AfterEach {
        Clear-GerberCommandRegistry
    }

    AfterAll {
        $null = Initialize-GerberCommandRegistry -PluginModulePathList @()
    }

    Context 'Staged plugin preparation' {
        It 'adds commands and startup lifecycle metadata to the builder without publishing' {
            $state = Copy-GerberCommandRegistryState -State $script:GerberCommandRegistryState
            $builder = [pscustomobject]@{
                CommandList = [System.Collections.Generic.List[object]]::new([object[]]@($state.CommandList))
                PluginList = [System.Collections.Generic.List[object]]::new()
                GerberVersion = Get-GerberCurrentVersion
            }

            Add-GerberPluginToRegistryBuilder -RegistryBuilder $builder -PluginModule $script:moduleA `
                -LifecycleState ([pscustomobject]@{ IsAssociated = $false; IsEnabled = $true })

            $builder.CommandList.Name | Should -Contain 'repository staging'
            $builder.PluginList.Count | Should -Be 1
            $builder.PluginList[0].Name | Should -Be $script:moduleA.Name
            $builder.PluginList[0].Guid | Should -Be $script:moduleA.Guid
            $builder.PluginList[0].Version | Should -Be $script:moduleA.Version.ToString()
            $builder.PluginList[0].PluginApiVersion | Should -Be '1'
            $builder.PluginList[0].PluginApiContext.PluginId | Should -Be $script:moduleA.Guid
            $builder.PluginList[0].MinimumGerberVersion | Should -Be $script:moduleA.PrivateData.Gerber.MinimumGerberVersion
            $builder.PluginList[0].ModulePath | Should -Be $script:moduleA.Path
            $builder.PluginList[0].IsAssociated | Should -BeFalse
            $builder.PluginList[0].IsEnabled | Should -BeTrue
            Get-GerberRegisteredCommand -Name 'repository staging' | Should -BeNullOrEmpty
            Get-GerberRegisteredCommand -Name 'repository' | Should -BeNullOrEmpty
            @($script:GerberCommandRegistryState.PluginList).Count | Should -Be 0
        }
    }
}
