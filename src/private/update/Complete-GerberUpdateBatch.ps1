function Complete-GerberUpdateBatch {
    param([object]$Batch)
    $execution = Initialize-GerberUpdateExecution $Batch
    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $Batch.Items) {
        $result = Complete-GerberUpdateItem $execution $item
        $results.Add($result)
        if ($item.Kind -eq 'Core') {
            Complete-GerberBatchCoreVerification $execution $result
        }
        $execution.Cancelled = $result.Outcome -eq 'Cancelled'
    }
    Complete-GerberBatchPluginVerification $execution @($results)
    @($results)
}

function Initialize-GerberUpdateExecution {
    param([object]$Batch)
    $execution = @{
        Batch       = $Batch
        CoreVersion = $Batch.InstalledCoreVersion
        Cancelled   = $false
    }
    if (@($Batch.Items | Where-Object Kind -EQ 'Core').Count -eq 0) {
        $core = Get-GerberBatchItemResult -Item (Get-GerberUpdateItem $Batch.CoreState) -Outcome 'NotAttempted' -Message ''
        Complete-GerberBatchCoreVerification $execution $core
    }
    $execution
}

function Complete-GerberUpdateItem {
    param([hashtable]$Execution, [object]$Item)
    if ($Execution.Cancelled) {
        return Get-GerberBatchItemResult -Item $Item -Outcome 'Cancelled' -Message 'Not attempted: batch cancelled.'
    }
    if (-not (Test-GerberBatchItemReady $Execution $Item)) {
        return Get-GerberBatchItemResult -Item $Item -Outcome 'Blocked' -Message 'Update blocked. Recheck approval, Core requirements and policy with /update list.'
    }
    Invoke-GerberBatchItemInstallation $Item
}

function Invoke-GerberBatchItemInstallation {
    param([object]$Item)
    try {
        $pmu = Submit-GerberBatchItem $Item
        ConvertTo-GerberBatchInstallResult $Item $pmu
    } catch {
        Assert-GerberUpdateNotCancelled $_
        Get-GerberBatchItemResult -Item $Item -Outcome 'Failed' -Message 'Installation failed. Inspect PMU journals and the selected installation before retrying; no rollback is assumed.'
    }
}

function Test-GerberBatchItemReady {
    param([hashtable]$Execution, [object]$Item)
    if ($Item.State.Status -ne 'Available') {
        return $false
    }
    if ($Item.Kind -eq 'Core') {
        return $true
    }
    Test-GerberPluginBatchItemReady $Execution $Item
}

function Test-GerberPluginBatchItemReady {
    param([hashtable]$Execution, [object]$Item)
    if ($null -eq $Execution.CoreVersion -or $null -eq $Item.MinimumCore) {
        return $false
    }
    if ($Item.MinimumCore -gt $Execution.CoreVersion) {
        return $false
    }
    if ($Item.State.Channel -cne (Resolve-GerberCoreUpdatePolicy).Channel) {
        return $false
    }
    Test-GerberCurrentPluginUpdateSelection $Item
}

function Test-GerberCurrentPluginUpdateSelection {
    param([object]$Item)
    $entries = @(Get-GerberPluginInventory | Where-Object Guid -EQ $Item.Plugin.Guid)
    if ($entries.Count -ne 1) {
        return $false
    }
    $entry = $entries[0]
    if ($entry.Name -cne $Item.Plugin.Name -or $entry.ModulePath -cne $Item.Plugin.ModulePath) {
        return $false
    }
    Test-GerberPluginUpdateEligibility $entry
}

function Submit-GerberBatchItem {
    param([object]$Item)
    if ($Item.Kind -eq 'Core') {
        return Invoke-GerberCoreUpdateInstall -State $Item.State -PassThru
    }
    Install-PSModuleUpdate -Update $Item.State.Plan -Credential $Item.Credential -Confirm:$false `
        -TrustRepository:$Item.State.Plan.RequiresRepositoryTrust -AcceptLicense:$Item.State.Plan.RequiresLicenseAcceptance `
        -ErrorAction Stop -WarningAction SilentlyContinue -InformationAction SilentlyContinue -Verbose:$false -Debug:$false
}

function Get-GerberBatchItemResult {
    param([object]$Item, [string]$Outcome, [string]$Message)
    [pscustomobject]@{
        Item               = $Item
        Outcome            = $Outcome
        VerificationStatus = 'NotRun'
        RecoveryStatus     = 'NotRequired'
        ActivationStatus   = 'NotRun'
        RestartRequired    = $false
        Message            = $Message
        PmuResult          = $null
    }
}

function ConvertTo-GerberBatchInstallResult {
    param([object]$Item, [object]$Pmu)
    if ($Pmu -is [string]) {
        return Get-GerberBatchItemResult -Item $Item -Outcome 'Failed' -Message $Pmu
    }
    $result = Get-GerberBatchItemResult -Item $Item -Outcome $Pmu.Outcome -Message 'Restart PowerShell before using installed updates; this session has not reloaded modules.'
    $result.PmuResult = $Pmu
    $result.VerificationStatus = $Pmu.VerificationStatus
    $result.RecoveryStatus = $Pmu.RecoveryStatus
    $result.RestartRequired = $Pmu.RestartRequired
    if (Test-GerberBatchInstallVerified $result) {
        $result.ActivationStatus = 'Unverified'
    }
    $result
}

function Test-GerberBatchInstallVerified {
    param([object]$Result)
    $Result.Outcome -in @('Installed', 'AlreadyInstalled') -and $Result.VerificationStatus -eq 'Verified'
}

function Complete-GerberBatchCoreVerification {
    param([hashtable]$Execution, [object]$Result)
    if ($Result.Outcome -eq 'Cancelled') {
        return
    }
    $expected = Resolve-GerberBatchCoreVersion $Execution $Result
    $probe = Read-GerberBatchCoreVerification -Execution $Execution -Result $Result -Expected $expected
    $Result.ActivationStatus = $probe.Status
    $Execution.CoreVersion = $null
    if ($probe.Status -eq 'Verified') {
        $Execution.CoreVersion = [System.Management.Automation.SemanticVersion]$probe.Version
    }
}

function Read-GerberBatchCoreVerification {
    param([hashtable]$Execution, [object]$Result, [object]$Expected)
    if ($null -eq $Expected) {
        return Get-GerberUpdateActivationSummary -Status 'Unverified'
    }
    Test-GerberUpdateActivation -Item $Result.Item -Result $Result.PmuResult `
        -CoreState $Execution.Batch.CoreState -CoreVersion $Expected
}

function Resolve-GerberBatchCoreVersion {
    param([hashtable]$Execution, [object]$Result)
    if (-not (Test-GerberBatchInstallVerified $Result)) {
        return $Execution.CoreVersion
    }
    $actual = Get-GerberModulePrivateDataValueOrNull $Result.PmuResult 'InstalledVersion'
    $parsed = $null
    $null = [System.Management.Automation.SemanticVersion]::TryParse([string]$actual, [ref]$parsed)
    $parsed
}

function Complete-GerberBatchPluginVerification {
    param([hashtable]$Execution, [object[]]$Results)
    if ($Execution.Cancelled) {
        return
    }
    foreach ($result in @($Results | Where-Object {
                $_.Item.Kind -eq 'Plugin'
            })) {
        Complete-GerberBatchPluginItemVerification $Execution $result
    }
}

function Complete-GerberBatchPluginItemVerification {
    param([hashtable]$Execution, [object]$Result)
    if (-not (Test-GerberBatchInstallVerified $Result)) {
        return
    }
    $probe = Test-GerberUpdateActivation -Item $Result.Item -Result $Result.PmuResult `
        -CoreState $Execution.Batch.CoreState -CoreVersion $Execution.CoreVersion
    $Result.ActivationStatus = $probe.Status
}
