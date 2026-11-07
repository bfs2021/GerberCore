BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) 'TestHelpers/GerberTestSupport.ps1')
}

Describe 'Invoke-Gerber integration' -Tag 'ActiveCommandTree' {
    It 'keeps both runtime requirements and registers /update without running startup on import' -Tag 'G4A7' {
        $root = Get-GerberProjectRoot -StartPath $PSScriptRoot
        $manifestPath = Join-Path $root 'dist/Gerber/Gerber.psd1'
        $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
        $manifest.RequiredModules.ModuleName | Should -Contain 'NovaModuleTools'
        $manifest.RequiredModules.ModuleName | Should -Contain 'PSModuleUpdate'
        $module = Import-Module $manifestPath -Force -PassThru
        & $module {
            Get-Variable GerberStartupUpdateState -Scope Script -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            $definition = Get-GerberCoreCommandDefinitionList | Where-Object Name -EQ 'update'
            $definition.Handler | Should -BeOfType ([scriptblock])
            (Get-Command Get-PSModuleUpdate).ModuleName | Should -Be 'PSModuleUpdate'
            (Get-Command Install-PSModuleUpdate).ModuleName | Should -Be 'PSModuleUpdate'
        }
    }

    It 'exposes the built public command and alias' {
        $command = Get-Command -Name 'Invoke-Gerber' -ErrorAction Stop
        $alias = Get-Command -Name 'gerber' -ErrorAction Stop

        $command.CommandType | Should -Be 'Function'
        $alias.CommandType | Should -Be 'Alias'
        $alias.Definition | Should -Be 'Invoke-Gerber'
    }

    It 'resolves root search input with an approved synthetic plugin loaded through normal discovery' {
        $gerberProjectRoot = Get-GerberProjectRoot -StartPath $PSScriptRoot
        $fixtureModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')
        $originalModulePath = $env:PSModulePath
        $originalConfigPath = $env:GERBER_CONFIG_PATH

        try {
            Remove-Module Gerber, Gerber.TestPlugin -Force -ErrorAction SilentlyContinue
            $env:PSModulePath = @(
                $fixtureModuleRoot
                (Join-Path $gerberProjectRoot 'dist')
                ($originalModulePath -split [System.IO.Path]::PathSeparator)
            ) -join [System.IO.Path]::PathSeparator
            $env:GERBER_CONFIG_PATH = Join-Path $TestDrive 'GerberCore.json'
            @{
                schemaVersion = 1
                plugins = @{
                    approved = @('6996218c-58d0-48ce-b6cc-38d06149230a')
                }
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $env:GERBER_CONFIG_PATH

            Import-Module (Join-Path $gerberProjectRoot 'dist/Gerber/Gerber.psd1') -Force | Out-Null

            $result = & (Get-Module Gerber) {
                param($PluginModulePath)

                Clear-GerberCommandRegistry
                $null = Initialize-GerberCommandRegistry -PluginModulePathList @($PluginModulePath)
                [pscustomobject]@{
                    ExitCommand = Resolve-GerberRootSearchCommand -InputText 'exit' -ActionList (Get-GerberActionList)
                    PluginLeafCommand = Resolve-GerberRootSearchCommand -InputText 'example' -ActionList (Get-GerberActionList)
                }
            } $fixtureModuleRoot
            $result.ExitCommand.IsValid | Should -BeTrue
            $result.ExitCommand.Name | Should -Be 'exit'
            $result.PluginLeafCommand.IsValid | Should -BeTrue
            $result.PluginLeafCommand.Name | Should -Be 'example'
            $result.PluginLeafCommand.Suggestions.DisplayText | Should -Contain '/example'
        } finally {
            $env:PSModulePath = $originalModulePath
            $env:GERBER_CONFIG_PATH = $originalConfigPath
            Remove-Module Gerber, Gerber.TestPlugin -Force -ErrorAction SilentlyContinue
            Remove-GerberPluginFixtureModuleRoot -Path $fixtureModuleRoot
        }
    }

    It 'does not expose commands from an associated disabled plugin' {
        $gerberProjectRoot = Get-GerberProjectRoot -StartPath $PSScriptRoot
        $fixtureModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')
        $originalModulePath = $env:PSModulePath
        $originalConfigPath = $env:GERBER_CONFIG_PATH

        try {
            Remove-Module Gerber, Gerber.TestPlugin -Force -ErrorAction SilentlyContinue
            $env:PSModulePath = @(
                $fixtureModuleRoot
                (Join-Path $gerberProjectRoot 'dist')
                ($originalModulePath -split [System.IO.Path]::PathSeparator)
            ) -join [System.IO.Path]::PathSeparator
            $env:GERBER_CONFIG_PATH = Join-Path $TestDrive 'GerberCore.json'
            @{
                schemaVersion = 1
                plugins = @{
                    approved = @('6996218c-58d0-48ce-b6cc-38d06149230a')
                    associated = @{
                        '6996218c-58d0-48ce-b6cc-38d06149230a' = @{
                            enabled = $false
                        }
                    }
                }
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $env:GERBER_CONFIG_PATH

            Import-Module (Join-Path $gerberProjectRoot 'dist/Gerber/Gerber.psd1') -Force | Out-Null

            $result = & (Get-Module Gerber) {
                param($PluginModulePath)

                Clear-GerberCommandRegistry
                $null = Initialize-GerberCommandRegistry -PluginModulePathList @($PluginModulePath)
                [pscustomobject]@{
                    ActionList = Get-GerberActionList
                    PluginLeafCommand = Resolve-GerberRootSearchCommand -InputText 'example' -ActionList (Get-GerberActionList)
                }
            } $fixtureModuleRoot

            @($result.ActionList) | Should -Not -Contain 'branch'
            @($result.ActionList) | Should -Not -Contain 'list'
            @($result.ActionList) | Should -Not -Contain 'pipelines'
            @($result.ActionList) | Should -Not -Contain 'repository'
            @($result.ActionList) | Should -Contain 'tools'
            $result.PluginLeafCommand.IsValid | Should -BeFalse
        } finally {
            $env:PSModulePath = $originalModulePath
            $env:GERBER_CONFIG_PATH = $originalConfigPath
            Remove-Module Gerber, Gerber.TestPlugin -Force -ErrorAction SilentlyContinue
            Remove-GerberPluginFixtureModuleRoot -Path $fixtureModuleRoot
        }
    }

    It 'does not expose commands from a declined plugin without prompting again' {
        $gerberProjectRoot = Get-GerberProjectRoot -StartPath $PSScriptRoot
        $fixtureModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')
        $originalModulePath = $env:PSModulePath
        $originalConfigPath = $env:GERBER_CONFIG_PATH

        try {
            Remove-Module Gerber, Gerber.TestPlugin -Force -ErrorAction SilentlyContinue
            $env:PSModulePath = @(
                $fixtureModuleRoot
                (Join-Path $gerberProjectRoot 'dist')
                ($originalModulePath -split [System.IO.Path]::PathSeparator)
            ) -join [System.IO.Path]::PathSeparator
            $env:GERBER_CONFIG_PATH = Join-Path $TestDrive 'GerberCore.json'
            @{
                schemaVersion = 1
                plugins = @{
                    declined = @('6996218c-58d0-48ce-b6cc-38d06149230a')
                }
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $env:GERBER_CONFIG_PATH

            Import-Module (Join-Path $gerberProjectRoot 'dist/Gerber/Gerber.psd1') -Force | Out-Null

            $result = & (Get-Module Gerber) {
                param($PluginModulePath)

                Clear-GerberCommandRegistry
                $null = Initialize-GerberCommandRegistry -PluginModulePathList @($PluginModulePath)
                [pscustomobject]@{
                    ActionList = Get-GerberActionList
                    PluginLeafCommand = Resolve-GerberRootSearchCommand -InputText 'example' -ActionList (Get-GerberActionList)
                }
            } $fixtureModuleRoot

            @($result.ActionList) | Should -Not -Contain 'branch'
            @($result.ActionList) | Should -Not -Contain 'list'
            @($result.ActionList) | Should -Not -Contain 'pipelines'
            @($result.ActionList) | Should -Not -Contain 'repository'
            @($result.ActionList) | Should -Contain 'tools'
            $result.PluginLeafCommand.IsValid | Should -BeFalse
        } finally {
            $env:PSModulePath = $originalModulePath
            $env:GERBER_CONFIG_PATH = $originalConfigPath
            Remove-Module Gerber, Gerber.TestPlugin -Force -ErrorAction SilentlyContinue
            Remove-GerberPluginFixtureModuleRoot -Path $fixtureModuleRoot
        }
    }
}
