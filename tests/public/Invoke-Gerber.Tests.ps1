BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Invoke-Gerber' -Tag 'G4A7' {
    It 'initializes the registry, starts the interactive menu, and clears the session registry afterward' {
        Mock Clear-GerberCommandRegistry {}
        Mock Initialize-GerberCommandRegistry {}
        Mock Show-GerberMenu {}
        Mock Invoke-GerberStartupUpdateCheck { [pscustomobject]@{ Status = 'Unavailable' } }

        Invoke-Gerber

        Should -Invoke Clear-GerberCommandRegistry -Times 2
        Should -Invoke Initialize-GerberCommandRegistry -Times 1
        Should -Invoke Show-GerberMenu -Times 1
    }

    It 'checks Core once per application start rather than on import and clears presentation state' {
        Mock Clear-GerberCommandRegistry {}
        Mock Initialize-GerberCommandRegistry {}
        Mock Invoke-GerberStartupUpdateCheck { [pscustomobject]@{ Status = 'Available'; Available = '0.2.0' } }
        Mock Show-GerberMenu {}

        Invoke-Gerber

        Should -Invoke Invoke-GerberStartupUpdateCheck -Times 1
        Should -Invoke Show-GerberMenu -Times 1
    }
}
