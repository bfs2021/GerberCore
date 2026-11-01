function Invoke-GerberPluginsCreateCommand {
    param([pscustomobject]$Command = [pscustomobject]@{ Arguments = @() })

    Assert-GerberPluginsActivationCommandInput -Command $Command -CommandName 'create'
    if (-not (Confirm-GerberPluginDevelopmentTool)) {
        return
    }
    Start-GerberScreen -Name '/plugins create'
    Show-GerberPluginProjectCreationIntroduction
    $result = Invoke-GerberPluginProjectCreationPrompt
    Show-GerberPluginProjectCreationSummary -Result $result
    Wait-GerberContinue
}

function Show-GerberPluginProjectCreationIntroduction {
    Show-GerberTextBlock -Title 'Create Gerber Plugin' -Text @'
Create a new Gerber PowerShell plugin project.
Includes a working example command, tests, and NovaModuleTools integration.
Esc cancels without approval.
'@
}

function Show-GerberPluginProjectCreationSummary {
    param([pscustomobject]$Result)

    $metadata = Get-GerberPluginProjectCreationMetadataText -Result $Result
    $repositorySummary = Get-GerberPluginProjectRepositorySummary -Result $Result
    $lifecycle = Get-GerberPluginProjectCreatedLifecycleText
    $nextSteps = Get-GerberPluginProjectCreationNextStepsText -Result $Result
    Show-GerberTextBlock -Title 'Gerber Plugin Created' -Text "$metadata`n$repositorySummary`n`n$lifecycle`n`n$nextSteps"
}

function Get-GerberPluginProjectCreationMetadataText {
    param([pscustomobject]$Result)

    return @"
Name:       $($Result.Name)
Version:    $($Result.Version)
Namespace:  /$($Result.Namespace)
Location:   $($Result.Path)
GUID: $($Result.Guid)
"@
}

function Get-GerberPluginProjectCreatedLifecycleText {
    return @'
Approval:   Approved
Associated: Yes
Enabled:    Yes
Installed:  No
'@
}

function Get-GerberPluginProjectCreationNextStepsText {
    param([pscustomobject]$Result)

    $quotedPath = $Result.Path.Replace("'", "''")
    return @"
Next steps:
  cd '$quotedPath'
  Publish-NovaModule -Local

Restart Gerber after installation.
Example command:
  /$($Result.Namespace) hello
"@
}

function Get-GerberPluginProjectRepositorySummary {
    param([pscustomobject]$Result)

    $summary = "Repository: $($Result.Repository.Name)`nURI:        $($Result.Repository.Uri)"
    if ($Result.Repository.Uri -ceq 'REPLACE_WITH_REPOSITORY_URI') {
        return "$summary`nReplace Manifest.PrivateData.Gerber.Repository.Uri before remote publishing or updates."
    }
    return $summary
}

function Invoke-GerberPluginProjectCreationPrompt {
    while ($true) {
        try {
            $request = Read-GerberPluginProjectRequest
            Write-GerberScreenLine -Text 'Generating and validating plugin (Nova build, unit tests, integration tests, Core registration)...'
            return New-GerberPluginProject -Request $request
        } catch [System.ArgumentException] {
            Write-GerberPromptTrace -EventName 'plugin-create-input-rejected' -Data @{ Field = 'Destination' }
            Write-GerberScreenLine -Text $_.Exception.Message
            Write-GerberScreenLine -Text 'Choose another module suffix or destination parent. Esc cancels.'
        }
    }
}
