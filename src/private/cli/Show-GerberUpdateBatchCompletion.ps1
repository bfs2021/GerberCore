function Show-GerberUpdateBatchCompletion {
    param([object[]]$ResultList)
    Write-GerberUpdateBatchResultList -ResultList $ResultList
    $restart = @($ResultList | Where-Object {
        $_.Outcome -in @('Installed', 'AlreadyInstalled') -and $_.VerificationStatus -eq 'Verified' -and $_.RestartRequired
    })
    if ($restart.Count -gt 0) {
        return Show-GerberUpdateBatchRestartChoice -Text (Get-GerberUpdateBatchRestartText -ResultList $ResultList)
    }
    Wait-GerberContinue
}

function Write-GerberUpdateBatchResultList {
    param([object[]]$ResultList)
    foreach ($result in $ResultList) {
        Write-GerberScreenLine -Text (Format-GerberUpdateBatchResultLine -Result $result)
        Write-GerberPromptTrace -EventName 'update-install-complete' -Data @{
            Component = $result.Item.State.Name; Outcome = $result.Outcome; Activation = $result.ActivationStatus
        }
    }
}

function Get-GerberUpdateBatchRestartText {
    param([object[]]$ResultList)
    $summary = @($ResultList | ForEach-Object {
        Format-GerberUpdateBatchResultLine -Result $_
    }) -join "`n"
    "$summary`n`nRestart PowerShell, then run gerber. Installed components are not hot reloaded in this session."
}

function Format-GerberUpdateBatchResultLine {
    param([object]$Result)
    "$($Result.Item.State.Name): $($Result.Outcome). Verification: $($Result.VerificationStatus). Recovery: $($Result.RecoveryStatus). Activation: $($Result.ActivationStatus). $($Result.Message)"
}
