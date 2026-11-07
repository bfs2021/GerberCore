function Get-GerberPluginManifestMetadataList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [string[]]$PluginModulePathList
    )

    return @(
        foreach ($manifestPath in (Get-GerberCandidatePluginManifestPathList -PluginModulePathList $PluginModulePathList)) {
            $metadata = Read-GerberPluginManifestRecord -ManifestPath $manifestPath
            if ($null -ne $metadata) {
                $metadata
            }
        }
    )
}

function Get-GerberCandidatePluginManifestPathList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [string[]]$PluginModulePathList
    )

    return [string[]]@(
        foreach ($moduleRoot in $PluginModulePathList) {
            if (Test-Path -LiteralPath $moduleRoot -PathType Container -ErrorAction SilentlyContinue) {
                Get-GerberManifestPathListFromModuleRoot -ModuleRoot $moduleRoot
            }
        }
    ) | Sort-Object -Unique
}

function Get-GerberManifestPathListFromModuleRoot {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleRoot
    )

    $manifestPathList = @(
        Get-ChildItem -LiteralPath $ModuleRoot -File -Filter '*.psd1' -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName
    )
    foreach ($moduleDirectory in (Get-ChildItem -LiteralPath $ModuleRoot -Directory -ErrorAction SilentlyContinue)) {
        $manifestPathList += @(Get-GerberManifestPathListFromModuleDirectory -ModuleDirectory $moduleDirectory)
    }
    return [string[]]$manifestPathList
}

function Get-GerberManifestPathListFromModuleDirectory {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo]$ModuleDirectory
    )

    $manifestName = "$($ModuleDirectory.Name).psd1"
    $manifestPathList = @()
    $directManifestPath = Join-Path $ModuleDirectory.FullName $manifestName
    if (Test-Path -LiteralPath $directManifestPath -PathType Leaf) {
        $manifestPathList += $directManifestPath
    }
    foreach ($versionDirectory in (Get-ChildItem -LiteralPath $ModuleDirectory.FullName -Directory -ErrorAction SilentlyContinue)) {
        $versionManifestPath = Join-Path $versionDirectory.FullName $manifestName
        if (Test-Path -LiteralPath $versionManifestPath -PathType Leaf) {
            $manifestPathList += $versionManifestPath
        }
    }
    return [string[]]$manifestPathList
}

function Read-GerberPluginManifestRecord {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath
    )

    try {
        $manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath -ErrorAction Stop
    } catch {
        Write-GerberPluginManifestWarning -ManifestPath $ManifestPath -Message 'could not inspect manifest metadata safely'
        return $null
    }

    $privateData = Get-GerberModulePrivateDataValueOrNull -InputObject $manifest -Name 'PrivateData'
    $gerberMetadata = Get-GerberModulePrivateDataValueOrNull -InputObject $privateData -Name 'Gerber'
    if ((Get-GerberModulePrivateDataValueOrNull -InputObject $gerberMetadata -Name 'Plugin') -ne $true) {
        return $null
    }
    return ConvertTo-GerberPluginManifestRecord -Manifest $manifest -ManifestPath $ManifestPath
}

function ConvertTo-GerberPluginManifestRecord {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest,

        [Parameter(Mandatory)]
        [string]$ManifestPath
    )

    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($ManifestPath)
    try {
        $guidValue = Get-GerberModulePrivateDataValueOrNull -InputObject $Manifest -Name 'GUID'
        $versionValue = Get-GerberModulePrivateDataValueOrNull -InputObject $Manifest -Name 'ModuleVersion'
        $guid = ConvertTo-GerberManifestGuid -Value $guidValue -ModuleName $moduleName
        $version = [version]$versionValue
        $moduleInfo = ConvertTo-GerberPluginManifestRecordValue `
            -Manifest $Manifest `
            -ManifestPath $ManifestPath `
            -Guid $guid `
            -Version $version
        return $moduleInfo
    } catch {
        Write-GerberPluginManifestWarning -ManifestPath $ManifestPath -Message $_.Exception.Message
        return $null
    }
}

function ConvertTo-GerberManifestGuid {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    $parsedGuid = [guid]::Empty
    if (-not [guid]::TryParse([string]$Value, [ref]$parsedGuid)) {
        throw [System.IO.InvalidDataException]::new(
            "Gerber plugin '$ModuleName' has an invalid manifest GUID."
        )
    }
    return $parsedGuid.ToString('D')
}

function ConvertTo-GerberPluginManifestRecordValue {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest,

        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [string]$Guid,

        [Parameter(Mandatory)]
        [version]$Version
    )

    return [pscustomobject][ordered]@{
        Name = [System.IO.Path]::GetFileNameWithoutExtension($ManifestPath)
        Version = $Version
        Guid = $Guid
        Path = $ManifestPath
        Description = [string](Get-GerberModulePrivateDataValueOrNull -InputObject $Manifest -Name 'Description')
        Author = [string](Get-GerberModulePrivateDataValueOrNull -InputObject $Manifest -Name 'Author')
        CompanyName = [string](Get-GerberModulePrivateDataValueOrNull -InputObject $Manifest -Name 'CompanyName')
        PrivateData = Get-GerberModulePrivateDataValueOrNull -InputObject $Manifest -Name 'PrivateData'
    }
}

function Write-GerberPluginManifestWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($ManifestPath)
    if ($moduleName -like 'Gerber.*') {
        Write-Warning "Skipping Gerber plugin '$moduleName': $Message."
    }
}
