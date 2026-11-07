function Initialize-GerberActiveTreeFixture {
    param([string]$Root, [string]$Name, [string]$Guid, [string[]]$Commands)

    $directory = Join-Path $Root "$Name/1.0.0"
    $null = New-Item -ItemType Directory -Path $directory -Force
    $manifest = "@{ RootModule = '$Name.psm1'; ModuleVersion = '1.0.0'; GUID = '$Guid'; FunctionsToExport = @('Get-GerberPlugin'); PrivateData = @{ Gerber = @{ Plugin = `$true; ApiVersion = '1'; MinimumGerberVersion = '0.1.0-preview' } } }"
    $definitions = @(foreach ($command in $Commands) {
        "[pscustomobject]@{ Name = '$command'; Description = 'Generic leaf'; Handler = { `$false }; Subcommands = @{} }"
    }) -join [Environment]::NewLine
    $module = "function Get-GerberPlugin { param(`$Gerber) [pscustomobject]@{ Commands = @($definitions) } }"
    [System.IO.File]::WriteAllText((Join-Path $directory "$Name.psd1"), "$manifest`n")
    [System.IO.File]::WriteAllText((Join-Path $directory "$Name.psm1"), "$module`n")
}
