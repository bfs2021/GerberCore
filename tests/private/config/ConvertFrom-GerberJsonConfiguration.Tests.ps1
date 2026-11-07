BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'ConvertFrom-GerberJsonConfiguration' -Tag 'PluginJson' {
    It 'preserves nested JSON types, date text, array boundaries and case-distinct fields' {
        $json = '{"date":"2026-01-01T02:00:00+02:00","Foo":1,"foo":2,"items":[null,true,3,[],["one"]]}'
        $value = ConvertFrom-GerberJsonConfiguration -Json $json
        $value['date'] | Should -BeOfType ([string])
        $value.ContainsKey('Foo') | Should -BeTrue
        $value.ContainsKey('foo') | Should -BeTrue
        (ConvertTo-Json -InputObject $value -Depth 100 -Compress) | Should -BeExactly $json
    }

    It 'retains a root empty array as an array value' {
        $value = ConvertFrom-GerberJsonConfiguration -Json '[]'
        (ConvertTo-Json -InputObject $value -Compress) | Should -BeExactly '[]'
    }
}
