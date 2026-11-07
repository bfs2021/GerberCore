# Cross-cutting: the delivered worker imports built Core and executes its actual Plugin API registry checks.
BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers/UpdateActivation.TestSupport.ps1')
    $script:root = Split-Path -Parent $PSScriptRoot
    $script:worker = Join-Path $script:root 'src/resources/update/Test-GerberUpdateActivationWorker.ps1'
    $script:coreManifest = Join-Path (Join-Path $script:root 'dist/Gerber') 'Gerber.psd1'
    $script:coreVersion = (Get-Content (Join-Path $script:root 'project.json') -Raw | ConvertFrom-Json).Version
    . (Join-Path $script:root 'src/private/update/Invoke-GerberUpdateProbe.ps1')
    . (Join-Path $script:root 'src/private/update/Close-GerberUpdateProbe.ps1')
    . (Join-Path $script:root 'src/private/update/Assert-GerberUpdateNotCancelled.ps1')
    . (Join-Path $script:root 'src/private/update/Get-GerberUpdateActivationSummary.ps1')
    . (Join-Path $script:root 'src/private/update/Wait-GerberUpdateProbeOutput.ps1')
    . (Join-Path $script:root 'src/private/update/Read-GerberUpdateActivationResponse.ps1')
    $probe = Join-Path $script:root 'src/private/update/Invoke-GerberUpdateActivationProbe.ps1'
    if (Test-Path $probe) {
        . $probe
    }
}

Describe 'Plugin update activation through a fresh process' -Tag 'G4A9' {
    BeforeEach {
        $script:plugin = Initialize-TestActivationFixture (Join-Path $TestDrive 'fixture') @{
            Plugin               = $true
            ApiVersion           = '1'
            MinimumGerberVersion = '0.2.0'
        }
        $script:payload = @{
            CoreManifest = $script:coreManifest
            CoreVersion  = $script:coreVersion
            Target       = $script:plugin
            OtherPlugins = @()
        }
    }

    It 'validates the intended installed Core and plugin without importing the plugin in the parent' {
        Get-Module Gerber.ActivationFixture | Should -BeNullOrEmpty
        $result = Invoke-TestActivationWorker $script:payload $script:worker
        $result.Status | Should -Be 'Verified'
        $result.Version | Should -Be $script:coreVersion
        Get-Module Gerber.ActivationFixture | Should -BeNullOrEmpty
    }

    It 'runs the actual built-Core check through the bounded production transport' {
        $result = Invoke-GerberUpdateActivationProbe $script:payload
        $result.Status | Should -Be 'Verified'
        $result.Version | Should -Be $script:coreVersion
        Get-Module Gerber.ActivationFixture | Should -BeNullOrEmpty
    }

    It 'reports an incompatible target API separately from successful package installation' {
        $script:plugin = Initialize-TestActivationFixture (Join-Path $TestDrive 'fixture') @{
            Plugin               = $true
            ApiVersion           = '2'
            MinimumGerberVersion = '0.2.0'
        }
        $script:payload.Target = $script:plugin
        $result = Invoke-TestActivationWorker $script:payload $script:worker
        $result.Status | Should -Be 'Failed'
    }

    It 'does not validate against a different Core version or plugin identity' {
        $script:payload.CoreVersion = '99.0.0'
        $result = Invoke-TestActivationWorker $script:payload $script:worker
        $result.Status | Should -Be 'Unverified'
        $script:payload.CoreVersion = $script:coreVersion
        $script:payload.Target.Guid = [guid]::NewGuid().ToString()
        $result = Invoke-TestActivationWorker $script:payload $script:worker
        $result.Status | Should -Be 'Failed'
    }
}
