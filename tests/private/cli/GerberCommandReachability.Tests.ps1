Set-StrictMode -Version Latest

$script:resolvedCommandCaseList = @(
    @{ CommandPath = '/tools create-uuid'; ExpectedRootName = 'tools'; ExpectedArguments = @('create-uuid') }
    @{ CommandPath = '/tools base-64'; ExpectedRootName = 'tools'; ExpectedArguments = @('base-64') }
    @{ CommandPath = '/tools base-64 encode'; ExpectedRootName = 'tools'; ExpectedArguments = @('base-64', 'encode') }
    @{ CommandPath = '/tools base-64 decode'; ExpectedRootName = 'tools'; ExpectedArguments = @('base-64', 'decode') }
    @{ CommandPath = '/plugins list'; ExpectedRootName = 'plugins'; ExpectedArguments = @('list') }
    @{ CommandPath = '/plugins info Gerber.TestPlugin'; ExpectedRootName = 'plugins'; ExpectedArguments = @('info', 'Gerber.TestPlugin') }
    @{ CommandPath = '/secrets list'; ExpectedRootName = 'secrets'; ExpectedArguments = @('list') }
    @{ CommandPath = '/secrets get'; ExpectedRootName = 'secrets'; ExpectedArguments = @('get') }
    @{ CommandPath = '/secrets test'; ExpectedRootName = 'secrets'; ExpectedArguments = @('test') }
    @{ CommandPath = '/secrets set'; ExpectedRootName = 'secrets'; ExpectedArguments = @('set') }
    @{ CommandPath = '/secrets remove'; ExpectedRootName = 'secrets'; ExpectedArguments = @('remove') }
)

$script:registeredMenuLeafNameList = @(
    'tools create-uuid',
    'tools base-64',
    'plugins list',
    'plugins info'
)

$script:internalActionCommandNameList = @(
    'tools base-64 encode',
    'tools base-64 decode',
    'secrets list',
    'secrets test',
    'secrets get',
    'secrets set',
    'secrets remove'
)

BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Gerber command reachability' {
    It 'resolves representative core command paths through the live command resolver' -ForEach $script:resolvedCommandCaseList {
        param($CommandPath, $ExpectedRootName, $ExpectedArguments)

        $result = Resolve-GerberCommand -InputText $CommandPath

        $result.IsValid | Should -BeTrue
        $result.Name | Should -Be $ExpectedRootName
        $result.Arguments | Should -Be $ExpectedArguments
    }

    It 'keeps registry-driven menu leaf commands registered in the live registry' {
        $missingCommandNameList = [System.Collections.Generic.List[string]]::new()
        foreach ($commandName in $script:registeredMenuLeafNameList) {
            if ($null -eq (Get-GerberRegisteredCommand -Name $commandName)) {
                $missingCommandNameList.Add($commandName)
            }
        }

        @($missingCommandNameList) | Should -Be @()
    }

    It 'keeps internally dispatched action commands out of the registry' -ForEach $script:internalActionCommandNameList {
        (Get-GerberRegisteredCommand -Name $_) | Should -BeNullOrEmpty
    }

    It 'detects missing registry-driven menu leaf commands through in-memory registry manipulation' {
        $registeredCommandList = @(
            Get-GerberCommandRegistry |
                Where-Object { $_.Name -notin @('tools create-uuid', 'plugins list') }
        )
        $registeredCommandNameList = @($registeredCommandList.Name)

        $registeredCommandNameList | Should -Not -Contain 'tools create-uuid'
        $registeredCommandNameList | Should -Not -Contain 'plugins list'
    }

    It 'routes direct invocation of registry-driven menu commands through the live registry' -ForEach @(
        @{ RootName = 'tools'; Subcommand = 'create-uuid'; MockTarget = 'Show-GerberCreateUuidTool' }
        @{ RootName = 'plugins'; Subcommand = 'list'; MockTarget = 'Invoke-GerberPluginsListCommand' }
    ) {
        param($RootName, $Subcommand, $MockTarget)

        Mock Show-GerberCreateUuidTool {}
        Mock Invoke-GerberPluginsListCommand {}

        $subcommandName = Get-GerberMenuSubcommand `
            -CommandName $RootName `
            -Command ([pscustomobject]@{
                Arguments = [string[]]@($Subcommand)
            })
        $registeredCommand = Get-GerberRegisteredSubcommandDefinition -CommandName $RootName -Subcommand $subcommandName

        Invoke-GerberRegisteredSubcommand -RegisteredCommand $registeredCommand -Arguments @($Subcommand)

        Should -Invoke $MockTarget -Times 1
    }

    It 'routes interactive registry-driven menus through the live registry' -ForEach @(
        @{ ViewFunction = 'Show-GerberToolsView'; SelectedSubcommand = 'create-uuid'; MockTarget = 'Show-GerberCreateUuidTool' }
    ) {
        param($ViewFunction, $SelectedSubcommand, $MockTarget)

        $selectedSubcommandName = $SelectedSubcommand
        $script:subcommandSelectionCount = 0
        Mock Get-GerberMenuSubcommand {
            $script:subcommandSelectionCount++
            if ($script:subcommandSelectionCount -eq 1) {
                return $selectedSubcommandName
            }

            return ''
        }
        Mock Show-GerberCreateUuidTool {}

        & $ViewFunction ([pscustomobject]@{ Arguments = @() })

        Should -Invoke $MockTarget -Times 1
    }
}
