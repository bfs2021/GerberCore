BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Publish-GerberUserConfigurationTemporaryFile' -Tag 'PluginJson' {
    It 'preserves an existing destination when the staged file cannot be published' {
        $destination = Join-Path $TestDrive 'GerberCore.json'
        [System.IO.File]::WriteAllText($destination, '{"original":true}')
        { Publish-GerberUserConfigurationTemporaryFile -SourcePath (Join-Path $TestDrive 'missing.tmp') -DestinationPath $destination } |
            Should -Throw
        [System.IO.File]::ReadAllText($destination) | Should -Be '{"original":true}'
    }
}
