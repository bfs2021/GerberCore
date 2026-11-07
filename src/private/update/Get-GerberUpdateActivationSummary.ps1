function Get-GerberUpdateActivationSummary {
    param([string]$Status, [string]$Version = '')
    [pscustomobject]@{
        Status  = $Status
        Version = $Version
    }
}
