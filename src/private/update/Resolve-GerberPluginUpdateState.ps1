function Resolve-GerberPluginUpdateState {
    param([object]$Entry, [pscredential]$Credential)
    $item = Get-GerberPluginUpdateItem $Entry $Credential
    try {
        Complete-GerberPluginUpdateDiscovery $item
    } catch {
        Assert-GerberUpdateNotCancelled $_
        Complete-GerberPluginUpdateFailure $item $_
    }
    $item
}

function Get-GerberPluginUpdateItem {
    param([object]$Entry, [pscredential]$Credential)
    $item = Get-GerberUpdateItem (Get-GerberPluginUpdateOverview $Entry)
    $item.Kind = 'Plugin'
    $item.Plugin = $Entry
    $item.Credential = $Credential
    $item
}

function Get-GerberPluginUpdateOverview {
    param([object]$Entry)
    [pscustomobject]@{
        Name       = $Entry.Name
        Installed  = $Entry.Version
        Available  = '-'
        Repository = '-'
        Status     = 'Unavailable'
        Plan       = $null
        Channel    = $null
        Message    = 'Check the declared plugin repository and installation, then retry /update list.'
    }
}

function Complete-GerberPluginUpdateDiscovery {
    param([object]$Item)
    $module = Read-GerberPluginUpdateModule $Item.Plugin
    $manifest = Read-GerberPluginUpdateManifest $Item.Plugin
    $repository = Resolve-GerberPluginRepository $manifest.PrivateData
    $Item.State.Repository = $repository.Name
    $uri = ConvertTo-GerberPluginRepositoryUri -Value $repository.Uri
    $policy = Resolve-GerberPluginUpdatePolicy $module $uri
    $Item.State.Channel = $policy.Channel
    $plan = Get-GerberPluginUpdatePlan -Item $Item -Module $module -Policy $policy
    Complete-GerberPluginUpdateOverview $Item.State $plan
}

function Get-GerberPluginUpdatePlan {
    param([object]$Item, [object]$Module, [hashtable]$Policy)
    Get-PSModuleUpdate -Module (Resolve-GerberPluginUpdateActiveModule $Module) -RepositoryUri $Policy.ExpectedRepositoryUri -Policy $Policy -Credential $Item.Credential `
        -ErrorAction Stop -WarningAction SilentlyContinue -InformationAction SilentlyContinue -Verbose:$false -Debug:$false
}

function Resolve-GerberPluginUpdateActiveModule {
    param([object]$Selected)
    $loaded = @(Get-Module -Name $Selected.Name -ErrorAction Stop | Where-Object Guid -EQ $Selected.Guid)
    if ($loaded.Count -eq 0) {
        return $Selected
    }
    if ($loaded.Count -ne 1) {
        throw [InvalidOperationException]::new('The active plugin installation is ambiguous.')
    }
    $loaded[0]
}

function Read-GerberPluginUpdateModule {
    param([object]$Entry)
    $modules = @(Get-Module -ListAvailable -Name $Entry.ModulePath -ErrorAction Stop)
    if ($modules.Count -ne 1) {
        throw [System.InvalidOperationException]::new('The selected plugin installation is ambiguous or missing.')
    }
    $module = $modules[0]
    if ($module.Name -cne $Entry.Name -or $module.Guid -ne [guid]$Entry.Guid) {
        throw [System.InvalidOperationException]::new('The selected plugin identity changed.')
    }
    $module
}

function Read-GerberPluginUpdateManifest {
    param([object]$Entry)
    $manifest = Import-PowerShellDataFile -LiteralPath $Entry.ModulePath -ErrorAction Stop
    if ([guid]$manifest.GUID -ne [guid]$Entry.Guid) {
        throw [System.InvalidOperationException]::new('The selected plugin manifest identity changed.')
    }
    $manifest
}

function Resolve-GerberPluginRepositoryUri {
    param([object]$PrivateData)
    $repository = Resolve-GerberPluginRepository $PrivateData
    ConvertTo-GerberPluginRepositoryUri -Value $repository.Uri
}

function Resolve-GerberPluginRepository {
    param([object]$PrivateData)
    $metadata = Read-GerberPluginUpdateMetadataRecord $PrivateData
    if ($metadata.Contains('Repository')) {
        return Read-GerberPluginRepositoryDescriptor $metadata.Repository
    }
    if (-not $metadata.Contains('RepositoryUri')) {
        return [pscustomobject]@{ Name = 'PSGallery'; Uri = 'https://www.powershellgallery.com/api/v2' }
    }
    Resolve-GerberPluginLegacyRepository $metadata.RepositoryUri
}

function Resolve-GerberPluginLegacyRepository {
    param([object]$Value)
    $uri = ConvertTo-GerberPluginRepositoryUri -Value $Value
    $name = $uri.AbsoluteUri
    if ($name.TrimEnd('/') -ieq 'https://www.powershellgallery.com/api/v2') {
        $name = 'PSGallery'
    }
    [pscustomobject]@{ Name = $name; Uri = $uri.AbsoluteUri }
}

function Read-GerberPluginRepositoryDescriptor {
    param([object]$Repository)
    if ($Repository -isnot [System.Collections.IDictionary]) {
        throw [System.InvalidOperationException]::new('The declared plugin repository must contain Name and Uri.')
    }
    if ($Repository.Name -isnot [string] -or [string]::IsNullOrWhiteSpace($Repository.Name)) {
        throw [System.InvalidOperationException]::new('The declared plugin repository name is invalid.')
    }
    [pscustomobject]@{ Name = $Repository.Name; Uri = $Repository.Uri }
}

function Read-GerberPluginUpdateMetadataRecord {
    param([object]$PrivateData)
    $metadata = Get-GerberModulePrivateDataValueOrNull $PrivateData 'Gerber'
    if ($null -eq $metadata) {
        throw [System.InvalidOperationException]::new('Plugin metadata is missing.')
    }
    $metadata
}

function Resolve-GerberPluginUpdatePolicy {
    param([object]$Module, [uri]$RepositoryUri)
    $policy = Resolve-GerberCoreUpdatePolicy
    $policy.Scope = Resolve-GerberPluginUpdateScope $Module
    $policy.ExpectedRepositoryUri = $RepositoryUri
    $policy
}

function Complete-GerberPluginUpdateOverview {
    param([object]$State, [object]$Plan)
    $State.Plan = $Plan
    $State.Installed = $Plan.InstalledVersion
    $State.Available = $Plan.TargetVersion
    $State.Status = Resolve-GerberUpdateDisposition $Plan
    $State.Message = "Plugin update status: $($State.Status)."
}

function Complete-GerberPluginUpdateFailure {
    param([object]$Item, [System.Management.Automation.ErrorRecord]$ErrorRecord)
    $statuses = @{
        'PMU.PackageNotFound'      = 'NoMatchingPackage'
        'PMU.AuthenticationFailed' = 'CredentialRequired'
    }
    $id = ($ErrorRecord.FullyQualifiedErrorId -split ',')[0]
    $Item.State.Status = $statuses[$id] ?? 'Unavailable'
    $Item.State.Plan = $null
}
