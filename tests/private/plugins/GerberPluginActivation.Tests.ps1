# Cross-cutting ownership: Enable/Disable-GerberPlugin, root action ordering and the
# registry jointly determine suggestions. Command-specific cases live in their mirrors.
BeforeAll {
    $supportPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers'
    . (Join-Path $supportPath 'GerberTestSupport.ps1')
    . (Join-Path $supportPath 'Initialize-GerberPluginActivationFixture.ps1')
    . (Join-Path $supportPath 'Clear-GerberPluginActivationFixture.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Plugin enable and disable lifecycle' -Tag 'PluginTransactions' {
    BeforeEach {
        $script:activationFixture = Initialize-GerberPluginActivationFixture -StartPath $PSScriptRoot -TestDrivePath $TestDrive
        Mock Get-GerberDefaultPluginModulePathList { [string[]]@($script:activationFixture.ModuleRoot) }
    }

    AfterEach {
        Clear-GerberPluginActivationFixture -Fixture $script:activationFixture
    }

    Context 'Root command ordering after activation changes' {
        It 'keeps reserved commands first and places plugin commands alphabetically' {
            $null = Enable-GerberPlugin -Guid $script:testPluginGuid
            Get-GerberActionList | Should -Be @('exit', 'help', 'plugins', 'update', 'example', 'secrets', 'tools')

            Disable-GerberPlugin -Guid $script:testPluginGuid
            Get-GerberActionList | Should -Be @('exit', 'help', 'plugins', 'update', 'secrets', 'tools')
        }
    }
}
