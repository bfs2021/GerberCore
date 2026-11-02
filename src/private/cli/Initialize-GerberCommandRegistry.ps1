function Initialize-GerberCommandRegistry {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [string[]]$PluginModulePathList = (Get-GerberDefaultPluginModulePathList)
    )

    $existingRegistryState = Get-GerberRegisteredCommandRegistryState
    if ($null -ne $existingRegistryState) {
        return @(Get-GerberRootCommandDefinitionList -CommandDefinitionList $existingRegistryState.CommandList)
    }

    $registryBuilder = ConvertTo-GerberCoreRegistryBuilder
    Add-GerberDiscoveredPluginRegistration -RegistryBuilder $registryBuilder -PluginModulePathList $PluginModulePathList
    Publish-GerberCommandRegistryState -RegistryBuilder $registryBuilder
    return @(Get-GerberRootCommandDefinitionList -CommandDefinitionList $script:GerberCommandRegistryState.CommandList)
}

function ConvertTo-GerberCoreRegistryBuilder {
    param()

    $registryBuilder = [pscustomobject][ordered]@{
        CommandList   = New-Object 'System.Collections.Generic.List[object]'
        PluginList    = New-Object 'System.Collections.Generic.List[object]'
        GerberVersion = Get-GerberCurrentVersion
    }

    Add-GerberOwnedCommandDefinitionList `
        -RegisteredCommandList $registryBuilder.CommandList `
        -CommandDefinitionList (Get-GerberCoreCommandDefinitionList) `
        -OwnerName 'Gerber.Core' `
        -OwnerType 'Core'

    return $registryBuilder
}

function Add-GerberDiscoveredPluginRegistration {
    param(
        [pscustomobject]$RegistryBuilder,
        [string[]]$PluginModulePathList
    )

    foreach ($pluginModule in (Get-GerberDiscoveredPluginModuleList -PluginModulePathList $PluginModulePathList)) {
        Add-GerberApprovedPluginRegistration -RegistryBuilder $RegistryBuilder -PluginModule $pluginModule
    }
}

function Add-GerberApprovedPluginRegistration {
    param(
        [pscustomobject]$RegistryBuilder,
        [pscustomobject]$PluginModule
    )

    if (-not (Resolve-GerberPluginApproval -PluginModule $PluginModule)) {
        return
    }
    $lifecycleState = Get-GerberPluginLifecycleState -Guid $PluginModule.Guid
    if ($lifecycleState.ShouldLoad) {
        Add-GerberPluginToRegistryBuilder -RegistryBuilder $RegistryBuilder -PluginModule $PluginModule -LifecycleState $lifecycleState
    }
}

function Get-GerberDefaultPluginModulePathList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param()

    if ([string]::IsNullOrWhiteSpace($env:PSModulePath)) {
        return [string[]]@()
    }

    return [string[]]@(
        foreach ($path in ($env:PSModulePath -split [System.IO.Path]::PathSeparator)) {
            if (-not [string]::IsNullOrWhiteSpace($path)) {
                $path
            }
        }
    )
}

function Get-GerberCurrentVersion {
    [OutputType([System.Management.Automation.SemanticVersion])]
    [CmdletBinding()]
    param()

    $loadedVersion = Get-GerberLoadedCommandVersion
    if ($null -ne $loadedVersion) {
        return $loadedVersion
    }

    $projectVersion = Get-GerberProjectVersionFromRepositoryRoot
    return [System.Management.Automation.SemanticVersion]::Parse($projectVersion)
}

function Get-GerberLoadedCommandVersion {
    [OutputType([System.Management.Automation.SemanticVersion])]
    [CmdletBinding()]
    param()

    $command = Get-Command -Name 'Invoke-Gerber' -CommandType Function -ErrorAction SilentlyContinue
    $commandModule = Resolve-GerberLoadedCommandModule -Command $command
    if ($null -eq $commandModule -or $null -eq $commandModule.Version) {
        return $null
    }

    return [System.Management.Automation.SemanticVersion]::Parse($commandModule.Version.ToString())
}

function Resolve-GerberLoadedCommandModule {
    param(
        [AllowNull()]
        [object]$Command
    )

    if ($null -eq $Command) {
        return $null
    }
    return $Command.Module
}

function Get-GerberProjectVersionFromRepositoryRoot {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    $projectPath = Join-Path (Get-Location) 'project.json'
    if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) {
        throw [System.InvalidOperationException]::new(
            'Gerber could not resolve the current version because project.json was not available from the current working directory.'
        )
    }

    $projectData = (Get-Content -LiteralPath $projectPath -Raw) | ConvertFrom-Json -AsHashtable
    return [string]$projectData.Version
}

function Get-GerberDiscoveredPluginModuleList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [string[]]$PluginModulePathList
    )

    $pluginModuleList = @(Read-GerberValidatedPluginManifest -PluginModulePathList $PluginModulePathList)
    $selectedModuleList = @(Select-GerberLatestPluginManifest -PluginModuleList $pluginModuleList)
    return @(
        $selectedModuleList |
            Sort-Object @{ Expression = { $_.Name.ToLowerInvariant() } }, @{ Expression = { [version]$_.Version }; Descending = $true }
    )
}

function Read-GerberValidatedPluginManifest {
    param(
        [string[]]$PluginModulePathList
    )

    return @(
        foreach ($moduleInfo in (Get-GerberPluginManifestMetadataList -PluginModulePathList $PluginModulePathList)) {
            Assert-GerberPluginModuleManifest -ModuleInfo $moduleInfo
            $moduleInfo
        }
    )

}

function Select-GerberLatestPluginManifest {
    param(
        [object[]]$PluginModuleList
    )

    return @(
        foreach ($group in ($PluginModuleList | Group-Object Name)) {
            $group.Group |
                Sort-Object @{ Expression = { [version]$_.Version }; Descending = $true } |
                Select-Object -First 1
        }
    )

}

function Assert-GerberPluginModuleManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$ModuleInfo
    )

    $gerberMetadata = Get-GerberModulePrivateDataValueOrNull -InputObject $ModuleInfo.PrivateData -Name 'Gerber'
    Assert-GerberRequiredPluginMetadataField -ModuleInfo $ModuleInfo -Metadata $gerberMetadata -Name 'ApiVersion'
    Assert-GerberSupportedPluginApi -ModuleInfo $ModuleInfo -Metadata $gerberMetadata
    Assert-GerberRequiredPluginMetadataField -ModuleInfo $ModuleInfo -Metadata $gerberMetadata -Name 'MinimumGerberVersion'
}

function Assert-GerberRequiredPluginMetadataField {
    param(
        [psobject]$ModuleInfo,
        [object]$Metadata,
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace([string]$Metadata.$Name)) {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$($ModuleInfo.Name)' is missing required manifest metadata 'PrivateData.Gerber.$Name'."
        )
    }

}

function Assert-GerberSupportedPluginApi {
    param(
        [psobject]$ModuleInfo,
        [object]$Metadata
    )

    if ([string]$Metadata.ApiVersion -ne '1') {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$($ModuleInfo.Name)' requires plugin API version '$([string]$Metadata.ApiVersion)', but Gerber supports plugin API version '1'."
        )
    }

}

function Get-GerberModulePrivateDataValueOrNull {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    return Read-GerberManifestProperty -InputObject $InputObject -Name $Name
}

function Read-GerberManifestProperty {
    param(
        [object]$InputObject,
        [string]$Name
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        return Read-GerberManifestDictionaryValue -InputObject $InputObject -Name $Name
    }
    return Read-GerberManifestObjectProperty -InputObject $InputObject -Name $Name
}

function Read-GerberManifestDictionaryValue {
    param(
        [System.Collections.IDictionary]$InputObject,
        [string]$Name
    )

    if ($InputObject.Contains($Name)) {
        return $InputObject[$Name]
    }
    return $null
}

function Read-GerberManifestObjectProperty {
    param(
        [object]$InputObject,
        [string]$Name
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Add-GerberOwnedCommandDefinitionList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$RegisteredCommandList,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$CommandDefinitionList,

        [Parameter(Mandatory)]
        [string]$OwnerName,

        [Parameter(Mandatory)]
        [ValidateSet('Core', 'Plugin')]
        [string]$OwnerType
    )

    # Bound fields retain collection, owner-name and owner-type validation.
    Complete-GerberOwnedCommandRegistration -Contribution ([pscustomobject]$PSBoundParameters)
}

function Complete-GerberOwnedCommandRegistration {
    param(
        [pscustomobject]$Contribution
    )

    $ownedCommandList = @(ConvertTo-GerberContributionCommandList -Contribution $Contribution)
    Add-GerberCommandContainerAncestor -Commands $Contribution.RegisteredCommandList -Definitions $ownedCommandList
    Assert-GerberOwnedCommandDefinitionList -OwnedCommandDefinitionList $ownedCommandList -RegisteredCommandList $Contribution.RegisteredCommandList
    Add-GerberOrderedCommandRegistration -RegisteredCommandList $Contribution.RegisteredCommandList -OwnedCommandDefinitionList $ownedCommandList
}

function ConvertTo-GerberContributionCommandList {
    param(
        [pscustomobject]$Contribution
    )

    $ownedCommandList = @()
    for ($index = 0; $index -lt $Contribution.CommandDefinitionList.Count; $index++) {
        $ownedCommand = ConvertTo-GerberOwnedCommandDefinition `
            -CommandDefinition $Contribution.CommandDefinitionList[$index] `
            -OwnerName $Contribution.OwnerName `
            -OwnerType $Contribution.OwnerType
        $ownedCommand | Add-Member -NotePropertyName RegistrationOrder -NotePropertyValue ($Contribution.RegisteredCommandList.Count + $index)
        $ownedCommandList += $ownedCommand
    }
    return $ownedCommandList
}

function Add-GerberOrderedCommandRegistration {
    param(
        [System.Collections.Generic.List[object]]$RegisteredCommandList,
        [object[]]$OwnedCommandDefinitionList
    )

    foreach ($ownedCommand in (Get-GerberOrderedOwnedCommandDefinitionList -OwnedCommandDefinitionList $OwnedCommandDefinitionList)) {
        if ($ownedCommand.ParentName) {
            Add-GerberOwnedSubcommandDefinition -RegisteredCommandList $RegisteredCommandList -OwnedCommandDefinition $ownedCommand
        }

        $null = $RegisteredCommandList.Add($ownedCommand)
    }
}

function ConvertTo-GerberOwnedCommandDefinition {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$CommandDefinition,

        [Parameter(Mandatory)]
        [string]$OwnerName,

        [Parameter(Mandatory)]
        [ValidateSet('Core', 'Plugin')]
        [string]$OwnerType
    )

    Assert-GerberCommandDefinition -CommandDefinition $CommandDefinition -OwnerName $OwnerName

    return ConvertTo-GerberOwnedRegistrationDefinition @PSBoundParameters
}

function ConvertTo-GerberOwnedRegistrationDefinition {
    [CmdletBinding()]
    param(
        [pscustomobject]$CommandDefinition,
        [string]$OwnerName,
        [string]$OwnerType
    )

    $ownedCommandDefinition = Copy-GerberCommandDefinitionPayload -CommandDefinition $CommandDefinition
    Add-GerberCommandOwnership -Definition $ownedCommandDefinition -OwnerName $OwnerName -OwnerType $OwnerType
    $ownedCommandDefinition | Add-Member -NotePropertyName IsContainer -NotePropertyValue (Test-GerberCommandContainer -Definition $CommandDefinition)
    return $ownedCommandDefinition
}

function Copy-GerberCommandDefinitionPayload {
    param(
        [pscustomobject]$CommandDefinition
    )

    return [pscustomobject][ordered]@{
        Name        = Resolve-GerberCommandName -CommandName ([string]$CommandDefinition.Name)
        Description = [string]$CommandDefinition.Description
        Handler     = $CommandDefinition.Handler
        Subcommands = Get-GerberCommandDefinitionSubcommandTable -Subcommands $CommandDefinition.Subcommands
    }
}

function Add-GerberCommandOwnership {
    param(
        [pscustomobject]$Definition,
        [string]$OwnerName,
        [string]$OwnerType
    )

    $Definition | Add-Member -NotePropertyMembers ([ordered]@{
        OwnerName   = $OwnerName
        OwnerType   = $OwnerType
        ParentName  = Get-GerberParentCommandName -CommandName $Definition.Name
        LeafName    = Get-GerberCommandLeafName -CommandName $Definition.Name
    })
}

function Assert-GerberCommandDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$CommandDefinition,

        [Parameter(Mandatory)]
        [string]$OwnerName
    )

    Assert-GerberCommandDefinitionIdentity @PSBoundParameters
    Assert-GerberCommandDefinitionHandler @PSBoundParameters
    Assert-GerberCommandDefinitionSubcommandTable @PSBoundParameters
}

function Assert-GerberCommandDefinitionIdentity {
    [CmdletBinding()]
    param(
        [pscustomobject]$CommandDefinition,
        [string]$OwnerName
    )

    Assert-GerberCommandDefinitionText -Value $CommandDefinition.Name `
        -Message "Gerber plugin '$OwnerName' returned an invalid command definition because 'Name' was missing."
    Assert-GerberCommandDefinitionText -Value $CommandDefinition.Description `
        -Message "Gerber plugin '$OwnerName' returned an invalid command definition for root command '$([string]$CommandDefinition.Name)' because 'Description' was missing."
}

function Assert-GerberCommandDefinitionText {
    param(
        [AllowNull()]
        [object]$Value,
        [string]$Message
    )

    if ([string]::IsNullOrWhiteSpace([string]$Value)) {
        throw [System.InvalidOperationException]::new(
            $Message
        )
    }

}

function Assert-GerberCommandDefinitionHandler {
    [CmdletBinding()]
    param(
        [pscustomobject]$CommandDefinition,
        [string]$OwnerName
    )

    if ($CommandDefinition.Handler -isnot [scriptblock]) {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$OwnerName' returned an invalid command definition for root command '$([string]$CommandDefinition.Name)' because 'Handler' was not a scriptblock."
        )
    }

}

function Assert-GerberCommandDefinitionSubcommandTable {
    [CmdletBinding()]
    param(
        [pscustomobject]$CommandDefinition,
        [string]$OwnerName
    )

    if (($null -ne $CommandDefinition.Subcommands) -and ($CommandDefinition.Subcommands -isnot [System.Collections.IDictionary])) {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$OwnerName' returned an invalid command definition for root command '$([string]$CommandDefinition.Name)' because 'Subcommands' was not a dictionary."
        )
    }

}

function Assert-GerberOwnedCommandDefinitionList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$OwnedCommandDefinitionList,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$RegisteredCommandList
    )

    Assert-GerberCommandContributionRegistration @PSBoundParameters
}

function Assert-GerberCommandContributionRegistration {
    [CmdletBinding()]
    param(
        [object[]]$OwnedCommandDefinitionList,
        [System.Collections.Generic.List[object]]$RegisteredCommandList
    )

    Assert-GerberOwnerCommandNamesAreUnique -OwnedCommandDefinitionList $OwnedCommandDefinitionList
    foreach ($ownedCommand in $OwnedCommandDefinitionList) {
        Assert-GerberContributedCommandRegistration -RegisteredCommandList $RegisteredCommandList `
            -OwnedCommandDefinitionList $OwnedCommandDefinitionList -OwnedCommandDefinition $ownedCommand
    }
}

function Assert-GerberContributedCommandRegistration {
    [CmdletBinding()]
    param(
        [System.Collections.Generic.List[object]]$RegisteredCommandList,
        [object[]]$OwnedCommandDefinitionList,
        [pscustomobject]$OwnedCommandDefinition
    )

    $existingCommand = Find-GerberRegisteredCommandConflict -RegisteredCommandList $RegisteredCommandList -CommandName $OwnedCommandDefinition.Name
    if ($null -ne $existingCommand) {
        throw (Get-GerberRegisteredCommandConflictException -OwnedCommandDefinition $OwnedCommandDefinition -ExistingCommandDefinition $existingCommand)
    }
    Assert-GerberOwnedCommandParentDefinition @PSBoundParameters
    Assert-GerberOwnedSubcommandConflict @PSBoundParameters
}

function Assert-GerberOwnerCommandNamesAreUnique {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$OwnedCommandDefinitionList
    )

    foreach ($group in ($OwnedCommandDefinitionList | Group-Object Name)) {
        if ($group.Count -le 1) {
            continue
        }

        throw (ConvertTo-GerberDuplicateOwnerCommandException -Group $group)
    }
}

function ConvertTo-GerberDuplicateOwnerCommandException {
    param(
        [psobject]$Group
    )

    $ownedCommand = $Group.Group[0]
    $commandKind = if ($ownedCommand.ParentName) { 'command' } else { 'root command' }
    return [System.InvalidOperationException]::new(
        "Gerber cannot register duplicate $commandKind '$($Group.Name)' from owner '$($ownedCommand.OwnerName)'."
    )
}

function Find-GerberRegisteredCommandConflict {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$RegisteredCommandList,

        [Parameter(Mandatory)]
        [string]$CommandName
    )

    return ($RegisteredCommandList |
        Where-Object { $_.Name -ieq $CommandName } |
        Select-Object -First 1)
}

function Get-GerberRootCommandDefinitionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$CommandDefinitionList
    )

    return @($CommandDefinitionList | Where-Object { -not $_.ParentName })
}

function Resolve-GerberCommandName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    return (($CommandName -split '\s+') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' '
}

function Get-GerberParentCommandName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    $tokenList = @(Get-GerberCommandNameTokenList -CommandName $CommandName)
    if ($tokenList.Count -le 1) {
        return $null
    }

    return (@($tokenList | Select-Object -SkipLast 1) -join ' ')
}

function Get-GerberCommandLeafName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    $tokenList = @(Get-GerberCommandNameTokenList -CommandName $CommandName)
    return $tokenList[-1]
}

function Get-GerberCommandNameTokenList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    return [string[]]@((Resolve-GerberCommandName -CommandName $CommandName) -split '\s+')
}

function Get-GerberCommandDefinitionSubcommandTable {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary]$Subcommands
    )

    if ($null -eq $Subcommands) {
        return [ordered]@{}
    }

    $orderedSubcommandTable = [ordered]@{}
    foreach ($subcommandName in $Subcommands.Keys) {
        $orderedSubcommandTable[$subcommandName] = $Subcommands[$subcommandName]
    }

    return $orderedSubcommandTable
}

function Get-GerberOrderedOwnedCommandDefinitionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$OwnedCommandDefinitionList
    )

    return @(
        $OwnedCommandDefinitionList |
            Sort-Object `
                @{ Expression = { (@(Get-GerberCommandNameTokenList -CommandName $_.Name)).Count } }, `
                @{ Expression = { $_.RegistrationOrder } }
    )
}

function Assert-GerberOwnedCommandParentDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$RegisteredCommandList,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$OwnedCommandDefinitionList,

        [Parameter(Mandatory)]
        [pscustomobject]$OwnedCommandDefinition
    )

    # Preserve the existing collection/mandatory binding contract at this entry point.
    Assert-GerberCommandParentRegistration -Commands $RegisteredCommandList -Definitions $OwnedCommandDefinitionList -Command $OwnedCommandDefinition
}

function Assert-GerberCommandParentRegistration {
    param(
        [System.Collections.Generic.List[object]]$Commands,
        [object[]]$Definitions,
        [pscustomobject]$Command
    )

    if ($Command.ParentName) {
        $parent = Find-GerberRegisteredCommandConflict -RegisteredCommandList $Commands -CommandName $Command.ParentName
        Assert-GerberCommandParentOwnership -Parent $parent -Command $Command
        if ($null -eq $parent) {
            Assert-GerberDeclaredCommandParent -Definitions $Definitions -Command $Command
        }
    }
}

function Assert-GerberDeclaredCommandParent {
    param(
        [object[]]$Definitions,
        [pscustomobject]$Command
    )

    foreach ($candidate in $Definitions) {
        if ($candidate.Name -ieq $Command.ParentName) {
            return
        }
    }
    throw [System.InvalidOperationException]::new(
        "Gerber cannot register command '$($Command.Name)' from owner '$($Command.OwnerName)' because parent command '$($Command.ParentName)' is not registered."
    )
}

function Assert-GerberOwnedSubcommandConflict {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$RegisteredCommandList,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$OwnedCommandDefinitionList,

        [Parameter(Mandatory)]
        [pscustomobject]$OwnedCommandDefinition
    )

    Assert-GerberSubcommandContributionAvailability -Contribution ([pscustomobject]$PSBoundParameters)
}

function Assert-GerberSubcommandContributionAvailability {
    param(
        [pscustomobject]$Contribution
    )

    $command = $Contribution.OwnedCommandDefinition
    if (-not $command.ParentName) {
        return
    }
    $parentCommand = Find-GerberSubcommandContributionParent -RegisteredCommandList $Contribution.RegisteredCommandList `
        -OwnedCommandDefinitionList $Contribution.OwnedCommandDefinitionList -OwnedCommandDefinition $command
    if (Test-GerberSubcommandContributionConflict -Parent $parentCommand `
            -Definitions $Contribution.OwnedCommandDefinitionList -Command $command) {
        throw (ConvertTo-GerberSubcommandOwnershipException -Parent $parentCommand -Command $command)
    }
}

function Find-GerberSubcommandContributionParent {
    [CmdletBinding()]
    param(
        [System.Collections.Generic.List[object]]$RegisteredCommandList,
        [object[]]$OwnedCommandDefinitionList,
        [pscustomobject]$OwnedCommandDefinition
    )

    $parentCommand = Find-GerberRegisteredCommandConflict -RegisteredCommandList $RegisteredCommandList -CommandName $OwnedCommandDefinition.ParentName
    if ($null -ne $parentCommand) {
        return $parentCommand
    }
    return ($OwnedCommandDefinitionList | Where-Object { $_.Name -ieq $OwnedCommandDefinition.ParentName } | Select-Object -First 1)
}

function Test-GerberSubcommandContributionConflict {
    param(
        [AllowNull()]
        [pscustomobject]$Parent,
        [object[]]$Definitions,
        [pscustomobject]$Command
    )

    if (($null -eq $Parent) -or (-not $Parent.Subcommands.Contains($Command.LeafName))) {
        return $false
    }
    $existingOwnedCommand = Find-GerberSubcommandContributionSibling -Definitions $Definitions -Command $Command
    return $null -eq $existingOwnedCommand
}

function Find-GerberSubcommandContributionSibling {
    param(
        [object[]]$Definitions,
        [pscustomobject]$Command
    )

    return Find-GerberOwnedCommandDefinitionByParentAndLeafName `
        -OwnedCommandDefinitionList $Definitions `
        -ParentName $Command.ParentName `
        -LeafName $Command.LeafName `
        -ExcludeName $Command.Name
}

function ConvertTo-GerberSubcommandOwnershipException {
    param(
        [pscustomobject]$Parent,
        [pscustomobject]$Command
    )

    return [System.InvalidOperationException]::new(
        "Gerber cannot register subcommand '$($Command.LeafName)' under command '$($Command.ParentName)' from owner '$($Command.OwnerName)' because it is already owned by '$($Parent.OwnerName)'."
    )
}

function Find-GerberOwnedCommandDefinitionByParentAndLeafName {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$OwnedCommandDefinitionList,

        [Parameter(Mandatory)]
        [string]$ParentName,

        [Parameter(Mandatory)]
        [string]$LeafName,

        [string]$ExcludeName
    )

    return Find-GerberOwnedCommandByCriterion -Criteria ([pscustomobject]$PSBoundParameters) -ExcludeName $ExcludeName
}

function Find-GerberOwnedCommandByCriterion {
    param(
        [pscustomobject]$Criteria,
        [string]$ExcludeName
    )

    return ($Criteria.OwnedCommandDefinitionList |
        Where-Object { Test-GerberOwnedCommandMatchesParentAndLeaf -Candidate $_ -Criteria $Criteria -ExcludeName $ExcludeName } |
        Select-Object -First 1)
}

function Test-GerberOwnedCommandMatchesParentAndLeaf {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [pscustomobject]$Candidate,
        [pscustomobject]$Criteria,
        [string]$ExcludeName
    )

    return ($Candidate.ParentName -ieq $Criteria.ParentName) -and
        ($Candidate.LeafName -ieq $Criteria.LeafName) -and
        ($Candidate.Name -ine $ExcludeName)
}

function Get-GerberRegisteredCommandConflictException {
    [OutputType([System.InvalidOperationException])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$OwnedCommandDefinition,

        [Parameter(Mandatory)]
        [pscustomobject]$ExistingCommandDefinition
    )

    $commandKind = if ($OwnedCommandDefinition.ParentName) { 'command' } else { 'root command' }
    return [System.InvalidOperationException]::new(
        "Gerber cannot register $commandKind '$($OwnedCommandDefinition.Name)' from owner '$($OwnedCommandDefinition.OwnerName)' because it is already owned by '$($ExistingCommandDefinition.OwnerName)'."
    )
}

function Add-GerberOwnedSubcommandDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$RegisteredCommandList,

        [Parameter(Mandatory)]
        [pscustomobject]$OwnedCommandDefinition
    )

    Add-GerberSubcommandCatalogRegistration @PSBoundParameters
}

function Add-GerberSubcommandCatalogRegistration {
    [CmdletBinding()]
    param(
        [System.Collections.Generic.List[object]]$RegisteredCommandList,
        [pscustomobject]$OwnedCommandDefinition
    )

    $parentCommand = Find-GerberRegisteredCommandConflict `
        -RegisteredCommandList $RegisteredCommandList `
        -CommandName $OwnedCommandDefinition.ParentName
    $parentCommand.Subcommands[$OwnedCommandDefinition.LeafName] = ConvertTo-GerberCommandCatalogEntry `
        -Description $OwnedCommandDefinition.Description `
        -Subcommands $OwnedCommandDefinition.Subcommands
}
