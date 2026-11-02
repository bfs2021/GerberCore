BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberModuleSemanticVersion' -Tag 'PluginCreate' {
    It 'fails with a clear error when the executing Gerber module cannot be resolved' {
        { Get-GerberModuleSemanticVersion } | Should -Throw '*Unable to resolve the executing Gerber module version*'
    }

    It 'preserves prerelease metadata from the executing module private data' {
        $modulePath = Join-Path $TestDrive 'Gerber'
        $null = New-Item -ItemType Directory -Path $modulePath
        Set-Content -LiteralPath (Join-Path $modulePath 'Gerber.psm1') -Value ''
        $manifestPath = Join-Path $modulePath 'Gerber.psd1'
        @'
@{
    RootModule = 'Gerber.psm1'
    ModuleVersion = '0.2.1'
    GUID = '0d9f3b43-6d2b-4a4b-9d01-6f3f0f7c2a11'
    Author = 'Gerber tests'
    FunctionsToExport = @()
    PrivateData = @{
        PSData = @{
            Prerelease = 'preview02'
        }
    }
}
'@ | Set-Content -LiteralPath $manifestPath
        $module = Import-Module $manifestPath -PassThru -Force
        try {
            Get-GerberModuleSemanticVersion -Module $module | Should -Be '0.2.1-preview02'
        } finally {
            Remove-Module Gerber -Force -ErrorAction SilentlyContinue
        }
    }
}
