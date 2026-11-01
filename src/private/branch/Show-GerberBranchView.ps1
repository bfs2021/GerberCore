function Show-GerberBranchView {
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscustomobject]$Command)
    Show-GerberRegisteredSubcommandMenu -CommandName 'branch' -Command $Command -AutoSelectFirstSuggestionOnSubmit
}
