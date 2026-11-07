function Test-GerberUpdateActivation {
    param([object]$Item, [object]$Result, [object]$CoreState, [object]$CoreVersion)
    try {
        $payload = Get-GerberUpdateActivationPayload $Item $Result $CoreState $CoreVersion
        Invoke-GerberUpdateActivationProbe $payload
    } catch {
        Assert-GerberUpdateNotCancelled $_
        Get-GerberUpdateActivationSummary -Status 'Unverified'
    }
}
