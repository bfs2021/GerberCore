# Loaded only into the disposable PTY Gerber module instance. Never calls a real provider.
$script:GerberTerminalUpdateStartup = $false
. (Join-Path $PSScriptRoot 'TestHarness.UpdateBatch.ps1')
function script:Get-GerberTerminalUpdateFixture {
    param()
    if (-not (Test-Path -LiteralPath $script:GerberTerminalUpdateFixturePath)) {
        return @{ disposition = 'UpToDate'; startupStatus = 'Unavailable' }
    }
    Get-Content -LiteralPath $script:GerberTerminalUpdateFixturePath -Raw | ConvertFrom-Json -AsHashtable
}

function script:Get-GerberTerminalUpdateState {
    param()
    $path = Join-Path (Split-Path $script:GerberTerminalUpdateFixturePath -Parent) 'update-state.json'
    if (-not (Test-Path -LiteralPath $path)) { return @{ discoveryCount = 0; startupDiscoveryCount = 0; installCount = 0 } }
    Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
}

function script:Get-GerberTerminalUpdateErrorMessage {
    param([hashtable]$Fixture)
    if ($Fixture.Contains('installErrorMessage')) { return $Fixture.installErrorMessage }
    'raw-update-token'
}

function script:Write-GerberTerminalUpdateState {
    param([hashtable]$State)
    $path = Join-Path (Split-Path $script:GerberTerminalUpdateFixturePath -Parent) 'update-state.json'
    [IO.File]::WriteAllText($path, ($State | ConvertTo-Json))
}

function script:Invoke-GerberUpdateProbe {
    param([object]$Request, [int]$TimeoutMilliseconds)
    if ($TimeoutMilliseconds -ne 2000) { throw 'Unexpected startup budget.' }
    $script:GerberTerminalUpdateStartup = $true
    try {
        Get-GerberCoreUpdateState -Request $Request | Select-Object Status, Name, Installed, Available, Repository, Message
    } finally { $script:GerberTerminalUpdateStartup = $false }
}

function script:Get-PSModuleUpdate {
    [CmdletBinding()]
    param([object]$Module, [Alias('RepositoryUri')][object]$Repository, [hashtable]$Policy, [pscredential]$Credential)
    Assert-GerberTerminalUpdateRequest $Module $Repository $Policy $Credential
    $fixture = Get-GerberTerminalUpdateFixture
    $state = Write-GerberTerminalUpdateDiscovery $Module $Repository $Policy
    if ($Module.Name -eq 'Gerber') {
        Assert-GerberTerminalUpdateDiscovery $fixture $state
    }
    $plan = Get-GerberTerminalUpdatePlanForModule $Module $Repository $Policy $fixture
    $script:GerberTerminalLiveUpdatePlans[$Module.Name] = $plan
    $plan
}

function script:Assert-GerberTerminalUpdateDiscovery {
    param([hashtable]$Fixture, [hashtable]$State)
    if ($Fixture.Contains('noMatchingPackage')) { Write-Error -ErrorId 'PMU.PackageNotFound' -Message 'No eligible fixture package' -ErrorAction Stop }
    if ($Fixture.Contains('discoveryError')) { Write-Error -ErrorId $Fixture.discoveryError -Message 'raw-update-token' -ErrorAction Stop }
    if (Test-GerberTerminalUpdateFailure $Fixture $State) { throw 'raw-update-token in provider failure' }
}

function script:Test-GerberTerminalUpdateFailure {
    param([hashtable]$Fixture, [hashtable]$State)
    if ($script:GerberTerminalUpdateStartup) { return $Fixture.startupStatus -eq 'Unavailable' }
    if (-not $Fixture.Contains('failDiscoveryCount')) { return $false }
    $State.discoveryCount -le $Fixture.failDiscoveryCount
}

function script:Assert-GerberTerminalUpdateRequest {
    param([object]$Module, [object]$Repository, [hashtable]$Policy, [pscredential]$Credential)
    if ($Module.Name -ne 'Gerber') {
        return Assert-GerberTerminalPluginUpdateRequest $Module $Repository $Policy
    }
    Assert-GerberTerminalCoreUpdatePolicy $Repository $Policy $Credential
}

function script:Assert-GerberTerminalCoreUpdatePolicy {
    param([string]$Repository, [hashtable]$Policy, [pscredential]$Credential)
    if ($Repository -cne 'PSGallery') {
        throw 'Unexpected terminal update target.'
    }
    if ($Policy.Channel -cnotin @('Stable', 'IncludePrerelease')) {
        throw 'Unexpected terminal update policy.'
    }
    Assert-GerberTerminalCoreUpdateEndpoint $Policy $Credential
}

function script:Assert-GerberTerminalCoreUpdateEndpoint {
    param([hashtable]$Policy, [pscredential]$Credential)
    if ($Policy.Scope -cne 'CurrentUser') {
        throw 'Unexpected terminal update policy.'
    }
    if ($Policy.ExpectedRepositoryUri.AbsoluteUri -cne 'https://www.powershellgallery.com/api/v2') {
        throw 'Unexpected terminal update endpoint.'
    }
    if ($null -ne $Credential) {
        throw 'Core must not request credentials.'
    }
}

function script:Get-GerberTerminalUpdatePlan {
    param([hashtable]$Fixture, [string]$Channel)
    $installed = if ($Fixture.Contains('installedVersion')) { $Fixture.installedVersion } else { '0.1.0-preview' }
    $target = if ($Fixture.Contains('targetVersion')) { $Fixture.targetVersion } else { '0.2.0' }
    [pscustomobject]@{
        ModuleName = 'Gerber'; InstalledVersion = $installed; TargetVersion = $target
        ModuleGuid = 'ec5ae6fe-540b-48c2-a6d1-cb39aac6c444'
        TargetInstalledPath = Join-Path (Split-Path $script:GerberTerminalUpdateFixturePath) 'simulated-core-target'
        RepositoryName = 'PSGallery'; UpdateAvailable = $Fixture.disposition -eq 'UpdateAvailable'
        RepositoryUri = 'https://www.powershellgallery.com/api/v2'; Channel = $Channel; Scope = 'CurrentUser'
        Disposition = $Fixture.disposition; RestartRequired = $false
        RequiresRepositoryTrust = $false; RequiresLicenseAcceptance = $false
    }
}

$script:GerberTerminalSaveConfiguration = ${function:Save-GerberUserConfiguration}
function script:Save-GerberUserConfiguration {
        [CmdletBinding(SupportsShouldProcess)]
        param([object]$Configuration)
        if (-not $PSCmdlet.ShouldProcess('disposable terminal configuration', 'Save')) {
            return
        }
        $fixture = Get-GerberTerminalUpdateFixture
        if ($fixture.Contains('failPolicySaveCount') -and $fixture.failPolicySaveCount -gt 0) {
            $fixture.failPolicySaveCount--
            [IO.File]::WriteAllText($script:GerberTerminalUpdateFixturePath, ($fixture | ConvertTo-Json))
            throw [IO.IOException]::new('Simulated configuration write failure.')
        }
        & $script:GerberTerminalSaveConfiguration -Configuration $Configuration -Confirm:$false
}

function script:Install-PSModuleUpdate {
    [CmdletBinding(SupportsShouldProcess)]
    param([object]$Update, [pscredential]$Credential, [switch]$TrustRepository, [switch]$AcceptLicense)
    $null = $Credential, $TrustRepository, $AcceptLicense
    Assert-GerberTerminalLiveUpdatePlan $Update
    if (-not $PSCmdlet.ShouldProcess('disposable terminal fixture', 'Record simulated installation')) { return }
    Write-GerberTerminalBatchInstall $Update
    $fixture = Get-GerberTerminalUpdateFixture
    Assert-GerberTerminalInstallOutcome $Update $fixture
    Get-GerberTerminalInstallResult $Update
}
