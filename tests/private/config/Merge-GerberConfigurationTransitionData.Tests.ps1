BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Merge-GerberConfigurationTransitionData' -Tag 'PluginJson' {
    It 'merges nested unknown settings without mutating either original' {
        $existing = @{ unknown = @{ left = 1 } }
        $incoming = @{ unknown = @{ right = 2 } }
        $merged = Merge-GerberConfigurationTransitionData -Existing $existing -Incoming $incoming -Path 'Core.json'
        $merged.unknown.left | Should -Be 1
        $merged.unknown.right | Should -Be 2
        $existing.unknown.ContainsKey('right') | Should -BeFalse
        $incoming.unknown.ContainsKey('left') | Should -BeFalse
    }

    It 'does not treat an existing null setting as permission to overwrite it' {
        { Merge-GerberConfigurationTransitionData -Existing @{ setting = $null } -Incoming @{ setting = 1 } -Path 'Core.json' } |
            Should -Throw '*conflict*setting*'
    }

    It 'preserves empty and singleton JSON arrays when merging existing and new fields' {
        $existing = @{ approved = @('example-guid') }
        $incoming = @{ approved = @('example-guid'); empty = @(); single = @(42) }
        $merged = Merge-GerberConfigurationTransitionData -Existing $existing -Incoming $incoming -Path 'GerberCore.json'
        (ConvertTo-Json -InputObject $merged.approved -Compress) | Should -Be '["example-guid"]'
        (ConvertTo-Json -InputObject $merged.empty -Compress) | Should -Be '[]'
        (ConvertTo-Json -InputObject $merged.single -Compress) | Should -Be '[42]'
    }
}
