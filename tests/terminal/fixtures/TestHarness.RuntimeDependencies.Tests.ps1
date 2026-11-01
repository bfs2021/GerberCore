BeforeAll {
    . "$PSScriptRoot/TestHarness.RuntimeDependencies.ps1"
}

Describe 'Import-GerberTerminalRuntimeDependency' -Tag 'G4A7' {
    Context 'read-only dependency loading before fixture isolation' {
        It 'temporarily uses supplied runtime paths and restores fixture isolation after <Outcome>' -TestCases @(
            @{ Outcome = 'success'; FailImport = $false }
            @{ Outcome = 'failure'; FailImport = $true }
        ) {
            param($FailImport)
            $originalPath = $env:PSModulePath
            $originalRuntimePath = $env:GERBER_TERMINAL_RUNTIME_MODULE_PATH
            $env:PSModulePath = "$TestDrive/fixtures"
            $env:GERBER_TERMINAL_RUNTIME_MODULE_PATH = "$TestDrive/dependencies"
            Mock Import-PowerShellDataFile { @{ RequiredModules = @('RequiredFixture') } }
            Mock Import-Module {
                if ($env:PSModulePath -ne "$TestDrive/dependencies") { throw 'Wrong dependency path' }
                if ($FailImport) { throw 'Expected dependency failure' }
            }
            try {
                if ($FailImport) {
                    { Import-GerberTerminalRuntimeDependency -GerberRoot $TestDrive } | Should -Throw '*Expected dependency failure*'
                } else {
                    Import-GerberTerminalRuntimeDependency -GerberRoot $TestDrive
                }
                $env:PSModulePath | Should -Be "$TestDrive/fixtures"
                Should -Invoke Import-Module -Times 1
            } finally {
                $env:PSModulePath = $originalPath
                $env:GERBER_TERMINAL_RUNTIME_MODULE_PATH = $originalRuntimePath
            }
        }

        It 'imports exactly the built manifest requirements without building or changing modules' {
            Mock Import-PowerShellDataFile {
                @{ RequiredModules = @(
                    @{ ModuleName = 'NovaModuleTools'; ModuleVersion = '3.4.2' }
                    @{ ModuleName = 'PSModuleUpdate'; ModuleVersion = '0.1.1' }
                ) }
            }
            Mock Import-Module {}
            Import-GerberTerminalRuntimeDependency -GerberRoot $TestDrive
            Should -Invoke Import-Module -Times 1 -ParameterFilter { $FullyQualifiedName[0].Name -eq 'NovaModuleTools' }
            Should -Invoke Import-Module -Times 1 -ParameterFilter { $FullyQualifiedName[0].Name -eq 'PSModuleUpdate' }
        }
    }
}
