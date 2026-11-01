BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHarness.Configuration.ps1')
}

Describe 'Initialize-GerberTerminalConfigurationEnvironment' -Tag 'TerminalFixtureExtraction' {
    BeforeEach {
        $script:originalConfigPath = $env:GERBER_CONFIG_PATH
        $script:originalHome = $env:HOME
        $script:originalTemp = $env:TEMP
        $script:originalTmp = $env:TMP
        $script:originalTmpDir = $env:TMPDIR
        $script:originalXdgConfigHome = $env:XDG_CONFIG_HOME
    }

    AfterEach {
        $env:GERBER_CONFIG_PATH = $script:originalConfigPath
        $env:HOME = $script:originalHome
        $env:TEMP = $script:originalTemp
        $env:TMP = $script:originalTmp
        $env:TMPDIR = $script:originalTmpDir
        $env:XDG_CONFIG_HOME = $script:originalXdgConfigHome
    }

    It 'isolates configuration, home, and temporary filesystem state beside the prompt trace' {
        $promptTracePath = Join-Path $TestDrive 'runtime/prompt-debug.log'

        Initialize-GerberTerminalConfigurationEnvironment -PromptTracePath $promptTracePath

        $env:GERBER_CONFIG_PATH | Should -Be (Join-Path $TestDrive 'runtime/GerberCore.json')
        $env:HOME | Should -Be (Join-Path $TestDrive 'runtime/home')
        $env:TEMP | Should -Be (Join-Path $TestDrive 'runtime/temp')
        $env:TMP | Should -Be (Join-Path $TestDrive 'runtime/temp')
        $env:TMPDIR | Should -Be (Join-Path $TestDrive 'runtime/temp')
        $env:XDG_CONFIG_HOME | Should -Be (Join-Path $TestDrive 'runtime/xdg-config')
        Test-Path -LiteralPath $env:HOME -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $env:TEMP -PathType Container | Should -BeTrue
    }
}
