function Get-GerberCoreUpdateState {
    param([object]$Request)
    $state = Get-GerberCoreUpdateOverview
    try {
        $state.Installed = Get-GerberCoreInstalledVersion $Request
        if ($null -eq $Request) { $Request = Resolve-GerberCoreUpdateRequest }
        $state.Status = 'Unavailable'
        return Complete-GerberCoreUpdateOverview -State $state -Request $Request
    } catch [System.Management.Automation.PipelineStoppedException] { throw
    } catch [System.OperationCanceledException] { throw
    } catch {
        return Complete-GerberCoreUpdateFailure $state $_
    }
}

function Get-GerberCoreInstalledVersion {
    param([object]$Request)
    $module = if ($null -eq $Request) {
        (Get-Command -Name Invoke-Gerber -CommandType Function -ErrorAction Stop).Module
    } else { $Request.Module }
    if ($null -eq $module) { return '-' }
    $psData = Get-GerberModulePrivateDataValueOrNull -InputObject $module.PrivateData -Name 'PSData'
    $prerelease = Get-GerberModulePrivateDataValueOrNull -InputObject $psData -Name 'Prerelease'
    if ([string]::IsNullOrEmpty($prerelease)) { return [string]$module.Version }
    '{0}-{1}' -f $module.Version, $prerelease
}

function Complete-GerberCoreUpdateFailure {
    param([object]$State, [System.Management.Automation.ErrorRecord]$ErrorRecord)
    if (($ErrorRecord.FullyQualifiedErrorId -split ',')[0] -eq 'PMU.PackageNotFound') { $State.Status = 'NoMatchingPackage' }
    $State.Message = Get-GerberUpdateFailureMessage $ErrorRecord
    $State
}

function Get-GerberCoreUpdateOverview {
    param()
    [pscustomobject]@{
        Name = 'Gerber'; Installed = '-'; Available = '-'; Repository = 'PSGallery'
        Status = 'Unavailable'; Plan = $null; Channel = $null
        Message = 'Core update discovery is unavailable. Run /update list to retry PSGallery.'
    }
}

function Complete-GerberCoreUpdateOverview {
    param([object]$State, [object]$Request)
    $policy = Resolve-GerberCoreUpdatePolicy
    $State.Channel = $policy.Channel
    $plan = Get-PSModuleUpdate -Module $Request.Module -Repository PSGallery -Policy $policy `
        -ErrorAction Stop -WarningAction SilentlyContinue -InformationAction SilentlyContinue -Verbose:$false -Debug:$false
    Complete-GerberCorePlanOverview -State $State -Plan $plan
}

function Complete-GerberCorePlanOverview {
    param([object]$State, [object]$Plan)
    $State.Installed = $Plan.InstalledVersion
    $State.Available = $Plan.TargetVersion
    $State.Status = Resolve-GerberUpdateDisposition $Plan
    $State.Message = Get-GerberUpdateDispositionMessage $State.Status $State.Channel
    $State.Plan = $Plan
    $State
}

function Get-GerberUpdateDispositionMessage {
    param([string]$Status, [string]$Channel)
    $label = Get-GerberCoreUpdateChannelLabel $Channel
    $messages = @{
        Available = 'A Core update is available.'
        UpToDate = "Core is up to date according to PSGallery and the selected update policy: $label."
        RestartRequired = 'A newer Core version is already installed. Restart PowerShell before using Gerber again.'
    }
    $messages[$Status]
}
