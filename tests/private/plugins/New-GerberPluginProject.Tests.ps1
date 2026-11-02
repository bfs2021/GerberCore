BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'New-GerberPluginProject' -Tag 'PluginCreate' {
    BeforeEach {
        Mock Get-GerberModuleSemanticVersion { '1.2.3' }
        $parent = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
        $null = New-Item -ItemType Directory -Path $parent
        $request = [pscustomobject]@{
            Name = 'Gerber.Example'
            Suffix = 'Example'
            Description = 'Example tools'
            Namespace = 'example'
            ParentPath = $parent
            Destination = Join-Path $parent 'Gerber.Example'
        }
        $null = $request
    }

    It 'generates and validates before persisting approval for the same GUID' {
        Mock Test-GerberPluginProject {}
        Mock Resolve-GerberPluginApproval { $true }
        $result = New-GerberPluginProject -Request $request
        $project = Get-Content (Join-Path $result.Path 'project.json') -Raw | ConvertFrom-Json
        $project.ProjectName | Should -Be 'Gerber.Example'
        $project.Manifest.GUID | Should -Be $result.Guid
        $project.Manifest.PrivateData.Gerber.ApiVersion | Should -Be '1'
        $result.Name | Should -Be 'Gerber.Example'
        $result.Version | Should -Be $project.Version
        $result.Repository.Name | Should -BeExactly 'PSGallery'
        $result.Repository.Uri | Should -BeExactly 'https://www.powershellgallery.com/api/v2'
        Test-Path (Join-Path $result.Path 'src/public/Get-GerberPlugin.ps1') | Should -BeTrue
        Test-Path (Join-Path $result.Path 'tests/public/Get-GerberPlugin.Integration.Tests.ps1') | Should -BeTrue
        Should -Invoke Resolve-GerberPluginApproval -Times 1 -ParameterFilter {
            $ExplicitApproval -and $PluginModule.Guid -eq $result.Guid -and
            $DisplayMetadata.name -eq 'Gerber.Example' -and $DisplayMetadata.version -eq $project.Version
        }
    }

    It 'cleans only its staging directory and never approves after failed validation' {
        Mock Test-GerberPluginProject { throw [System.IO.InvalidDataException]::new('validation failed') }
        Mock Resolve-GerberPluginApproval {}
        { New-GerberPluginProject -Request $request } | Should -Throw '*validation failed*'
        Test-Path $request.Destination | Should -BeFalse
        @(Get-ChildItem $request.ParentPath -Force).Count | Should -Be 0
        Should -Invoke Resolve-GerberPluginApproval -Times 0
    }

    It 'cleans invalid authored generation before finalization and GUID approval' -Tag 'PluginBoundary' {
        Mock Write-GerberPluginProject {
            $null = New-Item -ItemType Directory "$Path/src/private" -Force
            Set-Content "$Path/src/private/Invalid.ps1" 'Get-GerberCommandRegistry'
        }
        Mock Resolve-GerberPluginApproval {}
        { New-GerberPluginProject -Request $request } | Should -Throw '*boundary validation failed*'
        Test-Path $request.Destination | Should -BeFalse
        @(Get-ChildItem $request.ParentPath -Force).Count | Should -Be 0
        Should -Invoke Resolve-GerberPluginApproval -Times 0
    }

    It 'preserves the final project and reports its exact path when approval persistence fails' {
        Mock Test-GerberPluginProject {}
        Mock Resolve-GerberPluginApproval { throw [System.IO.IOException]::new('config denied') }
        { New-GerberPluginProject -Request $request } | Should -Throw "*$($request.Destination)*not approved*"
        Test-Path (Join-Path $request.Destination 'project.json') | Should -BeTrue
    }

    It 'cleans staging and leaves approval untouched when validation is cancelled' {
        Mock Test-GerberPluginProject { throw [System.OperationCanceledException]::new('cancelled') }
        Mock Resolve-GerberPluginApproval {}
        { New-GerberPluginProject -Request $request } | Should -Throw '*cancelled*'
        @(Get-ChildItem $request.ParentPath -Force).Count | Should -Be 0
        Should -Invoke Resolve-GerberPluginApproval -Times 0
    }

    It 'preserves a destination created by another process during validation' {
        Mock Test-GerberPluginProject {
            $null = New-Item -ItemType Directory -Path $Request.Destination
            Set-Content -LiteralPath (Join-Path $Request.Destination 'user.txt') -Value 'keep me'
        }
        Mock Resolve-GerberPluginApproval {}
        { New-GerberPluginProject -Request $request } | Should -Throw
        Get-Content (Join-Path $request.Destination 'user.txt') | Should -Be 'keep me'
        @(Get-ChildItem $request.ParentPath -Directory -Force).Count | Should -Be 1
        Should -Invoke Resolve-GerberPluginApproval -Times 0
    }

    It 'does not create or approve anything under WhatIf' {
        Mock Test-GerberPluginProject {}
        Mock Resolve-GerberPluginApproval {}
        New-GerberPluginProject -Request $request -WhatIf
        @(Get-ChildItem $request.ParentPath -Force).Count | Should -Be 0
        Should -Invoke Test-GerberPluginProject -Times 0
        Should -Invoke Resolve-GerberPluginApproval -Times 0
    }

    It 'preserves <Label> through defensive normalization and approval identity' -Tag 'PluginCreateRepository' -ForEach @(
        @{ Label = 'known URI'; Uri = 'https://packages.example.org/feed' }
        @{ Label = 'explicit placeholder'; Uri = 'REPLACE_WITH_REPOSITORY_URI' }
    ) {
        $request | Add-Member Repository (@{ Name = 'ExampleFeed'; Uri = $Uri })
        Mock Test-GerberPluginProject {
        }
        Mock Resolve-GerberPluginApproval {
            $true
        }
        $result = New-GerberPluginProject -Request $request
        $metadata = (Get-Content (Join-Path $result.Path 'project.json') -Raw | ConvertFrom-Json -AsHashtable).Manifest.PrivateData.Gerber
        $metadata.Repository.Name | Should -BeExactly 'ExampleFeed'
        $metadata.Repository.Uri | Should -BeExactly $Uri
        $result.Repository.Name | Should -BeExactly 'ExampleFeed'
        $result.Repository.Uri | Should -BeExactly $Uri
        Should -Invoke Resolve-GerberPluginApproval -Times 1 -ParameterFilter {
            $ExplicitApproval -and $PluginModule.Guid -eq $result.Guid
        }
    }

    It 'rejects an explicit unsafe creation override before staging or approval' -Tag 'PluginCreateRepository' {
        $request | Add-Member RepositoryUri 'https://example.org/feed?token=secret'
        Mock Resolve-GerberPluginApproval {
        }
        {
            New-GerberPluginProject -Request $request
        } | Should -Throw '*absolute repository URI*'
        @(Get-ChildItem $request.ParentPath -Force).Count | Should -Be 0
        Should -Invoke Resolve-GerberPluginApproval -Times 0
    }
}
