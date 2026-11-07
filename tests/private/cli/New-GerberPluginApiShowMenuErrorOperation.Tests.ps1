BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'New-GerberPluginApiShowMenuErrorOperation' -Tag 'PluginPlatform' {
    It 'does not swallow pipeline cancellation while displaying an error' {
        $source = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) 'src/private/cli/New-GerberPluginApiShowMenuErrorOperation.ps1'
        $marker = Join-Path $TestDrive 'cancellation.txt'
        $child = Join-Path $TestDrive 'cancellation.ps1'
        $scriptText = @"
. '$($source.Replace("'", "''"))'
function Get-GerberModuleBoundScriptBlock { param([scriptblock]`$ScriptBlock) return `$ScriptBlock }
function Show-GerberMenuError {
    param([string]`$Message)
    [IO.File]::WriteAllText('$($marker.Replace("'", "''"))', 'inside')
    throw [System.Management.Automation.PipelineStoppedException]::new()
}
& (New-GerberPluginApiShowMenuErrorOperation) 'Recoverable'
[IO.File]::WriteAllText('$($marker.Replace("'", "''"))', 'continued')
"@
        [IO.File]::WriteAllText($child, $scriptText)
        $null = & (Get-Process -Id $PID).Path -NoLogo -NoProfile -File $child 2>&1
        [IO.File]::ReadAllText($marker) | Should -Be 'inside'
    }
}
