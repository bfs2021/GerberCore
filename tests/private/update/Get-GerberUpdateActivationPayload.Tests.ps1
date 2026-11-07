BeforeAll {
    . (Join-Path $PSScriptRoot '../../TestHelpers/PluginUpdate.TestSupport.ps1')
    . (Join-Path $backendRoot 'update/Resolve-GerberCoreUpdateRequest.ps1')
    $path = Join-Path $backendRoot 'update/Get-GerberUpdateActivationPayload.ps1'
    if (Test-Path $path) {
        . $path
    }
}

Describe 'Get-GerberUpdateActivationPayload' -Tag 'G4A9' {
    BeforeEach {
        $script:item = Get-TestPluginUpdateItem
        $script:core = Get-TestCoreUpdateState
        $script:result = Get-TestPluginInstallResult
        $script:item.State.Plan | Add-Member -NotePropertyMembers @{
            ModuleGuid          = $script:item.Plugin.Guid
            TargetInstalledPath = Join-Path $TestDrive 'Gerber.Example/2.0.0'
        }
        $script:core.Plan | Add-Member -NotePropertyMembers @{
            InstalledManifestPath = Join-Path $TestDrive 'Gerber/0.2.0/Gerber.psd1'
            TargetInstalledPath   = Join-Path $TestDrive 'Gerber/0.3.0'
        }
        $script:result | Add-Member -NotePropertyMembers @{
            ModuleName    = $script:item.Plugin.Name
            ModuleGuid    = $script:item.Plugin.Guid
            Scope         = 'CurrentUser'
            InstalledPath = $script:item.State.Plan.TargetInstalledPath
        }
        Mock Get-GerberPluginInventory {
            @()
        }
    }

    It 'uses exact public PMU installation references without serializing plans or credentials' {
        $data = Get-GerberUpdateActivationPayload $script:item $script:result $script:core '0.3.0'
        $data.CoreManifest | Should -Be (Join-Path $script:core.Plan.TargetInstalledPath 'Gerber.psd1')
        $data.Target.Path | Should -Be (Join-Path $script:result.InstalledPath 'Gerber.Example.psd1')
        $data.Target.Guid | Should -Be $script:item.Plugin.Guid
        $data.Target.Version | Should -Be '2.0.0'
        ($data | ConvertTo-Json -Depth 8) | Should -Not -Match 'Credential|Disposition|RepositoryUri|TargetInstalledPath'
    }

    It 'retains the original installed Core reference when no Core update succeeded' {
        $data = Get-GerberUpdateActivationPayload $script:item $script:result $script:core '0.2.0'
        $data.CoreManifest | Should -Be $script:core.Plan.InstalledManifestPath
    }

    It 'rejects an unknown or unidentifiable intended Core version' -ForEach @(
        @{ Version = $null; Message = 'The intended Core version is unknown.' }
        @{ Version = '9.0.0'; Message = 'The intended Core installation cannot be identified.' }
    ) {
        {
            Get-GerberUpdateActivationPayload $script:item $script:result $script:core $Version
        } | Should -Throw $Message
    }

    It 'uses the executing Core manifest when discovery produced no plan' {
        $script:core.Plan = $null
        $script:executingCoreRoot = Join-Path $TestDrive 'executing-core'
        Mock Resolve-GerberCoreUpdateRequest {
            [pscustomobject]@{ Module = [pscustomobject]@{ ModuleBase = $script:executingCoreRoot } }
        }
        $data = Get-GerberUpdateActivationPayload $script:item $script:result $script:core '0.2.0'
        $data.CoreManifest | Should -Be (Join-Path $script:executingCoreRoot 'Gerber.psd1')
        $data.CoreVersion | Should -BeExactly '0.2.0'
    }

    It 'rejects an installation that PMU has not verified' {
        $script:result.VerificationStatus = 'Unverified'
        {
            Get-GerberUpdateActivationPayload $script:item $script:result $script:core '0.3.0'
        } | Should -Throw 'The installation was not verified.'
    }

    It 'compares installation paths case-insensitively only on Windows' -ForEach @(
        @{ Windows = $true; Matches = $true }
        @{ Windows = $false; Matches = $false }
    ) {
        $originalPlatform = Get-Variable -Name IsWindows -Scope Global -ValueOnly
        try {
            Set-Variable -Name IsWindows -Scope Global -Value $Windows -Force
            $expected = Join-Path $TestDrive 'MixedCase'
            Test-GerberActivationPath $expected.ToUpperInvariant() $expected | Should -Be $Matches
        } finally {
            Set-Variable -Name IsWindows -Scope Global -Value $originalPlatform -Force
        }
    }

    It 'includes only other eligible plugins with their installed <Prerelease> version' -ForEach @(
        @{ Prerelease = 'preview.2'; Version = '1.4.0-preview.2' }
        @{ Prerelease = ''; Version = '1.4.0' }
    ) {
        $script:otherPlugin = Get-TestPluginUpdateEntry 'Gerber.Other'
        $script:otherPlugin.Guid = '00000000-0000-0000-0000-000000000002'
        $script:disabledPlugin = Get-TestPluginUpdateEntry 'Gerber.Disabled'
        $script:disabledPlugin.Guid = '00000000-0000-0000-0000-000000000003'
        $script:disabledPlugin.IsEnabled = $false
        Mock Get-GerberPluginInventory { @($script:item.Plugin, $script:disabledPlugin, $script:otherPlugin) }
        $script:contextManifest = @{ ModuleVersion = '1.4.0'; PrivateData = @{ PSData = @{ Prerelease = $Prerelease } } }
        Mock Import-PowerShellDataFile { $script:contextManifest }
        $data = Get-GerberUpdateActivationPayload $script:item $script:result $script:core '0.3.0'
        $data.OtherPlugins.Count | Should -Be 1
        $data.OtherPlugins[0].Name | Should -BeExactly 'Gerber.Other'
        $data.OtherPlugins[0].Guid | Should -Be $script:otherPlugin.Guid
        $data.OtherPlugins[0].Path | Should -Be $script:otherPlugin.ModulePath
        $data.OtherPlugins[0].Version | Should -BeExactly $Version
        Should -Invoke Import-PowerShellDataFile -Times 1 -Exactly -ParameterFilter {
            $LiteralPath -eq $script:otherPlugin.ModulePath -and $ErrorAction -eq 'Stop'
        }
    }

    It 'rejects a result with a different identity, scope, target or installation path' -ForEach @(
        @{
            Field = 'ModuleGuid'
            Value = '00000000-0000-0000-0000-000000000001'
        },
        @{
            Field = 'Scope'
            Value = 'AllUsers'
        },
        @{
            Field = 'InstalledVersion'
            Value = '3.0.0'
        },
        @{
            Field = 'InstalledPath'
            Value = '/different-installation'
        }
    ) {
        $script:result.$Field = $Value
        {
            Get-GerberUpdateActivationPayload $script:item $script:result $script:core '0.3.0'
        } | Should -Throw '*does not match the selected update*'
    }
}
