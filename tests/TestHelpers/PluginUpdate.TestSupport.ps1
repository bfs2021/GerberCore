$backendRoot = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'src/private'
foreach ($name in @(
        'cli/Initialize-GerberCommandRegistry', 'plugins/Get-GerberPluginInventory',
        'config/Resolve-GerberCoreUpdatePolicy', 'update/Get-GerberCoreUpdateState',
        'update/Invoke-GerberCoreUpdateInstall', 'update/Invoke-GerberUpdateProbe',
        'plugins/Resolve-GerberPluginUpdateScopeRootMap', 'plugins/Resolve-GerberPluginUpdateScope'
    )) {
    . (Join-Path $backendRoot "$name.ps1")
}
foreach ($name in @(
        'Assert-GerberUpdateNotCancelled', 'Test-GerberPluginUpdateEligibility',
        'Get-GerberUpdateItem', 'Resolve-GerberUpdateDisposition', 'Resolve-GerberPluginUpdateState',
        'Resolve-GerberPluginUpdateStateList', 'Resolve-GerberUpdateBatch',
        'Complete-GerberUpdateBatch', 'Read-GerberUpdateActivationResponse',
        'Close-GerberUpdateProbe', 'Get-GerberUpdateActivationSummary',
        'Wait-GerberUpdateProbeOutput', 'Get-GerberUpdateActivationPayload',
        'Invoke-GerberUpdateActivationProbe', 'Test-GerberUpdateActivation'
    )) {
    $path = Join-Path $backendRoot "update/$name.ps1"
    if (Test-Path -LiteralPath $path) {
        . $path
    }
}

function Get-TestPluginUpdateEntry {
    param([string]$Name = 'Gerber.Example')
    [pscustomobject]@{
        Name           = $Name
        Guid           = '7dd21b37-e080-4240-b05f-ec727389035e'
        Version        = '1.0.0'
        ModulePath     = Join-Path (Join-Path $TestDrive $Name) "$Name.psd1"
        ApprovalStatus = 'Approved'
        IsAssociated   = $true
        IsEnabled      = $true
        IsDiscovered   = $true
    }
}

function Get-TestPluginUpdatePlan {
    param([string]$Name = 'Gerber.Example', [string]$Target = '2.0.0')
    [pscustomobject]@{
        ModuleName                = $Name
        InstalledVersion          = '1.0.0'
        TargetVersion             = $Target
        RepositoryName            = 'PSGallery'
        RepositoryUri             = 'https://www.powershellgallery.com/api/v2'
        Scope                     = 'CurrentUser'
        Channel                   = 'Stable'
        Disposition               = 'UpdateAvailable'
        RequiresRepositoryTrust   = $false
        RequiresLicenseAcceptance = $false
    }
}

function Get-TestPluginUpdateItem {
    param([string]$Name = 'Gerber.Example')
    [pscustomobject]@{
        Kind        = 'Plugin'
        State       = Get-TestUpdateOverview -Name $Name -Installed '1.0.0' -Target '2.0.0'
        Plugin      = Get-TestPluginUpdateEntry $Name
        Credential  = $null
        MinimumCore = $null
        AutoAdded   = $false
    }
}

function Get-TestCoreUpdateState {
    param([string]$Installed = '0.2.0', [string]$Target = '0.3.0')
    Get-TestUpdateOverview -Name 'Gerber' -Installed $Installed -Target $Target
}

function Get-TestUpdateOverview {
    param([string]$Name, [string]$Installed, [string]$Target)
    $state = Get-GerberCoreUpdateOverview
    $state.Name = $Name
    $state.Plan = Get-TestPluginUpdatePlan $Name $Target
    $state.Plan.InstalledVersion = $Installed
    $state.Installed = $Installed
    $state.Available = $Target
    $state.Status = 'Available'
    $state.Channel = 'Stable'
    $state
}

function Get-TestPluginTargetManifest {
    param([string]$Minimum = '0.2.0')
    @{
        GUID          = '7dd21b37-e080-4240-b05f-ec727389035e'
        ModuleVersion = '2.0.0'
        PrivateData   = @{
            Gerber = @{
                Plugin               = $true
                ApiVersion           = '1'
                MinimumGerberVersion = $Minimum
            }
        }
    }
}

function Get-PSModuleUpdateTargetManifest {
    [CmdletBinding()]
    param($Plan, [pscredential]$Credential, [switch]$TrustRepository, [switch]$AcceptLicense)
    $null = $Plan, $Credential, $TrustRepository, $AcceptLicense
}

function Get-TestPluginInstallResult {
    param()
    [pscustomobject]@{
        Outcome            = 'Installed'
        VerificationStatus = 'Verified'
        RecoveryStatus     = 'NotRequired'
        RestartRequired    = $true
        InstalledVersion   = '2.0.0'
    }
}

if (-not (Get-Command Test-GerberUpdateActivation -ErrorAction SilentlyContinue)) {
    function Test-GerberUpdateActivation {
        param($Item, $Result, $CoreState, $CoreVersion)
        $null = $Item, $Result, $CoreState, $CoreVersion
    }
}
