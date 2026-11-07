BeforeAll {
    . (Join-Path $PSScriptRoot '../../TestHelpers/PluginUpdate.TestSupport.ps1')
}

Describe 'Resolve-GerberUpdateBatch' -Tag 'G4A9' {
    BeforeEach {
        $script:item = Get-TestPluginUpdateItem
        $script:core = Get-TestCoreUpdateState
        Mock Get-PSModuleUpdateTargetManifest {
            [pscustomobject]@{
                Manifest = Get-TestPluginTargetManifest '0.3.0'
            }
        }
    }

    It 'adds required Core visibly before a selected plugin without replacing its live plan' {
        $original = $script:item.State.Plan
        $batch = Resolve-GerberUpdateBatch -CoreState $script:core -SelectedItemList @($script:item)
        @($batch.Items.Kind) | Should -Be @('Core', 'Plugin')
        $batch.Items[0].AutoAdded | Should -BeTrue
        $batch.Items[1].MinimumCore.ToString() | Should -Be '0.3.0'
        [object]::ReferenceEquals($batch.Items[1].State.Plan, $original) | Should -BeTrue
        Should -Invoke Get-PSModuleUpdateTargetManifest -Times 1 -ParameterFilter {
            [object]::ReferenceEquals($Plan, $original)
        }
    }

    It 'blocks an unsatisfied plugin without widening the Core channel' {
        $script:core.Status = 'UpToDate'
        $script:core.Available = '0.2.0'
        $batch = Resolve-GerberUpdateBatch -CoreState $script:core -SelectedItemList @($script:item)
        @($batch.Items).Count | Should -Be 1
        $batch.Items[0].State.Status | Should -Be 'Blocked'
        $batch.Items[0].State.Message | Should -Match 'Core'
    }

    It 'does not add Core when the installed version already satisfies the candidate' {
        $script:core = Get-TestCoreUpdateState '0.3.0' '0.3.0'
        $batch = Resolve-GerberUpdateBatch -CoreState $script:core -SelectedItemList @($script:item)
        @($batch.Items.Kind) | Should -Be @('Plugin')
        $batch.Items[0].State.Status | Should -Be 'Available'
    }

    It 'rejects an unverifiable installed Core version before inspecting candidates' {
        $script:core.Installed = 'not-a-version'

        { Resolve-GerberUpdateBatch -CoreState $script:core -SelectedItemList @($script:item) } |
            Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*installed Core version could not be verified*'
        Should -Invoke Get-PSModuleUpdateTargetManifest -Times 0 -Exactly
    }

    It 'blocks changed plugin identity or an unsupported API before installation' -ForEach @('GUID', 'ApiVersion') {
        $field = $_
        Mock Get-PSModuleUpdateTargetManifest {
            $manifest = Get-TestPluginTargetManifest
            if ($field -eq 'GUID') {
                $manifest.GUID = [guid]::NewGuid().ToString()
            }
            else {
                $manifest.PrivateData.Gerber.ApiVersion = '2'
            }
            [pscustomobject]@{
                Manifest = $manifest
            }
        }
        $batch = Resolve-GerberUpdateBatch -CoreState $script:core -SelectedItemList @($script:item)
        $batch.Items[0].State.Status | Should -Be 'Blocked'
    }

    It 'does not grant trust or license acceptance silently while inspecting' {
        $script:item.State.Plan.RequiresRepositoryTrust = $true
        $script:item.State.Plan.RequiresLicenseAcceptance = $true
        Resolve-GerberUpdateBatch -CoreState $script:core -SelectedItemList @($script:item) | Out-Null
        Should -Invoke Get-PSModuleUpdateTargetManifest -ParameterFilter {
            -not $TrustRepository -and -not $AcceptLicense
        }
    }

    It 'keeps provider diagnostics out of inspection failures and preserves cancellation' {
        Mock Get-PSModuleUpdateTargetManifest {
            throw 'provider-token-should-never-render'
        }
        $batch = Resolve-GerberUpdateBatch -CoreState $script:core -SelectedItemList @($script:item)
        $batch.Items[0].State.Status | Should -Be 'Blocked'
        $batch.Items[0].State.Message | Should -Not -Match 'provider-token'
        Mock Get-PSModuleUpdateTargetManifest {
            throw [OperationCanceledException]::new('cancel')
        }
        {
            Resolve-GerberUpdateBatch -CoreState $script:core -SelectedItemList @($script:item)
        } | Should -Throw
    }
}
