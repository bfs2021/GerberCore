BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Resolve-GerberCommand' {
    It 'returns a prompt message for empty input' {
        $result = Resolve-GerberCommand -InputText ''

        $result.IsValid | Should -BeFalse
        $result.ErrorMessage | Should -Be 'Enter a command like /tools or choose a numbered menu option.'
    }

    It 'parses slash action commands and arguments' {
        $result = Resolve-GerberCommand -InputText '/tools base-64 decode'

        $result.IsValid | Should -BeTrue
        $result.Name | Should -Be 'tools'
        $result.Arguments | Should -Be @('base-64', 'decode')
    }

    It 'suggests matching commands for partial slash input' {
        $result = Resolve-GerberCommand -InputText '/to'

        $result.IsValid | Should -BeFalse
        $result.Suggestions.DisplayText | Should -Contain '/tools'
        $result.Suggestions.DisplayText | Should -Contain '/repository'
        $result.ErrorMessage | Should -Match '/repository|/tools'
    }

    It 'shows root suggestions for a lone slash' {
        $result = Resolve-GerberCommand -InputText '/'

        $result.IsValid | Should -BeFalse
        $result.Suggestions.DisplayText | Should -Be @(
            '/exit',
            '/help',
            '/plugins',
            '/update',
            '/branch',
            '/list',
            '/pipelines',
            '/repository',
            '/secrets',
            '/tools'
        )
        $result.Suggestions.DisplayText | Should -Not -Contain '/status'
        $result.Suggestions.DisplayText | Should -Not -Contain '/git'
        $result.Suggestions.DisplayText | Should -Not -Contain '/test'
        $result.Suggestions.DisplayText | Should -Not -Contain '/http'
        $result.Suggestions.DisplayText | Should -Not -Contain '/config'
    }

    It 'keeps submenu prompt suggestions empty when the prompt disallows slash commands' {
        $result = Resolve-GerberPromptInput -InputText '/' -SuggestionMode 'None'

        $result.IsValid | Should -BeTrue
        $result.Suggestions | Should -BeNullOrEmpty
    }

    It 'accepts exact root search input for leaf commands without a slash' {
        $result = Resolve-GerberCommand -InputText 'help'

        $result.IsValid | Should -BeTrue
        $result.Name | Should -Be 'help'
        $result.Arguments | Should -Be @()
        $result.Suggestions.DisplayText | Should -Be @('/help')
    }

    It 'supports root search when a nested plugin command exposes leaf subcommands as descriptions' {
        Mock Get-GerberRegisteredCommand {
            param($Name)

            switch ($Name) {
                'tools' {
                    return [pscustomobject]@{
                        Name = 'tools'
                        Description = 'Open the interactive tools menu'
                        Subcommands = [ordered]@{
                            'bearer-token' = ConvertTo-GerberCommandCatalogEntry `
                                -Description 'Retrieve an OAuth bearer token for U, T, or PP' `
                                -Subcommands ([ordered]@{
                                        U = 'Get a bearer token for environment U (registerzone-client-test)'
                                        T = 'Get a bearer token for environment T (registerzone-client-test)'
                                        PP = 'Get a bearer token for environment PP (F2-client-preprod)'
                                    })
                        }
                    }
                }
                'exit' {
                    return [pscustomobject]@{
                        Name = 'exit'
                        Description = 'Exit Gerber'
                        Subcommands = [ordered]@{}
                    }
                }
                default {
                    return $null
                }
            }
        }

        $result = Resolve-GerberCommand -InputText 'exit' -ActionList @('tools', 'exit')

        $result.IsValid | Should -BeTrue
        $result.Name | Should -Be 'exit'
    }

    It 'builds leaf action search entries for nested plugin leaf commands whose terminal subcommands are descriptions' {
        $catalog = [ordered]@{
            tools = ConvertTo-GerberCommandCatalogEntry `
                -Description 'Open the interactive tools menu' `
                -Subcommands ([ordered]@{
                        'bearer-token' = ConvertTo-GerberCommandCatalogEntry `
                            -Description 'Retrieve an OAuth bearer token for U, T, or PP' `
                            -Subcommands ([ordered]@{
                                    U = 'Get a bearer token for environment U (registerzone-client-test)'
                                    T = 'Get a bearer token for environment T (registerzone-client-test)'
                                    PP = 'Get a bearer token for environment PP (F2-client-preprod)'
                                })
                    })
        }

        $result = @(Get-GerberLeafActionCommandList -Catalog $catalog)

        $result.DisplayText | Should -Contain '/tools bearer-token PP'
    }

    It 'treats removed plain-text commands as unknown commands' -ForEach @('config', 'git', 'http', 'status') {
        $result = Resolve-GerberCommand -InputText $_

        $result.IsValid | Should -BeFalse
        $result.Suggestions | Should -BeNullOrEmpty
        $result.ErrorMessage | Should -Match "Unknown command '$_'"
    }

    It 'treats removed slash commands as unknown commands' -ForEach @('/config', '/git', '/http', '/status', '/test') {
        $result = Resolve-GerberCommand -InputText $_

        $result.IsValid | Should -BeFalse
        $result.Suggestions | Should -BeNullOrEmpty
        $result.ErrorMessage | Should -Match "Unknown command '$_'"
    }

    It 'searches nested action commands and shows full command paths' {
        $result = Resolve-GerberCommand -InputText 'base'

        $result.IsValid | Should -BeFalse
        $result.Suggestions.DisplayText | Should -Be @('/tools base-64 decode', '/tools base-64 encode')
    }

    It 'matches only command path tokens during root action search' {
        $result = Resolve-GerberCommand -InputText 'azure'

        $result.IsValid | Should -BeFalse
        $result.Suggestions | Should -BeNullOrEmpty
    }

    It 'accepts exact nested action input without a slash' {
        $result = Resolve-GerberCommand -InputText 'tools base 64 encode'

        $result.IsValid | Should -BeTrue
        $result.Name | Should -Be 'tools'
        $result.Arguments | Should -Be @('base-64', 'encode')
        $result.Suggestions.DisplayText | Should -Be @('/tools base-64 encode')
    }

    It 'previews tools subcommands for /tools' {
        $result = Resolve-GerberCommand -InputText '/tools'

        $result.IsValid | Should -BeTrue
        $result.Suggestions.DisplayText | Should -Be @('/tools base-64', '/tools create-uuid')
    }

    It 'previews nested action commands for /tools base-64' {
        $result = Resolve-GerberCommand -InputText '/tools base-64'

        $result.IsValid | Should -BeTrue
        $result.Suggestions.DisplayText | Should -Be @('/tools base-64 decode', '/tools base-64 encode')
    }

    It 'previews list subcommands for /list' {
        $result = Resolve-GerberCommand -InputText '/list'

        $result.IsValid | Should -BeTrue
        $result.Suggestions | Should -BeNullOrEmpty
    }

    It 'previews repository subcommands for /repository' {
        $result = Resolve-GerberCommand -InputText '/repository'

        $result.IsValid | Should -BeTrue
        $result.Suggestions | Should -BeNullOrEmpty
    }

    It 'previews plugin subcommands for /plugins' {
        $result = Resolve-GerberCommand -InputText '/plugins'

        $result.IsValid | Should -BeTrue
        $result.Suggestions.DisplayText | Should -Be @('/plugins create', '/plugins disable', '/plugins enable', '/plugins info', '/plugins list')
    }

    It 'previews pipelines subcommands for /pipelines' {
        $result = Resolve-GerberCommand -InputText '/pipelines'

        $result.IsValid | Should -BeTrue
        $result.Suggestions | Should -BeNullOrEmpty
    }

    It 'treats /pipelines release as unknown when the example organization plugin is not installed' {
        $result = Resolve-GerberCommand -InputText '/pipelines release'

        $result.IsValid | Should -BeFalse
        $result.Suggestions | Should -BeNullOrEmpty
        $result.ErrorMessage | Should -Match "Unknown command '/pipelines release'"
    }

    It 'previews secrets subcommands for /secrets' {
        $result = Resolve-GerberCommand -InputText '/secrets'

        $result.IsValid | Should -BeTrue
        $result.Suggestions.DisplayText |
            Should -Be @('/secrets get', '/secrets list', '/secrets remove', '/secrets set', '/secrets test')
    }

    It 'shows nested submenu suggestions for /tools base-64 prompts' {
        $result = Resolve-GerberPromptInput `
            -InputText '/dec' `
            -SuggestionMode 'Subcommand' `
            -SuggestionCommandName 'tools base-64' `
            -SuggestionSubcommandTable ([ordered]@{
                encode = 'Encode UTF-8 text as Base64'
                decode = 'Decode Base64 text into UTF-8 text'
            })

        $result.IsValid | Should -BeFalse
        $result.Suggestions.DisplayText | Should -Be @('/tools base-64 decode')
    }

    It 'prefers prefix matches over contains matches for nested submenu prompts' {
        $result = Resolve-GerberPromptInput `
            -InputText '/tools base-64 de' `
            -SuggestionMode 'Subcommand' `
            -SuggestionCommandName 'tools base-64' `
            -SuggestionSubcommandTable ([ordered]@{
                encode = 'Encode UTF-8 text as Base64'
                decode = 'Decode Base64 text into UTF-8 text'
            })

        $result.IsValid | Should -BeFalse
        $result.Suggestions.DisplayText | Should -Be @('/tools base-64 decode')
    }

    It 'prefers prefix matches before contains matches in the shared token matcher' {
        $result = Get-GerberMatchingTokenList -CandidateList @('encode', 'decode') -InputToken 'de'

        $result | Should -Be @('decode')
    }

    It 'falls back to contains matches when no prefix match exists in the shared token matcher' {
        $result = Get-GerberMatchingTokenList -CandidateList @('create-uuid', 'base-64', 'ado-agents') -InputToken 'uuid'

        $result | Should -Be @('create-uuid')
    }

    It 'keeps unknown slash commands as normal parser errors when there are no suggestions' {
        $result = Resolve-GerberCommand -InputText '/zzz'

        $result.IsValid | Should -BeFalse
        $result.Suggestions | Should -BeNullOrEmpty
        $result.ErrorMessage | Should -Match "Unknown command '/zzz'"
    }

    It 'maps numeric menu selections to commands' {
        $result = Resolve-GerberCommand -InputText '1'

        $result.Name | Should -Be 'exit'
    }

    It 'rejects numeric menu selections outside the available range' {
        $result = Resolve-GerberCommand -InputText '99'

        $result.IsValid | Should -BeFalse
        $result.ErrorMessage | Should -Be "Menu option '99' is not available."
    }

    It 'treats plain text as neutral inside subcommand prompts' {
        $result = Resolve-GerberSubcommandPromptInput `
            -CommandName 'tools' `
            -InputText 'create-uuid' `
            -SubcommandTable ([ordered]@{
                'create-uuid' = 'Generate a UUID and copy it to the clipboard when possible'
                'base-64' = 'Open the Base64 text utility'
            })

        $result.IsValid | Should -BeTrue
        $result.Name | Should -BeNullOrEmpty
        $result.Suggestions | Should -BeNullOrEmpty
    }

    It 'normalizes empty subcommand prompt input to the command prefix' {
        $normalizedInput = ConvertTo-GerberSubcommandPromptCommandInput -CommandName 'tools' -InputText '/'
        $subcommandInput = Get-GerberPromptSubcommandInput -CommandName 'tools' -InputText $normalizedInput

        $normalizedInput | Should -Be '/tools '
        $subcommandInput | Should -Be ''
    }

    It 'keeps trailing-space submenu input valid while showing subcommand suggestions' {
        $result = Resolve-GerberCommand -InputText '/tools '

        $result.IsValid | Should -BeTrue
        $result.Suggestions.DisplayText | Should -Be @('/tools base-64', '/tools create-uuid')
    }

    It 'builds leaf action search results recursively from nested command entries' {
        $leafActionList = Get-GerberLeafActionCommandList -Catalog ([ordered]@{
                tools = ConvertTo-GerberCommandCatalogEntry -Description 'Tools' -Subcommands ([ordered]@{
                        alpha = ConvertTo-GerberCommandCatalogEntry -Description 'Alpha tool' -Subcommands ([ordered]@{
                                beta = ConvertTo-GerberCommandCatalogEntry -Description 'Beta action'
                            })
                    })
            })

        $leafActionList.DisplayText | Should -Be @('/tools alpha beta')
    }

    It 'returns an empty subcommand token when the normalized input only adds whitespace' {
        $result = Get-GerberPromptSubcommandInput -CommandName 'tools' -InputText '/tools   '

        $result | Should -Be ''
    }

    It 'rejects invalid commands' {
        (Resolve-GerberCommand -InputText 'oops').IsValid | Should -BeFalse
    }

    It 'accepts exact subcommand input for known subcommands' {
        $result = Resolve-GerberSubcommandPromptInput `
            -CommandName 'tools' `
            -InputText '/tools create-uuid' `
            -SubcommandTable ([ordered]@{
                'create-uuid' = 'Generate a UUID and copy it to the clipboard when possible'
                'base-64' = 'Open the Base64 text utility'
            })

        $result.IsValid | Should -BeTrue
        $result.Name | Should -BeNullOrEmpty
    }

    It 'returns an empty subcommand table when the entry has no subcommands' {
        $result = Get-GerberCatalogEntrySubcommandTable -Entry @{ Description = 'Leaf action' }

        $result | Should -Not -BeNull
        $result.Count | Should -Be 0
    }

    It 'resolves an unknown subcommand as an invalid command with suggestions' {
        $result = Resolve-GerberCommand -InputText '/tools zzz-unknown'

        $result.IsValid | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Unknown command'
    }

    It 'sorts string candidates case-insensitively with a deterministic secondary comparison' {
        $result = Get-GerberAlphabeticallySortedStringList -ValueList @('tools', 'Branch', 'branch', 'alpha')

        $result | Should -Be @('alpha', 'Branch', 'branch', 'tools')
    }

    It 'sorts submenu suggestions alphabetically across mixed core and plugin names' {
        $result = Get-GerberNamedSubcommandSuggestionList `
            -CommandName 'tools' `
            -SubcommandTable ([ordered]@{
                'create-uuid' = ConvertTo-GerberCommandCatalogEntry -Description 'Core UUID tool'
                'bearer-token' = ConvertTo-GerberCommandCatalogEntry -Description 'Plugin bearer token tool'
                'base-64' = ConvertTo-GerberCommandCatalogEntry -Description 'Core Base64 tool'
            })

        $result.DisplayText | Should -Be @('/tools base-64', '/tools bearer-token', '/tools create-uuid')
        $result.PreviewText | Should -Be @('Core Base64 tool', 'Plugin bearer token tool', 'Core UUID tool')
    }

    It 'keeps filtered token matches alphabetically sorted' {
        $result = Get-GerberMatchingTokenList -CandidateList @('create-uuid', 'bearer-token', 'base-64') -InputToken 'b'

        $result | Should -Be @('base-64', 'bearer-token')
    }

    It 'returns null from exact leaf action match when input has no search tokens' {
        $leafActionList = @(Get-GerberLeafActionCommandList -Catalog (Get-GerberCommandCatalog -ActionList @('tools', 'list', 'secrets', 'help', 'exit')))

        $result = Get-GerberExactLeafActionMatch -LeafActionList $leafActionList -InputText ''

        $result | Should -BeNull
    }

    It 'returns an empty list from matching leaf actions when input has no search tokens' {
        $leafActionList = @(Get-GerberLeafActionCommandList -Catalog (Get-GerberCommandCatalog -ActionList @('tools', 'list', 'secrets', 'help', 'exit')))

        $result = @(Get-GerberMatchingLeafActionList -LeafActionList $leafActionList -InputText '')

        $result.Count | Should -Be 0
    }

    It 'keeps the built-in list command catalog empty because list actions come from registered command definitions' {
        $catalog = Get-GerberListCommandCatalog

        $catalog.Count | Should -Be 0
    }

    It 'includes branch in the root command catalog' {
        $catalog = Get-GerberCommandCatalog -ActionList @('tools', 'list', 'branch', 'repository', 'secrets', 'help', 'exit')

        $catalog.Keys | Should -Contain 'branch'
        $catalog['branch'].Description | Should -Be 'Search repositories by branch'
    }

    It 'projects the root command catalog from the registered command definitions' {
        Mock Get-GerberCommandRegistry {
            @(
                [pscustomobject]@{
                    Name = 'alpha'
                    Description = 'Alpha command'
                    Handler = { param() $false }
                    Subcommands = [ordered]@{
                        beta = ConvertTo-GerberCommandCatalogEntry -Description 'Beta action'
                    }
                }
            )
        }

        $catalog = Get-GerberCommandCatalog -ActionList @('alpha')

        $catalog.Keys | Should -Be @('alpha')
        $catalog['alpha'].Description | Should -Be 'Alpha command'
        $catalog['alpha'].Subcommands.Keys | Should -Be @('beta')
    }

    It 'keeps the generic branch root empty without registered plugin leaves' {
        $result = Resolve-GerberCommand -InputText '/branch' -ActionList @('tools', 'list', 'branch', 'repository', 'secrets', 'help', 'exit')

        $result.IsValid | Should -BeTrue
        $result.Suggestions | Should -BeNullOrEmpty
    }

    It 'keeps the generic repository catalog empty without registered plugin leaves' {
        $catalog = (Get-GerberRegisteredCommand -Name repository).Subcommands

        $catalog.Count | Should -Be 0
    }
}
