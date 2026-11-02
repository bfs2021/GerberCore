function Resolve-GerberCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputText,

        [string[]]$ActionList = (Get-GerberActionList)
    )

    $trimmedInput = $InputText.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedInput)) {
        return ConvertTo-GerberResolvedCommand -Name $null -Arguments @() -Suggestions @() `
            -Outcome (ConvertTo-GerberCommandOutcome -IsValid $false -ErrorMessage 'Enter a command like /tools or choose a numbered menu option.')
    }

    return Resolve-GerberNonemptyCommandInput -InputText $trimmedInput -ActionList $ActionList
}

function Resolve-GerberNonemptyCommandInput {
    param(
        [string]$InputText,
        [string[]]$ActionList
    )

    $selection = 0
    if ([int]::TryParse($InputText, [ref]$selection)) {
        return Resolve-GerberNumericCommand -Selection $selection -ActionList $ActionList
    }

    if (-not $InputText.StartsWith('/')) {
        return Resolve-GerberRootSearchCommand -InputText $InputText -ActionList $ActionList
    }

    return Resolve-GerberSlashCommand -InputText $InputText -ActionList $ActionList
}

function Resolve-GerberRootSearchCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputText,

        [Parameter(Mandatory)]
        [string[]]$ActionList
    )

    $search = Initialize-GerberRootCommandSearch -InputText $InputText -ActionList $ActionList
    return ConvertTo-GerberRootSearchResolution -Search $search -InputText $InputText
}

function Initialize-GerberRootCommandSearch {
    param(
        [string]$InputText,
        [string[]]$ActionList
    )

    $catalog = Get-GerberCommandCatalog -ActionList $ActionList
    $leafActionList = @(Get-GerberLeafActionCommandList -Catalog $catalog)
    return [pscustomobject]@{
        SuggestionList = @(Get-GerberLeafActionSuggestionList -LeafActionList $leafActionList -InputText $InputText)
        ExactAction = Get-GerberExactLeafActionMatch -LeafActionList $leafActionList -InputText $InputText
    }
}

function ConvertTo-GerberRootSearchResolution {
    param(
        [pscustomobject]$Search,
        [string]$InputText
    )

    if ($null -eq $Search.ExactAction) {
        return ConvertTo-GerberUnmatchedSearchResolution -Search $Search -InputText $InputText
    }
    return ConvertTo-GerberResolvedCommand `
        -Outcome (ConvertTo-GerberCommandOutcome -IsValid $true -ErrorMessage $null) `
        -Name $Search.ExactAction.RootCommandName `
        -Arguments $Search.ExactAction.Arguments `
        -Suggestions $Search.SuggestionList
}

function ConvertTo-GerberUnmatchedSearchResolution {
    param(
        [pscustomobject]$Search,
        [string]$InputText
    )

    return ConvertTo-GerberResolvedCommand `
        -Outcome (ConvertTo-GerberCommandOutcome -IsValid $false -ErrorMessage (Get-GerberUnknownCommandMessage -InputText $InputText -SuggestionList $Search.SuggestionList)) `
        -Name $null `
        -Arguments @() `
        -Suggestions $Search.SuggestionList
}

function Resolve-GerberPromptInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputText,

        [ValidateSet('Root', 'Subcommand', 'Static', 'None')]
        [string]$SuggestionMode = 'Root',

        [string]$SuggestionCommandName,

        [System.Collections.IDictionary]$SuggestionSubcommandTable
    )

    switch ($SuggestionMode) {
        'None' {
            return ConvertTo-GerberResolvedCommand -Name $null -Arguments @() -Suggestions @() `
                -Outcome (ConvertTo-GerberCommandOutcome -IsValid $true -ErrorMessage $null)
        }
        'Subcommand' {
            $resolvedSubcommandTable = if ($null -eq $SuggestionSubcommandTable) {
                Get-GerberMenuSubcommandTable -CommandName $SuggestionCommandName
            } else {
                $SuggestionSubcommandTable
            }

            return Resolve-GerberSubcommandPromptInput `
                -CommandName $SuggestionCommandName `
                -InputText $InputText `
                -SubcommandTable $resolvedSubcommandTable
        }
        'Static' {
            return ConvertTo-GerberResolvedCommand -Name $null -Arguments @() -Suggestions @() `
                -Outcome (ConvertTo-GerberCommandOutcome -IsValid $true -ErrorMessage $null)
        }
        default {
            return Resolve-GerberCommand -InputText $InputText
        }
    }
}

function Resolve-GerberNumericCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Selection,

        [Parameter(Mandatory)]
        [string[]]$ActionList
    )

    if ($Selection -lt 1 -or $Selection -gt $ActionList.Count) {
        return ConvertTo-GerberResolvedCommand -Name $null -Arguments @() -Suggestions @() `
            -Outcome (ConvertTo-GerberCommandOutcome -IsValid $false -ErrorMessage "Menu option '$Selection' is not available.")
    }

    return ConvertTo-GerberResolvedCommand -Name $ActionList[$Selection - 1] -Arguments @() -Suggestions @() `
        -Outcome (ConvertTo-GerberCommandOutcome -IsValid $true -ErrorMessage $null)
}

function Resolve-GerberSubcommandPromptInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputText,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$SubcommandTable
    )

    if ([string]::IsNullOrWhiteSpace($InputText) -or -not $InputText.Trim().StartsWith('/')) {
        return ConvertTo-GerberResolvedCommand -Name $null -Arguments @() -Suggestions @() `
            -Outcome (ConvertTo-GerberCommandOutcome -IsValid $true -ErrorMessage $null)
    }

    $subcommandInput = Get-GerberPromptSubcommandInput -CommandName $CommandName -InputText $InputText
    $suggestionList = @(Get-GerberNamedSubcommandSuggestionList -CommandName $CommandName -SubcommandTable $SubcommandTable -SubcommandInput $subcommandInput)
    if ([string]::IsNullOrWhiteSpace($subcommandInput)) {
        return ConvertTo-GerberResolvedCommand -Name $null -Arguments @() -Suggestions $suggestionList `
            -Outcome (ConvertTo-GerberCommandOutcome -IsValid $true -ErrorMessage $null)
    }

    if (Test-GerberPromptKnownSubcommand -SubcommandTable $SubcommandTable -SubcommandInput $subcommandInput) {
        return ConvertTo-GerberResolvedCommand -Name $null -Arguments @() -Suggestions $suggestionList `
            -Outcome (ConvertTo-GerberCommandOutcome -IsValid $true -ErrorMessage $null)
    }

    return ConvertTo-GerberResolvedCommand `
        -Outcome (ConvertTo-GerberCommandOutcome -IsValid $false -ErrorMessage (Get-GerberUnknownCommandMessage -InputText "/$CommandName $subcommandInput" -SuggestionList $suggestionList)) `
        -Name $null `
        -Arguments @() `
        -Suggestions $suggestionList
}

function ConvertTo-GerberSubcommandPromptCommandInput {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [string]$InputText
    )

    $trimmedInput = $InputText.Trim()
    $trimmedToken = $trimmedInput.TrimStart('/')
    if ([string]::IsNullOrWhiteSpace($trimmedToken)) {
        return "/$CommandName "
    }

    if ($trimmedToken.StartsWith($CommandName, [System.StringComparison]::OrdinalIgnoreCase)) {
        return "/$trimmedToken"
    }

    return "/$CommandName $trimmedToken"
}

function Get-GerberPromptSubcommandInput {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputText
    )

    $normalizedInput = ConvertTo-GerberSubcommandPromptCommandInput -CommandName $CommandName -InputText $InputText
    $commandPrefix = "/$CommandName"
    if ($normalizedInput.Length -le $commandPrefix.Length) {
        return ''
    }

    $subcommandText = $normalizedInput.Substring($commandPrefix.Length).Trim()
    return ($subcommandText -split '\s+')[0].ToLowerInvariant()
}

function Test-GerberPromptKnownSubcommand {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$SubcommandTable,

        [Parameter(Mandatory)]
        [string]$SubcommandInput
    )

    return $SubcommandTable.Contains($SubcommandInput)
}

function Resolve-GerberSlashCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputText,

        [Parameter(Mandatory)]
        [string[]]$ActionList
    )

    $catalog = Get-GerberCommandCatalog -ActionList $ActionList
    $tokenData = Get-GerberCommandPathTokenData -InputText $InputText
    if (-not $catalog.Contains($tokenData.CommandName)) {
        return Get-GerberUnknownCommandResolution -Catalog $catalog -InputText "/$($tokenData.CommandName)"
    }

    return Get-GerberKnownCommandResolution -Catalog $catalog -TokenData $tokenData -InputText $InputText
}

function Get-GerberCommandCatalog {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$ActionList
    )

    return ConvertTo-GerberActiveCommandCatalog -ActionList $ActionList
}

function ConvertTo-GerberActiveCommandCatalog {
    param(
        [string[]]$ActionList
    )

    $filteredCatalog = [ordered]@{}
    foreach ($action in $ActionList) {
        $commandDefinition = Get-GerberRegisteredCommand -Name $action
        if ($null -ne $commandDefinition) {
            $filteredCatalog[$action] = ConvertTo-GerberCommandCatalogEntry `
                -Description $commandDefinition.Description `
                -Subcommands $commandDefinition.Subcommands
        }
    }

    return $filteredCatalog
}

function ConvertTo-GerberCommandCatalogEntry {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Description,

        [System.Collections.IDictionary]$Subcommands = [ordered]@{}
    )

    return @{
        Description = $Description
        Subcommands = $Subcommands
    }
}

function Get-GerberCatalogEntryDescription {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Entry
    )

    if ($Entry -is [string]) {
        return $Entry
    }

    return $Entry.Description
}

function Get-GerberCatalogEntrySubcommandTable {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Entry
    )

    if ($Entry -is [string] -or $null -eq $Entry.Subcommands) {
        return [ordered]@{}
    }

    return $Entry.Subcommands
}


function Get-GerberBase64CommandCatalog {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param()

    return [ordered]@{
        encode = ConvertTo-GerberCommandCatalogEntry -Description 'Encode UTF-8 text as Base64'
        decode = ConvertTo-GerberCommandCatalogEntry -Description 'Decode Base64 text as UTF-8'
    }
}

function Get-GerberSecretsCommandCatalog {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param()

    return [ordered]@{
        list = ConvertTo-GerberCommandCatalogEntry -Description 'Show the stored Gerber keys'
        get = ConvertTo-GerberCommandCatalogEntry -Description 'Reveal a stored Gerber secret after confirmation'
        test = ConvertTo-GerberCommandCatalogEntry -Description 'Check whether a Gerber credential exists'
        set = ConvertTo-GerberCommandCatalogEntry -Description 'Create or overwrite a stored Gerber secret'
        remove = ConvertTo-GerberCommandCatalogEntry -Description 'Remove a stored Gerber secret'
    }
}

function Get-GerberCommandPathTokenData {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputText
    )

    $originalTokenList = @(Split-GerberOriginalCommandToken -InputText $InputText)
    return ConvertTo-GerberCommandPathTokenData -InputText $InputText -OriginalTokenList $originalTokenList
}

function Split-GerberOriginalCommandToken {
    param(
        [string]$InputText
    )

    $trimmedInput = $InputText.Trim().TrimStart('/')
    if ([string]::IsNullOrWhiteSpace($trimmedInput)) {
        return @('')
    }
    return @($trimmedInput -split '\s+')
}

function ConvertTo-GerberNormalizedCommandToken {
    param(
        [object[]]$OriginalTokenList
    )

    return @(
        foreach ($token in $OriginalTokenList) {
            $token.ToLowerInvariant()
        }
    )
}

function ConvertTo-GerberCommandPathTokenData {
    param(
        [string]$InputText,
        [object[]]$OriginalTokenList
    )

    $normalizedTokenList = @(ConvertTo-GerberNormalizedCommandToken -OriginalTokenList $OriginalTokenList)
    return [pscustomobject][ordered]@{
        CommandName = $normalizedTokenList[0]
        OriginalTokenList = $OriginalTokenList
        NormalizedTokenList = $normalizedTokenList
        HasTrailingSpace = $InputText -match '\s$'
    }
}

function Get-GerberUnknownCommandResolution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Catalog,

        [Parameter(Mandatory)]
        [string]$InputText
    )

    return ConvertTo-GerberUnknownRootResolution @PSBoundParameters
}

function ConvertTo-GerberUnknownRootResolution {
    [CmdletBinding()]
    param(
        [hashtable]$Catalog,
        [string]$InputText
    )

    $normalizedInput = $InputText.TrimStart('/').ToLowerInvariant()
    $suggestionList = @(Get-GerberRootSuggestionList -Catalog $Catalog -InputToken $normalizedInput)
    return ConvertTo-GerberResolvedCommand `
        -Outcome (ConvertTo-GerberCommandOutcome -IsValid $false -ErrorMessage (Get-GerberUnknownCommandMessage -InputText $InputText -SuggestionList $suggestionList)) `
        -Name $null `
        -Arguments @() `
        -Suggestions $suggestionList
}

function Get-GerberKnownCommandResolution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Catalog,

        [Parameter(Mandatory)]
        [pscustomobject]$TokenData,

        [Parameter(Mandatory)]
        [string]$InputText
    )

    $path = Resolve-GerberKnownCommandPath -Catalog $Catalog -TokenData $TokenData
    return ConvertTo-GerberKnownPathResolution -Path $path -TokenData $TokenData -InputText $InputText
}

function Resolve-GerberKnownCommandPath {
    param(
        [hashtable]$Catalog,
        [pscustomobject]$TokenData
    )

    $path = [pscustomobject]@{
        CurrentCommandData = $Catalog[$TokenData.CommandName]
        CommandPathTokenList = @($TokenData.NormalizedTokenList[0])
        Index = 1
        UnknownSubcommand = $null
    }
    Complete-GerberKnownCommandPath -Path $path -TokenData $TokenData
    return $path
}

function Complete-GerberKnownCommandPath {
    param(
        [pscustomobject]$Path,
        [pscustomobject]$TokenData
    )

    while ($Path.Index -lt $TokenData.NormalizedTokenList.Count) {
        if (-not (Move-GerberKnownCommandPath -Path $Path -TokenData $TokenData)) {
            break
        }
    }
}

function Move-GerberKnownCommandPath {
    param(
        [pscustomobject]$Path,
        [pscustomobject]$TokenData
    )

    $subcommandTable = Get-GerberCatalogEntrySubcommandTable -Entry $Path.CurrentCommandData
    if ($subcommandTable.Count -eq 0) {
        return $false
    }
    $subcommandInput = $TokenData.NormalizedTokenList[$Path.Index]
    return Complete-GerberKnownCommandPathStep -Path $Path -Subcommands $subcommandTable -InputToken $subcommandInput
}

function Complete-GerberKnownCommandPathStep {
    param(
        [pscustomobject]$Path,
        [System.Collections.IDictionary]$Subcommands,
        [string]$InputToken
    )

    if (-not $Subcommands.Contains($InputToken)) {
        $Path.UnknownSubcommand = $InputToken
        return $false
    }
    $Path.CommandPathTokenList += $InputToken
    $Path.CurrentCommandData = $Subcommands[$InputToken]
    $Path.Index++
    return $true
}

function ConvertTo-GerberKnownPathResolution {
    param(
        [pscustomobject]$Path,
        [pscustomobject]$TokenData,
        [string]$InputText
    )

    if ($null -ne $Path.UnknownSubcommand) {
        return ConvertTo-GerberUnknownPathResolution -Path $Path -InputText $InputText
    }
    return ConvertTo-GerberValidPathResolution -Path $Path -TokenData $TokenData
}

function ConvertTo-GerberUnknownPathResolution {
    param(
        [pscustomobject]$Path,
        [string]$InputText
    )

    return Get-GerberUnknownSubcommandResolution `
        -InputText $InputText `
        -CommandPathTokenList $Path.CommandPathTokenList `
        -CurrentCommandData $Path.CurrentCommandData `
        -SubcommandInput $Path.UnknownSubcommand
}

function ConvertTo-GerberValidPathResolution {
    param(
        [pscustomobject]$Path,
        [pscustomobject]$TokenData
    )

    $arguments = @($TokenData.OriginalTokenList | Select-Object -Skip 1)
    $suggestionList = @(Select-GerberKnownPathSuggestion -Path $Path -TokenData $TokenData)
    return ConvertTo-GerberResolvedCommand -Name $TokenData.CommandName -Arguments $arguments -Suggestions $suggestionList `
        -Outcome (ConvertTo-GerberCommandOutcome -IsValid $true -ErrorMessage $null)
}

function Select-GerberKnownPathSuggestion {
    param(
        [pscustomobject]$Path,
        [pscustomobject]$TokenData
    )

    if ((Test-GerberCommandHasSubcommandMenu -CommandData $Path.CurrentCommandData) -and
            ($TokenData.NormalizedTokenList.Count -eq $Path.Index)) {
        return Get-GerberNamedSubcommandSuggestionList -CommandName ($Path.CommandPathTokenList -join ' ') `
            -SubcommandTable (Get-GerberCatalogEntrySubcommandTable -Entry $Path.CurrentCommandData)
    }
    return @()
}

function Test-GerberCommandHasSubcommandMenu {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CommandData
    )

    return (Get-GerberCatalogEntrySubcommandTable -Entry $CommandData).Count -gt 0
}

function Get-GerberUnknownSubcommandResolution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputText,

        [Parameter(Mandatory)]
        [string[]]$CommandPathTokenList,

        [Parameter(Mandatory)]
        [hashtable]$CurrentCommandData,

        [Parameter(Mandatory)]
        [string]$SubcommandInput
    )

    return ConvertTo-GerberUnknownSubcommandOutcome -Request ([pscustomobject]$PSBoundParameters)
}

function ConvertTo-GerberUnknownSubcommandOutcome {
    param(
        [pscustomobject]$Request
    )

    # Request fields/types were validated by Get-GerberUnknownSubcommandResolution.
    $commandName = $Request.CommandPathTokenList -join ' '
    $suggestionList = @(Get-GerberNamedSubcommandSuggestionList -CommandName $commandName -SubcommandTable (Get-GerberCatalogEntrySubcommandTable -Entry $Request.CurrentCommandData) -SubcommandInput $Request.SubcommandInput)
    return ConvertTo-GerberResolvedCommand `
        -Outcome (ConvertTo-GerberCommandOutcome -IsValid $false -ErrorMessage (Get-GerberUnknownCommandMessage -InputText $Request.InputText.Trim() -SuggestionList $suggestionList)) `
        -Name $null `
        -Arguments @() `
        -Suggestions $suggestionList
}

function Get-GerberRootSuggestionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Catalog,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputToken
    )

    return [object[]]@(
        foreach ($commandName in (Get-GerberRootCommandNameList -ValueList $Catalog.Keys)) {
            if (Test-GerberTokenMatch -Candidate $commandName -InputToken $InputToken) {
                ConvertTo-GerberSuggestion -DisplayText "/$commandName" -CompletionText "/$commandName" -PreviewText $Catalog[$commandName].Description
            }
        }
    )
}

function Get-GerberLeafActionSuggestionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$LeafActionList,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputText
    )

    $matchingActionList = @(Get-GerberMatchingLeafActionList -LeafActionList $LeafActionList -InputText $InputText)
    return [object[]]@(
        foreach ($action in $matchingActionList) {
            ConvertTo-GerberSuggestion -DisplayText $action.DisplayText -CompletionText $action.CompletionText -PreviewText $action.PreviewText
        }
    )
}

function Get-GerberExactLeafActionMatch {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$LeafActionList,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputText
    )

    $searchTokenList = @(Get-GerberSearchTokenList -InputText $InputText)
    if ($searchTokenList.Count -eq 0) {
        return $null
    }

    $searchKey = $searchTokenList -join ' '
    foreach ($action in $LeafActionList) {
        if ($action.SearchKey -eq $searchKey) {
            return $action
        }
    }

    return $null
}

function Get-GerberLeafActionCommandList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Catalog
    )

    return [object[]]@(
        foreach ($commandName in (Get-GerberRootCommandNameList -ValueList $Catalog.Keys)) {
            Get-GerberLeafActionCommandListForEntry -CommandPath @($commandName) -CommandEntry $Catalog[$commandName]
        }
    )
}

function Get-GerberLeafActionCommandListForEntry {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$CommandPath,

        [Parameter(Mandatory)]
        [object]$CommandEntry
    )

    $subcommandTable = Get-GerberCatalogEntrySubcommandTable -Entry $CommandEntry
    if ($subcommandTable.Count -eq 0) {
        $searchTokenList = @(Get-GerberSearchTokenList -InputText ($CommandPath -join ' '))
        $completionText = "/$($CommandPath -join ' ')"
        return [pscustomobject][ordered]@{
            DisplayText = $completionText
            CompletionText = $completionText
            PreviewText = Get-GerberCatalogEntryDescription -Entry $CommandEntry
            RootCommandName = $CommandPath[0]
            Arguments = @($CommandPath | Select-Object -Skip 1)
            SearchKey = $searchTokenList -join ' '
            SearchTokenList = $searchTokenList
        }
    }

    return [object[]]@(
        foreach ($subcommandName in (Get-GerberAlphabeticallySortedStringList -ValueList $subcommandTable.Keys)) {
            Get-GerberLeafActionCommandListForEntry -CommandPath @($CommandPath + $subcommandName) -CommandEntry $subcommandTable[$subcommandName]
        }
    )
}

function Get-GerberMatchingLeafActionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$LeafActionList,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputText
    )

    $searchTokenList = @(Get-GerberSearchTokenList -InputText $InputText)
    if ($searchTokenList.Count -eq 0) {
        return @()
    }

    $prefixMatchList = @(Get-GerberFilteredLeafActionMatchList -LeafActionList $LeafActionList -SearchTokenList $searchTokenList -MatchMode 'Prefix')
    if ($prefixMatchList.Count -gt 0) {
        return $prefixMatchList
    }

    return @(Get-GerberFilteredLeafActionMatchList -LeafActionList $LeafActionList -SearchTokenList $searchTokenList -MatchMode 'Contains')
}

function Get-GerberMatchingTokenList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.IEnumerable]$CandidateList,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputToken
    )

    $candidateNameList = @(Get-GerberAlphabeticallySortedStringList -ValueList $CandidateList)
    if ($candidateNameList.Count -eq 0) {
        return @()
    }
    if ([string]::IsNullOrWhiteSpace($InputToken)) {
        return $candidateNameList
    }

    $prefixMatchList = @(Get-GerberFilteredTokenMatchList -CandidateList $candidateNameList -InputToken $InputToken -MatchMode 'Prefix')
    if ($prefixMatchList.Count -gt 0) {
        return $prefixMatchList
    }

    return @(Get-GerberFilteredTokenMatchList -CandidateList $candidateNameList -InputToken $InputToken -MatchMode 'Contains')
}

function Get-GerberNamedSubcommandSuggestionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$SubcommandTable,

        [string]$SubcommandInput = ''
    )

    $matchingSubcommandNameList = Get-GerberMatchingTokenList -CandidateList $SubcommandTable.Keys -InputToken $SubcommandInput
    return [object[]]@(
        foreach ($subcommandName in $matchingSubcommandNameList) {
            ConvertTo-GerberSuggestion `
                -DisplayText "/$CommandName $subcommandName" `
                -CompletionText "/$CommandName $subcommandName" `
                -PreviewText (Get-GerberCatalogEntryDescription -Entry $SubcommandTable[$subcommandName])
        }
    )
}

function Get-GerberFilteredLeafActionMatchList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$LeafActionList,

        [Parameter(Mandatory)]
        [string[]]$SearchTokenList,

        [Parameter(Mandatory)]
        [ValidateSet('Prefix', 'Contains')]
        [string]$MatchMode
    )

    return @(
        foreach ($action in $LeafActionList) {
            if (Test-GerberLeafActionTokenMatch -Action $action -SearchTokenList $SearchTokenList -MatchMode $MatchMode) {
                $action
            }
        }
    )
}

function Get-GerberFilteredTokenMatchList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$CandidateList,

        [Parameter(Mandatory)]
        [string]$InputToken,

        [Parameter(Mandatory)]
        [ValidateSet('Prefix', 'Contains')]
        [string]$MatchMode
    )

    return @(
        foreach ($candidate in $CandidateList) {
            if (Test-GerberCandidateTokenMatch -Candidate $candidate -InputToken $InputToken -MatchMode $MatchMode) {
                $candidate
            }
        }
    )
}

function Test-GerberCandidateTokenMatch {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Candidate,

        [Parameter(Mandatory)]
        [string]$InputToken,

        [Parameter(Mandatory)]
        [ValidateSet('Prefix', 'Contains')]
        [string]$MatchMode
    )

    if ($MatchMode -eq 'Prefix') {
        return $Candidate.StartsWith($InputToken, [System.StringComparison]::OrdinalIgnoreCase)
    }

    return $Candidate.Contains($InputToken, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-GerberLeafActionTokenMatch {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Action,

        [Parameter(Mandatory)]
        [string[]]$SearchTokenList,

        [Parameter(Mandatory)]
        [ValidateSet('Prefix', 'Contains')]
        [string]$MatchMode
    )

    foreach ($searchToken in $SearchTokenList) {
        $hasMatch = $false
        foreach ($candidateToken in $Action.SearchTokenList) {
            if (Test-GerberCandidateTokenMatch -Candidate $candidateToken -InputToken $searchToken -MatchMode $MatchMode) {
                $hasMatch = $true
                break
            }
        }

        if (-not $hasMatch) {
            return $false
        }
    }

    return $true
}

function Get-GerberSearchTokenList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputText
    )

    return [string[]]@(
        foreach ($token in ($InputText.ToLowerInvariant() -split '[^a-z0-9]+')) {
            if (-not [string]::IsNullOrWhiteSpace($token)) {
                $token
            }
        }
    )
}

function Test-GerberTokenMatch {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Candidate,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputToken
    )

    if ([string]::IsNullOrWhiteSpace($InputToken)) {
        return $true
    }

    return $Candidate.StartsWith($InputToken, [System.StringComparison]::OrdinalIgnoreCase) -or
        $Candidate.Contains($InputToken, [System.StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-GerberSuggestion {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DisplayText,

        [Parameter(Mandatory)]
        [string]$CompletionText,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$PreviewText
    )

    return [pscustomobject][ordered]@{
        DisplayText = $DisplayText
        CompletionText = $CompletionText
        PreviewText = $PreviewText
    }
}

function Get-GerberUnknownCommandMessage {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputText,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$SuggestionList
    )

    if ($SuggestionList.Count -eq 0) {
        return "Unknown command '$InputText'. Use /help to see the available commands."
    }

    return "Unknown command '$InputText'. Try $($SuggestionList[0].DisplayText) or use /help to see the available commands."
}

function ConvertTo-GerberResolvedCommand {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Tuple[bool, string]]$Outcome,

        [AllowNull()]
        [string]$Name,

        [string[]]$Arguments = @(),

        [object[]]$Suggestions = @()
    )

    return [pscustomobject][ordered]@{
        IsValid = $Outcome.Item1
        Name = $Name
        Arguments = $Arguments
        ErrorMessage = $Outcome.Item2
        Suggestions = $Suggestions
    }

}

function ConvertTo-GerberCommandOutcome {
    [OutputType([System.Tuple[bool, string]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$IsValid,
        [string]$ErrorMessage
    )

    # Immutable, typed outcome: Item1 is validity; Item2 is the diagnostic.
    return [System.Tuple[bool, string]]::new($IsValid, $ErrorMessage)
}
