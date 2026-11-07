function Resolve-GerberPluginUpdateScopeRootMap {
    param()
    if ($IsWindows) {
        return @{
            CurrentUser = Join-Path (Get-GerberSpecialFolderPath -Name 'MyDocuments') 'PowerShell/Modules'
            AllUsers    = Join-Path ((Get-GerberSpecialFolderPath -Name 'ProgramFiles')) 'PowerShell/Modules'
        }
    }
    @{
        CurrentUser = Resolve-GerberUnixUserModuleRoot
        AllUsers    = '/usr/local/share/powershell/Modules'
    }
}

function Resolve-GerberUnixUserModuleRoot {
    param()
    $dataRoot = [Environment]::GetEnvironmentVariable('XDG_DATA_HOME')
    if ([string]::IsNullOrWhiteSpace($dataRoot)) {
        $dataRoot = Join-Path ((Get-GerberSpecialFolderPath -Name 'UserProfile')) '.local/share'
    }
    if (-not [IO.Path]::IsPathRooted($dataRoot)) {
        throw [System.InvalidOperationException]::new('The user module data directory must be absolute.')
    }
    Join-Path $dataRoot 'powershell/Modules'
}

function Get-GerberSpecialFolderPath {
    param([Parameter(Mandatory)][string]$Name)
    [Environment]::GetFolderPath($Name)
}
