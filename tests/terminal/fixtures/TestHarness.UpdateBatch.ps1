# Disposable PMU boundaries only: no downloads, provider mutations or module installation.
$script:GerberTerminalLiveUpdatePlans = @{
}
$script:GerberTerminalOriginalUpdateInteractive = ${function:Test-GerberUpdateInteractive}

function script:Test-GerberUpdateInteractive {
    param()
    $fixture = Get-GerberTerminalUpdateFixture
    if ($fixture.Contains('moduleDataRoot')) {
        $env:XDG_DATA_HOME = $fixture.moduleDataRoot
    }
    if ($fixture.Contains('nonInteractiveUpdates') -and $fixture.nonInteractiveUpdates) {
        return $false
    }
    & $script:GerberTerminalOriginalUpdateInteractive
}

function script:Write-GerberTerminalUpdateDiscovery {
    param([object]$Module, [object]$Repository, [hashtable]$Policy)
    $state = Get-GerberTerminalUpdateState
    Add-GerberTerminalUpdateDiscoveryCount $state $Policy
    $state.repository = [string]$Repository
    $state.channel = $Policy.Channel
    if ($Module.Name -ne 'Gerber') {
        Add-GerberTerminalPluginDiscovery $state $Repository
    }
    Write-GerberTerminalUpdateState $state
    $state
}

function script:Add-GerberTerminalUpdateDiscoveryCount {
    param([hashtable]$State, [hashtable]$Policy)
    if ($script:GerberTerminalUpdateStartup) {
        $State.startupDiscoveryCount++
        $State.startupChannel = $Policy.Channel
    } else {
        $State.discoveryCount++
    }
}

function script:Add-GerberTerminalPluginDiscovery {
    param([hashtable]$State, [uri]$RepositoryUri)
    if (-not $State.Contains('pluginRepositoryUris')) {
        $State.pluginRepositoryUris = @()
    }
    if (-not $State.Contains('startupPluginDiscoveryCount')) {
        $State.startupPluginDiscoveryCount = 0
    }
    if ($script:GerberTerminalUpdateStartup) {
        $State.startupPluginDiscoveryCount++
    }
    $State.pluginRepositoryUris += $RepositoryUri.AbsoluteUri
}

function script:Get-GerberTerminalUpdatePlanForModule {
    param([object]$Module, [object]$Repository, [hashtable]$Policy, [hashtable]$Fixture)
    if ($Module.Name -eq 'Gerber') {
        return Get-GerberTerminalUpdatePlan $Fixture $Policy.Channel
    }
    [pscustomobject]@{
        ModuleName = $Module.Name; ModuleGuid = $Module.Guid
        InstalledVersion = '1.0.0'; TargetVersion = '2.0.0'; TargetNumericVersion = [version]'2.0.0'
        RepositoryName = 'TerminalPluginFeed'; RepositoryUri = [string]$Repository
        Channel = $Policy.Channel; Scope = $Policy.Scope; Disposition = 'UpdateAvailable'; UpdateAvailable = $true
        RequiresRepositoryTrust = $false; RequiresLicenseAcceptance = $false; RestartRequired = $false
        InstalledManifestPath = $Module.Path; DestinationRoot = $Module.ModuleBase
        TargetInstalledPath = Join-Path (Split-Path $Module.ModuleBase) '2.0.0'
    }
}

function script:Assert-GerberTerminalPluginUpdateRequest {
    param([object]$Module, [uri]$RepositoryUri, [hashtable]$Policy)
    if ($Module.Name -notlike 'Gerber.Batch*') {
        throw 'Unexpected terminal plugin update target.'
    }
    if ($RepositoryUri.AbsoluteUri -cne $Policy.ExpectedRepositoryUri.AbsoluteUri) {
        throw 'Plugin endpoint binding changed.'
    }
    Assert-GerberTerminalPluginUpdatePolicy $Policy
}

function script:Assert-GerberTerminalPluginUpdatePolicy {
    param([hashtable]$Policy)
    if ($Policy.Scope -ne 'CurrentUser') {
        throw 'Unexpected plugin update scope.'
    }
    if ($Policy.Channel -notin @('Stable', 'IncludePrerelease')) {
        throw 'Unexpected plugin update channel.'
    }
}

function script:Get-PSModuleUpdateTargetManifest {
    [CmdletBinding()]
    param([object]$Plan, [pscredential]$Credential, [switch]$TrustRepository, [switch]$AcceptLicense)
    $null = $Credential, $TrustRepository, $AcceptLicense
    Assert-GerberTerminalLiveUpdatePlan $Plan
    $minimum = Get-GerberTerminalPluginMinimumCore $Plan
    Get-GerberTerminalTargetManifest $Plan $minimum
}

function script:Get-GerberTerminalPluginMinimumCore {
    param([object]$Plan)
    $fixture = Get-GerberTerminalUpdateFixture
    $minimum = '0.1.0-preview'
    if ($fixture.Contains('pluginMinimumCore') -and $fixture.pluginMinimumCore.Contains($Plan.ModuleName)) {
        $minimum = $fixture.pluginMinimumCore[$Plan.ModuleName]
    }
    $minimum
}

function script:Get-GerberTerminalTargetManifest {
    param([object]$Plan, [string]$Minimum)
    $metadata = @{
        Plugin = $true; ApiVersion = '1'; MinimumGerberVersion = $Minimum
    }
    $manifest = @{
        GUID = $Plan.ModuleGuid; PrivateData = @{
            Gerber = $metadata
        }
    }
    [pscustomobject]@{
        Manifest = $manifest
    }
}

function script:Assert-GerberTerminalLiveUpdatePlan {
    param([object]$Plan)
    if (-not [object]::ReferenceEquals($Plan, $script:GerberTerminalLiveUpdatePlans[$Plan.ModuleName])) {
        throw 'A stale terminal plan was supplied.'
    }
}

function script:Write-GerberTerminalBatchInstall {
    param([object]$Plan)
    $state = Get-GerberTerminalUpdateState
    $state.installCount++
    if (-not $state.Contains('installOrder')) {
        $state.installOrder = @()
    }
    $state.installOrder += $Plan.ModuleName
    $state.planIdentityVerified = $true
    Write-GerberTerminalUpdateState $state
}

function script:Assert-GerberTerminalInstallOutcome {
    param([object]$Plan, [hashtable]$Fixture)
    if ($Fixture.Contains('failModules') -and $Plan.ModuleName -in $Fixture.failModules) {
        Write-Error -ErrorId 'PMU.InstallFailed' -Message 'raw-update-token' -ErrorAction Stop
    }
    if ($Fixture.Contains('installError')) {
        Write-Error -ErrorId $Fixture.installError -Message (Get-GerberTerminalUpdateErrorMessage $Fixture) -ErrorAction Stop
    }
}

function script:Get-GerberTerminalInstallResult {
    param([object]$Plan)
    $outcome = Get-GerberTerminalInstallDisposition -Plan $Plan
    [pscustomobject]@{
        ModuleName = $Plan.ModuleName; ModuleGuid = $Plan.ModuleGuid; Scope = $Plan.Scope
        InstalledVersion = $Plan.TargetVersion; TargetVersion = $Plan.TargetVersion
        InstalledPath = $Plan.TargetInstalledPath; Outcome = $outcome
        VerificationStatus = 'Verified'; RecoveryStatus = 'NotRequired'; RestartRequired = $true
    }
}

function script:Get-GerberTerminalInstallDisposition {
    param([object]$Plan)
    $fixture = Get-GerberTerminalUpdateFixture
    if ($fixture.Contains('cancelModules') -and $Plan.ModuleName -in $fixture.cancelModules) {
        return 'Cancelled'
    }
    'Installed'
}

function script:Test-GerberUpdateActivation {
    param([object]$Item, [object]$Result, [object]$CoreState, [object]$CoreVersion)
    $null = $Result, $CoreState
    $fixture = Get-GerberTerminalUpdateFixture
    $status = 'Verified'
    if ($fixture.Contains('activationFailures') -and $Item.State.Name -in $fixture.activationFailures) {
        $status = 'Failed'
    }
    [pscustomobject]@{
        Status = $status; Version = [string]$CoreVersion
    }
}
