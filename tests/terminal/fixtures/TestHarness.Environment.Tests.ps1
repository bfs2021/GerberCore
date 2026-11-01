BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHarness.State.ps1')
    . (Join-Path $PSScriptRoot 'TestHarness.Environment.ps1')
}

Describe 'ConvertTo-GerberTerminalHttpBodyMap' {
    It 'normalizes JSON request bodies for strict matching' {
        $result = ConvertTo-GerberTerminalHttpBodyMap -Body '{"project":{"id":"project-terminal"},"enabled":true}'

        $result.project.id | Should -Be 'project-terminal'
        $result.enabled | Should -BeTrue
    }
}

Describe 'Find-GerberTerminalHttpFixtureMatch' {
    It 'matches equivalent query parameters regardless of ordering' {
        $fixture = @{
            requests = @(
                @{
                    method = 'Get'
                    uri = 'https://example.test/items?api-version=7.1&tagFilters=old'
                }
            )
        }

        $result = Find-GerberTerminalHttpFixtureMatch `
            -Fixture $fixture `
            -Method 'Get' `
            -Uri 'https://example.test/items?tagFilters=old&api-version=7.1'

        $result | Should -Not -BeNullOrEmpty
    }

    It 'matches only the configured exact body' {
        $fixture = @{
            requests = @(
                @{
                    method = 'Patch'
                    uri = 'https://example.test/repositories/1'
                    expectedBody = @{ defaultBranch = 'refs/heads/main' }
                }
            )
        }

        foreach ($case in @(
                @{ Branch = 'main'; ShouldMatch = $true },
                @{ Branch = 'develop'; ShouldMatch = $false }
            )) {
            $result = Find-GerberTerminalHttpFixtureMatch `
                -Fixture $fixture `
                -Method 'Patch' `
                -Uri 'https://example.test/repositories/1' `
                -Body @{ defaultBranch = "refs/heads/$($case.Branch)" }

            ($null -ne $result) | Should -Be $case.ShouldMatch
        }
    }
}

Describe 'Initialize-GerberTerminalHttpShim' {
    It 'returns configured response headers and records exact sanitized request data' {
        $fixturePath = Join-Path $TestDrive 'http-fixture.json'
        $statePath = Join-Path $TestDrive 'http-state.json'
        Write-GerberTerminalJsonFile -Path $fixturePath -Value @{
            defaultResult = @{ type = 'error'; message = 'Unexpected request.' }
            requests = @(
                @{
                    method = 'Post'
                    uri = 'https://example.test/items'
                    expectedBody = @{
                        name = 'demo'
                        project = @{ id = 'project-terminal' }
                    }
                    response = @{ id = 'created' }
                    responseHeaders = @{ 'x-ms-continuationtoken' = 'next-page' }
                }
            )
        }
        Initialize-GerberTerminalHttpShim -FixturePath $fixturePath -StatePath $statePath

        $responseHeaders = $null
        $result = Invoke-RestMethod `
            -Method Post `
            -Uri 'https://example.test/items' `
            -Headers @{ Authorization = 'Basic secret-value'; Accept = 'application/json' } `
            -Body '{"name":"demo","project":{"id":"project-terminal"}}' `
            -ResponseHeadersVariable responseHeaders

        $result.id | Should -Be 'created'
        $responseHeaders.'x-ms-continuationtoken' | Should -Be 'next-page'
        $state = Read-GerberTerminalJsonFile -Path $statePath -DefaultValue @{ requests = @() }
        $state.requests[0].body.name | Should -Be 'demo'
        $state.requests[0].body.project.id | Should -Be 'project-terminal'
        $state.requests[0].headers.Authorization | Should -Be '<redacted>'
        $state.requests[0].headers.Accept | Should -Be 'application/json'
        ($state | ConvertTo-Json -Depth 10) | Should -Not -Match 'secret-value'
    }

    It 'returns raw template content through Invoke-WebRequest and records the transport' {
        $fixturePath = Join-Path $TestDrive 'http-fixture.json'
        $statePath = Join-Path $TestDrive 'http-state.json'
        Write-GerberTerminalJsonFile -Path $fixturePath -Value @{
            defaultResult = @{ type = 'error'; message = 'Unexpected request.' }
            requests = @(
                @{
                    method = 'Get'
                    uri = 'https://example.test/items?path=%2FREADME.md&includeContent=true'
                    rawContent = '# PackageName'
                }
            )
        }
        Initialize-GerberTerminalHttpShim -FixturePath $fixturePath -StatePath $statePath

        $result = Invoke-WebRequest `
            -Uri 'https://example.test/items?includeContent=true&path=%2FREADME.md' `
            -Headers @{ Authorization = 'Basic secret-value' } `
            -UseBasicParsing

        $result.Content | Should -Be '# PackageName'
        $state = Read-GerberTerminalJsonFile -Path $statePath -DefaultValue @{ requests = @() }
        $state.requests[0].transport | Should -Be 'Invoke-WebRequest'
        $state.requests[0].headers.Authorization | Should -Be '<redacted>'
    }

    It 'fails closed when no template content fixture matches' {
        $fixturePath = Join-Path $TestDrive 'http-fixture.json'
        $statePath = Join-Path $TestDrive 'http-state.json'
        Write-GerberTerminalJsonFile -Path $fixturePath -Value @{
            defaultResult = @{ type = 'error'; message = 'Unexpected template request.' }
            requests = @()
        }
        Initialize-GerberTerminalHttpShim -FixturePath $fixturePath -StatePath $statePath

        {
            Invoke-WebRequest -Uri 'https://example.test/unexpected' -UseBasicParsing
        } | Should -Throw 'Unexpected template request.'
    }
}

Describe 'Initialize-GerberPromptTracePath' -Tag 'TerminalFixtureExtraction' {
    It 'keeps the isolated configuration path available after initialization returns' {
        $tracePath = Join-Path $TestDrive 'runtime/prompt-debug.log'

        Initialize-GerberPromptTracePath -Path $tracePath

        $configPath = Join-Path $TestDrive 'runtime/GerberCore.json'
        Resolve-GerberConfigPath | Should -Be $configPath
        ((Get-Content -LiteralPath $configPath -Raw) | ConvertFrom-Json).schemaVersion | Should -Be 1
        Test-Path -LiteralPath (Join-Path $TestDrive 'runtime/config.json') | Should -BeFalse
    }
}
