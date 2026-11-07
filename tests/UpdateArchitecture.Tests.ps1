# Cross-cutting guardrail: proves the PMU/Nova boundary across startup and update source files.
BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    $script:allUpdateFiles = Get-ChildItem "$root/src/private/update" -Filter '*.ps1'
    $coreFileNames = @(
        'Invoke-GerberStartupUpdateCheck', 'Resolve-GerberCoreUpdateRequest',
        'Show-GerberStartupUpdateNotification', 'Format-GerberCoreUpdateOverview',
        'Invoke-GerberCoreUpdateInstall', 'Get-GerberCoreUpdateState',
        'Show-GerberCoreUpdateSummary', 'Test-GerberUpdateInteractive',
        'Get-GerberUpdateFailureMessage', 'Invoke-GerberUpdateProbe', 'Close-GerberUpdateProbe'
    )
    $script:updateFiles = @($allUpdateFiles | Where-Object BaseName -In $coreFileNames)
}

Describe 'Plugin update architecture' -Tag 'G4A9' {
    It 'uses public PMU acquisition and installation without a second package manager' {
        $text = ($allUpdateFiles | ForEach-Object {
                Get-Content -LiteralPath $_ -Raw
            }) -join "`n"
        $text | Should -Match 'Get-PSModuleUpdateTargetManifest'
        $text | Should -Not -Match 'Find-PSResource|Save-PSResource|Install-PSResource|Update-Module|Install-Module'
        $text | Should -Not -Match 'Register-PSRepository|Register-PSResourceRepository|Invoke-NovaBuild'
    }
}

Describe 'Core update architecture' -Tag 'G4A7' {
    It 'has one PMU discovery boundary and one PMU install boundary, with no alternate updater' {
        $calls = foreach ($file in $updateFiles) {
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
            $ast.FindAll({
                    param($node) $node -is [System.Management.Automation.Language.CommandAst]
                }, $true) |
                ForEach-Object {
                    $_.GetCommandName()
                }
        }
        @($calls | Where-Object {
                $_ -eq 'Get-PSModuleUpdate'
            }).Count | Should -Be 1
        @($calls | Where-Object {
                $_ -eq 'Install-PSModuleUpdate'
            }).Count | Should -Be 1
        $calls | Should -Not -Contain 'Update-Module'
        $calls | Should -Not -Contain 'Install-Module'
        $calls | Should -Not -Contain 'Install-PSResource'
    }

    It 'never performs Nova build or packaging operations in application startup or Core updates' {
        $paths = @("$root/src/public/Invoke-Gerber.ps1") + @($updateFiles.FullName)
        $text = ($paths | ForEach-Object {
                Get-Content -LiteralPath $_ -Raw
            }) -join "`n"
        $text | Should -Not -Match 'Invoke-NovaBuild|New-NovaPackage|Publish-Nova|Test-NovaBuild'
        $text | Should -Not -Match 'Register-PSRepository|Register-PSResourceRepository'
    }

    It 'reads only the isolated Core channel resolver, never legacy or plugin update bindings' {
        $text = ($updateFiles | ForEach-Object {
                Get-Content -LiteralPath $_ -Raw
            }) -join "`n"
        $text | Should -Not -Match 'Get-GerberUserConfiguration|Get-GerberCredential|updates\.modules|Unconfigured|CredentialRequired'
        $text | Should -Match 'Resolve-GerberCoreUpdatePolicy'
        $bindingFiles = $updateFiles | Where-Object BaseName -NE 'Test-GerberUpdateInteractive'
        $bindingText = ($bindingFiles | ForEach-Object {
                Get-Content -LiteralPath $_ -Raw
            }) -join "`n"
        $bindingText | Should -Not -Match '\$env:|GetEnvironmentVariable'
    }
}
