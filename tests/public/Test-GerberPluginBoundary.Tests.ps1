# Real Core ownership and capability closures span many files. These scenarios
# intentionally exercise that contract through the public command.
BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Test-GerberPluginBoundary' -Tag 'PluginBoundary' {
    BeforeEach {
        $projectPath = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path "$projectPath/src/private" -Force
    }

    It 'accepts public API, external commands, comments and ordinary strings' {
        Set-Content "$projectPath/src/private/Allowed.ps1" @'
param($Gerber)
& $Gerber.UI.ShowTextBlock 'Hello' 'World'
Get-ChildItem
Invoke-Gerber
# Get-GerberCommandRegistry
'Get-GerberCommandRegistry'
'Import-Module Gerber/private/internal.psm1'
'@
        $result = Test-GerberPluginBoundary -Path $projectPath
        $result.IsValid | Should -BeTrue
        $result.Diagnostics.Count | Should -Be 0
        $result.PublicApi.UI | Should -Contain 'ShowTextBlock'
        $result.PublicApi.Keys | Should -Not -Contain 'Ado'
        $result.PublicApi.Configuration | Should -Contain 'Read'
    }

    It 'detects <Label> without executing source' -ForEach @(
        @{ Label = 'direct call'; Source = 'Get-GerberCommandRegistry'; Dependency = 'Get-GerberCommandRegistry'; Reason = 'PrivateCoreCommand' }
        @{ Label = 'quoted call'; Source = "& 'Get-GerberCommandRegistry'"; Dependency = 'Get-GerberCommandRegistry'; Reason = 'PrivateCoreCommand' }
        @{ Label = 'constant variable call'; Source = '$command = ''Get-GerberCommandRegistry''; & $command'; Dependency = 'Get-GerberCommandRegistry'; Reason = 'PrivateCoreCommand' }
        @{ Label = 'module-qualified call'; Source = 'Gerber\Get-GerberCommandRegistry'; Dependency = 'Gerber\Get-GerberCommandRegistry'; Reason = 'PrivateCoreCommand' }
        @{ Label = 'private lookup'; Source = 'Get-Command Get-GerberCommandRegistry'; Dependency = 'Get-GerberCommandRegistry'; Reason = 'PrivateCoreCommand' }
        @{ Label = 'literal expression'; Source = "Invoke-Expression 'Get-GerberCommandRegistry'"; Dependency = 'Get-GerberCommandRegistry'; Reason = 'PrivateCoreCommand' }
        @{ Label = 'literal expression with arguments'; Source = "Invoke-Expression 'Get-GerberCommandRegistry -Example'"; Dependency = 'Get-GerberCommandRegistry'; Reason = 'PrivateCoreCommand' }
        @{ Label = 'literal concatenation'; Source = "& ('Get-Gerber' + 'CommandRegistry')"; Dependency = 'Get-GerberCommandRegistry'; Reason = 'PrivateCoreCommand' }
        @{ Label = 'qualified named lookup'; Source = 'Microsoft.PowerShell.Core\Get-Command -Name Gerber\Get-GerberCommandRegistry'; Dependency = 'Gerber\Get-GerberCommandRegistry'; Reason = 'PrivateCoreCommand' }
        @{ Label = 'private dot source'; Source = ". '/checkout/Gerber/src/private/cli/Get-GerberCommandRegistry.ps1'"; Dependency = '/checkout/Gerber/src/private/cli/Get-GerberCommandRegistry.ps1'; Reason = 'CoreImplementationImport' }
        @{ Label = 'private import'; Source = "Import-Module '/checkout/Gerber/src/private/cli/Get-GerberCommandRegistry.ps1'"; Dependency = '/checkout/Gerber/src/private/cli/Get-GerberCommandRegistry.ps1'; Reason = 'CoreImplementationImport' }
        @{ Label = 'internal module'; Source = "Import-Module '/modules/Gerber/private/Implementation.psm1'"; Dependency = '/modules/Gerber/private/Implementation.psm1'; Reason = 'CoreImplementationImport' }
        @{ Label = 'module root'; Source = "using module '/modules/Gerber/Gerber.psm1'"; Dependency = '/modules/Gerber/Gerber.psm1'; Reason = 'CoreImplementationImport' }
        @{ Label = 'Core module scope'; Source = '& (Get-Module Gerber) { $script:State }'; Dependency = 'Gerber'; Reason = 'CoreModuleScope' }
        @{ Label = 'Core session state'; Source = '(Get-Module Gerber).SessionState.PSVariable.Get("State")'; Dependency = 'Gerber'; Reason = 'CoreModuleScope' }
    ) {
        Set-Content "$projectPath/src/private/Invalid.ps1" $Source
        $result = Test-GerberPluginBoundary -Path $projectPath
        $result.IsValid | Should -BeFalse
        $diagnostic = @($result.Diagnostics | Where-Object Reason -EQ $Reason)[0]
        $diagnostic.File | Should -Be 'src/private/Invalid.ps1'
        $diagnostic.Line | Should -Be 1
        $diagnostic.Dependency | Should -Be $Dependency
        $diagnostic.Resolution | Should -Match 'public|capability'
    }

    It 'allows plugin-owned same-name functions across authored files and local private imports' {
        Set-Content "$projectPath/src/private/Own.ps1" 'function Get-GerberCommandRegistry { "plugin owned" }'
        Set-Content "$projectPath/src/private/Caller.ps1" @'
Get-GerberCommandRegistry
. "$PSScriptRoot/Own.ps1"
Import-Module Gerber
Import-Module Gerber.OtherPlugin
Microsoft.PowerShell.Management\Get-ChildItem
'@
        (Test-GerberPluginBoundary $projectPath).IsValid | Should -BeTrue
    }

    It 'does not let a local same-name function hide a qualified Core dependency' {
        Set-Content "$projectPath/src/private/Own.ps1" 'function Get-GerberCommandRegistry {}; Gerber\Get-GerberCommandRegistry'
        (Test-GerberPluginBoundary $projectPath).Diagnostics.Dependency | Should -Be 'Gerber\Get-GerberCommandRegistry'
    }

    It 'orders exact diagnostics deterministically across recursive authored files' {
        $null = New-Item -ItemType Directory "$projectPath/src/public/nested" -Force
        Set-Content "$projectPath/src/public/nested/Z.psm1" "`nGet-GerberCommandRegistry"
        Set-Content "$projectPath/src/private/A.ps1" 'Get-GerberCommandRegistry'
        $first = Test-GerberPluginBoundary $projectPath
        $second = Test-GerberPluginBoundary $projectPath
        $first.FileCount | Should -Be 2
        $first.Diagnostics.File | Should -Be @('src/private/A.ps1', 'src/public/nested/Z.psm1')
        $first.Diagnostics.Line | Should -Be @(1, 2)
        ($first | ConvertTo-Json -Depth 8) | Should -Be ($second | ConvertTo-Json -Depth 8)
        $first.Diagnostics[0].Resolution | Should -Be 'No public API v1 equivalent is declared for Get-GerberCommandRegistry. Request a public capability instead of importing Core internals.'
    }

    It 'rejects parse errors but does not scan generated artifacts or test strings' {
        $null = New-Item -ItemType Directory "$projectPath/dist", "$projectPath/tests" -Force
        Set-Content "$projectPath/dist/Generated.ps1" 'Get-GerberCommandRegistry'
        Set-Content "$projectPath/tests/Fixture.ps1" 'Get-GerberCommandRegistry'
        Set-Content "$projectPath/src/private/Invalid.ps1" 'function Broken {'
        $result = Test-GerberPluginBoundary $projectPath
        $result.FileCount | Should -Be 1
        $result.Diagnostics.Reason | Should -Be 'ParseError'
    }

    It 'reports missing authored source rather than declaring an empty project valid' {
        Remove-Item "$projectPath/src" -Recurse -Force
        { Test-GerberPluginBoundary $projectPath } | Should -Throw '*src*'
    }

    It 'recognizes lexical local definitions without hiding calls outside their scope' {
        Set-Content "$projectPath/src/private/Local.ps1" @'
function Invoke-Own {
    function Get-GerberCommandRegistry { 'local' }
    Get-GerberCommandRegistry
}
Get-GerberCommandRegistry
'@
        $result = Test-GerberPluginBoundary $projectPath
        $result.Diagnostics.Count | Should -Be 1
        $result.Diagnostics[0].Line | Should -Be 5
    }

    It 'does not infer computed, reassigned or conditional variable targets' {
        Set-Content "$projectPath/src/private/Dynamic.ps1" @'
param($InputName)
$target = 'Get-GerberCommandRegistry'
$target = $InputName
& $target
if ($InputName) { $conditional = 'Get-GerberCommandRegistry' }
& $conditional
& ('Get-' + $InputName)
'@
        (Test-GerberPluginBoundary $projectPath).IsValid | Should -BeTrue
    }

    It 'finds a real public equivalent from the implemented context declaration' {
        Set-Content "$projectPath/src/private/Ui.ps1" "Show-GerberPluginApiTextBlock -Title 'Hello' -Text 'World'"
        $result = Test-GerberPluginBoundary $projectPath
        $result.Diagnostics[0].Resolution | Should -Be 'Use the supplied public API v1 operation $Gerber.UI.ShowTextBlock instead.'
    }

    It 'validates all authored src directories but never imports them or invokes handlers' {
        Set-Content "$projectPath/src/Entry.ps1" "throw 'source executed'; Get-GerberCommandRegistry"
        $result = Test-GerberPluginBoundary $projectPath
        $result.IsValid | Should -BeFalse
        $result.Diagnostics.File | Should -Be 'src/Entry.ps1'
    }

    It 'checks authored scripts and root entrypoints without scanning test fixtures' {
        $null = New-Item -ItemType Directory "$projectPath/scripts" -Force
        Set-Content "$projectPath/scripts/Task.ps1" 'Get-GerberCommandRegistry'
        Set-Content "$projectPath/Start.ps1" 'Get-GerberCommandRegistry'
        $result = Test-GerberPluginBoundary $projectPath
        $result.Diagnostics.File | Should -Be @('scripts/Task.ps1', 'Start.ps1')
    }

    It 'allows an explicitly external module lookup with a coincidental Core-private name' {
        Set-Content "$projectPath/src/private/Lookup.ps1" 'Get-Command -Module OtherModule -Name Get-GerberCommandRegistry'
        (Test-GerberPluginBoundary $projectPath).IsValid | Should -BeTrue
    }

    It 'allows colon-form external module lookup and leaves runtime argument validation to PowerShell' {
        Set-Content "$projectPath/src/private/Lookup.ps1" @'
Get-Command -Module:OtherModule -Name Get-GerberCommandRegistry
Get-Command -Module
'@
        (Test-GerberPluginBoundary $projectPath).IsValid | Should -BeTrue
    }

    It 'does not let plugin-owned names hide an explicitly Core-module lookup' {
        Set-Content "$projectPath/src/private/Lookup.ps1" @'
function Get-GerberCommandRegistry {}
Get-Command -Module Gerber -Name Get-GerberCommandRegistry
'@
        $result = Test-GerberPluginBoundary $projectPath
        $result.IsValid | Should -BeFalse
        $result.Diagnostics[0].Dependency | Should -Be 'Gerber\Get-GerberCommandRegistry'
    }
}
