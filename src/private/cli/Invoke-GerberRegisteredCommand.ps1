function Invoke-GerberRegisteredCommand {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$CommandDefinition,

        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    if (Test-GerberCommandContainer -Definition $CommandDefinition) {
        return Invoke-GerberContainerMenu -CommandDefinition $CommandDefinition -Command $Command
    }

    $result = Invoke-GerberValidatedCommandHandler -CommandDefinition $CommandDefinition -Command $Command
    return ConvertTo-GerberHandlerExitResult -Result $result -CommandName $CommandDefinition.Name
}

function Invoke-GerberContainerMenu {
    param(
        [pscustomobject]$CommandDefinition,
        [pscustomobject]$Command
    )

    return [bool](Show-GerberRegisteredSubcommandMenu -CommandName $CommandDefinition.Name `
        -Command $Command -AutoSelectFirstSuggestionOnSubmit -PropagateExit)
}

function Invoke-GerberValidatedCommandHandler {
    param(
        [pscustomobject]$CommandDefinition,
        [pscustomobject]$Command
    )

    if ($CommandDefinition.Handler -isnot [scriptblock]) {
        throw [System.ArgumentException]::new(
            "Gerber command '$($CommandDefinition.Name)' does not define a valid handler scriptblock."
        )
    }

    return Invoke-GerberRegisteredCommandHandler -CommandDefinition $CommandDefinition -Command $Command
}

function ConvertTo-GerberHandlerExitResult {
    param(
        [AllowNull()]
        [object]$Result,
        [string]$CommandName
    )

    if ($null -eq $Result -or $Result -is [bool]) {
        return [bool]$Result
    }

    throw [System.InvalidOperationException]::new(
        "Gerber command '$CommandName' returned an invalid handler result type '$($Result.GetType().FullName)'."
    )
}

function Invoke-GerberRegisteredCommandHandler {
    [OutputType([object])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$CommandDefinition,

        [Parameter(Mandatory)]
        [pscustomobject]$Command
    )

    if ([string]$CommandDefinition.OwnerType -eq 'Plugin') {
        $pluginContext = Get-GerberRegisteredPluginApiContext -OwnerName $CommandDefinition.OwnerName
        return (& $CommandDefinition.Handler $Command $pluginContext)
    }

    return (& $CommandDefinition.Handler $Command)
}

function Get-GerberRegisteredPluginApiContext {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OwnerName
    )

    $registryState = Resolve-GerberPluginContextRegistry
    return Find-GerberPluginOwnerContext -PluginList $registryState.PluginList -OwnerName $OwnerName
}

function Resolve-GerberPluginContextRegistry {
    param()

    $registryState = Get-GerberRegisteredCommandRegistryState
    if ($null -eq $registryState) {
        throw [System.InvalidOperationException]::new(
            'Gerber command registry has not been initialized for this session.'
        )
    }

    return $registryState
}

function Find-GerberPluginOwnerContext {
    param(
        [object[]]$PluginList,
        [string]$OwnerName
    )

    foreach ($pluginState in $PluginList) {
        if ([string]$pluginState.Name -ieq $OwnerName) {
            return $pluginState.PluginApiContext
        }
    }

    throw [System.InvalidOperationException]::new(
        "Gerber command '$OwnerName' does not have an initialized plugin API context."
    )
}
