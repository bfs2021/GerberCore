function Resolve-GerberUpdateCredentialItemList {
    param([object[]]$ItemList)
    foreach ($item in $ItemList) {
        Resolve-GerberUpdateCredentialItem -Item $item
    }
}

function Resolve-GerberUpdateCredentialItem {
    param([object]$Item)
    if ($Item.Kind -ne 'Plugin' -or $Item.State.Status -ne 'CredentialRequired') {
        return $Item
    }
    $credential = Read-GerberUpdateCredentialConsent -Item $Item
    if ($null -eq $credential) {
        return $Item
    }
    $resolved = Resolve-GerberPluginUpdateState -Entry $Item.Plugin -Credential $credential
    Write-GerberScreenLine -Text (Format-GerberUpdateItemOverview -Item $resolved)
    $resolved
}

function Read-GerberUpdateCredentialConsent {
    param([object]$Item)
    $options = Get-GerberConfirmationPromptOptionSet -ActionLabel 'Provide credentials' -CancelLabel 'Skip' -DefaultOption 'cancel'
    $text = "$($Item.State.Name): $($Item.State.Repository). Credentials are used only for this update operation and are not saved."
    $accepted = Read-GerberConfirmationPrompt -Prompt 'Authenticate this repository?' -ScreenTitle '/update list' -ScreenText $text -PromptOptionSet $options
    if ($accepted) {
        Read-GerberUpdateOperationCredential
    }
}

function Read-GerberUpdateOperationCredential {
    param()
    $userName = Read-GerberCommand -Prompt 'Repository user name' -SuggestionMode 'None'
    $password = Read-GerberSecureValue -Prompt 'Repository password or token'
    [pscredential]::new($userName, $password)
}
