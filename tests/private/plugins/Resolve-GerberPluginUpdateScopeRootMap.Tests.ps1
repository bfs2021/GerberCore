BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . (Join-Path $root 'src/private/plugins/Resolve-GerberPluginUpdateScopeRootMap.ps1')
}

Describe 'Resolve-GerberPluginUpdateScopeRootMap' -Tag 'G4A9' {
    It 'provides distinct absolute roots without changing process environment' {
        $before = [Environment]::GetEnvironmentVariable('XDG_DATA_HOME')
        $roots = Resolve-GerberPluginUpdateScopeRootMap
        [IO.Path]::IsPathRooted($roots.CurrentUser) | Should -BeTrue
        [IO.Path]::IsPathRooted($roots.AllUsers) | Should -BeTrue
        $roots.CurrentUser | Should -Not -Be $roots.AllUsers
        [Environment]::GetEnvironmentVariable('XDG_DATA_HOME') | Should -Be $before
    }

    It 'maps Windows scopes to the platform document and program folders' {
        $originalPlatform = Get-Variable -Name IsWindows -Scope Global -ValueOnly
        try {
            Set-Variable -Name IsWindows -Scope Global -Value $true -Force
            Mock Get-GerberSpecialFolderPath { Join-Path $TestDrive $Name }
            $roots = Resolve-GerberPluginUpdateScopeRootMap
            $roots.CurrentUser | Should -Be (Join-Path (Join-Path $TestDrive 'MyDocuments') 'PowerShell/Modules')
            $roots.AllUsers | Should -Be (Join-Path (Join-Path $TestDrive 'ProgramFiles') 'PowerShell/Modules')
        } finally {
            Set-Variable -Name IsWindows -Scope Global -Value $originalPlatform -Force
        }
    }

    It 'rejects relative XDG data roots rather than resolving them against the working directory' {
        $originalDataRoot = [Environment]::GetEnvironmentVariable('XDG_DATA_HOME')
        try {
            [Environment]::SetEnvironmentVariable('XDG_DATA_HOME', 'relative-data')
            { Resolve-GerberUnixUserModuleRoot } | Should -Throw 'The user module data directory must be absolute.'
        } finally {
            [Environment]::SetEnvironmentVariable('XDG_DATA_HOME', $originalDataRoot)
        }
    }
}
