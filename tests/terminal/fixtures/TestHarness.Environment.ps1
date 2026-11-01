function Initialize-GerberTerminalClipboardShim {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $script:GerberTerminalClipboardStatePath = $Path
    $script:GerberTerminalClipboardValueList = @()
    Initialize-GerberTerminalFile -Path $Path -Value @{
        values = @()
    }
    function global:Set-Clipboard {
        [CmdletBinding()]
        param(
            [AllowEmptyString()]
            [string]$Value
        )

        $script:GerberTerminalClipboardValueList += @(@{
                value = $Value
                length = $Value.Length
            })
        Write-GerberTerminalJsonFile -Path $script:GerberTerminalClipboardStatePath -Value @{
            values = @($script:GerberTerminalClipboardValueList)
        }
    }
}

function Get-GerberTerminalHttpException {
    [OutputType([System.Exception], [System.Threading.Tasks.TaskCanceledException])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Type = 'generic'
    )

    switch ($Type) {
        'timeout' {
            return [System.Threading.Tasks.TaskCanceledException]::new($Message)
        }
        default {
            return [System.Exception]::new($Message)
        }
    }
}

function ConvertTo-GerberTerminalHttpBodyMap {
    [OutputType([hashtable], [object[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Body
    )

    if ($Body -is [string]) {
        try {
            $Body = $Body | ConvertFrom-Json -AsHashtable -NoEnumerate
        } catch {
            return @{}
        }
    }

    if (Test-GerberTerminalSequenceValue -Value $Body) {
        return ,@($Body)
    }

    if ($Body -isnot [System.Collections.IDictionary]) {
        return @{}
    }

    $bodyMap = @{}
    foreach ($key in $Body.Keys) {
        $bodyMap[[string]$key] = $Body[$key]
    }

    return $bodyMap
}

function Test-GerberTerminalSequenceValue {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($Value -isnot [System.Collections.IEnumerable]) {
        return $false
    }
    return ($Value -isnot [string]) -and ($Value -isnot [System.Collections.IDictionary])
}

function ConvertTo-GerberTerminalComparableValue {
    [OutputType([System.Collections.Specialized.OrderedDictionary], [object[]], [object])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($Value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in @($Value.Keys | Sort-Object)) {
            $result[[string]$key] = ConvertTo-GerberTerminalComparableValue -Value $Value[$key]
        }
        return $result
    }

    if (($Value -is [System.Collections.IEnumerable]) -and ($Value -isnot [string])) {
        return @($Value | ForEach-Object { ConvertTo-GerberTerminalComparableValue -Value $_ })
    }

    return $Value
}

function ConvertTo-GerberTerminalComparableJson {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    return ConvertTo-GerberTerminalComparableValue -Value $Value |
        ConvertTo-Json -Depth 20 -Compress
}

function ConvertTo-GerberTerminalSafeHeaderMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [hashtable]$Headers
    )

    $safeHeaders = @{}
    if ($null -eq $Headers) {
        return $safeHeaders
    }
    foreach ($key in @($Headers.Keys)) {
        $safeHeaders[[string]$key] = if ($key -match '^(Proxy-)?Authorization$') {
            '<redacted>'
        } else {
            [string]$Headers[$key]
        }
    }
    return $safeHeaders
}

function Add-GerberTerminalHttpRequestLogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StatePath,

        [Parameter(Mandatory)]
        [hashtable]$RequestEntry
    )

    $requestLog = Read-GerberTerminalJsonFile -Path $StatePath -DefaultValue @{
        requests = @()
    }
    $requestLog.requests = @($requestLog.requests + @($RequestEntry))
    Write-GerberTerminalJsonFile -Path $StatePath -Value $requestLog
}

function Find-GerberTerminalHttpFixtureMatch {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Fixture,

        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Uri,

        [object]$Body = @{}
    )

    foreach ($entry in @($Fixture.requests)) {
        if (-not (Test-GerberTerminalHttpFixtureIdentity -Entry $entry -Method $Method -Uri $Uri)) {
            continue
        }

        if (-not (Test-GerberTerminalHttpFixtureBody -Entry $entry -Body $Body)) {
            continue
        }

        return $entry
    }

    return $null
}

function Test-GerberTerminalHttpFixtureIdentity {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Entry,

        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Uri
    )

    return ($Entry.method -eq $Method) -and (
        (ConvertTo-GerberTerminalCanonicalUri -Uri ([string]$Entry.uri)) -eq
        (ConvertTo-GerberTerminalCanonicalUri -Uri $Uri)
    )
}

function ConvertTo-GerberTerminalCanonicalUri {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    $parsedUri = [uri]$Uri
    $queryItemList = @(
        $parsedUri.Query.TrimStart('?').Split(
            '&',
            [System.StringSplitOptions]::RemoveEmptyEntries
        ) | Sort-Object
    )
    $queryText = if ($queryItemList.Count -eq 0) { '' } else { "?$($queryItemList -join '&')" }
    return "$($parsedUri.GetLeftPart([System.UriPartial]::Path))$queryText"
}

function Test-GerberTerminalHttpFixtureBody {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Entry,

        [object]$Body = @{}
    )

    if (-not $Entry.ContainsKey('expectedBody')) {
        return $true
    }

    return (ConvertTo-GerberTerminalComparableJson -Value $Entry.expectedBody) -eq
        (ConvertTo-GerberTerminalComparableJson -Value $Body)
}

function Resolve-GerberTerminalHttpFixtureResponse {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Fixture,

        [AllowNull()]
        [object]$MatchingEntry
    )

    if ($null -eq $MatchingEntry) {
        throw (Get-GerberTerminalHttpException -Message $fixture.defaultResult.message -Type ([string]$fixture.defaultResult.type))
    }

    if ($MatchingEntry.ContainsKey('error')) {
        throw (Get-GerberTerminalHttpException -Message $matchingEntry.error.message -Type ([string]$matchingEntry.error.type))
    }

    return $MatchingEntry.response |
        ConvertTo-Json -Depth 20 |
        ConvertFrom-Json
}

function Initialize-GerberTerminalHttpShim {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FixturePath,

        [Parameter(Mandatory)]
        [string]$StatePath
    )

    Initialize-GerberTerminalFile -Path $StatePath -Value @{
        requests = @()
    }
    $script:GerberTerminalHttpFixturePath = $FixturePath
    $script:GerberTerminalHttpStatePath = $StatePath
    Set-Item -Path Function:\global:Invoke-RestMethod -Value (Get-GerberTerminalRestMethodShim)
    Set-Item -Path Function:\global:Invoke-WebRequest -Value ${function:Invoke-GerberTerminalWebRequestShim}
}

function Get-GerberTerminalRestMethodShim {
    [OutputType([scriptblock])]
    [CmdletBinding()]
    param()

    return {
        [CmdletBinding()]
        param(
            [string]$Method,
            [uri]$Uri,
            [int]$ConnectionTimeoutSeconds,
            [int]$OperationTimeoutSeconds,
            [string]$ContentType,
            [hashtable]$Headers,
            [object]$Body,
            [string]$ResponseHeadersVariable
        )

        $requestContext = [pscustomobject]@{
            Method = if ([string]::IsNullOrWhiteSpace($Method)) { 'Get' } else { $Method }
            Uri = $Uri.AbsoluteUri
            Headers = ConvertTo-GerberTerminalSafeHeaderMap -Headers $Headers
            Body = ConvertTo-GerberTerminalHttpBodyMap -Body $Body
            Transport = 'Invoke-RestMethod'
            ConnectionTimeoutSeconds = $ConnectionTimeoutSeconds
            OperationTimeoutSeconds = $OperationTimeoutSeconds
            ContentType = $ContentType
        }
        $resolution = Resolve-GerberTerminalHttpInvocation -RequestContext $requestContext
        Write-GerberTerminalHttpResponseHeader `
            -VariableName $ResponseHeadersVariable `
            -MatchingEntry $resolution.MatchingEntry
        return Resolve-GerberTerminalHttpFixtureResponse `
            -Fixture $resolution.Fixture `
            -MatchingEntry $resolution.MatchingEntry
    }
}

function Invoke-GerberTerminalWebRequestShim {
    [CmdletBinding()]
    param(
        [string]$Method = 'Get',
        [uri]$Uri,
        [hashtable]$Headers,
        [switch]$UseBasicParsing
    )

    $null = $UseBasicParsing
    $requestContext = [pscustomobject]@{
        Method = $Method
        Uri = $Uri.AbsoluteUri
        Headers = ConvertTo-GerberTerminalSafeHeaderMap -Headers $Headers
        Body = @{}
        Transport = 'Invoke-WebRequest'
        ConnectionTimeoutSeconds = 0
        OperationTimeoutSeconds = 0
        ContentType = ''
    }
    $resolution = Resolve-GerberTerminalHttpInvocation -RequestContext $requestContext
    $matchingEntry = Resolve-GerberTerminalWebResponseEntry -Resolution $resolution
    return [pscustomobject]@{
        Content = [string]$matchingEntry.rawContent
    }
}

function Resolve-GerberTerminalWebResponseEntry {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Resolution
    )

    $matchingEntry = $Resolution.MatchingEntry
    if ($null -eq $matchingEntry) {
        throw (Get-GerberTerminalHttpException `
            -Message $Resolution.Fixture.defaultResult.message `
            -Type ([string]$Resolution.Fixture.defaultResult.type))
    }
    if ($matchingEntry.ContainsKey('error')) {
        throw (Get-GerberTerminalHttpException `
            -Message $matchingEntry.error.message `
            -Type ([string]$matchingEntry.error.type))
    }
    return $matchingEntry
}

function Resolve-GerberTerminalHttpInvocation {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RequestContext
    )

    $fixture = Read-GerberTerminalJsonFile -Path $script:GerberTerminalHttpFixturePath -DefaultValue @{
        defaultResult = @{
            type = 'error'
            message = 'No terminal HTTP fixture matched this request.'
        }
        requests = @()
    }
    Add-GerberTerminalHttpRequestLogEntry `
        -StatePath $script:GerberTerminalHttpStatePath `
        -RequestEntry (ConvertTo-GerberTerminalHttpRequestLogEntry -RequestContext $RequestContext)
    $matchingEntry = Find-GerberTerminalHttpFixtureMatch `
        -Fixture $fixture `
        -Method $RequestContext.Method `
        -Uri $RequestContext.Uri `
        -Body $RequestContext.Body
    return [pscustomobject]@{
        Fixture = $fixture
        MatchingEntry = $matchingEntry
    }
}

function ConvertTo-GerberTerminalHttpRequestLogEntry {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RequestContext
    )

    return @{
        method = $RequestContext.Method
        uri = $RequestContext.Uri
        transport = $RequestContext.Transport
        connectionTimeoutSeconds = $RequestContext.ConnectionTimeoutSeconds
        operationTimeoutSeconds = $RequestContext.OperationTimeoutSeconds
        contentType = $RequestContext.ContentType
        headers = $RequestContext.Headers
        body = $RequestContext.Body
    }
}

function Write-GerberTerminalHttpResponseHeader {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$VariableName,

        [AllowNull()]
        [object]$MatchingEntry
    )

    if ([string]::IsNullOrWhiteSpace($VariableName) -or $null -eq $MatchingEntry) {
        return
    }

    if ($MatchingEntry.ContainsKey('responseHeaders')) {
        Set-Variable -Name $VariableName -Value $MatchingEntry.responseHeaders -Scope 2
    }
}

function Initialize-GerberPromptTracePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $directoryPath = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $directoryPath -Force
    }

    $script:GerberTerminalConfigPath = Join-Path $directoryPath 'GerberCore.json'
    if (-not (Test-Path -LiteralPath $script:GerberTerminalConfigPath -PathType Leaf)) {
        [System.IO.File]::WriteAllText(
            $script:GerberTerminalConfigPath,
            '{"schemaVersion":1}',
            [System.Text.Encoding]::UTF8
        )
    }

    function global:Resolve-GerberConfigPath {
        [OutputType([string])]
        [CmdletBinding()]
        param(
            [string]$Path
        )

        if ([string]::IsNullOrWhiteSpace($Path)) {
            return $script:GerberTerminalConfigPath
        }

        return [System.IO.Path]::GetFullPath($Path)
    }
}
