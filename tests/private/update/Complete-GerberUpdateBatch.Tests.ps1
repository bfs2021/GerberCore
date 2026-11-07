BeforeAll {
    . (Join-Path $PSScriptRoot '../../TestHelpers/PluginUpdate.TestSupport.ps1')
}

Describe 'Complete-GerberUpdateBatch' -Tag 'G4A9' {
    BeforeEach {
        $script:core = Get-TestCoreUpdateState
        $script:first = Get-TestPluginUpdateItem
        $script:second = Get-TestPluginUpdateItem 'Gerber.Second'
        $script:second.Plugin.Guid = [guid]::NewGuid().ToString()
        $script:first.MinimumCore = [System.Management.Automation.SemanticVersion]'0.3.0'
        $script:second.MinimumCore = [System.Management.Automation.SemanticVersion]'0.2.0'
        $script:batch = [pscustomobject]@{
            Items                = @((Get-GerberUpdateItem $script:core), $script:first, $script:second)
            InstalledCoreVersion = [System.Management.Automation.SemanticVersion]'0.2.0'
            CoreState            = $script:core
        }
        Mock Resolve-GerberCoreUpdatePolicy {
            @{
                Channel               = 'Stable'
                Scope                 = 'CurrentUser'
                ExpectedRepositoryUri = [uri]'https://www.powershellgallery.com/api/v2'
            }
        }
        Mock Get-GerberPluginInventory {
            @($script:first.Plugin, $script:second.Plugin)
        }
        Mock Invoke-GerberCoreUpdateInstall {
            $result = Get-TestPluginInstallResult
            $result.InstalledVersion = '0.3.0'
            $result
        }
        Mock Install-PSModuleUpdate {
            Get-TestPluginInstallResult
        }
        Mock Test-GerberUpdateActivation {
            [pscustomobject]@{
                Status  = 'Verified'
                Version = [string]$CoreVersion
            }
        }
    }

    It 'installs Core first, then passes the original plugin plans sequentially to PMU' {
        $script:order = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-GerberCoreUpdateInstall {
            $script:order.Add('Gerber')
            $result = Get-TestPluginInstallResult
            $result.InstalledVersion = '0.3.0'
            $result
        }
        Mock Install-PSModuleUpdate {
            $script:order.Add($Update.ModuleName)
            Get-TestPluginInstallResult
        }
        $results = @(Complete-GerberUpdateBatch $script:batch)
        @($script:order) | Should -Be @('Gerber', 'Gerber.Example', 'Gerber.Second')
        @($results.Outcome) | Should -Be @('Installed', 'Installed', 'Installed')
        Should -Invoke Install-PSModuleUpdate -ParameterFilter {
            [object]::ReferenceEquals($Update, $script:first.State.Plan) -and -not $Confirm
        }
    }

    It 'blocks a dependent plugin after Core failure but still installs an independent plugin' {
        Mock Invoke-GerberCoreUpdateInstall {
            'Core installation failed safely.'
        }
        Mock Test-GerberUpdateActivation {
            [pscustomobject]@{
                Status  = 'Verified'
                Version = '0.2.0'
            }
        }
        $results = @(Complete-GerberUpdateBatch $script:batch)
        @($results.Outcome) | Should -Be @('Failed', 'Blocked', 'Installed')
        Should -Invoke Install-PSModuleUpdate -Times 1 -ParameterFilter {
            $Update.ModuleName -eq 'Gerber.Second'
        }
    }

    It 'continues after an individual plugin failure without exposing provider diagnostics' {
        $script:batch.Items = @($script:second, $script:second.PSObject.Copy())
        $script:batch.Items[1] = Get-TestPluginUpdateItem 'Gerber.Third'
        $script:batch.Items[1].Plugin.Guid = [guid]::NewGuid().ToString()
        $script:batch.Items[1].MinimumCore = [System.Management.Automation.SemanticVersion]'0.2.0'
        Mock Get-GerberPluginInventory {
            @($script:batch.Items.Plugin)
        }
        Mock Install-PSModuleUpdate {
            if ($Update.ModuleName -eq 'Gerber.Second') {
                throw 'private-provider-token'
            }
            Get-TestPluginInstallResult
        }
        $results = @(Complete-GerberUpdateBatch $script:batch)
        @($results.Outcome) | Should -Be @('Failed', 'Installed')
        ($results.Message -join ' ') | Should -Not -Match 'private-provider-token'
    }

    It 'retains installed status but reports failed activation without claiming rollback' {
        Mock Test-GerberUpdateActivation {
            [pscustomobject]@{
                Status  = 'Failed'
                Version = [string]$CoreVersion
            }
        } -ParameterFilter {
            $Item.Kind -eq 'Plugin'
        }
        $script:batch.Items = @($script:second)
        $result = Complete-GerberUpdateBatch $script:batch
        $result.Outcome | Should -Be 'Installed'
        $result.ActivationStatus | Should -Be 'Failed'
        $result.RecoveryStatus | Should -Be 'NotRequired'
        $result.RestartRequired | Should -BeTrue
    }

    It 'stops further installations when PMU reports explicit cancellation' {
        Mock Install-PSModuleUpdate {
            $result = Get-TestPluginInstallResult
            $result.Outcome = 'Cancelled'
            $result
        }
        $script:first.MinimumCore = [System.Management.Automation.SemanticVersion]'0.2.0'
        $script:batch.Items = @($script:first, $script:second)
        $results = @(Complete-GerberUpdateBatch $script:batch)
        @($results.Outcome) | Should -Be @('Cancelled', 'Cancelled')
        Should -Invoke Install-PSModuleUpdate -Times 1
    }

    It 'does not import plugins for pending activation checks after explicit cancellation' {
        $script:first.MinimumCore = [System.Management.Automation.SemanticVersion]'0.2.0'
        $script:batch.Items = @($script:first, $script:second)
        Mock Install-PSModuleUpdate {
            $result = Get-TestPluginInstallResult
            if ($Update.ModuleName -eq 'Gerber.Second') {
                $result.Outcome = 'Cancelled'
            }
            $result
        }
        $results = @(Complete-GerberUpdateBatch $script:batch)
        @($results.Outcome) | Should -Be @('Installed', 'Cancelled')
        $results[0].ActivationStatus | Should -Be 'Unverified'
        Should -Invoke Test-GerberUpdateActivation -Times 0 -ParameterFilter {
            $Item.Kind -eq 'Plugin'
        }
    }

    It 'rechecks plugin approval and activation before mutating anything' {
        $script:second.Plugin.IsEnabled = $false
        $script:batch.Items = @($script:second)
        $result = Complete-GerberUpdateBatch $script:batch
        $result.Outcome | Should -Be 'Blocked'
        Should -Invoke Install-PSModuleUpdate -Times 0
    }

    It 'blocks an item whose discovery status is no longer available' {
        $script:second.State.Status = 'Unavailable'
        $script:batch.Items = @($script:second)
        (Complete-GerberUpdateBatch $script:batch).Outcome | Should -Be 'Blocked'
        Should -Invoke Install-PSModuleUpdate -Times 0
    }

    It 'blocks a plugin when the shared update channel changed after discovery' {
        $script:second.State.Channel = 'IncludePrerelease'
        $script:batch.Items = @($script:second)
        (Complete-GerberUpdateBatch $script:batch).Outcome | Should -Be 'Blocked'
        Should -Invoke Install-PSModuleUpdate -Times 0
    }

    It 'blocks missing or ambiguous current plugin selections with <Count> matches' -ForEach @(
        @{ Count = 0 }
        @{ Count = 2 }
    ) {
        $script:selection = @(@($script:second.Plugin) * $Count)
        Mock Get-GerberPluginInventory { $script:selection }
        $script:batch.Items = @($script:second)
        (Complete-GerberUpdateBatch $script:batch).Outcome | Should -Be 'Blocked'
        Should -Invoke Install-PSModuleUpdate -Times 0
    }

    It 'blocks a current plugin whose <Field> changed since selection' -ForEach @(
        @{ Field = 'Name'; Value = 'Gerber.Renamed' }
        @{ Field = 'ModulePath'; Value = '/different-installation/Gerber.Second.psd1' }
    ) {
        $script:selection = $script:second.Plugin.PSObject.Copy()
        $script:selection.$Field = $Value
        Mock Get-GerberPluginInventory { $script:selection }
        $script:batch.Items = @($script:second)
        (Complete-GerberUpdateBatch $script:batch).Outcome | Should -Be 'Blocked'
        Should -Invoke Install-PSModuleUpdate -Times 0
    }

    It 'does not use a planned Core target as proof of the actual installed version' {
        Mock Invoke-GerberCoreUpdateInstall {
            $result = Get-TestPluginInstallResult
            $result.InstalledVersion = '0.2.0'
            $result
        }
        Mock Test-GerberUpdateActivation {
            [pscustomobject]@{
                Status  = 'Verified'
                Version = '0.2.0'
            }
        }
        $results = @(Complete-GerberUpdateBatch $script:batch)
        @($results.Outcome) | Should -Be @('Installed', 'Blocked', 'Installed')
    }

    It 'verifies the existing Core before installing plugins without a selected Core update' {
        $script:batch.Items = @($script:second)
        Mock Test-GerberUpdateActivation {
            [pscustomobject]@{
                Status  = 'Unverified'
                Version = ''
            }
        }
        (Complete-GerberUpdateBatch $script:batch).Outcome | Should -Be 'Blocked'
        Should -Invoke Install-PSModuleUpdate -Times 0
    }

    It 'keeps completed results when the Core installation reports an unverifiable version' {
        Mock Invoke-GerberCoreUpdateInstall {
            $result = Get-TestPluginInstallResult
            $result.InstalledVersion = 'not-a-version'
            $result
        }
        $results = @(Complete-GerberUpdateBatch $script:batch)
        @($results.Outcome) | Should -Be @('Installed', 'Blocked', 'Blocked')
        Should -Invoke Install-PSModuleUpdate -Times 0
    }
}
