function Get-GerberUpdateItem {
    param([object]$State)
    [pscustomobject]@{
        Kind        = 'Core'
        State       = $State
        Plugin      = $null
        Credential  = $null
        MinimumCore = $null
        AutoAdded   = $false
    }
}
