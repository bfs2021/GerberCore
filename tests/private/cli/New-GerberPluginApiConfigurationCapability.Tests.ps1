BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'New-GerberPluginApiConfigurationCapability' -Tag 'PluginJson' {
    BeforeEach {
        $script:corePath = Join-Path $TestDrive 'settings/GerberCore.json'
        Mock Resolve-GerberUserConfigPath { $script:corePath }
    }

    It 'binds configuration to the module name without creating files during registration' {
        $api = New-GerberPluginApiContext -ApiVersion '1' -PluginId ([guid]::NewGuid()) -PluginModuleName 'Gerber.Example'
        (& $api.Configuration.Read) | Should -BeNullOrEmpty
        (Test-Path (Split-Path $script:corePath -Parent)) | Should -BeFalse
    }

    It 'round-trips plugin-defined JSON without imposing a schema' -ForEach @(
        @{ Value = @{ nested = @{ enabled = $true }; unknown = 'kept' } }
        @{ Value = @('one', 'two') }
        @{ Value = @('only') }
        @{ Value = 'scalar' }
        @{ Value = $false }
        @{ Value = $null }
    ) {
        $api = New-GerberPluginApiContext -ApiVersion '1' -PluginId ([guid]::NewGuid()) -PluginModuleName 'Gerber.Example'
        & $api.Configuration.Save $Value
        $result = & $api.Configuration.Read
        (ConvertTo-Json -InputObject $result -Depth 100 -Compress) | Should -Be (ConvertTo-Json -InputObject $Value -Depth 100 -Compress)
        (Test-Path (Join-Path $TestDrive 'settings/Gerber.Example.json')) | Should -BeTrue
        (Test-Path $script:corePath) | Should -BeFalse
    }

    It 'keeps the original file when publishing a replacement fails' {
        $api = New-GerberPluginApiContext -ApiVersion '1' -PluginId ([guid]::NewGuid()) -PluginModuleName 'Gerber.Example'
        & $api.Configuration.Save @{ existing = 'original' }
        Mock Publish-GerberUserConfigurationTemporaryFile { throw [System.IO.IOException]::new('Publish failed') }
        { & $api.Configuration.Save @{ replacement = 'new' } } | Should -Throw '*could not save*'
        (& $api.Configuration.Read).existing | Should -Be 'original'
        @(Get-ChildItem (Split-Path $script:corePath -Parent) -Filter '*.tmp') | Should -BeNullOrEmpty
    }

    It 'does not replace invalid existing JSON with defaults or new content' -ForEach @(
        @{ InvalidJson = '{' }
        @{ InvalidJson = '' }
        @{ InvalidJson = '{"value":1,}' }
    ) {
        $null = New-Item -ItemType Directory -Path (Split-Path $script:corePath -Parent) -Force
        $path = Join-Path $TestDrive 'settings/Gerber.Example.json'
        [System.IO.File]::WriteAllText($path, $InvalidJson)
        $api = New-GerberPluginApiContext -ApiVersion '1' -PluginId ([guid]::NewGuid()) -PluginModuleName 'Gerber.Example'
        { & $api.Configuration.Read } | Should -Throw '*JSON*'
        { & $api.Configuration.Save @{ replacement = $true } } | Should -Throw '*JSON*'
        [System.IO.File]::ReadAllText($path) | Should -Be $InvalidJson
    }

    It 'cannot select Core or another plugin file through extra operation arguments' {
        $first = New-GerberPluginApiContext -ApiVersion '1' -PluginId ([guid]::NewGuid()) -PluginModuleName 'Gerber.First'
        $second = New-GerberPluginApiContext -ApiVersion '1' -PluginId ([guid]::NewGuid()) -PluginModuleName 'Gerber.Second'
        & $first.Configuration.Save @{ owner = 'first' } $script:corePath 'Gerber.Second'
        (& $second.Configuration.Read) | Should -BeNullOrEmpty
        (& $first.Configuration.Read).owner | Should -Be 'first'
        (Test-Path $script:corePath) | Should -BeFalse
    }

    It 'rejects unsafe module identities before constructing a file capability' -ForEach @(
        @{ ModuleName = '../GerberCore' }
        @{ ModuleName = 'GerberCore' }
        @{ ModuleName = 'Gerber.Other/../../GerberCore' }
    ) {
        { New-GerberPluginApiContext -ApiVersion '1' -PluginId ([guid]::NewGuid()) -PluginModuleName $ModuleName } |
            Should -Throw '*module name*'
    }
}
