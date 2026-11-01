function Write-GerberPluginProject {
    param([pscustomobject]$Request, [string]$Path, [string]$Guid)

    $templateRoot = Get-GerberPluginTemplatePath
    foreach ($file in (Get-ChildItem -LiteralPath $templateRoot -Recurse -File -Force -Filter '*.template')) {
        $relativePath = [System.IO.Path]::GetRelativePath($templateRoot, $file.FullName) -replace '\.template$', ''
        $destination = Join-Path $Path $relativePath
        $null = [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        $text = (Get-Content -LiteralPath $file.FullName -Raw).Replace('{{Name}}', $Request.Name).Replace('{{Namespace}}', $Request.Namespace).Replace('{{Guid}}', $Guid)
        [System.IO.File]::WriteAllText($destination, $text.TrimEnd() + "`n")
    }
    Write-GerberPluginProjectMetadataFile -Request $Request -Path $Path
}

function Write-GerberPluginProjectMetadataFile {
    param([pscustomobject]$Request, [string]$Path)

    $projectPath = Join-Path $Path 'project.json'
    $project = Get-Content -LiteralPath $projectPath -Raw | ConvertFrom-Json -AsHashtable
    $project.Description = $Request.Description
    $project.Manifest.Author = $Request.Suffix
    if ($Request.PSObject.Properties['Repository']) {
        $project.Manifest.PrivateData.Gerber.Repository = $Request.Repository
    }
    $json = $project | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($projectPath, $json.TrimEnd() + "`n")
}
