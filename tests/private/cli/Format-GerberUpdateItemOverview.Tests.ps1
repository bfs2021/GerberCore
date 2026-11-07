BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $source = "$root/src/private/cli/Format-GerberUpdateItemOverview.ps1"
    if (Test-Path $source) {
        . $source
    }
    . "$root/src/private/config/Get-GerberCoreUpdateChannelLabel.ps1"
}

Describe 'Format-GerberUpdateItemOverview' -Tag 'G4A9UI' {
    It 'labels plugins accurately and retains complete versions and safe status messages' {
        $state = [pscustomobject]@{
            Name = 'ExamplePlugin'; Installed = '1.0.0-preview'; Available = '2.0.0-preview.12'; Repository = 'Feed'; Status = 'Blocked'; Message = 'Required Core is unavailable.'
        }
        $text = Format-GerberUpdateItemOverview -Item ([pscustomobject]@{
            Kind = 'Plugin'; State = $state
        })
        $text | Should -Match 'Plugin'
        $text | Should -Match '1.0.0-preview'
        $text | Should -Match '2.0.0-preview.12'
        $text | Should -Match 'Blocked.*Required Core is unavailable'
        $text | Should -Not -Match 'Component: Core'
    }

    It 'keeps the active shared channel visible in overview and consent text' {
        $state = [pscustomobject]@{
            Name = 'Gerber'; Installed = '1.0.0'; Available = '2.0.0'; Repository = 'PSGallery'; Status = 'Available'; Message = ''; Channel = 'IncludePrerelease'
        }
        Format-GerberUpdateItemOverview -Item ([pscustomobject]@{
            Kind = 'Core'; State = $state
        }) | Should -Match 'Channel: Include prereleases'
    }
}
