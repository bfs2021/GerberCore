BeforeAll {
    function Resolve-GerberPluginUpdateScopeRootMap {
        param()
    }
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $path = Join-Path $root 'src/private/plugins/Resolve-GerberPluginUpdateScope.ps1'
    if (Test-Path -LiteralPath $path) {
        . $path
    }
}

Describe 'Resolve-GerberPluginUpdateScope' -Tag 'G4A9' {
    BeforeEach {
        $script:roots = @{
            CurrentUser = Join-Path $TestDrive 'UserModules'
            AllUsers    = Join-Path $TestDrive 'SharedModules'
        }
        Mock Resolve-GerberPluginUpdateScopeRootMap {
            $script:roots
        }
        $script:module = [pscustomobject]@{
            Name       = 'Gerber.Example'
            Version    = [version]'1.0.0'
            ModuleBase = ''
        }
    }

    It 'preserves the existing numeric installation scope' -ForEach @('CurrentUser', 'AllUsers') {
        $scope = $_
        $script:module.ModuleBase = Join-Path (Join-Path $script:roots[$scope] 'Gerber.Example') '1.0.0'
        Resolve-GerberPluginUpdateScope $script:module | Should -Be $scope
    }

    It 'rejects unknown roots and flat layouts instead of installing another copy' -ForEach @('unknown', 'flat') {
        if ($_ -eq 'unknown') {
            $script:module.ModuleBase = Join-Path $TestDrive 'unknown/Gerber.Example/1.0.0'
        }
        else {
            $script:module.ModuleBase = Join-Path $script:roots.CurrentUser 'Gerber.Example'
        }
        {
            Resolve-GerberPluginUpdateScope $script:module
        } | Should -Throw
    }
}
