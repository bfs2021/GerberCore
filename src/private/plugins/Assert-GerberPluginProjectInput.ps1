function Assert-GerberPluginProjectInput {
    param([string]$Field, [AllowEmptyString()][string]$Value)

    $validator = @{
        Suffix = 'Assert-GerberPluginProjectSuffix'
        Namespace = 'Assert-GerberPluginProjectNamespace'
        ParentPath = 'Assert-GerberPluginProjectParent'
        Description = 'Assert-GerberPluginProjectDescription'
        RepositoryUri = 'Assert-GerberPluginProjectRepositoryInput'
        RepositoryName = 'Assert-GerberPluginProjectRepositoryName'
    }
    & $validator[$Field] -Value $Value
}

function Assert-GerberPluginProjectRepositoryName {
    param([AllowEmptyString()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw [System.ArgumentException]::new('Enter a repository name. Esc cancels without generating a plugin.')
    }
}

function Assert-GerberPluginProjectDescription {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw [System.ArgumentException]::new('Enter a description for the plugin.')
    }
}

function Assert-GerberPluginProjectRepositoryInput {
    param([AllowEmptyString()][string]$Value)

    if ($Value -ceq 'REPLACE_WITH_REPOSITORY_URI') {
        return
    }
    try {
        $null = ConvertTo-GerberPluginRepositoryUri -Value $Value
    } catch [System.InvalidOperationException] {
        throw [System.ArgumentException]::new('Enter an absolute repository URI without credentials, query or fragment. Press Enter for an unknown URI, or Esc to cancel.')
    }
}

function Assert-GerberPluginProjectSuffix {
    param([string]$Value)

    if ($Value -cnotmatch '^[A-Za-z][A-Za-z0-9]{0,63}$') {
        throw [System.ArgumentException]::new('Enter a module suffix using letters and numbers, starting with a letter. The Gerber. prefix is fixed.')
    }
}

function Assert-GerberPluginProjectNamespace {
    param([string]$Value)

    if ($Value -cnotmatch '^[a-z][a-z0-9-]{0,63}$') {
        throw [System.ArgumentException]::new('Enter a lowercase command namespace using letters, numbers or hyphens, starting with a letter.')
    }
    $rootList = @(Get-GerberCommandRegistry | ForEach-Object { ($_.Name -split ' ')[0] })
    if ($rootList -icontains $Value) {
        throw [System.ArgumentException]::new("Command namespace '$Value' is already registered. Choose another namespace.")
    }
}

function Assert-GerberPluginProjectParent {
    param([string]$Value)

    if (($Value -split '[/\\]') -contains '..') {
        throw [System.ArgumentException]::new('Destination parent must not contain path traversal (..). Choose an existing directory.')
    }
    if (-not (Test-Path -LiteralPath $Value -PathType Container)) {
        throw [System.ArgumentException]::new('Destination parent must be an existing filesystem directory.')
    }
    $item = Get-Item -LiteralPath $Value -ErrorAction Stop
    if ($item.PSProvider.Name -ne 'FileSystem') {
        throw [System.ArgumentException]::new('Destination parent must be a filesystem directory.')
    }
}
