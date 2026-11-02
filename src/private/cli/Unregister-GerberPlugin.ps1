function Unregister-GerberPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Guid
    )

    $state = Get-GerberRegisteredCommandRegistryState
    if ($null -eq $state) {
        return
    }
    $plugin = $state.PluginList | Where-Object { $_.Guid -ieq $Guid } | Select-Object -First 1
    if ($null -ne $plugin) {
        $script:GerberCommandRegistryState = Copy-GerberRegistryWithoutPlugin -State $state -Plugin $plugin
    }
}

function Copy-GerberRegistryWithoutPlugin {
    param(
        [pscustomobject]$State,
        [pscustomobject]$Plugin
    )

    $stagedState = Copy-GerberCommandRegistryState -State $State
    $remainingCommands = Select-GerberPluginCommandRemainder -State $stagedState -Plugin $Plugin
    return [pscustomobject][ordered]@{
        CommandList   = @(Select-GerberActiveCommandDefinitionList -Commands $remainingCommands)
        PluginList    = @($State.PluginList | Where-Object { $_.Guid -ine $Plugin.Guid })
        GerberVersion = $State.GerberVersion
    }
}

function Select-GerberPluginCommandRemainder {
    param(
        [pscustomobject]$State,
        [pscustomobject]$Plugin
    )

    $ownedCommandList = @(
        $State.CommandList | Where-Object { ($_.OwnerType -eq 'Plugin') -and ($_.OwnerName -ieq $Plugin.Name) }
    )
    $remainingCommandList = @(
        $State.CommandList | Where-Object { $ownedCommandList -notcontains $_ }
    )
    Clear-GerberPluginCommandAttachmentList -CommandList $remainingCommandList -OwnedCommandList $ownedCommandList
    return ,$remainingCommandList
}

function Clear-GerberPluginCommandAttachmentList {
    param(
        [object[]]$CommandList,
        [object[]]$OwnedCommandList
    )

    foreach ($ownedCommand in $OwnedCommandList) {
        Clear-GerberPluginSubcommandEntry -CommandList $CommandList -OwnedCommand $ownedCommand
    }
}
