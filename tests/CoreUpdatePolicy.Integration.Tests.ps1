# Built-module integration: persistence, PMU policy and startup transport span config/update boundaries.
# Nova APIs are unused here; isolate their import cost without changing the real Core probe or its budget.
BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    . (Join-Path $PSScriptRoot 'TestHelpers/Initialize-GerberCorePolicyNovaFixture.ps1')
    $novaManifest = Initialize-GerberCorePolicyNovaFixture -DestinationRoot $TestDrive
    $script:policyModule = Import-Module "$root/dist/Gerber/Gerber.psd1" -Force -PassThru
    $script:originalPolicyConfigPath = $env:GERBER_CONFIG_PATH
    $script:realProbeScript = & $script:policyModule { Get-GerberUpdateProbeScript }
    $script:probePrelude = @'
$fixtureModule = Import-Module '__MANIFEST__' -PassThru
& $fixtureModule {
    function script:Get-PSModuleUpdate {
        [CmdletBinding()]
        param($Module, $Repository, $Policy)
        if ($Repository -cne 'PSGallery' -or $Policy.Scope -cne 'CurrentUser') { throw 'Incorrect Core binding' }
        [pscustomobject]@{ InstalledVersion = '0.1.0'; TargetVersion = $Policy.Channel; Disposition = 'UpToDate' }
    }
}
'@.Replace('__MANIFEST__', "$root/dist/Gerber/Gerber.psd1".Replace("'", "''"))
    $script:probePrelude = "Import-Module '$($novaManifest.Replace("'", "''"))' -ErrorAction Stop`n$script:probePrelude"
}

Describe 'Core update policy integration' -Tag 'CoreUpdatePolicy' {
    BeforeEach {
        $env:GERBER_CONFIG_PATH = Join-Path $TestDrive "$([guid]::NewGuid()).json"
    }

    AfterAll {
        $env:GERBER_CONFIG_PATH = $script:originalPolicyConfigPath
        Remove-Module Gerber -Force -ErrorAction SilentlyContinue
    }

    It 'leaves missing configuration untouched when resolving the default policy' {
        (& $script:policyModule { Resolve-GerberCoreUpdatePolicy }).Channel | Should -BeExactly 'Stable'
        Test-Path -LiteralPath $env:GERBER_CONFIG_PATH | Should -BeFalse
    }

    It 'persists <channel> with unrelated settings and reads it in a fresh process' -ForEach @('Stable', 'IncludePrerelease') {
        $channel = $_
        '{"schemaVersion":1,"preferences":{"theme":"dark"},"coreUpdates":{"channel":"IncludePrerelease"}}' |
            Set-Content -LiteralPath $env:GERBER_CONFIG_PATH
        $null = & $script:policyModule { param($channel) Set-GerberCoreUpdateChannel $channel } $channel
        $manifest = $script:policyModule.Path.Replace("'", "''")
        $command = "`$m = Import-Module '$manifest' -PassThru; & `$m { Resolve-GerberCoreUpdatePolicy | ConvertTo-Json -Compress }"
        $json = & (Join-Path $PSHOME pwsh) -NoLogo -NoProfile -NonInteractive -Command $command
        $LASTEXITCODE | Should -Be 0
        ($json | ConvertFrom-Json).Channel | Should -BeExactly $channel
        (Get-Content $env:GERBER_CONFIG_PATH -Raw | ConvertFrom-Json).preferences.theme | Should -BeExactly 'dark'
    }

    It 'uses GERBER_CONFIG_PATH and the same <channel> for manual discovery and the real startup child' -ForEach @('Stable', 'IncludePrerelease') {
        @{ schemaVersion = 1; coreUpdates = @{ channel = $_ } } | ConvertTo-Json |
            Set-Content -LiteralPath $env:GERBER_CONFIG_PATH
        Mock Get-PSModuleUpdate -ModuleName Gerber {
            [pscustomobject]@{ InstalledVersion = '0.1.0'; TargetVersion = $Policy.Channel; Disposition = 'UpToDate' }
        }
        Mock Get-GerberUpdateProbeScript -ModuleName Gerber { "$script:probePrelude`n$script:realProbeScript" }
        $manual = & $script:policyModule { Get-GerberCoreUpdateState }
        $startup = & $script:policyModule { Invoke-GerberStartupUpdateCheck }
        $manual.Status | Should -BeExactly 'UpToDate'
        $startup.Status | Should -BeExactly 'UpToDate'
        $manual.Available | Should -BeExactly $_
        $startup.Available | Should -BeExactly $manual.Available
        $startup.Message | Should -BeExactly $manual.Message
    }
}
