BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $source = "$root/src/private/cli/Resolve-GerberUpdateCredentialItemList.ps1"
    if (Test-Path $source) {
        . $source
    }
    . "$root/src/private/cli/Read-GerberConfirmationPrompt.ps1"
    function Read-GerberCommand {
        param($Prompt, $SuggestionMode)
        $null = $Prompt, $SuggestionMode
    }
    function Read-GerberSecureValue {
        param($Prompt)
        $null = $Prompt
    }
    function Resolve-GerberPluginUpdateState {
        param($Entry, [pscredential]$Credential)
        $null = $Entry, $Credential
    }
    function Write-GerberScreenLine {
        param($Text)
        $null = $Text
    }
    . "$root/src/private/cli/Format-GerberUpdateItemOverview.ps1"
}

Describe 'Resolve-GerberUpdateCredentialItemList' -Tag 'G4A9UI' {
    BeforeEach {
        $script:entry = [pscustomobject]@{
            Name = 'ExamplePlugin'
        }
        $script:item = [pscustomobject]@{
            Kind = 'Plugin'; Plugin = $script:entry; State = [pscustomobject]@{
                Name = 'ExamplePlugin'; Repository = 'Private'; Status = 'CredentialRequired'; Installed = '1.0.0'; Available = $null; Message = ''
            }
        }
        Mock Read-GerberConfirmationPrompt {
            $false
        }
        Mock Read-GerberCommand {
            'fixture-user'
        }
        Mock Read-GerberSecureValue {
            [System.Security.SecureString]::new()
        }
        Mock Resolve-GerberPluginUpdateState {
            $script:item
        }
        Mock Write-GerberScreenLine {
        }
    }

    It 'does not request or store credentials unless the user explicitly accepts the per-call prompt' {
        $result = @(Resolve-GerberUpdateCredentialItemList -ItemList @($script:item))
        [object]::ReferenceEquals($result[0], $script:item) | Should -BeTrue
        Should -Invoke Read-GerberSecureValue -Times 0
        Should -Invoke Resolve-GerberPluginUpdateState -Times 0
    }

    It 'replans the exact inventory entry with operation-only PSCredential after consent' {
        Mock Read-GerberConfirmationPrompt {
            $true
        }
        $null = Resolve-GerberUpdateCredentialItemList -ItemList @($script:item)
        Should -Invoke Resolve-GerberPluginUpdateState -Times 1 -ParameterFilter {
            [object]::ReferenceEquals($Entry, $script:entry) -and $Credential -is [pscredential] -and $Credential.UserName -eq 'fixture-user'
        }
    }

    It 'never asks for credentials for Core or ordinary available rows' {
        $script:item.Kind = 'Core'
        $null = Resolve-GerberUpdateCredentialItemList -ItemList @($script:item)
        Should -Invoke Read-GerberConfirmationPrompt -Times 0
    }
}
