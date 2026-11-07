BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-GerberPluginsCreateCommand' -Tag 'PluginCreate' {
    BeforeEach {
        Mock Read-GerberNumberedMenuPrompt {
            'PSGallery'
        }
        Mock Confirm-GerberPluginDevelopmentTool { $true }
        Mock Start-GerberScreen {}
        Mock Write-GerberScreenLine {}
        $script:blocks = [System.Collections.Generic.List[object]]::new()
        Mock Show-GerberTextBlock { $script:blocks.Add([pscustomobject]@{ Title = $Title; Text = $Text }) }
        Mock Wait-GerberContinue {}
        Mock Write-GerberPromptTrace {}
        Mock New-GerberPluginProject {
            [pscustomobject]@{
                Name = 'Gerber.MyCompany'; Version = '0.1.0'
                Path = (Join-Path $TestDrive "parent's projects/Gerber.MyCompany")
                Guid = 'fixture-guid'; Namespace = 'mycompany'
                Repository = @{ Name = 'PSGallery'; Uri = 'https://www.powershellgallery.com/api/v2' }
            }
        }
    }

    It 'uses shared input with an immutable prefix and the default cwd parent' {
        $script:answers = [System.Collections.Generic.Queue[string]]::new([string[]]@('MyCompany', 'Tools', 'mycompany', ''))
        Mock Read-GerberCommand { $script:answers.Dequeue() }
        Invoke-GerberPluginsCreateCommand -Command ([pscustomobject]@{ Arguments = @() })
        Should -Invoke New-GerberPluginProject -Times 1 -ParameterFilter {
            $Request.Name -eq 'Gerber.MyCompany' -and $Request.ParentPath -eq (Get-Location).ProviderPath
        }
        Should -Invoke Read-GerberCommand -ParameterFilter { $Prompt -like '*suffix*Gerber.*' }
    }

    It 'renders field guidance, separated sections and the actual cwd and child defaults' {
        $script:answers = [System.Collections.Generic.Queue[string]]::new([string[]]@('MyCompany', 'Tools', 'mycompany', ''))
        Mock Read-GerberCommand { $script:answers.Dequeue() }
        Invoke-GerberPluginsCreateCommand
        Should -Invoke Show-GerberTextBlock -ParameterFilter {
            $Title -eq 'Create Gerber Plugin' -and $Text -match 'working example'
        }
        foreach ($text in @(
            'Enter the name', 'Briefly describe', 'Commands provided',
            'Select the parent directory', "Default: $((Get-Location).ProviderPath)",
            (Join-Path (Get-Location).ProviderPath 'Gerber.MyCompany')
        )) {
            Should -Invoke Write-GerberScreenLine -ParameterFilter { $Text -like "*$text*" }
        }
        Should -Invoke Write-GerberScreenLine -Times 10 -Exactly -ParameterFilter { $Text -eq '' }
    }

    It 'summarizes actual creation metadata and quotes a usable PowerShell location' {
        $script:answers = [System.Collections.Generic.Queue[string]]::new([string[]]@('MyCompany', 'Tools', 'mycompany', ''))
        Mock Read-GerberCommand { $script:answers.Dequeue() }
        Invoke-GerberPluginsCreateCommand
        $summary = $script:blocks | Where-Object Title -EQ 'Gerber Plugin Created'
        $summary | Should -Not -BeNullOrEmpty
        foreach ($pattern in @(
            'Name:\s+Gerber.MyCompany', 'Version:\s+0.1.0', 'Namespace:\s+/mycompany',
            'Approval:\s+Approved', 'Associated:\s+Yes', 'Enabled:\s+Yes', 'Installed:\s+No',
            "cd '.*parent''s projects/Gerber.MyCompany'", 'Publish-NovaModule -Local',
            'Restart Gerber', '/mycompany hello'
        )) {
            $summary.Text | Should -Match $pattern
        }
    }

    It 'recovers from invalid input and permits a different name and destination' {
        $script:answers = [System.Collections.Generic.Queue[string]]::new(
            [string[]]@('../bad', 'MyCompany', 'Tools', 'tools', 'mycompany', 'missing-parent', $TestDrive)
        )
        Mock Read-GerberCommand { $script:answers.Dequeue() }
        Invoke-GerberPluginsCreateCommand -Command ([pscustomobject]@{ Arguments = @() })
        Should -Invoke New-GerberPluginProject -Times 1 -ParameterFilter { $Request.ParentPath -eq $TestDrive }
        Should -Invoke Write-GerberPromptTrace -Times 3 -ParameterFilter { $EventName -eq 'plugin-create-input-rejected' }
    }

    It 'does no generation when Nova installation is declined' {
        Mock Confirm-GerberPluginDevelopmentTool { $false }
        Invoke-GerberPluginsCreateCommand -Command ([pscustomobject]@{ Arguments = @() })
        Should -Invoke New-GerberPluginProject -Times 0
    }

    It 'dispatches through the Core registry and returns control to Gerber' {
        Mock Confirm-GerberPluginDevelopmentTool { $false }
        $entry = Get-GerberRegisteredCommand -Name 'plugins create'
        (& $entry.Handler ([pscustomobject]@{ Arguments = @() })) | Should -BeFalse
        Should -Invoke Confirm-GerberPluginDevelopmentTool -Times 1
    }

    It 'propagates shared Esc navigation without generating or approving' {
        Mock Read-GerberCommand { throw [System.OperationCanceledException]::new('cancel') }
        { Invoke-GerberPluginsCreateCommand -Command ([pscustomobject]@{ Arguments = @() }) } | Should -Throw '*cancel*'
        Should -Invoke New-GerberPluginProject -Times 0
    }

    It 'recovers from a destination collision by accepting another module suffix' {
        $null = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'Gerber.Existing')
        $script:answers = [System.Collections.Generic.Queue[string]]::new(
            [string[]]@('Existing', 'Tools', 'existing', $TestDrive, 'Another', 'Tools', 'another', $TestDrive)
        )
        Mock Read-GerberCommand { $script:answers.Dequeue() }
        Invoke-GerberPluginsCreateCommand -Command ([pscustomobject]@{ Arguments = @() })
        Should -Invoke New-GerberPluginProject -Times 1 -ParameterFilter { $Request.Name -eq 'Gerber.Another' }
        Test-Path (Join-Path $TestDrive 'Gerber.Existing') | Should -BeTrue
    }

    It 'summarizes <Label> and its metadata action honestly' -Tag 'PluginCreateRepository' -ForEach @(
        @{ Label = 'PSGallery'; Name = 'PSGallery'; Uri = 'https://www.powershellgallery.com/api/v2'; Guidance = 'https://www.powershellgallery.com/api/v2' }
        @{ Label = 'known custom repository'; Name = 'ExampleFeed'; Uri = 'https://packages.example.org/feed'; Guidance = 'https://packages.example.org/feed' }
        @{ Label = 'unknown custom repository'; Name = 'ExampleFeed'; Uri = 'REPLACE_WITH_REPOSITORY_URI'; Guidance = 'Replace.*Repository.Uri.*before.*publish.*update' }
    ) {
        $result = [pscustomobject]@{
            Name = 'Gerber.MyCompany'; Version = '0.1.0'; Path = $TestDrive
            Guid = 'fixture-guid'; Namespace = 'mycompany'
            Repository = @{ Name = $Name; Uri = $Uri }
        }
        Show-GerberPluginProjectCreationSummary -Result $result
        $summary = $script:blocks | Where-Object Title -EQ 'Gerber Plugin Created'
        $summary.Text | Should -Match "Repository:\s+$Name"
        $summary.Text | Should -Match ([regex]::Escape($Uri))
        $summary.Text | Should -Match $Guidance
    }
}
