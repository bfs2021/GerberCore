function Read-GerberPluginProjectRequest {
    $fields = Get-GerberPluginProjectPromptFieldMap
    $answers = @{}
    foreach ($field in $fields.Keys) {
        Show-GerberPluginProjectField -Field $field -Suffix $answers['Suffix']
        $value = Read-GerberPluginProjectField -Field $field -Prompt $fields[$field]
        if ($null -ne $value) {
            $answers[$field] = $value
        }
    }
    return Resolve-GerberPluginProjectRequest -InputMap $answers
}

function Get-GerberPluginProjectPromptFieldMap {
    return [ordered]@{
        Suffix = 'Module suffix (fixed Gerber. prefix)'
        Description = 'Description'
        Namespace = 'Command namespace'
        Repository = 'Plugin repository'
        ParentPath = 'Destination parent'
    }
}

function Show-GerberPluginProjectField {
    param([string]$Field, [string]$Suffix)

    Write-GerberScreenLine -Text ''
    foreach ($line in (Get-GerberPluginProjectFieldLineList -Field $Field -Suffix $Suffix)) {
        Write-GerberScreenLine -Text $line
    }
    Write-GerberScreenLine -Text ''
}

function Get-GerberPluginProjectFieldLineList {
    param([string]$Field, [string]$Suffix)

    $guidance = @{
        Suffix = @('Plugin Name', 'Enter the name of your plugin. Gerber automatically adds the "Gerber." prefix.', 'Example: Gerber.MyCompany (enter MyCompany)')
        Description = @('Description', 'Briefly describe the purpose of your plugin.', 'Example: Local development tools')
        Namespace = @('Command Namespace', 'Commands provided by your plugin will be registered under this namespace.', 'Example: mycompany registers /mycompany hello')
        Repository = @('Plugin Repository', 'Choose PSGallery (default), or name another repository and enter its URI.', 'For an unknown custom URI, press Enter to record REPLACE_WITH_REPOSITORY_URI; replace Repository.Uri before remote publishing or updates.')
        ParentPath = @('Destination', 'Select the parent directory for your project. Press Enter to use the current working directory.', "Default: $((Get-Location).ProviderPath)", "Project directory: $(Join-Path (Get-Location).ProviderPath "Gerber.$Suffix")")
    }
    $lines = $guidance[$Field]
    return @($lines[0]; ([string][char]0x2500) * 51; $lines[1..($lines.Count - 1)])
}

function Read-GerberPluginProjectField {
    param([string]$Field, [string]$Prompt)

    if ($Field -eq 'Repository') {
        return Read-GerberPluginProjectRepositoryInput
    }
    return Read-GerberPluginProjectTextField -Field $Field -Prompt $Prompt
}

function Read-GerberPluginProjectRepositoryInput {
    $items = @(
        Get-GerberPluginProjectRepositoryMenuItem -Number 1 -Value PSGallery -Label 'PSGallery (default)' -PreviewText 'Record PSGallery and its official URI.'
        Get-GerberPluginProjectRepositoryMenuItem -Number 2 -Value Other -Label 'Another repository' -PreviewText 'Enter a name, then a URI or an explicit replacement placeholder.'
    )
    $choice = Read-GerberNumberedMenuPrompt -Prompt 'Plugin repository' -MenuItemList $items
    if ($choice -eq 'PSGallery') {
        return @{ Name = 'PSGallery'; Uri = 'https://www.powershellgallery.com/api/v2' }
    }
    $name = Read-GerberPluginProjectTextField -Field RepositoryName -Prompt 'Repository name'
    $uri = Read-GerberPluginProjectTextField -Field RepositoryUri -Prompt 'Repository URI (Enter if unknown)'
    return @{ Name = $name; Uri = $uri }
}

function Get-GerberPluginProjectRepositoryMenuItem {
    param([int]$Number, [string]$Value, [string]$Label, [string]$PreviewText)

    return [pscustomobject]@{
        Number = $Number
        Value = $Value
        Label = $Label
        PreviewText = $PreviewText
    }
}

function Read-GerberPluginProjectTextField {
    param([string]$Field, [string]$Prompt)

    while ($true) {
        $value = Read-GerberCommand -Prompt $Prompt -SuggestionMode 'None' -TrimResult $true
        $value = Resolve-GerberPluginProjectFieldDefault -Field $Field -Value $value
        if (Test-GerberPluginProjectFieldInput -Field $Field -Value $value) {
            return $value
        }
    }
}

function Resolve-GerberPluginProjectFieldDefault {
    param([string]$Field, [string]$Value)

    $defaults = @{
        ParentPath = (Get-Location).ProviderPath
        RepositoryUri = 'REPLACE_WITH_REPOSITORY_URI'
    }
    if ([string]::IsNullOrWhiteSpace($Value) -and $defaults.ContainsKey($Field)) {
        return $defaults[$Field]
    }
    return $Value
}

function Test-GerberPluginProjectFieldInput {
    param([string]$Field, [string]$Value)

    try {
        Assert-GerberPluginProjectInput -Field $Field -Value $Value
        return $true
    } catch [System.ArgumentException] {
        Write-GerberPromptTrace -EventName 'plugin-create-input-rejected' -Data @{ Field = $Field }
        Write-GerberScreenLine -Text $_.Exception.Message
        return $false
    }
}
