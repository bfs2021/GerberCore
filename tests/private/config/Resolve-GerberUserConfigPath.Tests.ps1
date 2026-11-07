BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Use-GerberUserConfigEnvironmentMock {
        param(
            [hashtable]$ValueByName = @{}
        )

        $script:GerberUserConfigEnvironmentValueByName = $ValueByName
        Mock Get-GerberUserConfigEnvironmentValue {
            if ($script:GerberUserConfigEnvironmentValueByName.ContainsKey($Name)) {
                return $script:GerberUserConfigEnvironmentValueByName[$Name]
            }

            return $null
        }
    }
}

Describe 'Resolve-GerberUserConfigPath' -Tag 'PluginJson' {
    It 'uses APPDATA on Windows' {
        Use-GerberUserConfigEnvironmentMock -ValueByName @{
            APPDATA = (Join-Path $TestDrive 'AppData/Roaming')
        }

        $result = Resolve-GerberUserConfigPath -IsWindowsPlatform $true

        $result | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $TestDrive 'AppData/Roaming/Gerber/GerberCore.json')))
    }

    It 'uses XDG_CONFIG_HOME on Unix-like platforms when it is defined' {
        Use-GerberUserConfigEnvironmentMock -ValueByName @{
            XDG_CONFIG_HOME = (Join-Path $TestDrive 'xdg-config')
            HOME = (Join-Path $TestDrive 'home')
        }

        $result = Resolve-GerberUserConfigPath -IsWindowsPlatform $false

        $result | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $TestDrive 'xdg-config/Gerber/GerberCore.json')))
    }

    It 'falls back to HOME/.config on Unix-like platforms when XDG_CONFIG_HOME is missing' {
        Use-GerberUserConfigEnvironmentMock -ValueByName @{
            HOME = (Join-Path $TestDrive 'home')
        }

        $result = Resolve-GerberUserConfigPath -IsWindowsPlatform $false

        $result | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $TestDrive 'home/.config/Gerber/GerberCore.json')))
    }

    It 'prefers GERBER_CONFIG_PATH over platform-specific defaults' {
        $overridePath = Join-Path $TestDrive 'custom/location/settings.json'

        Use-GerberUserConfigEnvironmentMock -ValueByName @{
            GERBER_CONFIG_PATH = $overridePath
            APPDATA = (Join-Path $TestDrive 'AppData/Roaming')
            XDG_CONFIG_HOME = (Join-Path $TestDrive 'xdg-config')
            HOME = (Join-Path $TestDrive 'home')
        }

        $result = Resolve-GerberUserConfigPath -IsWindowsPlatform $true

        $result | Should -Be ([System.IO.Path]::GetFullPath($overridePath))
    }

    It 'does not depend on the current working directory' {
        $firstLocation = Join-Path $TestDrive 'first'
        $secondLocation = Join-Path $TestDrive 'second'
        $null = New-Item -ItemType Directory -Path $firstLocation -Force
        $null = New-Item -ItemType Directory -Path $secondLocation -Force

        Use-GerberUserConfigEnvironmentMock -ValueByName @{
            XDG_CONFIG_HOME = (Join-Path $TestDrive 'xdg-config')
            HOME = (Join-Path $TestDrive 'home')
        }

        Push-Location $firstLocation
        try {
            $firstResult = Resolve-GerberUserConfigPath -IsWindowsPlatform $false
            Set-Location $secondLocation
            $secondResult = Resolve-GerberUserConfigPath -IsWindowsPlatform $false
        } finally {
            Pop-Location
        }

        $firstResult | Should -Be $secondResult
    }

    It 'throws an actionable error when GERBER_CONFIG_PATH is blank' {
        Use-GerberUserConfigEnvironmentMock -ValueByName @{
            GERBER_CONFIG_PATH = ' '
        }

        { Resolve-GerberUserConfigPath -IsWindowsPlatform $false } | Should -Throw "*GERBER_CONFIG_PATH*full file path*"
    }

    It 'throws an actionable error when GERBER_CONFIG_PATH is relative' {
        Use-GerberUserConfigEnvironmentMock -ValueByName @{
            GERBER_CONFIG_PATH = 'relative/config.json'
        }

        { Resolve-GerberUserConfigPath -IsWindowsPlatform $false } | Should -Throw "*GERBER_CONFIG_PATH*absolute path*"
    }

    It 'throws an actionable error when APPDATA is missing on Windows' {
        Use-GerberUserConfigEnvironmentMock

        { Resolve-GerberUserConfigPath -IsWindowsPlatform $true } | Should -Throw "*APPDATA*"
    }

    It 'throws an actionable error when XDG_CONFIG_HOME is blank' {
        Use-GerberUserConfigEnvironmentMock -ValueByName @{
            XDG_CONFIG_HOME = ''
            HOME = (Join-Path $TestDrive 'home')
        }

        { Resolve-GerberUserConfigPath -IsWindowsPlatform $false } | Should -Throw "*XDG_CONFIG_HOME*"
    }

    It 'does not create directories while resolving the path' {
        $xdgConfigHome = Join-Path $TestDrive 'xdg-root'

        Use-GerberUserConfigEnvironmentMock -ValueByName @{
            XDG_CONFIG_HOME = $xdgConfigHome
            HOME = (Join-Path $TestDrive 'home')
        }

        $result = Resolve-GerberUserConfigPath -IsWindowsPlatform $false

        $result | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $xdgConfigHome 'Gerber/GerberCore.json')))
        (Test-Path -LiteralPath $xdgConfigHome) | Should -BeFalse
    }

    It 'normalizes a legacy config.json override to its sibling Core file' {
        Use-GerberUserConfigEnvironmentMock -ValueByName @{ GERBER_CONFIG_PATH = (Join-Path $TestDrive 'custom/config.json') }
        Resolve-GerberUserConfigPath -IsWindowsPlatform $false | Should -Be (Join-Path $TestDrive 'custom/GerberCore.json')
    }

    It 'preserves case-distinct custom overrides on Unix while recognizing Windows legacy names' -ForEach @(
        @{ WindowsPlatform = $false; ExpectedName = 'CONFIG.JSON' }
        @{ WindowsPlatform = $true; ExpectedName = 'GerberCore.json' }
    ) {
        $directory = Join-Path $TestDrive 'custom'
        Use-GerberUserConfigEnvironmentMock -ValueByName @{ GERBER_CONFIG_PATH = (Join-Path $directory 'CONFIG.JSON') }
        Resolve-GerberUserConfigPath -IsWindowsPlatform $WindowsPlatform | Should -Be (Join-Path $directory $ExpectedName)
    }
}
