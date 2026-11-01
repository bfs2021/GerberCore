function Get-GerberPluginInventory {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [hashtable]$Configuration,

        [string[]]$PluginModulePathList = (Get-GerberDefaultPluginModulePathList)
    )

    if ($null -eq $Configuration) {
        $Configuration = Get-GerberUserConfiguration
    }

    $discoveredRecordList = @(Get-GerberPluginManifestMetadataList -PluginModulePathList $PluginModulePathList)
    $discoveredRecordTable = Get-GerberPreferredDiscoveredPluginRecordTable -DiscoveredRecordList $discoveredRecordList
    $loadedPluginStateTable = Get-GerberLoadedPluginStateTable
    $loadedPluginCommandTable = Get-GerberLoadedPluginCommandTable -LoadedPluginStateTable $loadedPluginStateTable
    $inventoryContext = Get-GerberPluginInventoryContext `
        -Configuration $Configuration `
        -DiscoveredRecordTable $discoveredRecordTable `
        -LoadedPluginStateTable $loadedPluginStateTable `
        -LoadedPluginCommandTable $loadedPluginCommandTable

    $inventoryEntryList = @(
        foreach ($guid in (Get-GerberPluginInventoryGuidList `
                    -Configuration $Configuration `
                    -DiscoveredRecordList $discoveredRecordList `
                    -LoadedPluginStateTable $loadedPluginStateTable)) {
            ConvertTo-GerberPluginInventoryEntry `
                -Guid $guid `
                -InventoryContext $inventoryContext
        }
    )

    return @(
        $inventoryEntryList |
            Sort-Object @{ Expression = { Get-GerberPluginInventorySortKey -Entry $_ } }, Guid
    )
}

function Get-GerberPluginInventoryContext {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [hashtable]$DiscoveredRecordTable,

        [Parameter(Mandatory)]
        [hashtable]$LoadedPluginStateTable,

        [Parameter(Mandatory)]
        [hashtable]$LoadedPluginCommandTable
    )

    return [pscustomobject][ordered]@{
        Configuration           = $Configuration
        DiscoveredRecordTable   = $DiscoveredRecordTable
        LoadedPluginStateTable  = $LoadedPluginStateTable
        LoadedPluginCommandTable = $LoadedPluginCommandTable
    }
}

function Get-GerberPreferredDiscoveredPluginRecordTable {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$DiscoveredRecordList
    )

    $table = @{}
    foreach ($group in ($DiscoveredRecordList | Group-Object Guid)) {
        $table[$group.Name] = @(
            $group.Group |
                Sort-Object @{ Expression = { [version]$_.Version }; Descending = $true }, @{ Expression = { $_.Path } }
        )[0]
    }

    return $table
}

function Get-GerberLoadedPluginStateTable {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param()

    $table = @{}
    foreach ($pluginState in @(Get-GerberRegisteredPluginStateList)) {
        $table[[string]$pluginState.Guid] = $pluginState
    }

    return $table
}

function Get-GerberLoadedPluginCommandTable {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$LoadedPluginStateTable
    )

    $ownerCommandTable = @{}
    foreach ($commandDefinition in @(Get-GerberRegisteredPluginCommandDefinitionList)) {
        Add-GerberPluginOwnerCommand `
            -OwnerCommandTable $ownerCommandTable `
            -CommandDefinition $commandDefinition
    }

    $table = @{}
    foreach ($guid in $LoadedPluginStateTable.Keys) {
        $pluginState = $LoadedPluginStateTable[$guid]
        $table[$guid] = @(Get-GerberPluginOwnerCommandNameList -OwnerCommandTable $ownerCommandTable -OwnerName ([string]$pluginState.Name))
    }

    return $table
}

function Add-GerberPluginOwnerCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$OwnerCommandTable,

        [Parameter(Mandatory)]
        [pscustomobject]$CommandDefinition
    )

    $ownerName = [string]$CommandDefinition.OwnerName
    if (-not $OwnerCommandTable.Contains($ownerName)) {
        $OwnerCommandTable[$ownerName] = New-Object 'System.Collections.Generic.List[string]'
    }

    $null = $OwnerCommandTable[$ownerName].Add([string]$CommandDefinition.Name)
}

function Get-GerberPluginOwnerCommandNameList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$OwnerCommandTable,

        [Parameter(Mandatory)]
        [string]$OwnerName
    )

    if (-not $OwnerCommandTable.Contains($OwnerName)) {
        return [string[]]@()
    }

    return [string[]]@(
        $OwnerCommandTable[$OwnerName] |
            Sort-Object -Unique
    )
}

function Get-GerberRegisteredPluginStateList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param()

    $registryState = Get-GerberRegisteredCommandRegistryState
    if ($null -eq $registryState) {
        return @()
    }

    return @($registryState.PluginList)
}

function Get-GerberRegisteredPluginCommandDefinitionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param()

    $registryState = Get-GerberRegisteredCommandRegistryState
    if ($null -eq $registryState) {
        return @()
    }

    return @(
        foreach ($commandDefinition in @($registryState.CommandList)) {
            if ([string]$commandDefinition.OwnerType -eq 'Plugin') {
                $commandDefinition
            }
        }
    )
}

function Get-GerberRegisteredCommandRegistryState {
    [OutputType([object])]
    [CmdletBinding()]
    param()

    $registryState = Get-Variable `
        -Name 'GerberCommandRegistryState' `
        -Scope Script `
        -ErrorAction SilentlyContinue
    if ($null -eq $registryState) {
        return $null
    }

    return $registryState.Value
}

function Get-GerberPluginInventoryGuidList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$DiscoveredRecordList,

        [Parameter(Mandatory)]
        [hashtable]$LoadedPluginStateTable
    )

    $guidSet = @{}
    foreach ($discoveredRecord in $DiscoveredRecordList) {
        $guidSet[[string]$discoveredRecord.Guid] = $true
    }

    foreach ($guid in (Get-GerberConfiguredPluginGuidList -Configuration $Configuration)) {
        $guidSet[$guid] = $true
    }

    foreach ($guid in $LoadedPluginStateTable.Keys) {
        $guidSet[$guid] = $true
    }

    return [string[]]@(
        $guidSet.Keys |
            Sort-Object |
            ForEach-Object { [string]$_ }
    )
}

function Get-GerberConfiguredPluginGuidList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration
    )

    $pluginConfiguration = Get-GerberUserConfigurationPropertyValue `
        -Configuration $Configuration `
        -PropertyName 'plugins'
    if ($null -eq $pluginConfiguration) {
        return [string[]]@()
    }

    return [string[]]@(
        @(
            Get-GerberConfiguredDecisionGuidList -PluginConfiguration $pluginConfiguration
            Get-GerberAssociatedPluginGuidList -PluginConfiguration $pluginConfiguration
        ) |
            Sort-Object -Unique |
            ForEach-Object { [string]$_ }
    )
}

function Get-GerberConfiguredDecisionGuidList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$PluginConfiguration
    )

    return [string[]]@(
        foreach ($propertyName in @('approved', 'declined')) {
            foreach ($guid in @(Get-GerberUserConfigurationPropertyValue -Configuration $PluginConfiguration -PropertyName $propertyName)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$guid)) {
                    [string]$guid
                }
            }
        }
    )
}

function Get-GerberAssociatedPluginGuidList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$PluginConfiguration
    )

    $associatedPluginTable = Get-GerberUserConfigurationPropertyValue `
        -Configuration $PluginConfiguration `
        -PropertyName 'associated'
    if ($null -eq $associatedPluginTable) {
        return [string[]]@()
    }

    return [string[]]@(
        foreach ($entry in @(Get-GerberPluginConfigurationEntryList -Configuration $associatedPluginTable)) {
            [string]$entry.Name
        }
    )
}

function ConvertTo-GerberPluginInventoryEntry {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Guid,

        [Parameter(Mandatory)]
        [pscustomobject]$InventoryContext
    )

    $discoveredRecord = Get-GerberPluginTableValue -Table $InventoryContext.DiscoveredRecordTable -Key $Guid
    $loadedPluginState = Get-GerberPluginTableValue -Table $InventoryContext.LoadedPluginStateTable -Key $Guid
    $registeredCommandPathList = @(
        Get-GerberPluginTableValue -Table $InventoryContext.LoadedPluginCommandTable -Key $Guid |
            Where-Object { $null -ne $_ }
    )
    $lifecycleState = Get-GerberPluginLifecycleState -Configuration $InventoryContext.Configuration -Guid $Guid
    $approvalStatus = Get-GerberPluginApprovalStatus -Configuration $InventoryContext.Configuration -Guid $Guid
    $isDiscovered = $null -ne $discoveredRecord
    $pluginSource = Get-GerberPluginInventorySource -DiscoveredRecord $discoveredRecord -LoadedPluginState $loadedPluginState
    $metadata = Get-GerberPluginInventoryMetadataRecord -PluginSource $pluginSource
    if ($null -eq $discoveredRecord -and $null -eq $loadedPluginState) {
        Complete-GerberMissingPluginDisplayRecord -Metadata $metadata -Configuration $InventoryContext.Configuration -Guid $Guid
    }

    return [pscustomobject][ordered]@{
        Guid                    = $Guid
        Name                    = $metadata.Name
        DisplayName             = Get-GerberPluginInventoryDisplayName -Guid $Guid -Name $metadata.Name
        Version                 = $metadata.Version
        Description             = $metadata.Description
        Author                  = $metadata.Author
        CompanyName             = $metadata.CompanyName
        ModulePath              = $metadata.ModulePath
        ApprovalStatus          = $approvalStatus
        IsAssociated            = $lifecycleState.IsAssociated
        IsEnabled               = $lifecycleState.IsEnabled
        State                   = Get-GerberPluginInventoryState -IsDiscovered:$isDiscovered -LifecycleState $lifecycleState
        Loaded                  = $null -ne $loadedPluginState
        IsDiscovered            = $isDiscovered
        RegisteredNamespaceList = @(Get-GerberPluginRegisteredNamespaceList -CommandPathList $registeredCommandPathList)
        RegisteredCommandList   = $registeredCommandPathList
    }
}

function Complete-GerberMissingPluginDisplayRecord {
    param([pscustomobject]$Metadata, [hashtable]$Configuration, [string]$Guid)

    $record = $Configuration
    foreach ($key in @('plugins', 'associated', $Guid)) {
        $record = Get-GerberUserConfigurationPropertyValue -Configuration $record -PropertyName $key
        if ($null -eq $record) {
            return
        }
    }
    $Metadata.Name = Get-GerberUserConfigurationPropertyValue -Configuration $record -PropertyName 'name'
    $Metadata.Version = Get-GerberUserConfigurationPropertyValue -Configuration $record -PropertyName 'version'
}

function Get-GerberPluginInventoryDisplayName {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Guid,

        [AllowNull()]
        [string]$Name
    )

    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        return $Name
    }

    return $Guid
}

function Get-GerberPluginInventoryMetadataRecord {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PluginSource
    )

    return [pscustomobject][ordered]@{
        Name        = Get-GerberPluginInventoryValue -PluginSource $PluginSource -PropertyName 'Name'
        Version     = Get-GerberPluginInventoryValue -PluginSource $PluginSource -PropertyName 'Version' -TreatWhitespaceAsNull
        Description = Get-GerberPluginInventoryValue -PluginSource $PluginSource -PropertyName 'Description'
        Author      = Get-GerberPluginInventoryValue -PluginSource $PluginSource -PropertyName 'Author'
        CompanyName = Get-GerberPluginInventoryValue -PluginSource $PluginSource -PropertyName 'CompanyName'
        ModulePath  = Get-GerberPluginInventoryModulePath -PluginSource $PluginSource
    }
}

function Get-GerberPluginInventorySource {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [pscustomobject]$DiscoveredRecord,

        [AllowNull()]
        [pscustomobject]$LoadedPluginState
    )

    return [pscustomobject][ordered]@{
        DiscoveredRecord = $DiscoveredRecord
        LoadedPluginState = $LoadedPluginState
    }
}

function Get-GerberPluginInventoryValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PluginSource,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [switch]$TreatWhitespaceAsNull
    )

    $value = $null
    if ($null -ne $PluginSource.DiscoveredRecord) {
        $value = [string]$PluginSource.DiscoveredRecord.$PropertyName
    } elseif ($null -ne $PluginSource.LoadedPluginState) {
        $value = [string]$PluginSource.LoadedPluginState.$PropertyName
    }

    if ($TreatWhitespaceAsNull -and [string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    return $value
}

function Get-GerberPluginInventoryModulePath {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PluginSource
    )

    if ($null -ne $PluginSource.DiscoveredRecord) {
        return [string]$PluginSource.DiscoveredRecord.Path
    }

    if ($null -eq $PluginSource.LoadedPluginState) {
        return $null
    }

    return [string]$PluginSource.LoadedPluginState.ModulePath
}

function Get-GerberPluginTableValue {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Table,

        [Parameter(Mandatory)]
        [string]$Key
    )

    if (-not $Table.Contains($Key)) {
        return $null
    }

    return $Table[$Key]
}

function Get-GerberPluginApprovalStatus {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [string]$Guid
    )

    if (Test-GerberPluginGuidDecision -Configuration $Configuration -PropertyName 'approved' -Guid $Guid) {
        return 'Approved'
    }

    if (Test-GerberPluginGuidDecision -Configuration $Configuration -PropertyName 'declined' -Guid $Guid) {
        return 'Declined'
    }

    return 'Unknown'
}

function Get-GerberPluginInventoryState {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$IsDiscovered,

        [Parameter(Mandatory)]
        [pscustomobject]$LifecycleState
    )

    if (-not $IsDiscovered) {
        if ($LifecycleState.IsAssociated) {
            return 'Missing'
        }

        return 'Not discovered'
    }

    if (-not $LifecycleState.IsAssociated) {
        return 'Discovered'
    }

    if ($LifecycleState.IsEnabled) {
        return 'Enabled'
    }

    return 'Disabled'
}

function Get-GerberPluginRegisteredNamespaceList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$CommandPathList = @()
    )

    return @(
        foreach ($commandPath in $CommandPathList) {
            if ([string]::IsNullOrWhiteSpace($commandPath)) {
                continue
            }

            ($commandPath -split '\s+')[0]
        }
    ) | Sort-Object -Unique
}

function Get-GerberPluginInventorySortKey {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Entry
    )

    return [string]$Entry.DisplayName.ToLowerInvariant()
}
