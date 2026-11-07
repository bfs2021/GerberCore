function Assert-GerberJsonConfigurationText {
    param([AllowEmptyString()][string]$Json, [string]$Path)

    try {
        $options = [System.Text.Json.JsonDocumentOptions]::new()
        $options.MaxDepth = 100
        $document = [System.Text.Json.JsonDocument]::Parse($Json, $options)
        $document.Dispose()
    } catch {
        throw [System.IO.InvalidDataException]::new("Gerber could not parse configuration file '$Path' as JSON. Correct the file before retrying; it was not overwritten.")
    }
}
