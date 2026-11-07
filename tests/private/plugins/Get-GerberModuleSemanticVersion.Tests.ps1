BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    $script:NewTestGerberModule = {
        param([string]$ModuleVersion, [string]$Prerelease)

        $modulePath = Join-Path $TestDrive ('Gerber-' + [System.IO.Path]::GetRandomFileName())
        $null = New-Item -ItemType Directory -Path $modulePath
        Set-Content -LiteralPath (Join-Path $modulePath 'Gerber.psm1') -Value ''
        $privateData = if ($Prerelease) {
            "@{ PSData = @{ Prerelease = '$Prerelease' } }"
        } else {
            '@{ PSData = @{ } }'
        }
        $manifest = @"
@{
    RootModule = 'Gerber.psm1'
    ModuleVersion = '$ModuleVersion'
    GUID = '0d9f3b43-6d2b-4a4b-9d01-6f3f0f7c2a11'
    Author = 'Gerber tests'
    FunctionsToExport = @()
    PrivateData = $privateData
}
"@
        Set-Content -LiteralPath (Join-Path $modulePath 'Gerber.psd1') -Value $manifest
        Import-Module (Join-Path $modulePath 'Gerber.psd1') -PassThru -Force
    }
}

Describe 'Get-GerberModuleSemanticVersion' -Tag 'PluginCreate' {
    It 'fails with a clear error when the executing Gerber module cannot be resolved' {
        { Get-GerberModuleSemanticVersion } | Should -Throw '*Unable to resolve the executing Gerber module version*'
    }

    It 'fails with the same error when the given module is not Gerber' {
        $module = New-Module -Name 'NotGerber' -ScriptBlock { }
        try {
            { Get-GerberModuleSemanticVersion -Module $module } | Should -Throw '*Unable to resolve the executing Gerber module version*'
        } finally {
            Remove-Module NotGerber -Force -ErrorAction SilentlyContinue
        }
    }

    It 'preserves prerelease metadata from the executing module private data' {
        $previous = @(Get-Module Gerber)
        $module = & $script:NewTestGerberModule '0.2.1' 'preview02'
        try {
            Get-GerberModuleSemanticVersion -Module $module | Should -Be '0.2.1-preview02'
        } finally {
            Remove-Module Gerber -Force -ErrorAction SilentlyContinue
            if ($previous.Count -gt 0) {
                Import-Module $previous[0].Path -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'formats a four-part module version as SemVer' {
        $previous = @(Get-Module Gerber)
        $module = & $script:NewTestGerberModule '0.2.1.7' 'preview02'
        try {
            Get-GerberModuleSemanticVersion -Module $module | Should -Be '0.2.1-preview02'
        } finally {
            Remove-Module Gerber -Force -ErrorAction SilentlyContinue
            if ($previous.Count -gt 0) {
                Import-Module $previous[0].Path -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'omits the prerelease suffix when the module has none' {
        $previous = @(Get-Module Gerber)
        $module = & $script:NewTestGerberModule '0.2.1' ''
        try {
            Get-GerberModuleSemanticVersion -Module $module | Should -Be '0.2.1'
        } finally {
            Remove-Module Gerber -Force -ErrorAction SilentlyContinue
            if ($previous.Count -gt 0) {
                Import-Module $previous[0].Path -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
