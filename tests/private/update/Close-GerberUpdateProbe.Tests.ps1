# Cross-cutting process lifetime coverage lives in Invoke-GerberUpdateProbe.Tests.ps1
# and Invoke-GerberUpdateActivationProbe.Tests.ps1, including bounded termination.
BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/private/update/Close-GerberUpdateProbe.ps1')
}

Describe 'Close-GerberUpdateProbe' {
    BeforeEach {
        $script:process = [System.Diagnostics.Process]::new()
        $script:process | Add-Member -MemberType NoteProperty -Name DisposalCount -Value 0
        $script:process | Add-Member -MemberType ScriptMethod -Name Dispose -Force -Value {
            $this.DisposalCount++
            $this.PSBase.Dispose()
        }
    }

    AfterEach {
        $script:process.PSBase.Dispose()
    }

    It 'reports an unstarted probe without throwing and still disposes it' {
        $messages = & {
            $VerbosePreference = 'Continue'
            Close-GerberUpdateProbe -Process $script:process
        } 4>&1

        @($messages).Count | Should -Be 1
        $messages.Message | Should -Be 'Update probe already exited or could not start.'
        $script:process.DisposalCount | Should -Be 1
    }

    It 'kills the entire running probe tree before disposing it' {
        $script:process | Add-Member -MemberType ScriptProperty -Name HasExited -Value { $false } -Force
        $script:process | Add-Member -MemberType NoteProperty -Name KilledTree -Value $false
        $script:process | Add-Member -MemberType ScriptMethod -Name Kill -Force -Value {
            param([bool]$EntireProcessTree)
            $this.DisposalCount | Should -Be 0
            $this.KilledTree = $EntireProcessTree
        }

        Close-GerberUpdateProbe -Process $script:process

        $script:process.KilledTree | Should -BeTrue
        $script:process.DisposalCount | Should -Be 1
    }

    It 'disposes an exited probe without trying to kill it' {
        $script:process | Add-Member -MemberType ScriptProperty -Name HasExited -Value { $true } -Force
        $script:process | Add-Member -MemberType ScriptMethod -Name Kill -Force -Value {
            throw 'An exited probe must not be killed.'
        }

        { Close-GerberUpdateProbe -Process $script:process } | Should -Not -Throw

        $script:process.DisposalCount | Should -Be 1
    }
}
