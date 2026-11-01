BeforeAll {
    $script:repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
    $script:coreManifest = Join-Path $script:repositoryRoot 'dist/Gerber/Gerber.psd1'
    . (Join-Path $script:repositoryRoot 'tests/TestHelpers/PluginCreationLifecycle.TestSupport.ps1')
}

Describe 'New-GerberPluginProject isolated lifecycle integration' -Tag 'PluginCreate', 'PluginCreateRepository' {
    BeforeEach {
        $script:originalConfig = $env:GERBER_CONFIG_PATH
        $parent = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
        $null = New-Item -ItemType Directory -Path $parent
        $env:GERBER_CONFIG_PATH = Join-Path $parent 'config.json'
        Import-Module $script:coreManifest -Force
    }

    AfterEach {
        $env:GERBER_CONFIG_PATH = $script:originalConfig
        Remove-Module Gerber.MyCompany -Force -ErrorAction SilentlyContinue
    }

    It 'builds, tests, locally publishes and discovers the approved GUID on fresh startup with <Label>' -ForEach @(
        @{ Label = 'explicit PSGallery descriptor'; RepositoryUri = $null }
        @{ Label = 'known repository URI'; RepositoryUri = 'https://packages.example.org/feed' }
        @{ Label = 'unknown repository placeholder'; RepositoryUri = 'REPLACE_WITH_REPOSITORY_URI' }
    ) {
        $inputMap = Get-TestPluginCreationInputMap -Parent $parent -RepositoryUri $RepositoryUri
        $created = Invoke-TestPluginProjectCreation -InputMap $inputMap
        Assert-GerberCreatedPluginLifecycle -Created $created -ConfigPath $env:GERBER_CONFIG_PATH
        Assert-TestCreatedPluginBoundary -Created $created
        $moduleRoot = Join-Path $parent 'modules'
        Publish-TestCreatedPlugin -Created $created -ModuleRoot $moduleRoot
        Assert-TestCreatedPluginRestart -ModuleRoot $moduleRoot -ConfigPath $env:GERBER_CONFIG_PATH
        Assert-TestCreatedPluginManifest -Created $created -ModuleRoot $moduleRoot -RepositoryUri $RepositoryUri
    }
}
