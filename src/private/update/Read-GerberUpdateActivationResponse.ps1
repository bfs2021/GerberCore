function Read-GerberUpdateActivationResponse {
    param([string]$Text, [string]$ExpectedCoreVersion)
    try {
        $response = $Text | ConvertFrom-Json -ErrorAction Stop
        Assert-GerberUpdateActivationResponse $response $ExpectedCoreVersion
        Get-GerberUpdateActivationSummary -Status $response.Status -Version $response.Version
    } catch {
        Get-GerberUpdateActivationSummary -Status 'Unverified'
    }
}

function Assert-GerberUpdateActivationResponse {
    param([object]$Response, [string]$ExpectedCoreVersion)
    if ($Response.Protocol -ne 1) {
        throw 'Unsupported activation protocol.'
    }
    if ($Response.Status -notin @('Verified', 'Failed', 'Unverified')) {
        throw 'Invalid activation status.'
    }
    if ($Response.Version -cne $ExpectedCoreVersion) {
        throw 'Unexpected Core version.'
    }
}
