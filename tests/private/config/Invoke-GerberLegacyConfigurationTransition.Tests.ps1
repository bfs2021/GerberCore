BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Set-GerberTransitionTestJson {
        [CmdletBinding(SupportsShouldProcess)]
        param([string]$Path, [object]$Value)
        if (-not $PSCmdlet.ShouldProcess($Path, 'Write test JSON')) { return }
        $null = New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force
        [System.IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 100))
    }
}

Describe 'Invoke-GerberLegacyConfigurationTransition' -Tag 'PluginJson' {
    BeforeEach {
        $script:corePath = Join-Path (Join-Path $TestDrive ([guid]::NewGuid().ToString())) 'GerberCore.json'
        $script:legacyPath = Join-Path (Split-Path $script:corePath -Parent) 'config.json'
        $script:pluginPath = Join-Path (Split-Path $script:corePath -Parent) 'Gerber.AzureDevOps.json'
        Mock Resolve-GerberUserConfigPath { $script:corePath }
    }

    It 'transfers Core and ADO data separately without approving a plugin and is repeatable' {
        Set-GerberTransitionTestJson $script:legacyPath @{
            schemaVersion = 1; custom = @{ keep = 'yes' }; ado = @{ profiles = @{ Example = @{ projectUrl = 'https://dev.azure.com/example/project' } } }
        }
        $configuration = Get-GerberUserConfiguration
        $configuration.custom.keep | Should -Be 'yes'
        $configuration.ContainsKey('ado') | Should -BeFalse
        $configuration.ContainsKey('plugins') | Should -BeFalse
        (Get-Content $script:pluginPath -Raw | ConvertFrom-Json -AsHashtable).ado.profiles.Example.projectUrl |
            Should -Be 'https://dev.azure.com/example/project'
        (Test-Path $script:legacyPath) | Should -BeFalse
        (Get-GerberUserConfiguration).custom.keep | Should -Be 'yes'
    }

    It 'preserves disjoint destination settings and matching values' {
        Set-GerberTransitionTestJson $script:legacyPath @{ schemaVersion = 1; shared = 'same'; legacy = 1; ado = @{ profiles = @{} } }
        Set-GerberTransitionTestJson $script:corePath @{ schemaVersion = 1; shared = 'same'; destination = 2 }
        Set-GerberTransitionTestJson $script:pluginPath @{ other = 'kept' }
        $configuration = Get-GerberUserConfiguration
        $configuration.legacy | Should -Be 1
        $configuration.destination | Should -Be 2
        (Get-Content $script:pluginPath -Raw | ConvertFrom-Json -AsHashtable).other | Should -Be 'kept'
        (Test-Path $script:legacyPath) | Should -BeFalse
    }

    It 'preserves every original when destination values conflict' {
        Set-GerberTransitionTestJson $script:legacyPath @{ schemaVersion = 1; theme = 'legacy'; ado = @{ value = 'old' } }
        Set-GerberTransitionTestJson $script:corePath @{ schemaVersion = 1; theme = 'new' }
        $original = [System.IO.File]::ReadAllText($script:legacyPath)
        { Get-GerberUserConfiguration } | Should -Throw '*conflict*'
        [System.IO.File]::ReadAllText($script:legacyPath) | Should -Be $original
        (Get-Content $script:corePath -Raw | ConvertFrom-Json -AsHashtable).theme | Should -Be 'new'
        (Test-Path $script:pluginPath) | Should -BeFalse
    }

    It 'retains the source after a partial write failure and finishes safely on retry' {
        Set-GerberTransitionTestJson $script:legacyPath @{ schemaVersion = 1; custom = 42; ado = @{ profiles = @{} } }
        $script:failPluginWrite = $true
        Mock Publish-GerberUserConfigurationTemporaryFile {
            if ($script:failPluginWrite) { throw [System.IO.IOException]::new('Full disk') }
            [System.IO.File]::Move($SourcePath, $DestinationPath, $true)
        } -ParameterFilter {
            $DestinationPath -eq $script:pluginPath
        }
        { Get-GerberUserConfiguration } | Should -Throw '*could not save*'
        (Test-Path $script:legacyPath) | Should -BeTrue
        (Get-Content $script:corePath -Raw | ConvertFrom-Json -AsHashtable).custom | Should -Be 42
        $script:failPluginWrite = $false
        (Get-GerberUserConfiguration).custom | Should -Be 42
        (Get-Content $script:pluginPath -Raw | ConvertFrom-Json -AsHashtable).ado.profiles.Count | Should -Be 0
        (Test-Path $script:legacyPath) | Should -BeFalse
    }

    It 'refuses invalid legacy JSON without creating destinations' {
        $null = New-Item -ItemType Directory -Path (Split-Path $script:corePath -Parent) -Force
        [System.IO.File]::WriteAllText($script:legacyPath, '{')
        { Get-GerberUserConfiguration } | Should -Throw '*JSON*'
        (Test-Path $script:legacyPath) | Should -BeTrue
        (Test-Path $script:corePath) | Should -BeFalse
        (Test-Path $script:pluginPath) | Should -BeFalse
    }

    It 'treats an existing null destination as data rather than an absent file' {
        Set-GerberTransitionTestJson $script:legacyPath @{ schemaVersion = 1; ado = @{ profiles = @{} } }
        Set-GerberTransitionTestJson $script:pluginPath $null
        { Get-GerberUserConfiguration } | Should -Throw '*conflict*'
        [System.IO.File]::ReadAllText($script:pluginPath) | Should -Be 'null'
        (Test-Path $script:corePath) | Should -BeFalse
        (Test-Path $script:legacyPath) | Should -BeTrue
    }

    It 'validates both destination files before writing either destination' {
        Set-GerberTransitionTestJson $script:legacyPath @{ schemaVersion = 1; ado = @{ profiles = @{} } }
        [System.IO.File]::WriteAllText($script:pluginPath, '{')
        { Get-GerberUserConfiguration } | Should -Throw '*JSON*'
        [System.IO.File]::ReadAllText($script:pluginPath) | Should -Be '{'
        (Test-Path $script:corePath) | Should -BeFalse
        (Test-Path $script:legacyPath) | Should -BeTrue
    }

    It 'preserves case-distinct unknown JSON fields during the legacy split' {
        $null = New-Item -ItemType Directory -Path (Split-Path $script:corePath -Parent) -Force
        [System.IO.File]::WriteAllText($script:legacyPath, '{"schemaVersion":1,"Foo":1,"foo":2,"ADO":{"unknown":true},"ado":{"profiles":{}}}')
        $configuration = Get-GerberUserConfiguration
        $configuration['Foo'] | Should -Be 1
        $configuration['foo'] | Should -Be 2
        $configuration['ADO'].unknown | Should -BeTrue
        (Get-Content $script:pluginPath -Raw | ConvertFrom-Json -AsHashtable).ado.profiles.Count | Should -Be 0
    }

    It 'refuses a Core override that selects the ADO destination before writing either file' {
        $script:corePath = $script:pluginPath
        Set-GerberTransitionTestJson $script:legacyPath @{ schemaVersion = 1; ado = @{ profiles = @{} } }
        { Get-GerberUserConfiguration } | Should -Throw '*Core*configuration*'
        (Test-Path $script:pluginPath) | Should -BeFalse
        (Test-Path $script:legacyPath) | Should -BeTrue
    }
}
