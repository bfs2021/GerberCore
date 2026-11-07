BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/private/cli/Test-GerberCommandContainer.ps1')
}

Describe 'Test-GerberCommandContainer' -Tag 'ActiveCommandTree' {
    It 'recognizes only explicitly marked menu-only definitions' -ForEach @(
        @{ Definition = [pscustomobject]@{ IsContainer = $true }; Expected = $true }
        @{ Definition = @{ IsContainer = $true }; Expected = $true }
        @{ Definition = [pscustomobject]@{ Handler = {} }; Expected = $false }
        @{ Definition = @{ IsContainer = $false }; Expected = $false }
    ) {
        Test-GerberCommandContainer -Definition $Definition | Should -Be $Expected
    }
}
