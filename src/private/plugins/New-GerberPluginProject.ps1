function New-GerberPluginProject {
    [CmdletBinding(SupportsShouldProcess)]
    param([pscustomobject]$Request)

    $Request = Resolve-GerberPluginProjectCreationRequest -Request $Request
    if (-not $PSCmdlet.ShouldProcess($Request.Destination, 'Create, validate and approve Gerber plugin project')) {
        return
    }
    $stage = Join-Path $Request.ParentPath ('.gerber-create-' + [System.IO.Path]::GetRandomFileName())
    $null = New-Item -ItemType Directory -Path $stage -ErrorAction Stop
    try {
        return Complete-GerberPluginProjectCreation -Request $Request -Stage $stage
    } finally {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction Stop
    }
}

function Resolve-GerberPluginProjectCreationRequest {
    param([pscustomobject]$Request)

    $inputMap = @{}
    foreach ($property in $Request.PSObject.Properties) {
        $inputMap[$property.Name] = $property.Value
    }
    return Resolve-GerberPluginProjectRequest -InputMap $inputMap
}

function Complete-GerberPluginProjectCreation {
    param([pscustomobject]$Request, [string]$Stage)

    $guid = [guid]::NewGuid().ToString('D')
    $projectPath = Join-Path $Stage $Request.Name
    Write-GerberPluginProject -Request $Request -Path $projectPath -Guid $guid
    Test-GerberPluginProject -Request $Request -Path $projectPath -Guid $guid
    $project = Get-Content -LiteralPath (Join-Path $projectPath 'project.json') -Raw | ConvertFrom-Json
    [System.IO.Directory]::Move($projectPath, $Request.Destination)
    Complete-GerberPluginProjectApproval -Request $Request -Guid $guid -Version $project.Version
    return Get-GerberPluginProjectCreationResult -Request $Request -Guid $guid -Version $project.Version
}

function Get-GerberPluginProjectCreationResult {
    param([pscustomobject]$Request, [string]$Guid, [string]$Version)

    $result = [pscustomobject]@{
        Name = $Request.Name
        Version = $Version
        Path = $Request.Destination
        Guid = $Guid
        Namespace = $Request.Namespace
        Repository = $Request.Repository
    }
    return $result
}

function Complete-GerberPluginProjectApproval {
    param([pscustomobject]$Request, [string]$Guid, [string]$Version)

    try {
        $identity = [pscustomobject]@{ Name = $Request.Name; Guid = $Guid }
        $null = Resolve-GerberPluginApproval -PluginModule $identity -ExplicitApproval `
            -DisplayMetadata @{ name = $Request.Name; version = $Version }
    } catch {
        throw [System.IO.IOException]::new(
            "Project preserved at '$($Request.Destination)' (GUID $Guid), but not approved: configuration could not be saved. Retry approval with /plugins enable after local publish. $($_.Exception.Message)", $_.Exception
        )
    }
    Write-GerberPromptTrace -EventName 'plugin-create-completed' -Data @{ Name = $Request.Name; Guid = $Guid; Path = $Request.Destination }
}
