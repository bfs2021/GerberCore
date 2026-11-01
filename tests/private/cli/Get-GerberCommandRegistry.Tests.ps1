BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberCommandRegistry' {
    It 'returns the initialized effective session registry' {
        $registry = @(Get-GerberCommandRegistry)

        $registry.Name | Should -Be @(
            'tools',
            'list',
            'branch',
            'repository',
            'plugins',
            'pipelines',
            'secrets',
            'update',
            'help',
            'exit',
            'tools create-uuid',
            'tools base-64',
            'plugins list',
            'plugins info',
            'plugins enable',
            'plugins disable',
            'plugins create',
            'update list',
            'update policy'
        )
    }

    It 'throws when the session registry has not been initialized' {
        Clear-GerberCommandRegistry

        {
            Get-GerberCommandRegistry
        } | Should -Throw 'Gerber command registry has not been initialized for this session.'

        Initialize-GerberCommandRegistry -PluginModulePathList @()
    }
}
