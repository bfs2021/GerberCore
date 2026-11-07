BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Write-GerberPluginProject' -Tag 'PluginCreate' {
    BeforeEach {
        Mock Get-GerberModuleSemanticVersion { '1.2.3-preview04' }
    }

    Context 'repository metadata' -Tag 'PluginCreateRepository' {
        It 'writes canonical <Label> directly under Gerber without an Update intermediary' -ForEach @(
            @{ Label = 'known custom source'; Uri = 'https://packages.example.org/feed' }
            @{ Label = 'unknown custom source'; Uri = 'REPLACE_WITH_REPOSITORY_URI' }
        ) {
            $request = [pscustomobject]@{
                Name = 'Gerber.Example'; Namespace = 'example'; Suffix = 'Example'
                Description = 'Local tools'; Repository = @{ Name = 'ExampleFeed'; Uri = $Uri }
            }
            Write-GerberPluginProject -Request $request -Path $TestDrive -Guid '5ff12592-8333-40d1-b167-9f5902149843'
            $metadata = (Get-Content (Join-Path $TestDrive 'project.json') -Raw | ConvertFrom-Json -AsHashtable).Manifest.PrivateData.Gerber
            $metadata.Repository.Name | Should -BeExactly 'ExampleFeed'
            $metadata.Repository.Uri | Should -BeExactly $Uri
            $metadata.Keys | Should -Not -Contain 'RepositoryUri'
            $metadata.Keys | Should -Not -Contain 'Update'
        }

        It 'writes an explicit canonical default Gallery source without legacy metadata' {
            $request = [pscustomobject]@{
                Name = 'Gerber.Example'; Namespace = 'example'; Suffix = 'Example'; Description = 'Local tools'
            }
            Write-GerberPluginProject -Request $request -Path $TestDrive -Guid '5ff12592-8333-40d1-b167-9f5902149843'
            $metadata = (Get-Content (Join-Path $TestDrive 'project.json') -Raw | ConvertFrom-Json -AsHashtable).Manifest.PrivateData.Gerber
            $metadata.Keys | Should -Not -Contain 'RepositoryUri'
            $metadata.Repository.Name | Should -BeExactly 'PSGallery'
            $metadata.Repository.Uri | Should -BeExactly 'https://www.powershellgallery.com/api/v2'
        }
    }

    It 'writes complete sources without source manifests and safely serializes descriptions' {
        $request = [pscustomobject]@{
            Name = 'Gerber.Example'; Namespace = 'example'; Suffix = 'Example'
            Description = 'Quotes " and {{Name}} stay literal'
        }
        $guid = '5ff12592-8333-40d1-b167-9f5902149843'
        Write-GerberPluginProject -Request $request -Path $TestDrive -Guid $guid
        $project = Get-Content (Join-Path $TestDrive 'project.json') -Raw | ConvertFrom-Json
        $project.Description | Should -Be $request.Description
        $project.Manifest.GUID | Should -Be $guid
        $project.Manifest.PrivateData.Gerber.PSObject.Properties.Name | Should -Not -Contain 'Guid'
        $project.Manifest.PrivateData.Gerber.Plugin | Should -BeTrue
        $project.Manifest.PrivateData.Gerber.MinimumGerberVersion | Should -Be '1.2.3-preview04'
        (Get-Content (Join-Path $TestDrive 'AGENTS.md') -Raw) | Should -Match ([regex]::Escape('MinimumGerberVersion: "1.2.3-preview04"'))
        Test-Path (Join-Path $TestDrive '.gitignore') | Should -BeTrue
        @(Get-ChildItem $TestDrive -Recurse -Include '*.psd1', '*.psm1').Count | Should -Be 0
    }

    Context 'agent-first scaffold' {
        BeforeEach {
            $request = [pscustomobject]@{
                Name = 'Gerber.Example'; Namespace = 'example'; Suffix = 'Example'; Description = 'Local tools'
            }
            Write-GerberPluginProject -Request $request -Path $TestDrive -Guid '5ff12592-8333-40d1-b167-9f5902149843'
        }

        It 'initializes the exact unreleased changelog without a fictional release' {
            $text = Get-Content (Join-Path $TestDrive 'CHANGELOG.md') -Raw
            $text | Should -Match ([regex]::Escape('All notable changes to this project will be documented in this file and **UNRELEASED** changes will be included in the next **stable** release!'))
            $text | Should -Match 'https://keepachangelog.com/en/1.1.0/'
            $text | Should -Match 'https://semver.org/spec/v2.0.0.html'
            @([regex]::Matches($text, '(?m)^### (.+)$').Groups | Where-Object Name -EQ 1 | ForEach-Object Value) |
                Should -Be @('Added', 'Changed', 'Deprecated', 'Removed', 'Fixed', 'Security')
            $text | Should -Match 'Working `/example hello` Plugin API v1 example.'
            @([regex]::Matches($text, '(?m)^## ')).Count | Should -Be 1
            $text.EndsWith("`n") | Should -BeTrue
            $text.EndsWith("`n`n") | Should -BeFalse
        }

        It 'provides canonical self-contained Gerber guidance and thin tool bridges' {
            $guide = Get-Content (Join-Path $TestDrive 'AGENTS.md') -Raw
            foreach ($contract in @('Plugin API v1', 'Manifest.GUID', 'PrivateData.Gerber', 'src/public', 'src/private', 'dist/', 'docs/schema', 'Get-GerberPlugin', 'Get-PluginCommandDefinitionList', 'Get-PluginHelloHandler', '/example hello', 'UI.ReadSubcommand', 'Configuration.Read', 'Configuration.Save', 'Secrets.GetText', 'Clipboard.CopyText', 'Invoke-NovaBuild', 'Invoke-NovaTest', 'Test-NovaBuild', 'Publish-NovaModule -Local', 'Update-NovaModuleVersion', 'PSScriptAnalyzer', 'CodeScene', '90%')) {
                $guide | Should -Match ([regex]::Escape($contract))
            }
            $guide | Should -Not -Match 'Ado\.OpenConnection'
            foreach ($bridge in @('CLAUDE.md', '.github/copilot-instructions.md')) {
                $text = Get-Content (Join-Path $TestDrive $bridge) -Raw
                $text | Should -Match 'AGENTS.md'
                $text.Length | Should -BeLessThan 1000
            }
        }

        It 'writes focused scoped instructions and actionable valid agent and skill resources' {
            $github = Join-Path $TestDrive '.github'
            $instructions = @(Get-ChildItem (Join-Path $github 'instructions') -Filter '*.instructions.md')
            $instructions.Count | Should -BeGreaterOrEqual 3
            foreach ($file in $instructions) {
                (Get-Content $file.FullName -Raw) | Should -Match '(?s)^---\napplyTo: ".+?"\n---\n'
            }
            $agent = Get-Content (Join-Path $github 'agents/plugin-developer.agent.md') -Raw
            $agent | Should -Match '(?s)^---\nname: plugin-developer\ndescription: .+?\n---'
            $agent | Should -Match 'Plugin API v1'
            foreach ($name in @('plugin-command-development', 'gerber-plugin-api', 'nova-development')) {
                $skill = Get-Content (Join-Path $github "skills/$name/SKILL.md") -Raw
                $skill | Should -Match "(?s)^---\nname: $name\ndescription: .+?\n---"
                $skill | Should -Match '(?m)^1\. '
                $skill | Should -Match 'AGENTS.md'
            }
        }

        It 'ships standalone boundary validation in the standard Nova and agent workflows' -Tag 'PluginBoundary' {
            $scriptText = Get-Content (Join-Path $TestDrive 'scripts/Test-PluginBoundary.ps1') -Raw
            $scriptText | Should -Match 'Import-Module Gerber'
            $scriptText | Should -Match 'Test-GerberPluginBoundary'
            $scriptText | Should -Match 'IsValid'
            foreach ($path in @('AGENTS.md', 'README.md', '.github/agents/plugin-developer.agent.md',
                '.github/instructions/powershell.instructions.md', '.github/skills/gerber-plugin-api/SKILL.md',
                '.github/skills/nova-development/SKILL.md')) {
                (Get-Content (Join-Path $TestDrive $path) -Raw) | Should -Match 'Test-PluginBoundary.ps1'
            }
        }

        It 'leaves no unresolved placeholders, private Core dependency or unrelated language instructions' {
            foreach ($file in (Get-ChildItem $TestDrive -Recurse -File -Force)) {
                $text = Get-Content $file.FullName -Raw
                $text | Should -Not -Match '\{\{[A-Za-z]+\}\}|Gerber\.ExampleOrg|\bJava\b'
                $text.EndsWith("`n`n") | Should -BeFalse
            }
        }

        It 'generates authored sources and tests with zero default analyzer findings' -Tag 'PluginCreateAnalyzer' {
            $findings = @(
                Invoke-ScriptAnalyzer -Path (Join-Path $TestDrive 'src') -Recurse
                Invoke-ScriptAnalyzer -Path (Join-Path $TestDrive 'tests') -Recurse
                Invoke-ScriptAnalyzer -Path (Join-Path $TestDrive 'scripts') -Recurse
            )
            $findings | Should -BeNullOrEmpty
        }
    }
}
