function Initialize-GerberCorePolicyNovaFixture {
    param([string]$DestinationRoot)
    $moduleRoot = Join-Path $DestinationRoot 'NovaModuleTools'
    $null = New-Item -ItemType Directory -Path $moduleRoot -Force
    $manifest = Join-Path $moduleRoot 'NovaModuleTools.psd1'
    New-ModuleManifest -Path $manifest -ModuleVersion '3.4.2' `
        -Guid '6b9202c8-0353-473b-b73c-afab632125a6' `
        -FunctionsToExport @() -CmdletsToExport @() -AliasesToExport @() -VariablesToExport @()
    return $manifest
}
