function Show-GerberUpdateMenu {
    param([pscustomobject]$Command)
    if (Test-GerberUpdateInteractive) {
        return Show-GerberRegisteredSubcommandMenu -CommandName update -Command $Command -AutoSelectFirstSuggestionOnSubmit -PropagateExit
    }
    if ($Command.Arguments.Count -eq 0) {
        Write-GerberScreenLine -Text 'Use /update list to check Core and eligible plugin updates, or /update policy in an interactive session to choose the shared channel.'
        return
    }
    $definition = Get-GerberRegisteredCommand -Name "update $($Command.Arguments[0])"
    return Invoke-GerberRegisteredCommand -CommandDefinition $definition -Command $Command
}
