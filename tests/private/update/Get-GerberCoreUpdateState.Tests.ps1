BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    foreach ($name in @('Get-GerberCoreUpdateState', 'Resolve-GerberUpdateDisposition',
        'Resolve-GerberCoreUpdateRequest', 'Get-GerberUpdateFailureMessage')) {
        . "$root/src/private/update/$name.ps1"
    }
    . "$root/src/private/credentials/Get-GerberCredential.ps1"
    foreach ($name in @('Get-GerberUserConfiguration', 'Resolve-GerberCoreUpdatePolicy', 'Resolve-GerberUserConfigPath',
        'Test-GerberCoreUpdateConfiguration', 'Test-GerberUserConfiguration', 'Get-GerberCoreUpdateChannelLabel')) {
        . "$root/src/private/config/$name.ps1"
    }
    . "$root/src/private/cli/Initialize-GerberCommandRegistry.ps1"
    Import-Module PSModuleUpdate
    $script:manifest = Join-Path $TestDrive 'Gerber.psd1'
    New-ModuleManifest -Path $script:manifest -ModuleVersion '0.1.0' -Prerelease 'preview'
}

Describe 'Get-GerberCoreUpdateState' -Tag 'G4A7' {
    BeforeEach {
        $script:request = [pscustomobject]@{
            Module = Test-ModuleManifest $script:manifest
            Repository = 'HostileFeed'; Policy = @{ Channel = 'IncludePrerelease'; Scope = 'AllUsers' }
            CredentialSetting = @{ identifier = 'secret'; username = 'user' }
        }
        $script:plan = [pscustomobject]@{
            InstalledVersion = '0.1.0-preview'; TargetVersion = '0.1.0'; Disposition = 'UpdateAvailable'
        }
        Mock Resolve-GerberCoreUpdateRequest { $script:request }
        Mock Get-Command { [pscustomobject]@{ Module = $script:request.Module } } -ParameterFilter { $Name -eq 'Invoke-Gerber' }
        Mock Get-PSModuleUpdate { $script:plan }
        Mock Get-GerberUserConfiguration { @{ schemaVersion = 1 } }
        Mock Install-PSModuleUpdate { throw 'Discovery cannot install' }
        Mock Get-GerberCredential { throw 'Core cannot read credentials' }
    }

    Context 'fixed PMU discovery boundary' {
        It 'ignores hostile request repository policy and credentials and retains the original live plan' {
            $state = Get-GerberCoreUpdateState -Request $script:request
            $state.Repository | Should -BeExactly 'PSGallery'
            $state.Status | Should -Be 'Available'
            [object]::ReferenceEquals($state.Plan, $script:plan) | Should -BeTrue
            Should -Invoke Get-PSModuleUpdate -Times 1 -ParameterFilter {
                $Repository -ceq 'PSGallery' -and $Policy.Channel -ceq 'Stable' -and
                $Policy.Scope -ceq 'CurrentUser' -and $Policy.ExpectedRepositoryUri -is [uri] -and
                $Policy.ExpectedRepositoryUri.AbsoluteUri -ceq 'https://www.powershellgallery.com/api/v2' -and $null -eq $Credential
            }
            Should -Invoke Get-GerberCredential -Times 0
            Should -Invoke Install-PSModuleUpdate -Times 0
        }

        It 'preserves installed identity and never falls back after <id>' -ForEach @(
            @{ id = 'PMU.RepositoryUnavailable'; expected = 'Unavailable' }
            @{ id = 'PMU.RepositoryChanged'; expected = 'Unavailable' }
            @{ id = 'PMU.DiscoveryFailed'; expected = 'Unavailable' }
            @{ id = 'PMU.PackageNotFound'; expected = 'NoMatchingPackage' }
        ) {
            Mock Get-PSModuleUpdate { Write-Error -Message 'raw-secret' -ErrorId $id -ErrorAction Stop }
            $state = Get-GerberCoreUpdateState
            $state.Installed | Should -BeExactly '0.1.0-preview'
            $state.Available | Should -BeExactly '-'
            $state.Repository | Should -BeExactly 'PSGallery'
            $state.Status | Should -Be $expected
            $state.Plan | Should -BeNullOrEmpty
            $state.Message | Should -Not -Match 'raw-secret|/secrets|configuration'
            Should -Invoke Get-PSModuleUpdate -Times 1 -ParameterFilter { $Repository -ceq 'PSGallery' }
            Should -Invoke Get-PSModuleUpdate -Times 1
            Should -Invoke Get-GerberCredential -Times 0
        }

        It 'does not describe no matching package as up to date' {
            Mock Get-PSModuleUpdate { Write-Error -Message 'none' -ErrorId 'PMU.PackageNotFound' -ErrorAction Stop }
            (Get-GerberCoreUpdateState).Message | Should -Match 'No eligible.*PSGallery'
        }

        It 'honors PMU dispositions rather than comparing versions itself' -ForEach @(
            @{ disposition = 'UpToDate'; expected = 'UpToDate' }
            @{ disposition = 'AlreadyInstalledRestartRequired'; expected = 'RestartRequired' }
        ) {
            $script:plan.Disposition = $disposition
            (Get-GerberCoreUpdateState).Status | Should -Be $expected
        }

        It 'uses the configured prerelease channel and retains it independently of the live plan' {
            Mock Get-GerberUserConfiguration { @{ schemaVersion = 1; coreUpdates = @{ channel = 'IncludePrerelease' } } }
            $script:plan.Disposition = 'UpToDate'
            $state = Get-GerberCoreUpdateState
            $state.Channel | Should -BeExactly 'IncludePrerelease'
            $state.Message | Should -Match 'Include prereleases'
            $state.Message | Should -Not -Match 'stable update policy'
            [object]::ReferenceEquals($state.Plan, $script:plan) | Should -BeTrue
            Should -Invoke Get-PSModuleUpdate -Times 1 -ParameterFilter {
                $Repository -ceq 'PSGallery' -and $Policy.Channel -ceq 'IncludePrerelease' -and $Policy.Scope -ceq 'CurrentUser'
            }
        }

        It 'reports unavailable rather than unconfigured when executing identity cannot be resolved' {
            Mock Resolve-GerberCoreUpdateRequest { throw 'raw identity error' }
            $state = Get-GerberCoreUpdateState
            $state.Status | Should -Be 'Unavailable'
            $state.Installed | Should -BeExactly '0.1.0-preview'
            Should -Invoke Get-PSModuleUpdate -Times 0
        }

        It 'preserves stable identity when no prerelease metadata exists' {
            $script:request.Module.PrivateData = $null
            Mock Get-PSModuleUpdate { throw 'offline' }
            (Get-GerberCoreUpdateState -Request $script:request).Installed | Should -BeExactly '0.1.0'
        }

        It 'fails closed on unsupported PMU dispositions without retaining a plan' {
            $script:plan.Disposition = 'Unknown'
            $state = Get-GerberCoreUpdateState
            $state.Status | Should -Be 'Unavailable'
            $state.Plan | Should -BeNullOrEmpty
        }
    }
}
