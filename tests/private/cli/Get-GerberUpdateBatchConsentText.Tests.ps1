BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $source = "$root/src/private/cli/Get-GerberUpdateBatchConsentText.ps1"
    if (Test-Path $source) {
        . $source
    }
    . "$root/src/private/cli/Format-GerberUpdateItemOverview.ps1"
}

Describe 'Get-GerberUpdateBatchConsentText' -Tag 'G4A9UI' {
    It 'shows full versions, exact feed/scope, automatic Core requirement and installation trust/license consent' {
        $plan = [pscustomobject]@{
            Scope = 'CurrentUser'; RepositoryUri = 'https://example.test/v2'
            RequiresRepositoryTrust = $true; RequiresLicenseAcceptance = $true
        }
        $state = [pscustomobject]@{
            Name = 'Gerber'; Installed = '1.0.0-preview'; Available = '2.0.0-preview.12'; Repository = 'PSGallery'; Status = 'Available'; Plan = $plan; Message = ''
        }
        $item = [pscustomobject]@{
            Kind = 'Core'; State = $state; AutoAdded = $true; MinimumCore = $null
        }
        $text = Get-GerberUpdateBatchConsentText -Batch ([pscustomobject]@{
            Items = @($item)
        })
        $text | Should -Match '1.0.0-preview'
        $text | Should -Match '2.0.0-preview.12'
        $text | Should -Match 'https://example.test/v2'
        $text | Should -Match 'CurrentUser'
        $text | Should -Match 'automatically added.*Core'
        $text | Should -Match 'trust'
        $text | Should -Match 'license'
        $text | Should -Match 'Cancel is the default'
        $text | Should -Match 'not hot reload'
    }

    It 'retains blocked item reasons in the final preview without inventing scope or versions' {
        $state = [pscustomobject]@{
            Name = 'BlockedPlugin'; Installed = '1.0.0'; Available = '2.0.0'; Repository = 'Private'; Status = 'Blocked'; Plan = $null; Message = 'Required Core is unavailable.'
        }
        $item = [pscustomobject]@{
            Kind = 'Plugin'; State = $state; AutoAdded = $false; MinimumCore = '3.0.0'
        }
        Get-GerberUpdateBatchConsentText -Batch ([pscustomobject]@{
            Items = @($item)
        }) | Should -Match 'Blocked.*Required Core is unavailable'
    }
}
