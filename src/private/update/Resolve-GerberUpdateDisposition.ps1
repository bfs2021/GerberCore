function Resolve-GerberUpdateDisposition {
    param([object]$Plan)
    $statuses = @{
        UpdateAvailable                 = 'Available'
        UpToDate                        = 'UpToDate'
        AlreadyInstalledRestartRequired = 'RestartRequired'
    }
    $status = $statuses[$Plan.Disposition]
    if (-not $status) {
        throw [System.InvalidOperationException]::new('Unsupported PSModuleUpdate disposition.')
    }
    $status
}
