function Get-GerberHttpTransportFailureHint {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [System.Exception]$Exception
    )

    if (Test-GerberHttpNameResolutionFailure -Exception $Exception) {
        return 'Verify DNS/VPN/network access and try again.'
    }

    if (Test-GerberHttpTimeoutFailure -Exception $Exception) {
        return 'Try again in a moment.'
    }

    return ''
}

function Test-GerberHttpNameResolutionFailure {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [System.Exception]$Exception
    )

    if ($null -eq $Exception) {
        return $false
    }

    if ($Exception.Message -match 'nodename nor servname provided, or not known|Name or service not known|No such host is known|Temporary failure in name resolution') {
        return $true
    }

    return Test-GerberHttpNameResolutionFailure -Exception $Exception.InnerException
}
