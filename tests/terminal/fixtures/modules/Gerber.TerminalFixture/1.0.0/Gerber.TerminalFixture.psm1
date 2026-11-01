function Get-GerberPlugin {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Gerber
    )

    return [pscustomobject][ordered]@{
        Commands = @(
            Get-GerberTerminalFixtureCommand -Name 'repository fixture-api' -Description 'Exercise generic Plugin API shared capabilities' -Handler (Get-GerberTerminalFixtureApiHandler -Gerber $Gerber)
            Get-GerberTerminalFixtureCommand -Name 'repository fixture-status' -Description 'Show a synthetic plugin success screen' -Handler (Get-GerberTerminalFixtureTextHandler -Gerber $Gerber -Title '/repository fixture-status' -Text 'Synthetic plugin command executed.' -WaitForContinue)
            Get-GerberTerminalFixtureCommand -Name 'repository explode' -Description 'Throw a synthetic plugin failure' -Handler (Get-GerberTerminalFixtureExplodeHandler)
            Get-GerberTerminalFixtureCommand -Name 'repository empty-text' -Description 'Render a synthetic empty text screen' -Handler (Get-GerberTerminalFixtureTextHandler -Gerber $Gerber -Title '/repository empty-text' -Text '')
        )
    }
}

function Get-GerberTerminalFixtureCommand {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter(Mandatory)]
        [scriptblock]$Handler
    )

    return [pscustomobject][ordered]@{
        Name = $Name
        Description = $Description
        Handler = $Handler
        Subcommands = [ordered]@{}
    }
}

function Get-GerberTerminalFixtureTextHandler {
    [OutputType([scriptblock])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Gerber,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [switch]$WaitForContinue
    )

    $null = $Gerber, $Title, $Text, $WaitForContinue
    return {
        param($ResolvedCommand)
        $null = $ResolvedCommand
        & $Gerber.UI.ShowTextBlock $Title $Text
        if ($WaitForContinue) {
            $null = & $Gerber.UI.WaitForContinue
        }
        return $false
    }.GetNewClosure()
}

function Get-GerberTerminalFixtureExplodeHandler {
    [OutputType([scriptblock])]
    [CmdletBinding()]
    param()

    return {
        param($ResolvedCommand)
        $null = $ResolvedCommand
        throw [System.InvalidOperationException]::new('Synthetic plugin failure.')
    }
}

function Get-GerberTerminalFixtureApiHandler {
    [OutputType([scriptblock])]
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscustomobject]$Gerber)

    $null = $Gerber
    return {
        param($ResolvedCommand)
        $null = $ResolvedCommand
        $pathSegmentList = @('terminal', 'contract')
        $secretValue = 'terminal-plugin-secret'
        & $Gerber.Secrets.Set $pathSegmentList $secretValue
        $stored = & $Gerber.Secrets.Test $pathSegmentList
        $resolvedSecret = & $Gerber.Secrets.GetText $pathSegmentList
        & $Gerber.Configuration.Save @{ fixture = 'generic-json-contract' }
        $configuration = & $Gerber.Configuration.Read
        $copied = & $Gerber.Clipboard.CopyText 'fixture-api-ok'
        $removed = & $Gerber.Secrets.Remove $pathSegmentList
        $contractPassed = @($stored, ($resolvedSecret -eq $secretValue), ($configuration.fixture -eq 'generic-json-contract'), $copied, $removed) -notcontains $false
        if (-not $contractPassed) {
            throw [System.InvalidOperationException]::new('Synthetic Plugin API contract failed.')
        }

        & $Gerber.UI.ShowTextBlock '/repository fixture-api' 'Synthetic Plugin API contract passed.'
        $null = & $Gerber.UI.WaitForContinue
        return $false
    }.GetNewClosure()
}
