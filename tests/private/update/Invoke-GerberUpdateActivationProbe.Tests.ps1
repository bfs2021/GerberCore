BeforeAll {
    . (Join-Path $PSScriptRoot '../../TestHelpers/PluginUpdate.TestSupport.ps1')
    $probe = Join-Path $backendRoot 'update/Invoke-GerberUpdateActivationProbe.ps1'
    if (Test-Path $probe) {
        . $probe
    }
}

Describe 'Invoke-GerberUpdateActivationProbe' -Tag 'G4A9' {
    BeforeEach {
        $script:probeWorker = Join-Path $TestDrive 'worker.ps1'
        if (Get-Command Get-GerberUpdateActivationWorkerPath -ErrorAction SilentlyContinue) {
            Mock Get-GerberUpdateActivationWorkerPath {
                $script:probeWorker
            }
        }
        $script:probePayload = @{
            CoreVersion = '0.3.0'
        }
    }

    It 'returns only a validated structured response from the child' {
        Set-Content $script:probeWorker "param(`$Payload); '{`"Protocol`":1,`"Status`":`"Verified`",`"Version`":`"0.3.0`"}'"
        (Invoke-GerberUpdateActivationProbe $script:probePayload).Status | Should -Be 'Verified'
    }

    It 'reports nonzero exit and unexpected output as unverified' -ForEach @('exit 3', "'private-diagnostic'") {
        Set-Content $script:probeWorker "param(`$Payload); $_"
        $result = Invoke-GerberUpdateActivationProbe $script:probePayload
        $result.Status | Should -Be 'Unverified'
        ($result | ConvertTo-Json) | Should -Not -Match 'private-diagnostic'
    }

    It 'bounds a child that does not finish' {
        Set-Content $script:probeWorker 'param($Payload); Start-Sleep -Seconds 30'
        $watch = [Diagnostics.Stopwatch]::StartNew()
        (Invoke-GerberUpdateActivationProbe $script:probePayload -TimeoutMilliseconds 100).Status | Should -Be 'Unverified'
        $watch.Elapsed.TotalSeconds | Should -BeLessThan 10
    }

    It 'reports a probe exception as unverified without leaking diagnostics and closes the process' {
        Mock Receive-GerberUpdateActivationProbe { throw 'private-probe-diagnostic' }
        Mock Close-GerberUpdateProbe { $Process.Dispose() }
        $result = Invoke-GerberUpdateActivationProbe $script:probePayload
        $result.Status | Should -Be 'Unverified'
        ($result | ConvertTo-Json) | Should -Not -Match 'private-probe-diagnostic'
        Should -Invoke Close-GerberUpdateProbe -Times 1 -Exactly
    }

    It 'propagates cancellation while still closing the process' {
        Mock Receive-GerberUpdateActivationProbe { throw [OperationCanceledException]::new('Probe cancelled.') }
        Mock Close-GerberUpdateProbe { $Process.Dispose() }
        { Invoke-GerberUpdateActivationProbe $script:probePayload } | Should -Throw 'Probe cancelled.'
        Should -Invoke Close-GerberUpdateProbe -Times 1 -Exactly
    }
}

Describe 'Get-GerberUpdateActivationWorkerPath' -Tag 'G4A9' {
    It 'resolves the worker from <Relative> without requiring a build' -ForEach @(
        @{ Relative = 'resources/update'; Probes = 1 }
        @{ Relative = '../../resources/update'; Probes = 2 }
    ) {
        $script:workerCandidate = Join-Path (Join-Path $backendRoot "update/$Relative") 'Test-GerberUpdateActivationWorker.ps1'
        Mock Test-Path { $LiteralPath -eq $script:workerCandidate }
        Get-GerberUpdateActivationWorkerPath | Should -Be ([IO.Path]::GetFullPath($script:workerCandidate))
        Should -Invoke Test-Path -Times $Probes -Exactly -ParameterFilter { $PathType -eq 'Leaf' }
    }

    It 'reports a missing worker rather than returning an unusable path' {
        Mock Test-Path { $false }
        { Get-GerberUpdateActivationWorkerPath } | Should -Throw '*activation worker is missing*Rebuild or reinstall Gerber*'
        Should -Invoke Test-Path -Times 2 -Exactly
    }
}
