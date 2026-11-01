function Resolve-GerberUserConfigPath {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [bool]$IsWindowsPlatform = $IsWindows
    )

    $overridePath = Get-GerberUserConfigEnvironmentValue -Name 'GERBER_CONFIG_PATH'
    if ($null -ne $overridePath) {
        $resolvedPath = Resolve-GerberUserConfigAbsolutePath `
            -Path $overridePath `
            -EnvironmentVariableName 'GERBER_CONFIG_PATH' `
            -Description 'a full file path'
        return ConvertTo-GerberCoreConfigPath -Path $resolvedPath -IsWindowsPlatform $IsWindowsPlatform
    }

    if ($IsWindowsPlatform) {
        $appDataPath = Get-GerberUserConfigRequiredEnvironmentValue `
            -Name 'APPDATA' `
            -Description 'the Windows roaming application data directory'
        return [System.IO.Path]::GetFullPath((Join-Path $appDataPath 'Gerber/GerberCore.json'))
    }

    $xdgConfigHome = Get-GerberUserConfigEnvironmentValue -Name 'XDG_CONFIG_HOME'
    if ($null -ne $xdgConfigHome) {
        $resolvedXdgConfigHome = Resolve-GerberUserConfigAbsolutePath `
            -Path $xdgConfigHome `
            -EnvironmentVariableName 'XDG_CONFIG_HOME' `
            -Description 'a directory path'
        return [System.IO.Path]::GetFullPath((Join-Path $resolvedXdgConfigHome 'Gerber/GerberCore.json'))
    }

    $homePath = Get-GerberUserConfigRequiredEnvironmentValue `
        -Name 'HOME' `
        -Description 'the user home directory'
    return [System.IO.Path]::GetFullPath((Join-Path $homePath '.config/Gerber/GerberCore.json'))
}

function ConvertTo-GerberCoreConfigPath {
    param([string]$Path, [bool]$IsWindowsPlatform)

    $name = [System.IO.Path]::GetFileName($Path)
    $comparison = [System.StringComparison]::Ordinal
    if ($IsWindowsPlatform) {
        $comparison = [System.StringComparison]::OrdinalIgnoreCase
    }
    if ([string]::Equals($name, 'config.json', $comparison)) {
        return Join-Path (Split-Path $Path -Parent) 'GerberCore.json'
    }
    return $Path
}

function Get-GerberUserConfigEnvironmentValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return [Environment]::GetEnvironmentVariable($Name)
}

function Get-GerberUserConfigRequiredEnvironmentValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Description
    )

    $value = Get-GerberUserConfigEnvironmentValue -Name $Name
    return Resolve-GerberUserConfigAbsolutePath `
        -Path $value `
        -EnvironmentVariableName $Name `
        -Description $Description
}

function Resolve-GerberUserConfigAbsolutePath {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$EnvironmentVariableName,

        [Parameter(Mandatory)]
        [string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw [System.ArgumentException]::new(
            "Gerber could not resolve the user configuration path because environment variable '$EnvironmentVariableName' must contain $Description."
        )
    }

    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        throw [System.ArgumentException]::new(
            "Gerber could not resolve the user configuration path because environment variable '$EnvironmentVariableName' must contain an absolute path."
        )
    }

    try {
        return [System.IO.Path]::GetFullPath($Path)
    } catch [System.ArgumentException] {
        throw [System.ArgumentException]::new(
            "Gerber could not resolve the user configuration path because environment variable '$EnvironmentVariableName' must contain a valid path.",
            $_.Exception
        )
    } catch [System.NotSupportedException] {
        throw [System.ArgumentException]::new(
            "Gerber could not resolve the user configuration path because environment variable '$EnvironmentVariableName' must contain a valid path.",
            $_.Exception
        )
    }
}
