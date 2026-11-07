BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    . (Join-Path $root 'src/private/cli/Format-GerberUpdateItemListOverview.ps1')
    . (Join-Path $root 'src/private/update/Format-GerberCoreUpdateOverview.ps1')
    . (Join-Path $root 'src/private/config/Get-GerberCoreUpdateChannelLabel.ps1')
}

Describe 'Format-GerberUpdateItemListOverview' -Tag 'G4A9UI' {
    BeforeEach {
        $script:core = [pscustomobject]@{
            Kind = 'Core'
            State = [pscustomobject]@{
                Name = 'Gerber'
                Installed = '0.2.1-preview02'
                Available = '0.2.1-preview01'
                Repository = 'PSGallery'
                Status = 'UpToDate'
                Message = ''
                Channel = 'IncludePrerelease'
            }
        }
        $script:plugin = [pscustomobject]@{
            Kind = 'Plugin'
            State = [pscustomobject]@{
                Name = 'Gerber.AT'
                Installed = '0.1.0'
                Available = '-'
                Repository = '-'
                Status = 'Unavailable'
                Message = 'Check the declared plugin repository and installation, then retry /update list.'
            }
        }
    }

    It 'matches the existing Core-only table and shared channel for a single Core row' {
        Format-GerberUpdateItemListOverview -ItemList @($script:core) |
            Should -BeExactly (Format-GerberCoreUpdateOverview -State $script:core.State)
    }

    It 'aligns plugin and Core columns while preserving complete versions and unavailable placeholders' {
        $text = Format-GerberUpdateItemListOverview -ItemList @($script:core, $script:plugin)
        $rows = $text -split "`n"
        $coreRow = $rows | Where-Object {
            $_ -match '^Core\s'
        }
        $pluginRow = $rows | Where-Object {
            $_ -match '^Plugin\s'
        }
        $coreRow | Should -Match 'Gerber\s+0\.2\.1-preview02\s+0\.2\.1-preview01\s+PSGallery\s+UpToDate'
        $pluginRow | Should -Match 'Gerber\.AT\s+0\.1\.0\s+-\s+-\s+Unavailable'
        $pluginRow.IndexOf('Gerber.AT') | Should -Be $coreRow.IndexOf('Gerber')
        $pluginRow.IndexOf('0.1.0') | Should -Be $coreRow.IndexOf('0.2.1-preview02')
        @($rows | Where-Object {
            $_ -match '^Channel: Include prereleases'
        }).Count | Should -Be 1
        $text | Should -Not -Match 'Gerber\.AT:|Check the declared plugin repository'
        $text | Should -Match 'Unavailable[^\S\n]*\r?\n\r?\nChannel: Include prereleases\.\s*$'
        $text | Should -Not -Match '\| Installed:'
    }

    It 'does not truncate long plugin names or version labels before terminal rendering' {
        $script:plugin.State.Name = 'Gerber.AVeryLongPluginNameForTerminalRendering'
        $script:plugin.State.Available = '2026.100.100-preview.123456789'
        $text = Format-GerberUpdateItemListOverview -ItemList @($script:core, $script:plugin)
        $text | Should -Match '(?m)^Plugin\s+Gerber\.AVeryLongPluginNameForTerminalRendering\s+0\.1\.0\s+2026\.100\.100-preview\.123456789\s+-\s+Unavailable\s*$'
    }

    It 'renders no table or channel for an empty component list' {
        Format-GerberUpdateItemListOverview -ItemList @() | Should -Be ''
    }
}
