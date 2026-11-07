function Resolve-GerberPluginProjectRequest {
    param([hashtable]$InputMap)

    $inputMap = Initialize-GerberPluginProjectInputMap -InputMap $InputMap
    foreach ($field in @('Suffix', 'Description', 'Namespace', 'ParentPath')) {
        Assert-GerberPluginProjectInput -Field $field -Value $inputMap[$field]
    }
    $repository = Resolve-GerberPluginProjectRepositoryInput -InputMap $inputMap
    $request = ConvertTo-GerberPluginProjectRequest -InputMap $inputMap
    $request | Add-Member -NotePropertyName Repository -NotePropertyValue $repository
    return $request
}

function Resolve-GerberPluginProjectRepositoryInput {
    param([hashtable]$InputMap)

    if ($InputMap.ContainsKey('Repository')) {
        return ConvertTo-GerberPluginProjectRepositoryInput $InputMap.Repository
    }
    if ($InputMap.ContainsKey('RepositoryUri')) {
        Assert-GerberPluginProjectInput -Field RepositoryUri -Value $InputMap.RepositoryUri
        $name = $InputMap.RepositoryUri
        if ($name -eq 'https://www.powershellgallery.com/api/v2') {
            $name = 'PSGallery'
        }
        return ConvertTo-GerberPluginProjectRepositoryInput @{ Name = $name; Uri = $InputMap.RepositoryUri }
    }
    return @{ Name = 'PSGallery'; Uri = 'https://www.powershellgallery.com/api/v2' }
}

function ConvertTo-GerberPluginProjectRepositoryInput {
    param([object]$Repository)

    $name = Get-GerberModulePrivateDataValueOrNull $Repository 'Name'
    $uri = Get-GerberModulePrivateDataValueOrNull $Repository 'Uri'
    if ($name -isnot [string]) {
        throw [System.ArgumentException]::new('Enter a repository name and URI in Repository.Name and Repository.Uri.')
    }
    Assert-GerberPluginProjectInput -Field RepositoryName -Value $name
    Assert-GerberPluginProjectInput -Field RepositoryUri -Value $uri
    return @{ Name = $name; Uri = $uri }
}

function Initialize-GerberPluginProjectInputMap {
    param([hashtable]$InputMap)

    # Required fields: Suffix, Description, Namespace; optional ParentPath and Repository.
    $values = $InputMap.Clone()
    if (-not $values.ContainsKey('ParentPath')) {
        $values.ParentPath = (Get-Location).ProviderPath
    }
    return $values
}

function ConvertTo-GerberPluginProjectRequest {
    param([hashtable]$InputMap)

    $parent = (Get-Item -LiteralPath $InputMap.ParentPath -ErrorAction Stop).FullName
    $destination = Join-Path $parent "Gerber.$($InputMap.Suffix)"
    Assert-GerberPluginProjectDestination -Destination $destination
    return [pscustomobject]@{
        Name = "Gerber.$($InputMap.Suffix)"
        Suffix = $InputMap.Suffix
        Description = $InputMap.Description
        Namespace = $InputMap.Namespace
        ParentPath = $parent
        Destination = $destination
    }
}

function Assert-GerberPluginProjectDestination {
    param([string]$Destination)

    if (Test-Path -LiteralPath $Destination) {
        throw [System.ArgumentException]::new("Destination '$Destination' already exists. Choose another module suffix or destination parent; Gerber never overwrites it.")
    }
}
