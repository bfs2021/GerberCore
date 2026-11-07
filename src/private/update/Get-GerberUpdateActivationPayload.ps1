function Get-GerberUpdateActivationPayload {
    param([object]$Item, [object]$Result, [object]$CoreState, [object]$CoreVersion)
    $target = $null
    if ($Item.Kind -eq 'Plugin') {
        $target = Get-GerberActivationTargetRecord $Item $Result
    }
    @{
        CoreManifest = Resolve-GerberActivationCoreManifest $CoreState $CoreVersion
        CoreVersion  = [string]$CoreVersion
        Target       = $target
        OtherPlugins = @(Read-GerberActivationContext $Item.Plugin)
    }
}

function Resolve-GerberActivationCoreManifest {
    param([object]$State, [object]$Version)
    if ($null -eq $Version) {
        throw [InvalidOperationException]::new('The intended Core version is unknown.')
    }
    if ($null -eq $State.Plan) {
        return Join-Path (Resolve-GerberCoreUpdateRequest).Module.ModuleBase 'Gerber.psd1'
    }
    Resolve-GerberActivationPlannedCoreManifest $State.Plan $Version
}

function Resolve-GerberActivationPlannedCoreManifest {
    param([object]$Plan, [object]$Version)
    if ([string]$Version -ceq [string]$Plan.TargetVersion) {
        return Join-Path $Plan.TargetInstalledPath 'Gerber.psd1'
    }
    if ([string]$Version -ceq [string]$Plan.InstalledVersion) {
        return $Plan.InstalledManifestPath
    }
    throw [InvalidOperationException]::new('The intended Core installation cannot be identified.')
}

function Get-GerberActivationTargetRecord {
    param([object]$Item, [object]$Result)
    Assert-GerberActivationResultIdentity $Item $Result
    Assert-GerberActivationResultLocation $Item.State.Plan $Result
    @{
        Name    = $Result.ModuleName
        Guid    = [string]$Result.ModuleGuid
        Version = [string]$Result.InstalledVersion
        Path    = Join-Path $Result.InstalledPath "$($Result.ModuleName).psd1"
    }
}

function Assert-GerberActivationResultIdentity {
    param([object]$Item, [object]$Result)
    if ($Result.VerificationStatus -cne 'Verified') {
        throw [InvalidOperationException]::new('The installation was not verified.')
    }
    if ($Result.ModuleName -cne $Item.Plugin.Name -or [guid]$Result.ModuleGuid -ne [guid]$Item.Plugin.Guid) {
        throw [InvalidOperationException]::new('The installed plugin identity does not match the selected update.')
    }
}

function Assert-GerberActivationResultLocation {
    param([object]$Plan, [object]$Result)
    if ($Result.Scope -cne $Plan.Scope) {
        throw [InvalidOperationException]::new('The installation scope does not match the selected update.')
    }
    if ([string]$Result.InstalledVersion -cne [string]$Plan.TargetVersion) {
        throw [InvalidOperationException]::new('The installed version does not match the selected update.')
    }
    if (-not (Test-GerberActivationPath $Result.InstalledPath $Plan.TargetInstalledPath)) {
        throw [InvalidOperationException]::new('The installed path does not match the selected update.')
    }
}

function Test-GerberActivationPath {
    param([string]$Actual, [string]$Expected)
    $comparison = [StringComparison]::Ordinal
    if ($IsWindows) {
        $comparison = [StringComparison]::OrdinalIgnoreCase
    }
    [string]::Equals([IO.Path]::GetFullPath($Actual), [IO.Path]::GetFullPath($Expected), $comparison)
}

function Read-GerberActivationContext {
    param([object]$Target)
    $targetGuid = Get-GerberModulePrivateDataValueOrNull $Target 'Guid'
    foreach ($entry in @(Get-GerberPluginInventory)) {
        if ($entry.Guid -eq $targetGuid) {
            continue
        }
        if (Test-GerberPluginUpdateEligibility $entry) {
            Read-GerberActivationContextRecord $entry
        }
    }
}

function Read-GerberActivationContextRecord {
    param([object]$Entry)
    $manifest = Import-PowerShellDataFile -LiteralPath $Entry.ModulePath -ErrorAction Stop
    @{
        Name    = $Entry.Name
        Guid    = [string]$Entry.Guid
        Version = Read-GerberActivationContextVersion $manifest
        Path    = $Entry.ModulePath
    }
}

function Read-GerberActivationContextVersion {
    param([hashtable]$Manifest)
    $privateData = Get-GerberModulePrivateDataValueOrNull $Manifest 'PrivateData'
    $psData = Get-GerberModulePrivateDataValueOrNull $privateData 'PSData'
    $prerelease = Get-GerberModulePrivateDataValueOrNull $psData 'Prerelease'
    $version = [string]$Manifest.ModuleVersion
    if ($prerelease) {
        $version += "-$prerelease"
    }
    $version
}
