function ConvertTo-GerberPluginRepositoryUri {
    param([AllowNull()][AllowEmptyString()][string]$Value)

    $uri = $null
    if (-not [uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri)) {
        throw [System.InvalidOperationException]::new('The declared plugin repository URI is invalid.')
    }
    Assert-GerberPluginRepositoryUri -Uri $uri
    return $uri
}

function Assert-GerberPluginRepositoryUri {
    param([uri]$Uri)

    foreach ($component in @($Uri.UserInfo, $Uri.Query, $Uri.Fragment)) {
        if ($component) {
            throw [System.InvalidOperationException]::new('The declared repository URI must not contain credentials, query or fragment.')
        }
    }
}
