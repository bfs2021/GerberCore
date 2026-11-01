function Get-TestPluginCreationInputMap {
    param([string]$Parent, [AllowNull()][string]$RepositoryUri)

    $inputMap = @{
        Suffix = 'MyCompany'
        Description = 'Isolated hello'
        Namespace = 'mycompany'
        ParentPath = $Parent
    }
    if ($RepositoryUri) {
        $inputMap.Repository = @{ Name = 'ExampleFeed'; Uri = $RepositoryUri }
    }
    return $inputMap
}

function Invoke-TestPluginProjectCreation {
    param([hashtable]$InputMap)

    return & (Get-Module Gerber) {
        param($InputMap)
        Clear-GerberCommandRegistry
        $null = Initialize-GerberCommandRegistry -PluginModulePathList @()
        $request = Resolve-GerberPluginProjectRequest -InputMap $InputMap
        New-GerberPluginProject -Request $request
    } $InputMap
}

function Assert-GerberCreatedPluginLifecycle {
    param([pscustomobject]$Created, [string]$ConfigPath)

    Assert-TestCreatedPluginApproval -Created $Created -ConfigPath $ConfigPath
    Assert-TestCreatedPluginInventory -Created $Created
    Get-Module Gerber.MyCompany | Should -BeNullOrEmpty
    Test-Path (Join-Path $Created.Path 'dist/Gerber.MyCompany/Gerber.MyCompany.psd1') | Should -BeTrue
}

function Assert-TestCreatedPluginApproval {
    param([pscustomobject]$Created, [string]$ConfigPath)

    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
    $config.plugins.approved | Should -Contain $Created.Guid
    $config.plugins.associated[$Created.Guid].enabled | Should -BeTrue
    $config.plugins.associated[$Created.Guid].name | Should -Be 'Gerber.MyCompany'
    $config.plugins.associated[$Created.Guid].version | Should -Be '0.1.0'
}

function Assert-TestCreatedPluginInventory {
    param([pscustomobject]$Created)

    $inventory = & (Get-Module Gerber) {
        Get-GerberPluginInventory -PluginModulePathList @()
    }
    $entry = $inventory | Where-Object Guid -EQ $Created.Guid
    $entry.ApprovalStatus | Should -Be 'Approved'
    $entry.Name | Should -Be 'Gerber.MyCompany'
    $entry.Version | Should -Be '0.1.0'
    $entry.State | Should -Be 'Missing'
    $entry.IsAssociated | Should -BeTrue
    $entry.IsEnabled | Should -BeTrue
    $entry.IsDiscovered | Should -BeFalse
    $entry.Loaded | Should -BeFalse
}

function Assert-TestCreatedPluginBoundary {
    param([pscustomobject]$Created)

    $output = & (Join-Path $PSHOME 'pwsh') -NoLogo -NoProfile -NonInteractive -Command {
        param($Core, $Project)
        $coreModuleRoot = Split-Path -Parent (Split-Path -Parent $Core)
        $env:PSModulePath = $coreModuleRoot + [System.IO.Path]::PathSeparator + $env:PSModulePath
        Import-Module $Core -Force
        & (Join-Path $Project 'scripts/Test-PluginBoundary.ps1')
    } -args $script:coreManifest, $Created.Path
    $LASTEXITCODE | Should -Be 0
    ($output -join "`n") | Should -Match 'boundary: passed'
}

function Publish-TestCreatedPlugin {
    param([pscustomobject]$Created, [string]$ModuleRoot)

    $publishScript = Join-Path $script:repositoryRoot 'tests/TestHelpers/Publish-GerberPluginTestProject.ps1'
    & (Join-Path $PSHOME 'pwsh') -NoLogo -NoProfile -NonInteractive -File $publishScript -ProjectPath $Created.Path -ModuleRoot $ModuleRoot
    $LASTEXITCODE | Should -Be 0
}

function Assert-TestCreatedPluginRestart {
    param([string]$ModuleRoot, [string]$ConfigPath)

    $before = Get-Content $ConfigPath -Raw
    $probe = Join-Path $script:repositoryRoot 'tests/TestHelpers/Invoke-GerberPluginRestartProbe.ps1'
    $output = '' | & (Join-Path $PSHOME 'pwsh') -NoLogo -NoProfile -File $probe -CoreManifest $script:coreManifest -ModuleRoot $ModuleRoot
    $LASTEXITCODE | Should -Be 0
    ($output -join "`n") | Should -Match 'mycompany'
    ($output -join "`n") | Should -Match 'Hello from Gerber.MyCompany!'
    ($output -join "`n") | Should -Match 'Gerber.MyCompany\s+0.1.0\s+'
    (Get-Content $ConfigPath -Raw) | Should -Be $before
}

function Assert-TestCreatedPluginManifest {
    param([pscustomobject]$Created, [string]$ModuleRoot, [AllowNull()][string]$RepositoryUri)

    $manifestPath = Join-Path $ModuleRoot "$($Created.Name)/$($Created.Version)/$($Created.Name).psd1"
    $manifestPath | Should -Exist
    $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath -ErrorAction Stop
    $manifest.GUID.ToString() | Should -Be $Created.Guid
    $manifest.PrivateData.Gerber.Keys | Should -Not -Contain 'Guid'
    $manifest.PrivateData.Gerber.Keys | Should -Not -Contain 'RepositoryUri'
    if ($RepositoryUri) {
        $manifest.PrivateData.Gerber.Repository.Name | Should -BeExactly 'ExampleFeed'
        $manifest.PrivateData.Gerber.Repository.Uri | Should -BeExactly $RepositoryUri
    } else {
        $manifest.PrivateData.Gerber.Repository.Name | Should -BeExactly 'PSGallery'
        $manifest.PrivateData.Gerber.Repository.Uri | Should -BeExactly 'https://www.powershellgallery.com/api/v2'
    }
    $manifest.PrivateData.Gerber.Keys | Should -Not -Contain 'Update'
}
