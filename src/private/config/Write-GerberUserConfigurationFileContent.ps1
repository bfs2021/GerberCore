function Write-GerberUserConfigurationFileContent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Content)

    $stream = [System.IO.FileStream]::new($Path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
        Write-GerberConfigurationStream -Stream $stream -Content $Content
    } finally {
        $stream.Dispose()
    }
}

function Write-GerberConfigurationStream {
    param([System.IO.FileStream]$Stream, [string]$Content)

    $writer = [System.IO.StreamWriter]::new($Stream, [System.Text.UTF8Encoding]::new($false))
    try {
        $writer.Write($Content)
        $writer.Flush()
        $Stream.Flush($true)
    } finally {
        $writer.Dispose()
    }
}
