BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function New-GerberManifestTestModule {
        [CmdletBinding(SupportsShouldProcess)]
        param(
            [Parameter(Mandatory)]
            [string]$ModuleName,

            [Parameter(Mandatory)]
            [string]$Guid
        )

        $modulePath = Join-Path $script:manifestRoot $ModuleName
        if (-not $PSCmdlet.ShouldProcess($modulePath, 'Create plugin manifest test module')) {
            return
        }
        $null = New-Item -ItemType Directory -Path $modulePath -Force
        Set-Content -LiteralPath (Join-Path $modulePath "$ModuleName.psd1") -Value @"
@{
    RootModule = '$ModuleName.psm1'
    ModuleVersion = '1.0.0'
    GUID = '$Guid'
    Description = 'Fixture description'
    Author = 'Fixture Publisher'
    PrivateData = @{
        Gerber = @{
            Plugin = `$true
            ApiVersion = '1'
            MinimumGerberVersion = '0.1.0-preview'
        }
    }
}
"@
        Set-Content -LiteralPath (Join-Path $modulePath "$ModuleName.psm1") -Value "throw 'Plugin code must not execute during discovery.'"
    }
}

Describe 'Get-GerberPluginManifestMetadataList' -Tag 'PluginManifestMetadata' {
    BeforeEach {
        $script:manifestRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path $script:manifestRoot -Force
    }

    It 'reads and normalizes a valid manifest GUID without executing plugin code' {
        New-GerberManifestTestModule `
            -ModuleName 'Gerber.ValidGuidPlugin' `
            -Guid '977537C5-B7F5-4F2F-9DD4-5EC0E28D2618'

        $result = @(Get-GerberPluginManifestMetadataList -PluginModulePathList @($script:manifestRoot))

        $result.Count | Should -Be 1
        $result[0].Guid | Should -Be '977537c5-b7f5-4f2f-9dd4-5ec0e28d2618'
        $result[0].Description | Should -Be 'Fixture description'
        $result[0].Author | Should -Be 'Fixture Publisher'
        Get-Module -Name 'Gerber.ValidGuidPlugin' | Should -BeNullOrEmpty
    }

    It 'continues discovering accessible plugins when a module search root denies access' {
        $script:deniedRoot = Join-Path $TestDrive 'denied-root'
        New-GerberManifestTestModule -ModuleName 'Gerber.AccessiblePlugin' -Guid '977537c5-b7f5-4f2f-9dd4-5ec0e28d2618'
        Mock Test-Path -ParameterFilter {
            $LiteralPath -eq $script:deniedRoot
        } -MockWith {
            param($ErrorAction = 'Stop')
            Write-Error -Exception ([System.UnauthorizedAccessException]::new('Permission denied')) -Category PermissionDenied -ErrorAction $ErrorAction
        }
        $result = @(Get-GerberPluginManifestMetadataList -PluginModulePathList @($script:deniedRoot, $script:manifestRoot) -ErrorAction Stop)
        $result.Count | Should -Be 1
        $result[0].Guid | Should -Be '977537c5-b7f5-4f2f-9dd4-5ec0e28d2618'
    }

    It 'rejects an invalid manifest GUID with a controlled diagnostic' {
        New-GerberManifestTestModule -ModuleName 'Gerber.InvalidGuidPlugin' -Guid 'not-a-guid'

        $warningList = @()
        $result = @(
            Get-GerberPluginManifestMetadataList `
                -PluginModulePathList @($script:manifestRoot) `
                -WarningVariable warningList
        )

        $result | Should -BeNullOrEmpty
        @($warningList) -join ' ' | Should -Match "Gerber.InvalidGuidPlugin.*invalid manifest GUID"
        Get-Module -Name 'Gerber.InvalidGuidPlugin' | Should -BeNullOrEmpty
    }

    It 'rejects an invalid Gerber manifest without preventing discovery from completing' {
        $modulePath = Join-Path $script:manifestRoot 'Gerber.InvalidManifestPlugin'
        $null = New-Item -ItemType Directory -Path $modulePath -Force
        Set-Content -LiteralPath (Join-Path $modulePath 'Gerber.InvalidManifestPlugin.psd1') -Value '@{'

        $warningList = @()
        $result = @(
            Get-GerberPluginManifestMetadataList `
                -PluginModulePathList @($script:manifestRoot) `
                -WarningVariable warningList
        )

        $result | Should -BeNullOrEmpty
        @($warningList) -join ' ' | Should -Match 'could not inspect manifest metadata safely'
    }
}
