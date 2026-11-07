[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$GerberRoot,

    [string]$FixtureModuleRoot,

    [Parameter(Mandatory)]
    [string]$SecretStoreStatePath,

    [Parameter(Mandatory)]
    [string]$ClipboardStatePath,

    [Parameter(Mandatory)]
    [string]$HttpFixturePath,

    [Parameter(Mandatory)]
    [string]$HttpStatePath,

    [Parameter(Mandatory)]
    [string]$ModuleStatePath,

    [Parameter(Mandatory)]
    [string]$DiagnosticStatePath,

    [Parameter(Mandatory)]
    [string]$PromptTracePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'TestHarness.State.ps1')
. (Join-Path $PSScriptRoot 'TestHarness.ModuleValidation.ps1')
. (Join-Path $PSScriptRoot 'TestHarness.CredentialStore.ps1')
. (Join-Path $PSScriptRoot 'TestHarness.Configuration.ps1')
. (Join-Path $PSScriptRoot 'TestHarness.Environment.ps1')
. (Join-Path $PSScriptRoot 'TestHarness.RuntimeDependencies.ps1')

Initialize-GerberTerminalConfigurationEnvironment -PromptTracePath $PromptTracePath
Write-GerberTerminalJsonFile -Path $DiagnosticStatePath -Value @{
    events = @()
}
Write-GerberTerminalJsonFile -Path $ModuleStatePath -Value (Get-GerberTerminalDefaultModuleState)

try {
    Add-GerberTerminalDiagnosticEvent -Path $DiagnosticStatePath -Kind 'terminal-harness-started'
    Import-GerberTerminalRuntimeDependency -GerberRoot $GerberRoot

    Initialize-GerberTerminalClipboardShim -Path $ClipboardStatePath
    Initialize-GerberTerminalHttpShim -FixturePath $HttpFixturePath -StatePath $HttpStatePath
    Initialize-GerberPromptTracePath -Path $PromptTracePath

    $modulePathList = @()
    if (-not [string]::IsNullOrWhiteSpace($FixtureModuleRoot)) {
        $modulePathList += $FixtureModuleRoot
    }

    $modulePathList += (Join-Path $GerberRoot 'dist')
    $env:PSModulePath = ($modulePathList -join [System.IO.Path]::PathSeparator)
    Add-GerberTerminalDiagnosticEvent -Path $DiagnosticStatePath -Kind 'module-path-prepared' -Data @{
        modulePath = $env:PSModulePath
    }

    $validationContext = Get-GerberTerminalModuleValidationContext `
        -ModuleStatePath $ModuleStatePath `
        -DiagnosticStatePath $DiagnosticStatePath
    $gerberExpected = Get-GerberTerminalExpectedModuleRecord -Name 'Gerber' -ManifestPath (Join-Path $GerberRoot 'dist/Gerber/Gerber.psd1')
    $gerberModule = Import-Module $gerberExpected.ManifestPath -Force -PassThru -ErrorAction Stop
    Assert-GerberTerminalResolvedModule `
        -ValidationContext $validationContext `
        -Expected $gerberExpected `
        -Module $gerberModule `
        -ResolutionKind 'explicit import'

    if (-not [string]::IsNullOrWhiteSpace($FixtureModuleRoot)) {
        $fixtureExpected = Get-GerberTerminalExpectedModuleRecord `
            -Name 'Gerber.TerminalFixture' `
            -ManifestPath (Join-Path $FixtureModuleRoot 'Gerber.TerminalFixture/1.0.0/Gerber.TerminalFixture.psd1')
        $fixtureModule = Get-GerberTerminalFirstAvailableModule -Name $fixtureExpected.Name
        Assert-GerberTerminalResolvedModule `
            -ValidationContext $validationContext `
            -Expected $fixtureExpected `
            -Module $fixtureModule `
            -ResolutionKind 'module discovery'
    }

    Complete-GerberTerminalModuleValidation -Path $ModuleStatePath
    Add-GerberTerminalDiagnosticEvent -Path $DiagnosticStatePath -Kind 'module-validation-complete'

    & (Get-Module Gerber) {
        param(
            [string]$SecretStorePath,
            [string]$ConfigPath
        )

        $script:GerberCredentialStore = Get-GerberTerminalCredentialStore -Path $SecretStorePath
        $script:GerberTerminalConfigPath = $ConfigPath
        function script:Resolve-GerberConfigPath {
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
    } $SecretStoreStatePath $env:GERBER_CONFIG_PATH

    & $gerberModule {
        param($ShimPath, $FixturePath)
        . $ShimPath
        $script:GerberTerminalUpdateFixturePath = $FixturePath
    } (Join-Path $PSScriptRoot 'TestHarness.Update.ps1') (Join-Path (Split-Path $PromptTracePath -Parent) 'update-fixture.json')

    Add-GerberTerminalDiagnosticEvent -Path $DiagnosticStatePath -Kind 'invoke-gerber'
    Invoke-Gerber
} catch {
    Write-GerberTerminalModuleValidationFailure -Path $ModuleStatePath -ErrorRecord $_
    Add-GerberTerminalDiagnosticEvent -Path $DiagnosticStatePath -Kind 'terminal-harness-failure' -Data @{
        message = $_.Exception.Message
        scriptStackTrace = $_.ScriptStackTrace
    }
    throw
}
