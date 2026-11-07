function Add-GerberCommandContainerAncestor {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()][System.Collections.Generic.List[object]]$Commands,
        [AllowEmptyCollection()][object[]]$Definitions
    )

    foreach ($definition in $Definitions) {
        Add-GerberMissingCommandParent -Commands $Commands -Definitions $Definitions -Name $definition.ParentName -Contribution $definition
    }
}

function Add-GerberMissingCommandParent {
    param(
        [System.Collections.Generic.List[object]]$Commands,
        [object[]]$Definitions,
        [AllowNull()][string]$Name,
        [pscustomobject]$Contribution
    )

    if ([string]::IsNullOrEmpty($Name)) { return }
    if (@($Commands + $Definitions | Where-Object Name -EQ $Name).Count -gt 0) { return }
    Add-GerberMissingCommandParent -Commands $Commands -Definitions $Definitions `
        -Name (Get-GerberParentCommandName -CommandName $Name) -Contribution $Contribution
    $container = ConvertTo-GerberSharedCommandContainer -Name $Name -Order $Commands.Count
    Complete-GerberSharedContainerRegistration -Commands $Commands -Container $container -Contribution $Contribution
}

function Complete-GerberSharedContainerRegistration {
    param(
        [System.Collections.Generic.List[object]]$Commands,
        [pscustomobject]$Container,
        [pscustomobject]$Contribution
    )

    Assert-GerberSharedContainerParent -Commands $Commands -Container $Container -Contribution $Contribution
    if ($Container.ParentName) { Add-GerberOwnedSubcommandDefinition -RegisteredCommandList $Commands -OwnedCommandDefinition $Container }
    $Commands.Add($Container)
}

function Assert-GerberSharedContainerParent {
    param(
        [System.Collections.Generic.List[object]]$Commands,
        [pscustomobject]$Container,
        [pscustomobject]$Contribution
    )

    if (-not $Container.ParentName) { return }
    $parent = Find-GerberRegisteredCommandConflict -RegisteredCommandList $Commands -CommandName $Container.ParentName
    Assert-GerberCommandParentOwnership -Parent $parent -Command $Contribution
    $probe = $Container.PSObject.Copy()
    $probe.OwnerName = $Contribution.OwnerName
    Assert-GerberOwnedSubcommandConflict -RegisteredCommandList $Commands -OwnedCommandDefinitionList @() -OwnedCommandDefinition $probe
    $Container.OwnerName = $parent.OwnerName
    $Container.OwnerType = $parent.OwnerType
}

function ConvertTo-GerberSharedCommandContainer {
    param([string]$Name, [int]$Order)

    return [pscustomobject][ordered]@{
        Name = $Name
        Description = "Open the /$Name menu"
        Handler = { $false }
        Subcommands = [ordered]@{}
        OwnerName = 'Gerber.Core'
        OwnerType = 'Core'
        ParentName = Get-GerberParentCommandName -CommandName $Name
        LeafName = Get-GerberCommandLeafName -CommandName $Name
        RegistrationOrder = $Order
        IsContainer = $true
    }
}
