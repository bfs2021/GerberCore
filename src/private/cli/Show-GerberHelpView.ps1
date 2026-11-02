function Show-GerberHelpView {
    [CmdletBinding()]
    param()

    Show-GerberTextBlock -Title '/help' -Text (ConvertTo-GerberHelpText)
    Wait-GerberContinue
}

function ConvertTo-GerberHelpText {
    param()

    return @(
        'Commands'
        (Get-GerberHelpRootCommandLineList)
        (Get-GerberHelpNestedCommandLineList)
        ''
        'Autocomplete'
        '  Type / to see the available commands'
        '  Type /to and press Tab to expand to /tools'
        '  Type /tools to preview the available tools'
        '  Type /secrets to preview the available secrets actions'
        '  Use Up/Down to browse suggestions'
        '  Press Tab to apply the selected suggestion'
        '  Press Enter to accept the highlighted suggestion and execute it when it is complete'
        ''
        'Examples'
        (Get-GerberHelpLeafActionExampleLineList)
    ) -join [Environment]::NewLine

}

function Get-GerberHelpRootCommandLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param()

    $catalog = Get-GerberCommandCatalog -ActionList (Get-GerberActionList)
    return @(
        foreach ($commandName in $catalog.Keys) {
            "  /$commandName $(Get-GerberCatalogEntryDescription -Entry $catalog[$commandName])"
        }
    )
}

function Get-GerberHelpNestedCommandLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param()

    return @(
        foreach ($commandDefinition in (Get-GerberCommandRegistry)) {
            if (-not $commandDefinition.Name.Contains(' ')) {
                continue
            }

            "  /$($commandDefinition.Name) $($commandDefinition.Description)"
        }
    )
}

function Get-GerberHelpLeafActionExampleLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param()

    $catalog = Get-GerberCommandCatalog -ActionList (Get-GerberActionList)
    return @(
        foreach ($action in (Get-GerberLeafActionCommandList -Catalog $catalog)) {
            "  $($action.DisplayText)"
        }
    )
}
