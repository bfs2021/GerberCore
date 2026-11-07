param([Parameter(Mandatory)][string]$Payload)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Read-ActivationValue {
    param([object]$Data, [string[]]$Path)
    foreach ($key in $Path) {
        if ($null -eq $Data -or -not $Data.Contains($key)) {
            return $null
        }
        $Data = $Data[$key]
    }
    $Data
}

function Read-ActivationVersion {
    param([hashtable]$Manifest)
    $version = [string]$Manifest.ModuleVersion
    $prerelease = Read-ActivationValue $Manifest @('PrivateData', 'PSData', 'Prerelease')
    if ($prerelease) {
        $version += "-$prerelease"
    }
    [System.Management.Automation.SemanticVersion]$version
}

function Get-ActivationSummary {
    param([string]$Status, [string]$Version)
    [pscustomobject]@{
        Protocol = 1
        Status   = $Status
        Version  = $Version
    }
}

function Import-ActivationCore {
    param([hashtable]$Data)
    $manifest = Import-PowerShellDataFile -LiteralPath $Data.CoreManifest
    if ([guid]$manifest.GUID -ne [guid]'ec5ae6fe-540b-48c2-a6d1-cb39aac6c444') {
        throw [System.InvalidOperationException]::new('Unexpected Core identity.')
    }
    if ((Read-ActivationVersion $manifest).ToString() -cne $Data.CoreVersion) {
        throw [System.InvalidOperationException]::new('Unexpected Core version.')
    }
    Import-Module -Name $Data.CoreManifest -PassThru -ErrorAction Stop -WarningAction SilentlyContinue
}

function Initialize-ActivationRegistry {
    param([System.Management.Automation.PSModuleInfo]$Core, [string]$Version)
    $builder = [pscustomobject]@{
        GerberVersion = [System.Management.Automation.SemanticVersion]$Version
        CommandList   = [System.Collections.Generic.List[object]]::new()
        PluginList    = [System.Collections.Generic.List[object]]::new()
    }
    & $Core {
        param($builder)
        Add-GerberOwnedCommandDefinitionList -RegisteredCommandList $builder.CommandList `
            -CommandDefinitionList (Get-GerberCoreCommandDefinitionList) -OwnerName 'Gerber.Core' -OwnerType 'Core'
    } $builder
    $builder
}

function Read-ActivationPluginRecord {
    param([hashtable]$Record)
    $manifest = Import-PowerShellDataFile -LiteralPath $Record.Path
    if ([guid]$manifest.GUID -ne [guid]$Record.Guid) {
        throw [System.InvalidOperationException]::new('Unexpected plugin identity.')
    }
    if ((Read-ActivationVersion $manifest).ToString() -cne $Record.Version) {
        throw [System.InvalidOperationException]::new('Unexpected plugin version.')
    }
    $manifest
}

function Add-ActivationPlugin {
    param([System.Management.Automation.PSModuleInfo]$Core, [object]$Builder, [hashtable]$Record)
    $manifest = Read-ActivationPluginRecord $Record
    & $Core {
        param($builder, $manifest, $record)
        $plugin = ConvertTo-GerberPluginManifestRecord -Manifest $manifest -ManifestPath $record.Path
        Assert-GerberPluginModuleManifest -ModuleInfo $plugin
        $lifecycle = [pscustomobject]@{
            IsAssociated = $true
            IsEnabled    = $true
            ShouldLoad   = $true
        }
        Add-GerberPluginToRegistryBuilder -RegistryBuilder $builder -PluginModule $plugin -LifecycleState $lifecycle
    } $Builder $manifest $Record 3>$null 4>$null 5>$null 6>$null
}

function Test-ActivationContext {
    param([System.Management.Automation.PSModuleInfo]$Core, [object]$Builder, [object[]]$Plugins)
    try {
        foreach ($plugin in $Plugins) {
            Add-ActivationPlugin -Core $Core -Builder $Builder -Record $plugin
        }
        $true
    } catch {
        $false
    }
}

function Test-ActivationTarget {
    param([System.Management.Automation.PSModuleInfo]$Core, [object]$Builder, [hashtable]$Data)
    if ($null -eq $Data.Target) {
        return Get-ActivationSummary 'Verified' $Data.CoreVersion
    }
    try {
        Add-ActivationPlugin -Core $Core -Builder $Builder -Record $Data.Target
        Get-ActivationSummary 'Verified' $Data.CoreVersion
    } catch {
        Get-ActivationSummary 'Failed' $Data.CoreVersion
    }
}

function Invoke-ActivationValidation {
    param([hashtable]$Data)
    $core = Import-ActivationCore $Data
    $builder = Initialize-ActivationRegistry $core $Data.CoreVersion
    if (-not (Test-ActivationContext -Core $core -Builder $builder -Plugins $Data.OtherPlugins)) {
        return Get-ActivationSummary 'Unverified' $Data.CoreVersion
    }
    Test-ActivationTarget -Core $core -Builder $builder -Data $Data
}

try {
    $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Payload))
    $data = $json | ConvertFrom-Json -AsHashtable
    $summary = Invoke-ActivationValidation $data
} catch {
    $summary = Get-ActivationSummary 'Unverified' ''
}
$summary | ConvertTo-Json -Compress
