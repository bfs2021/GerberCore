function Add-GerberPluginToRegistryBuilder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$RegistryBuilder,

        [Parameter(Mandatory)]
        [pscustomobject]$PluginModule,

        [Parameter(Mandatory)]
        [pscustomobject]$LifecycleState
    )

    Assert-GerberPluginRegistrationIdentity -PluginList $RegistryBuilder.PluginList -PluginModule $PluginModule
    Complete-GerberPluginRegistryPreparation -RegistryBuilder $RegistryBuilder -PluginModule $PluginModule -LifecycleState $LifecycleState
}

function Complete-GerberPluginRegistryPreparation {
    param(
        [pscustomobject]$RegistryBuilder,
        [pscustomobject]$PluginModule,
        [pscustomobject]$LifecycleState
    )

    $registration = ConvertTo-GerberPluginRegistration -PluginModule $PluginModule -GerberVersion $RegistryBuilder.GerberVersion
    Add-GerberPluginRegistrationCommandList -RegistryBuilder $RegistryBuilder -Registration $registration -OwnerName $PluginModule.Name
    Complete-GerberPluginRegistryState `
        -RegistryBuilder $RegistryBuilder `
        -PluginModule $PluginModule `
        -Registration $registration `
        -LifecycleState $LifecycleState
}

function Add-GerberPluginRegistrationCommandList {
    param(
        [pscustomobject]$RegistryBuilder,
        [pscustomobject]$Registration,
        [string]$OwnerName
    )

    Add-GerberOwnedCommandDefinitionList `
        -RegisteredCommandList $RegistryBuilder.CommandList `
        -CommandDefinitionList $Registration.Commands `
        -OwnerName $OwnerName `
        -OwnerType 'Plugin'
}

function ConvertTo-GerberPluginRegistration {
    param(
        [pscustomobject]$PluginModule,
        [System.Management.Automation.SemanticVersion]$GerberVersion
    )

    $pluginApiVersion = [string]$PluginModule.PrivateData.Gerber.ApiVersion
    $pluginApiContext = New-GerberPluginApiContext `
        -ApiVersion $pluginApiVersion `
        -PluginId $PluginModule.Guid `
        -PluginModuleName $PluginModule.Name
    $pluginDefinition = Get-GerberPluginDefinition `
        -PluginModule $PluginModule `
        -CurrentGerberVersion $GerberVersion `
        -PluginContext $pluginApiContext
    return ConvertTo-GerberPluginRegistrationData -PluginModule $PluginModule -Definition $pluginDefinition -Context $pluginApiContext -ApiVersion $pluginApiVersion
}

function ConvertTo-GerberPluginRegistrationData {
    param(
        [pscustomobject]$PluginModule,
        [pscustomobject]$Definition,
        [pscustomobject]$Context,
        [string]$ApiVersion
    )

    return [pscustomobject]@{
        ApiContext = $Context
        ApiVersion = $ApiVersion
        Commands = Get-GerberPluginCommandDefinitionList -PluginModule $PluginModule -PluginDefinition $Definition
    }
}

function ConvertTo-GerberRegisteredPluginState {
    param(
        [pscustomobject]$PluginModule,
        [pscustomobject]$Registration
    )

    return [pscustomobject][ordered]@{
        Name                 = $PluginModule.Name
        Guid                 = $PluginModule.Guid
        Version              = $PluginModule.Version.ToString()
        PluginApiVersion     = $Registration.ApiVersion
        PluginApiContext     = $Registration.ApiContext
        MinimumGerberVersion = [string]$PluginModule.PrivateData.Gerber.MinimumGerberVersion
        ModulePath           = $PluginModule.Path
    }
}

function Complete-GerberPluginRegistryState {
    param(
        [pscustomobject]$RegistryBuilder,
        [pscustomobject]$PluginModule,
        [pscustomobject]$Registration,
        [pscustomobject]$LifecycleState
    )

    $state = ConvertTo-GerberRegisteredPluginState -PluginModule $PluginModule -Registration $Registration
    $state | Add-Member -NotePropertyName IsAssociated -NotePropertyValue $LifecycleState.IsAssociated
    $state | Add-Member -NotePropertyName IsEnabled -NotePropertyValue $LifecycleState.IsEnabled
    $null = $RegistryBuilder.PluginList.Add($state)
}

function Get-GerberPluginDefinition {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$PluginModule,

        [Parameter(Mandatory)]
        [System.Management.Automation.SemanticVersion]$CurrentGerberVersion,

        [Parameter(Mandatory)]
        [pscustomobject]$PluginContext
    )

    $minimumVersion = [System.Management.Automation.SemanticVersion]::Parse(
        [string]$PluginModule.PrivateData.Gerber.MinimumGerberVersion
    )
    if ($minimumVersion -gt $CurrentGerberVersion) {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$($PluginModule.Name)' requires Gerber version '$minimumVersion' or later, but the current Gerber version is '$CurrentGerberVersion'."
        )
    }

    try {
        $importedModule = Import-Module -Name $PluginModule.Path -Force -PassThru -ErrorAction Stop
    } catch {
        throw [System.InvalidOperationException]::new(
            "Gerber could not import plugin '$($PluginModule.Name)': $($_.Exception.Message)"
        )
    }

    $entryPoint = Get-Command -Name 'Get-GerberPlugin' -Module $importedModule.Name -ErrorAction SilentlyContinue
    if ($null -eq $entryPoint) {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$($PluginModule.Name)' does not export the required entry point 'Get-GerberPlugin'."
        )
    }

    $pluginDefinition = & $entryPoint -Gerber $PluginContext
    if ($null -eq $pluginDefinition) {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$($PluginModule.Name)' returned an empty plugin definition."
        )
    }

    return $pluginDefinition
}

function Get-GerberPluginCommandDefinitionList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$PluginModule,

        [Parameter(Mandatory)]
        [pscustomobject]$PluginDefinition
    )

    if ($PluginDefinition.PSObject.Properties.Name -notcontains 'Commands') {
        throw [System.InvalidOperationException]::new(
            "Gerber plugin '$($PluginModule.Name)' returned an invalid definition because the 'Commands' property was missing."
        )
    }

    $commandDefinitionList = [object[]]@($PluginDefinition.Commands)
    return ,$commandDefinitionList
}
