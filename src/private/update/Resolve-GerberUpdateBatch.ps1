function Resolve-GerberUpdateBatch {
    param([object]$CoreState, [object[]]$SelectedItemList, [switch]$InspectionApproved)
    $batch = Get-GerberUpdateBatch $CoreState $SelectedItemList
    foreach ($item in @($SelectedItemList | Where-Object Kind -EQ 'Plugin')) {
        Complete-GerberCandidateInspection $item -Approved:$InspectionApproved
        Add-GerberUpdateCoreDependency -Batch $batch -Item $item -CoreState $CoreState
    }
    $batch.Items = @($batch.Items | Sort-Object {
            $_.Kind -ne 'Core'
        } -Stable)
    $batch
}

function Get-GerberUpdateBatch {
    param([object]$CoreState, [object[]]$SelectedItemList)
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $SelectedItemList) {
        $items.Add($item)
    }
    [pscustomobject]@{
        Items                = $items
        InstalledCoreVersion = ConvertTo-GerberUpdateVersion $CoreState.Installed
        CoreState            = $CoreState
    }
}

function ConvertTo-GerberUpdateVersion {
    param([string]$Version)
    $parsed = $null
    if (-not [System.Management.Automation.SemanticVersion]::TryParse($Version, [ref]$parsed)) {
        throw [System.InvalidOperationException]::new('The installed Core version could not be verified. Retry /update list after restarting PowerShell.')
    }
    $parsed
}

function Complete-GerberCandidateInspection {
    param([object]$Item, [switch]$Approved)
    try {
        $target = Read-GerberUpdateCandidateManifest $Item -Approved:$Approved
        Assert-GerberUpdateCandidateManifest $Item $target.Manifest
        $Item.MinimumCore = ConvertTo-GerberUpdateVersion $target.Manifest.PrivateData.Gerber.MinimumGerberVersion
    } catch {
        Assert-GerberUpdateNotCancelled $_
        Complete-GerberUpdateItemBlocking $Item 'Candidate metadata could not be verified. Check the declared repository, permissions and package requirements, then retry /update list.'
    }
}

function Read-GerberUpdateCandidateManifest {
    param([object]$Item, [switch]$Approved)
    $parameters = @{
        Plan            = $Item.State.Plan
        Credential      = $Item.Credential
        TrustRepository = $Approved -and $Item.State.Plan.RequiresRepositoryTrust
        AcceptLicense   = $Approved -and $Item.State.Plan.RequiresLicenseAcceptance
        ErrorAction     = 'Stop'
    }
    Get-PSModuleUpdateTargetManifest @parameters
}

function Assert-GerberUpdateCandidateManifest {
    param([object]$Item, [hashtable]$Manifest)
    if ([guid]$Manifest.GUID -ne [guid]$Item.Plugin.Guid) {
        throw [System.InvalidOperationException]::new('The target plugin identity changed.')
    }
    $metadata = $Manifest.PrivateData.Gerber
    if ($metadata.Plugin -ne $true -or [string]$metadata.ApiVersion -cne '1') {
        throw [System.InvalidOperationException]::new('The candidate does not support Plugin API v1.')
    }
    $null = ConvertTo-GerberUpdateVersion $metadata.MinimumGerberVersion
}

function Add-GerberUpdateCoreDependency {
    param([object]$Batch, [object]$Item, [object]$CoreState)
    if ($Item.State.Status -ne 'Available') {
        return
    }
    if ($Item.MinimumCore -le $Batch.InstalledCoreVersion) {
        return
    }
    if (-not (Test-GerberUpdateCoreCandidate $CoreState $Item.MinimumCore)) {
        Complete-GerberUpdateItemBlocking $Item "Requires Core $($Item.MinimumCore); no permitted Core target satisfies this requirement."
        return
    }
    Add-GerberRequiredCoreItem $Batch $CoreState
}

function Test-GerberUpdateCoreCandidate {
    param([object]$CoreState, [System.Management.Automation.SemanticVersion]$Minimum)
    if ($CoreState.Status -ne 'Available') {
        return $false
    }
    (ConvertTo-GerberUpdateVersion $CoreState.Available) -ge $Minimum
}

function Add-GerberRequiredCoreItem {
    param([object]$Batch, [object]$CoreState)
    if (@($Batch.Items | Where-Object Kind -EQ 'Core').Count -gt 0) {
        return
    }
    $core = Get-GerberUpdateItem $CoreState
    $core.AutoAdded = $true
    $Batch.Items.Add($core)
}

function Complete-GerberUpdateItemBlocking {
    param([object]$Item, [string]$Message)
    $Item.State.Status = 'Blocked'
    $Item.State.Message = $Message
}
