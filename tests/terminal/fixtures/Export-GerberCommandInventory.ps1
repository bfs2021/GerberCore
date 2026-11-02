[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$GerberRoot,

    [string]$FixtureModuleRoot,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-GerberTerminalDefinitionMap {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$CommandList
    )

    $definitionMap = @{}
    foreach ($command in $CommandList) {
        $definitionMap[[string]$command.Name] = $command
    }
    return $definitionMap
}

function Get-GerberTerminalSubcommandDescription {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Value
    )

    if ($Value -is [string]) {
        return $Value
    }
    return [string]$Value.Description
}

function Get-GerberTerminalSubcommandTable {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Value
    )

    if ($Value -is [string]) {
        return [ordered]@{}
    }
    return $Value.Subcommands
}

function Add-GerberTerminalInventoryItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Inventory,

        [Parameter(Mandatory)]
        [hashtable]$Context
    )

    $definition = $Context.DefinitionMap[$Context.Path]
    $owner = if ($null -eq $definition) { $Context.Owner } else { $definition }
    $null = $Inventory.Add([pscustomobject][ordered]@{
            canonicalPath = $Context.Path
            ownerName = [string]$owner.OwnerName
            ownerType = [string]$owner.OwnerType
            pluginIdentity = if ($owner.OwnerType -eq 'Plugin') { [string]$owner.OwnerName } else { $null }
            description = $Context.Description
            interactive = $true
            hasSubcommands = $Context.Subcommands.Count -gt 0
            conditionalContainer = $null -ne $definition -and
                $definition.OwnerType -eq 'Core' -and
                $null -ne $definition.PSObject.Properties['IsContainer'] -and $definition.IsContainer
            workflowIdentifiers = @("command:$($Context.Path)")
            externalDependencies = @()
            safeForUnattendedTesting = $false
        })
}

function Add-GerberTerminalSubcommandInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Inventory,

        [Parameter(Mandatory)]
        [hashtable]$Context
    )

    foreach ($entry in $Context.Subcommands.GetEnumerator()) {
        $path = "$($Context.Path) $([string]$entry.Key)"
        $childContext = @{
            Path = $path
            Description = Get-GerberTerminalSubcommandDescription -Value $entry.Value
            Subcommands = Get-GerberTerminalSubcommandTable -Value $entry.Value
            DefinitionMap = $Context.DefinitionMap
            Owner = $Context.Owner
        }
        Add-GerberTerminalInventoryItem -Inventory $Inventory -Context $childContext
        Add-GerberTerminalSubcommandInventory -Inventory $Inventory -Context $childContext
    }
}

function Get-GerberTerminalCommandInventory {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$CommandList
    )

    $inventory = New-Object 'System.Collections.Generic.List[object]'
    $definitionMap = Get-GerberTerminalDefinitionMap -CommandList $CommandList
    foreach ($root in @($CommandList | Where-Object { -not $_.ParentName })) {
        $context = @{
            Path = [string]$root.Name
            Description = [string]$root.Description
            Subcommands = $root.Subcommands
            DefinitionMap = $definitionMap
            Owner = $root
        }
        Add-GerberTerminalInventoryItem -Inventory $inventory -Context $context
        Add-GerberTerminalSubcommandInventory -Inventory $inventory -Context $context
    }
    return $inventory.ToArray()
}

. (Join-Path $PSScriptRoot 'TestHarness.RuntimeDependencies.ps1')
Import-GerberTerminalRuntimeDependency -GerberRoot $GerberRoot

$modulePathList = @()
if (-not [string]::IsNullOrWhiteSpace($FixtureModuleRoot)) {
    $modulePathList += $FixtureModuleRoot
}
$modulePathList += (Join-Path $GerberRoot 'dist')
$env:PSModulePath = $modulePathList -join [System.IO.Path]::PathSeparator
$originalConfigPath = $env:GERBER_CONFIG_PATH
$inventoryConfigPath = Join-Path ([System.IO.Path]::GetTempPath()) "gerber-inventory-$([guid]::NewGuid()).json"
$inventoryConfiguration = @{
    schemaVersion = 1
}
if (-not [string]::IsNullOrWhiteSpace($FixtureModuleRoot)) {
    $fixtureManifestPath = Join-Path $FixtureModuleRoot 'Gerber.TerminalFixture/1.0.0/Gerber.TerminalFixture.psd1'
    $fixtureManifest = Import-PowerShellDataFile -LiteralPath $fixtureManifestPath
    $inventoryConfiguration.plugins = @{
        approved = @(([guid]$fixtureManifest.GUID).ToString('D'))
    }
}
[System.IO.File]::WriteAllText(
    $inventoryConfigPath,
    ($inventoryConfiguration | ConvertTo-Json -Depth 5),
    [System.Text.UTF8Encoding]::new($false)
)
$env:GERBER_CONFIG_PATH = $inventoryConfigPath

try {
    $gerberModule = Import-Module (Join-Path $GerberRoot 'dist/Gerber/Gerber.psd1') -Force -PassThru
    $commandList = & $gerberModule {
        $null = Initialize-GerberCommandRegistry
        return $script:GerberCommandRegistryState.CommandList
    }
    $inventory = Get-GerberTerminalCommandInventory -CommandList $commandList
    $outputDirectory = Split-Path -Parent $OutputPath
    $null = New-Item -ItemType Directory -Path $outputDirectory -Force
    [System.IO.File]::WriteAllText(
        $OutputPath,
        ($inventory | ConvertTo-Json -Depth 8),
        [System.Text.UTF8Encoding]::new($false)
    )
} finally {
    $env:GERBER_CONFIG_PATH = $originalConfigPath
    Remove-Item -LiteralPath $inventoryConfigPath -Force -ErrorAction SilentlyContinue
}
