BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
    $script:assertManifestValidationFailure = {
        param(
            [Parameter(Mandatory)]
            [pscustomobject]$ModuleInfo,

            [Parameter(Mandatory)]
            [string]$ExpectedMessage
        )

        $actualMessage = $null
        try {
            Assert-GerberPluginModuleManifest -ModuleInfo $ModuleInfo
        } catch {
            $actualMessage = $_.Exception.Message
        }

        $actualMessage | Should -Be $ExpectedMessage
    }.GetNewClosure()
    $script:assertCommandDefinitionFailure = {
        param(
            [Parameter(Mandatory)]
            [pscustomobject]$CommandDefinition,

            [Parameter(Mandatory)]
            [string]$ExpectedMessage
        )

        $actualMessage = $null
        try {
            Assert-GerberCommandDefinition -CommandDefinition $CommandDefinition -OwnerName 'Gerber.Test'
        } catch {
            $actualMessage = $_.Exception.Message
        }

        $actualMessage | Should -Be $ExpectedMessage
    }.GetNewClosure()
}

Describe 'Initialize-GerberCommandRegistry' -Tag 'PluginTransactions', 'G4A7' {
    BeforeEach {
        Mock Resolve-GerberPluginApproval { $true }
        Mock Get-GerberPluginLifecycleState {
            [pscustomobject]@{
                Guid = $Guid
                IsAssociated = $false
                IsEnabled = $true
                ShouldLoad = $true
            }
        }
    }

    AfterEach {
        Reset-GerberPluginTestEnvironment
        if (-not [string]::IsNullOrWhiteSpace($script:isolatedModuleRoot)) {
            Remove-GerberPluginFixtureModuleRoot -Path $script:isolatedModuleRoot
            $script:isolatedModuleRoot = $null
        }
        Initialize-GerberCommandRegistry -PluginModulePathList @() | Out-Null
    }

    It 'builds the effective registry from core plus discovered plugin commands' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')

        $registry = @(Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot))

        $registry.Name | Should -Be @('tools', 'plugins', 'secrets', 'update', 'help', 'exit', 'example')
        ($registry | Where-Object Name -EQ 'example').OwnerName | Should -Be 'Gerber.TestPlugin'
        Get-GerberActionList | Should -Be @('exit', 'help', 'plugins', 'update', 'example', 'secrets', 'tools')
    }

    It 'adds discovered plugin commands to the command catalog and resolver without plugin-specific branches' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')
        Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot) | Out-Null

        $catalog = Get-GerberCommandCatalog -ActionList (Get-GerberActionList)
        $resolution = Resolve-GerberCommand -InputText '/example'

        $catalog.Keys | Should -Contain 'example'
        $catalog['example'].Description | Should -Be 'Run the Gerber test plugin command'
        $resolution.IsValid | Should -BeTrue
        $resolution.Name | Should -Be 'example'
    }

    It 'shows discovered plugin root commands in help output' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')
        Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot) | Out-Null
        $script:helpText = $null
        Mock Show-GerberTextBlock { $script:helpText = $Text }
        Mock Wait-GerberContinue {}

        Show-GerberHelpView

        $script:helpText | Should -Match '/example Run the Gerber test plugin command'
    }

    It 'dispatches the real plugin handler across the module boundary and reaches the plugin private function' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')
        Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot) | Out-Null
        Gerber.TestPlugin\Reset-GerberTestPluginInvocationCount

        $result = Invoke-GerberMenuCommand -Command ([pscustomobject]@{ Name = 'example'; Arguments = @() })

        $result | Should -BeFalse
        Gerber.TestPlugin\Get-GerberTestPluginInvocationCount | Should -Be 1
        (Gerber.TestPlugin\Get-GerberTestPluginRegistrationContext).ApiVersion | Should -Be '1'
        (Gerber.TestPlugin\Get-GerberTestPluginHandlerContext).ApiVersion | Should -Be '1'
        [object]::ReferenceEquals(
            (Gerber.TestPlugin\Get-GerberTestPluginRegistrationContext),
            (Gerber.TestPlugin\Get-GerberTestPluginHandlerContext)
        ) | Should -BeTrue
    }

    It 'discovers and registers plugins only during explicit initialization' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')
        $script:discoverCallCount = 0
        Mock Get-GerberDiscoveredPluginModuleList {
            $script:discoverCallCount++
            @()
        }

        Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot) | Out-Null
        Get-GerberActionList | Out-Null
        Get-GerberCommandCatalog -ActionList (Get-GerberActionList) | Out-Null
        Get-GerberRegisteredCommand -Name 'tools' | Out-Null

        $script:discoverCallCount | Should -Be 1
    }

    It 'ignores normal PowerShell modules that are not marked as Gerber plugins' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin', 'NonGerber.TestModule')

        $registry = @(Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot))

        $registry.Name | Should -Not -Contain 'plain-module'
        $registry.OwnerName | Should -Not -Contain 'NonGerber.TestModule'
    }

    It 'skips an unknown plugin before importing or executing it' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')
        Mock Resolve-GerberPluginApproval { $false }
        Mock Import-Module { throw 'Unknown plugin code must not be imported.' }

        $registry = @(Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot))

        $registry.Name | Should -Not -Contain 'example'
        Should -Invoke Import-Module -Times 0
    }

    It 'loads an approved plugin through the existing validation process' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')

        $registry = @(Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot))

        $registry.Name | Should -Contain 'example'
        Should -Invoke Resolve-GerberPluginApproval -Times 1 -ParameterFilter {
            $PluginModule.Guid -eq '6996218c-58d0-48ce-b6cc-38d06149230a'
        }
    }

    It 'does not load an associated disabled plugin' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')
        Mock Get-GerberPluginLifecycleState {
            [pscustomobject]@{
                Guid = $Guid
                IsAssociated = $true
                IsEnabled = $false
                ShouldLoad = $false
            }
        }
        Mock Import-Module { throw 'Disabled plugin code must not be imported.' }

        $registry = @(Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot))

        $registry.Name | Should -Not -Contain 'example'
        Should -Invoke Import-Module -Times 0
    }

    It 'keeps Core commands usable when no plugins are discovered' {
        Reset-GerberPluginTestEnvironment

        $registry = @(Initialize-GerberCommandRegistry -PluginModulePathList @())

        $registry.Name | Should -Contain 'tools'
        $registry.Name | Should -Contain 'help'
        $registry.OwnerType | Should -Not -Contain 'Plugin'
    }

    It 'does not delete stored plugin lifecycle state when no plugin module is available' {
        $configPath = Join-Path $TestDrive 'user/config.json'
        $originalConfigPath = $env:GERBER_CONFIG_PATH

        try {
            $env:GERBER_CONFIG_PATH = $configPath
            Save-GerberUserConfiguration -Configuration @{
                schemaVersion = 1
                plugins = @{
                    approved = @('6996218c-58d0-48ce-b6cc-38d06149230a')
                    associated = @{
                        '6996218c-58d0-48ce-b6cc-38d06149230a' = @{
                            enabled = $false
                        }
                    }
                }
            }

            $null = Initialize-GerberCommandRegistry -PluginModulePathList @()

            $reloadedConfiguration = Get-GerberUserConfiguration
            @($reloadedConfiguration.plugins.approved) | Should -Be @('6996218c-58d0-48ce-b6cc-38d06149230a')
            $reloadedConfiguration.plugins.associated.'6996218c-58d0-48ce-b6cc-38d06149230a'.enabled | Should -BeFalse
        } finally {
            $env:GERBER_CONFIG_PATH = $originalConfigPath
        }
    }

    It 'returns the cached session registry on repeated initialization' {
        Reset-GerberPluginTestEnvironment
        $script:discoverCallCount = 0
        $originalModulePath = $env:PSModulePath
        Mock Get-GerberDiscoveredPluginModuleList {
            $script:discoverCallCount++
            @()
        }

        try {
            $env:PSModulePath = '/tmp/one:/tmp/two'

            $firstRegistry = @(Initialize-GerberCommandRegistry)
            $secondRegistry = @(Initialize-GerberCommandRegistry)

            $script:discoverCallCount | Should -Be 1
            $secondRegistry.Name | Should -Be $firstRegistry.Name
        } finally {
            $env:PSModulePath = $originalModulePath
        }
    }

    It 'reuses the same plugin API context across repeated initialization in one lifecycle and recreates it after clear' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')

        Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot) | Out-Null
        $firstContext = Gerber.TestPlugin\Get-GerberTestPluginRegistrationContext

        Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot) | Out-Null
        $secondContext = Gerber.TestPlugin\Get-GerberTestPluginRegistrationContext

        [object]::ReferenceEquals($firstContext, $secondContext) | Should -BeTrue

        Clear-GerberCommandRegistry
        Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot) | Out-Null
        $thirdContext = Gerber.TestPlugin\Get-GerberTestPluginRegistrationContext

        [object]::ReferenceEquals($firstContext, $thirdContext) | Should -BeFalse
    }

    It 'creates an isolated plugin API context per plugin in the same lifecycle' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin', 'Gerber.SecondTestPlugin')

        $registry = @(Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot))

        $registry.Name | Should -Contain 'example'
        $registry.Name | Should -Contain 'example-two'
        [object]::ReferenceEquals(
            (Gerber.TestPlugin\Get-GerberTestPluginRegistrationContext),
            (Gerber.SecondTestPlugin\Get-GerberSecondTestPluginRegistrationContext)
        ) | Should -BeFalse
    }

    It 'passes the plugin API context through the explicit Gerber parameter' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.NamedParameterPlugin')

        $registry = @(Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot))

        $registry.Name | Should -Be @('tools', 'plugins', 'secrets', 'update', 'help', 'exit')
        (Get-GerberRegisteredPluginApiContext -OwnerName 'Gerber.NamedParameterPlugin').ApiVersion | Should -Be '1'
    }

    It 'returns plugin module paths from PSModulePath and handles an empty value' {
        $originalModulePath = $env:PSModulePath
        try {
            $env:PSModulePath = ''
            (Get-GerberDefaultPluginModulePathList) | Should -Be @()

            $env:PSModulePath = '/tmp/one:/tmp/two'
            (Get-GerberDefaultPluginModulePathList) | Should -Be @('/tmp/one', '/tmp/two')
        } finally {
            $env:PSModulePath = $originalModulePath
        }
    }

    It 'resolves the loaded command version when available and otherwise returns null' {
        Mock Get-Command { $null }
        Get-GerberLoadedCommandVersion | Should -BeNullOrEmpty

        Mock Get-Command { [pscustomobject]@{ Module = $null } }
        Get-GerberLoadedCommandVersion | Should -BeNullOrEmpty

        Mock Get-Command { [pscustomobject]@{ Module = [pscustomobject]@{ Version = $null } } }
        Get-GerberLoadedCommandVersion | Should -BeNullOrEmpty

        Mock Get-Command { [pscustomobject]@{ Module = [pscustomobject]@{ Version = [version]'2.3.4' } } }
        (Get-GerberLoadedCommandVersion).ToString() | Should -Be '2.3.4'
    }

    It 'throws when project.json cannot be resolved from the current directory' {
        $originalLocation = Get-Location
        $temporaryPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path $temporaryPath -Force
        try {
            Set-Location -LiteralPath $temporaryPath

            {
                Get-GerberProjectVersionFromRepositoryRoot
            } | Should -Throw 'Gerber could not resolve the current version because project.json was not available from the current working directory.'
        } finally {
            Set-Location -LiteralPath $originalLocation
            Remove-Item -LiteralPath $temporaryPath -Recurse -Force
        }
    }

    It 'fails manifest validation when plugin API version metadata is missing' {
        & $script:assertManifestValidationFailure `
            -ModuleInfo ([pscustomobject]@{
                Name       = 'MissingApi'
                PrivateData = @{
                    Gerber = @{
                        ApiVersion           = ''
                        MinimumGerberVersion = '1.0.0'
                    }
                }
            }) `
            -ExpectedMessage "Gerber plugin 'MissingApi' is missing required manifest metadata 'PrivateData.Gerber.ApiVersion'."
    }

    It 'fails manifest validation when plugin minimum Gerber version metadata is missing' {
        & $script:assertManifestValidationFailure `
            -ModuleInfo ([pscustomobject]@{
                Name       = 'MissingMinimum'
                PrivateData = @{
                    Gerber = @{
                        ApiVersion           = '1'
                        MinimumGerberVersion = ''
                    }
                }
            }) `
            -ExpectedMessage "Gerber plugin 'MissingMinimum' is missing required manifest metadata 'PrivateData.Gerber.MinimumGerberVersion'."
    }

    It 'fails when a plugin entry point returns an empty definition' {
        $pluginModule = [pscustomobject]@{
            Name       = 'Gerber.EmptyDefinitionPlugin'
            Path       = 'ignored'
            PrivateData = @{
                Gerber = @{
                    MinimumGerberVersion = '0.1.0'
                }
            }
        }
        $importedModule = [pscustomobject]@{ Name = 'Gerber.EmptyDefinitionPlugin' }
        $entryPoint = { $null }.GetNewClosure()

        Mock Import-Module { $importedModule }
        Mock Get-Command { $entryPoint }

        {
            Get-GerberPluginDefinition `
                -PluginModule $pluginModule `
                -CurrentGerberVersion ([System.Management.Automation.SemanticVersion]::Parse('0.1.0')) `
                -PluginContext ([pscustomobject]@{ ApiVersion = '1' })
        } | Should -Throw "Gerber plugin 'Gerber.EmptyDefinitionPlugin' returned an empty plugin definition."
    }

    It 'fails when a plugin definition omits the Commands property' {
        {
            Get-GerberPluginCommandDefinitionList `
                -PluginModule ([pscustomobject]@{ Name = 'Gerber.MissingCommandsPlugin' }) `
                -PluginDefinition ([pscustomobject]@{ Name = 'Gerber.MissingCommandsPlugin' })
        } | Should -Throw "Gerber plugin 'Gerber.MissingCommandsPlugin' returned an invalid definition because the 'Commands' property was missing."
    }

    It 'fails command validation for missing name' {
        & $script:assertCommandDefinitionFailure `
            -CommandDefinition ([pscustomobject]@{ Name = ''; Description = 'desc'; Handler = {}; Subcommands = @{} }) `
            -ExpectedMessage "Gerber plugin 'Gerber.Test' returned an invalid command definition because 'Name' was missing."
    }

    It 'fails command validation for missing description' {
        & $script:assertCommandDefinitionFailure `
            -CommandDefinition ([pscustomobject]@{ Name = 'broken'; Description = ''; Handler = {}; Subcommands = @{} }) `
            -ExpectedMessage "Gerber plugin 'Gerber.Test' returned an invalid command definition for root command 'broken' because 'Description' was missing."
    }

    It 'fails command validation for invalid subcommands' {
        & $script:assertCommandDefinitionFailure `
            -CommandDefinition ([pscustomobject]@{ Name = 'broken'; Description = 'desc'; Handler = {}; Subcommands = @('bad') }) `
            -ExpectedMessage "Gerber plugin 'Gerber.Test' returned an invalid command definition for root command 'broken' because 'Subcommands' was not a dictionary."
    }

    It 'fails when a plugin registers duplicate root commands in the same contribution' {
        $duplicateCommands = @(
            [pscustomobject]@{ Name = 'duplicate'; Description = 'First'; Handler = {}; Subcommands = @{} }
            [pscustomobject]@{ Name = 'duplicate'; Description = 'Second'; Handler = {}; Subcommands = @{} }
        )
        $registeredCommandList = New-Object 'System.Collections.Generic.List[object]'

        {
            Add-GerberOwnedCommandDefinitionList `
                -RegisteredCommandList $registeredCommandList `
                -CommandDefinitionList $duplicateCommands `
                -OwnerName 'Gerber.TestPlugin' `
                -OwnerType 'Plugin'
        } | Should -Throw "Gerber cannot register duplicate root command 'duplicate' from owner 'Gerber.TestPlugin'."
    }

    It 'returns an empty ordered dictionary when a command definition omits subcommands' {
        $result = Get-GerberCommandDefinitionSubcommandTable

        $result | Should -BeOfType ([System.Collections.Specialized.OrderedDictionary])
        $result.Count | Should -Be 0
    }

    It 'orders root commands before nested commands even when the root name has a single token' {
        $result = @(Get-GerberOrderedOwnedCommandDefinitionList -OwnedCommandDefinitionList @(
                [pscustomobject]@{
                    Name              = 'tools plugin-tool'
                    RegistrationOrder = 1
                }
                [pscustomobject]@{
                    Name              = 'tools'
                    RegistrationOrder = 0
                }
            ))

        $result.Name | Should -Be @('tools', 'tools plugin-tool')
    }

    It 'fails when a nested command parent is not registered anywhere' {
        $registeredCommandList = New-Object 'System.Collections.Generic.List[object]'
        $ownedCommand = [pscustomobject]@{
            Name = 'tools plugin-tool'
            OwnerName = 'Gerber.TestPlugin'
            ParentName = 'tools'
            LeafName = 'plugin-tool'
            Subcommands = [ordered]@{}
        }

        {
            Assert-GerberOwnedCommandParentDefinition `
                -RegisteredCommandList $registeredCommandList `
                -OwnedCommandDefinitionList @() `
                -OwnedCommandDefinition $ownedCommand
        } | Should -Throw "Gerber cannot register command 'tools plugin-tool' from owner 'Gerber.TestPlugin' because parent command 'tools' is not registered."
    }

    It 'fails when a nested subcommand conflicts with an existing parent-owned leaf' {
        $registeredCommandList = New-Object 'System.Collections.Generic.List[object]'
        $null = $registeredCommandList.Add([pscustomobject]@{
                Name = 'tools'
                OwnerName = 'Gerber.Core'
                ParentName = $null
                LeafName = 'tools'
                Subcommands = [ordered]@{
                    'plugin-tool' = [pscustomobject]@{ Description = 'Existing'; Subcommands = [ordered]@{} }
                }
            })
        $ownedCommand = [pscustomobject]@{
            Name = 'tools plugin-tool'
            OwnerName = 'Gerber.TestPlugin'
            ParentName = 'tools'
            LeafName = 'plugin-tool'
            Subcommands = [ordered]@{}
        }

        {
            Assert-GerberOwnedSubcommandConflict `
                -RegisteredCommandList $registeredCommandList `
                -OwnedCommandDefinitionList @($ownedCommand) `
                -OwnedCommandDefinition $ownedCommand
        } | Should -Throw "Gerber cannot register subcommand 'plugin-tool' under command 'tools' from owner 'Gerber.TestPlugin' because it is already owned by 'Gerber.Core'."
    }

    It 'finds owned commands by parent and leaf name while honoring exclusions' {
        $ownedCommandList = @(
            [pscustomobject]@{
                Name = 'tools plugin-tool'
                ParentName = 'tools'
                LeafName = 'plugin-tool'
            }
            [pscustomobject]@{
                Name = 'tools base-64'
                ParentName = 'tools'
                LeafName = 'base-64'
            }
        )

        (Find-GerberOwnedCommandDefinitionByParentAndLeafName `
            -OwnedCommandDefinitionList $ownedCommandList `
            -ParentName 'tools' `
            -LeafName 'base-64').Name | Should -Be 'tools base-64'

        (Find-GerberOwnedCommandDefinitionByParentAndLeafName `
            -OwnedCommandDefinitionList $ownedCommandList `
            -ParentName 'tools' `
            -LeafName 'base-64' `
            -ExcludeName 'tools base-64') | Should -BeNullOrEmpty
    }

    It 'creates distinct conflict messages for root and nested commands' {
        $rootMessage = (Get-GerberRegisteredCommandConflictException `
                -OwnedCommandDefinition ([pscustomobject]@{
                    Name = 'tools'
                    OwnerName = 'Gerber.TestPlugin'
                    ParentName = $null
                }) `
                -ExistingCommandDefinition ([pscustomobject]@{
                    OwnerName = 'Gerber.Core'
                })).Message
        $nestedMessage = (Get-GerberRegisteredCommandConflictException `
                -OwnedCommandDefinition ([pscustomobject]@{
                    Name = 'tools plugin-tool'
                    OwnerName = 'Gerber.TestPlugin'
                    ParentName = 'tools'
                }) `
                -ExistingCommandDefinition ([pscustomobject]@{
                    OwnerName = 'Gerber.Core'
                })).Message

        $rootMessage | Should -Be "Gerber cannot register root command 'tools' from owner 'Gerber.TestPlugin' because it is already owned by 'Gerber.Core'."
        $nestedMessage | Should -Be "Gerber cannot register command 'tools plugin-tool' from owner 'Gerber.TestPlugin' because it is already owned by 'Gerber.Core'."
    }

    It 'fails plugin initialization with clear validation context' -TestCases @(
        @{
            ModuleNameList  = @('Gerber.UnsupportedApiPlugin')
            ExpectedMessage = "Gerber plugin 'Gerber.UnsupportedApiPlugin' requires plugin API version '2', but Gerber supports plugin API version '1'."
        }
        @{
            ModuleNameList  = @('Gerber.MissingEntryPointPlugin')
            ExpectedMessage = "Gerber plugin 'Gerber.MissingEntryPointPlugin' does not export the required entry point 'Get-GerberPlugin'."
        }
        @{
            ModuleNameList  = @('Gerber.InvalidDefinitionPlugin')
            ExpectedMessage = "Gerber plugin 'Gerber.InvalidDefinitionPlugin' returned an invalid command definition for root command 'broken' because 'Handler' was not a scriptblock."
        }
        @{
            ModuleNameList  = @('Gerber.ConflictCorePlugin')
            ExpectedMessage = "Gerber cannot register root command 'tools' from owner 'Gerber.ConflictCorePlugin' because it is already owned by 'Gerber.Core'."
        }
        @{
            ModuleNameList  = @('Gerber.ConflictOnePlugin', 'Gerber.ConflictTwoPlugin')
            ExpectedMessage = "Gerber cannot register root command 'shared' from owner 'Gerber.ConflictTwoPlugin' because it is already owned by 'Gerber.ConflictOnePlugin'."
        }
        @{
            ModuleNameList  = @('Gerber.ImportFailurePlugin')
            ExpectedMessage = "Gerber could not import plugin 'Gerber.ImportFailurePlugin': Import failed on purpose."
        }
    ) {
        param(
            [string[]]$ModuleNameList,
            [string]$ExpectedMessage
        )

        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList $ModuleNameList

        {
            Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot)
        } | Should -Throw $ExpectedMessage
    }

    It 'registers plugin commands atomically when any contributed root command conflicts' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.AtomicConflictPlugin')

        {
            Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot)
        } | Should -Throw "Gerber cannot register root command 'tools' from owner 'Gerber.AtomicConflictPlugin' because it is already owned by 'Gerber.Core'."

        {
            Get-GerberCommandRegistry
        } | Should -Throw 'Gerber command registry has not been initialized for this session.'
    }

    It 'keeps the registry uninitialized when plugin API context creation fails' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.TestPlugin')
        Mock New-GerberPluginApiContext {
            throw [System.InvalidOperationException]::new('Plugin API context creation failed on purpose.')
        }

        {
            Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot)
        } | Should -Throw 'Plugin API context creation failed on purpose.'

        {
            Get-GerberCommandRegistry
        } | Should -Throw 'Gerber command registry has not been initialized for this session.'
    }

    It 'keeps the registry uninitialized when Get-GerberPlugin fails after receiving the plugin API context' {
        Reset-GerberPluginTestEnvironment
        $script:isolatedModuleRoot = New-GerberPluginFixtureModuleRoot `
            -StartPath $PSScriptRoot `
            -ModuleNameList @('Gerber.GetPluginFailurePlugin')

        {
            Initialize-GerberCommandRegistry -PluginModulePathList @($script:isolatedModuleRoot)
        } | Should -Throw "Get-GerberPlugin failed for API version '1'."

        {
            Get-GerberCommandRegistry
        } | Should -Throw 'Gerber command registry has not been initialized for this session.'
    }

    It 'fails clearly when a plugin owner has no initialized API context' {
        {
            Get-GerberRegisteredPluginApiContext -OwnerName 'Gerber.MissingPlugin'
        } | Should -Throw "Gerber command 'Gerber.MissingPlugin' does not have an initialized plugin API context."
    }

    It 'fails clearly when no registry state exists for plugin API context lookup' {
        Clear-GerberCommandRegistry

        {
            Get-GerberRegisteredPluginApiContext -OwnerName 'Gerber.TestPlugin'
        } | Should -Throw 'Gerber command registry has not been initialized for this session.'

        Initialize-GerberCommandRegistry -PluginModulePathList @() | Out-Null
    }

}
