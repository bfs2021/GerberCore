function Get-GerberCoreCommandDefinitionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param()

    $definitionList = @(
        @(Get-GerberCoreRootCommandDefinitionList)
        @(Get-GerberCoreLeafCommandDefinitionList)
    )

    return @($definitionList)
}

function Get-GerberCoreRootCommandDefinitionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param()

    return @(
        [pscustomobject][ordered]@{
            Name        = 'tools'
            Description = 'Open the interactive tools menu'
            Handler     = { param([pscustomobject]$Command) Show-GerberToolsView -Command $Command; return $false }
            Subcommands = [ordered]@{}
        }
        [pscustomobject][ordered]@{
            Name        = 'plugins'
            Description = 'Show Gerber plugin status and manage plugin activation'
            Handler     = { param([pscustomobject]$Command) Show-GerberPluginsView -Command $Command; return $false }
            Subcommands = [ordered]@{}
        }
        [pscustomobject][ordered]@{
            Name        = 'secrets'
            Description = 'Open the interactive secrets menu'
            Handler     = { param([pscustomobject]$Command) Show-GerberSecretsView -Command $Command; return $false }
            Subcommands = Get-GerberSecretsCommandCatalog
        }
        Get-GerberCoreUpdateCommandDefinition
        [pscustomobject][ordered]@{
            Name        = 'help'
            Description = 'Show the built-in command help'
            Handler     = { param() Show-GerberHelpView; return $false }
            Subcommands = [ordered]@{}
        }
        [pscustomobject][ordered]@{
            Name        = 'exit'
            Description = 'Exit the interactive Gerber session'
            Handler     = { param() Write-GerberScreenLine -Text 'Exiting Gerber.'; return $true }
            Subcommands = [ordered]@{}
        }
    )
}

function Get-GerberCoreLeafCommandDefinitionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param()

    return @(
        [pscustomobject][ordered]@{
            Name        = 'tools create-uuid'
            Description = 'Generate a UUID and copy it to the clipboard when possible'
            Handler     = { Show-GerberCreateUuidTool; return $false }
            Subcommands = [ordered]@{}
        }
        [pscustomobject][ordered]@{
            Name        = 'tools base-64'
            Description = 'Open the Base64 text utility'
            Handler     = { param([pscustomobject]$Command) Show-GerberBase64Tool -Command $Command; return $false }
            Subcommands = Get-GerberBase64CommandCatalog
        }
        [pscustomobject][ordered]@{
            Name        = 'plugins list'
            Description = 'List discovered and persisted Gerber plugins'
            Handler     = { param([pscustomobject]$Command) Invoke-GerberPluginsListCommand -Command $Command; return $false }
            Subcommands = [ordered]@{}
        }
        [pscustomobject][ordered]@{
            Name        = 'plugins info'
            Description = 'Show detailed plugin information by GUID or unique module name'
            Handler     = { param([pscustomobject]$Command) Invoke-GerberPluginsInfoCommand -Command $Command; return $false }
            Subcommands = [ordered]@{}
        }
        [pscustomobject][ordered]@{
            Name        = 'plugins enable'
            Description = 'Enable and approve an installed Gerber plugin'
            Handler     = { param([pscustomobject]$Command) Invoke-GerberPluginsEnableCommand -Command $Command; return $false }
            Subcommands = [ordered]@{}
        }
        [pscustomobject][ordered]@{
            Name        = 'plugins disable'
            Description = 'Disable an active Gerber plugin and keep its approval'
            Handler     = { param([pscustomobject]$Command) Invoke-GerberPluginsDisableCommand -Command $Command; return $false }
            Subcommands = [ordered]@{}
        }
        Get-GerberCorePluginCreateCommandDefinition
        Get-GerberCoreUpdateLeafCommandDefinitionList
    )
}

function Get-GerberCorePluginCreateCommandDefinition {
    return [pscustomobject][ordered]@{
        Name        = 'plugins create'
        Description = 'Create and validate a working Gerber plugin project'
        Handler     = { param([pscustomobject]$Command) Invoke-GerberPluginsCreateCommand -Command $Command; return $false }
        Subcommands = [ordered]@{}
    }
}

function Get-GerberCoreUpdateCommandDefinition {
    [pscustomobject][ordered]@{
        Name = 'update'
        Description = 'Open the Core and plugin update menu'
        Handler = { param([pscustomobject]$Command) return [bool](Show-GerberUpdateMenu -Command $Command) }
        Subcommands = [ordered]@{}
    }
}

function Get-GerberCoreUpdateLeafCommandDefinitionList {
    Get-GerberCoreUpdateListCommandDefinition
    Get-GerberCoreUpdatePolicyCommandDefinition
}

function Get-GerberCoreUpdateListCommandDefinition {
    [pscustomobject][ordered]@{
        Name = 'update list'
        Description = 'Check and install Core and eligible plugin updates'
        Handler = { return [bool](Show-GerberUpdateView) }
        Subcommands = [ordered]@{}
    }
}

function Get-GerberCoreUpdatePolicyCommandDefinition {
    [pscustomobject][ordered]@{
        Name = 'update policy'
        Description = 'Choose the persistent shared update channel'
        Handler = { Show-GerberUpdatePolicyView; return $false }
        Subcommands = [ordered]@{}
    }
}
