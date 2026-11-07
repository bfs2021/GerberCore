# Built Plugin API v1 registration, persisted lifecycle, catalog and dispatch span
# multiple helpers. Generic isolated modules are the only runtime contributions.
BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers/Initialize-GerberActiveTreeFixture.ps1')
    $script:activeTreeModule = Import-Module (Join-Path $PSScriptRoot '../dist/Gerber/Gerber.psd1') -Force -PassThru
    $script:activeTreeOriginalConfig = $env:GERBER_CONFIG_PATH
}

Describe 'Built active command tree lifecycle' -Tag 'ActiveCommandTree' {
    BeforeEach {
        $script:activeTreeFixtureRoot = Join-Path $TestDrive 'modules'
        $script:activeTreeOne = '0205d32c-5234-4ab4-b5ae-bf796e12fe32'
        $script:activeTreeTwo = '0d3c63bf-02f1-4d32-a7c7-8021bcd38edc'
        Initialize-GerberActiveTreeFixture $activeTreeFixtureRoot Gerber.GenericOnePlugin $activeTreeOne @('repository alpha', 'branch leaf')
        Initialize-GerberActiveTreeFixture $activeTreeFixtureRoot Gerber.GenericTwoPlugin $activeTreeTwo @('repository beta', 'pipelines leaf', 'list leaf')
        $env:GERBER_CONFIG_PATH = Join-Path $TestDrive 'active-tree.json'
        Mock Get-GerberDefaultPluginModulePathList -ModuleName Gerber { @($script:activeTreeFixtureRoot) }
        Mock Read-GerberSubcommandPrompt -ModuleName Gerber {
            $escape = [System.OperationCanceledException]::new('Escape')
            $escape.Data['GerberMenuEscape'] = $true
            throw $escape
        }
        & $activeTreeModule { Clear-GerberCommandRegistry; $null = Initialize-GerberCommandRegistry -PluginModulePathList @() }
    }

    AfterEach {
        $env:GERBER_CONFIG_PATH = $script:activeTreeOriginalConfig
        Remove-Module Gerber.GenericOnePlugin, Gerber.GenericTwoPlugin -Force -ErrorAction SilentlyContinue
    }

    It 'enables and disables real generic modules in the current built session while retaining other contributors' {
        & $activeTreeModule { param($Guid) $null = Enable-GerberPlugin -Guid $Guid } $activeTreeOne
        & $activeTreeModule { Get-GerberActionList } | Should -Be @('exit', 'help', 'plugins', 'update', 'branch', 'repository', 'secrets', 'tools')
        & $activeTreeModule { param($Guid) $null = Enable-GerberPlugin -Guid $Guid } $activeTreeTwo
        & $activeTreeModule { param($Guid) Disable-GerberPlugin -Guid $Guid } $activeTreeOne
        & $activeTreeModule { (Get-GerberRegisteredCommand -Name repository).Subcommands.Keys } | Should -Be @('beta')
        & $activeTreeModule { Get-GerberRegisteredCommand -Name branch } | Should -BeNullOrEmpty
        & $activeTreeModule { (Resolve-GerberCommand '/repository beta').IsValid } | Should -BeTrue
        & $activeTreeModule { param($Guid) Disable-GerberPlugin -Guid $Guid } $activeTreeTwo
        & $activeTreeModule { Get-GerberActionList } | Should -Be @('exit', 'help', 'plugins', 'update', 'secrets', 'tools')
        & $activeTreeModule { param($Guid) $null = Enable-GerberPlugin -Guid $Guid } $activeTreeOne
        & $activeTreeModule { param($Guid) $null = Enable-GerberPlugin -Guid $Guid } $activeTreeOne
        & $activeTreeModule { @(Get-GerberCommandRegistry | Where-Object Name -EQ repository).Count } | Should -Be 1
        & $activeTreeModule { (Get-GerberRegisteredCommand -Name repository).Subcommands.Keys } | Should -Be @('alpha')
        & $activeTreeModule { Invoke-GerberMenuCommand -Command (Resolve-GerberCommand '/repository alpha') } | Should -BeFalse
        & $activeTreeModule { param($Guid) (Get-GerberPluginLifecycleState -Guid $Guid).IsEnabled } $activeTreeTwo | Should -BeFalse
        & $activeTreeModule { param($Guid) (Get-GerberPluginLifecycleState -Guid $Guid).IsEnabled } $activeTreeOne | Should -BeTrue
    }

    It 'starts without historical roots and rejects direct dispatch through the same tree' {
        & $activeTreeModule { Get-GerberActionList } | Should -Be @('exit', 'help', 'plugins', 'update', 'secrets', 'tools')
        foreach ($root in @('branch', 'list', 'pipelines', 'repository')) {
            & $activeTreeModule { param($Name) Get-GerberRegisteredCommand -Name $Name } $root | Should -BeNullOrEmpty
            & $activeTreeModule { param($Name) (Resolve-GerberCommand "/$Name").IsValid } $root | Should -BeFalse
            { & $activeTreeModule { param($Name) Invoke-GerberMenuCommand -Command ([pscustomobject]@{ Name = $Name; Arguments = @() }) } $root } |
                Should -Throw "Unknown Gerber root command '$root'."
        }
        & $activeTreeModule { Get-GerberHelpRootCommandLineList } | Should -Not -Match '/branch|/list|/pipelines|/repository'
    }
}
