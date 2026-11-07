function ConvertFrom-GerberJsonConfiguration {
    param([string]$Json)

    $options = [System.Text.Json.JsonDocumentOptions]::new()
    $options.MaxDepth = 100
    $document = [System.Text.Json.JsonDocument]::Parse($Json, $options)
    try {
        return ,(ConvertFrom-GerberJsonConfigurationElement -Element $document.RootElement)
    } finally {
        $document.Dispose()
    }
}

function ConvertFrom-GerberJsonConfigurationElement {
    param([System.Text.Json.JsonElement]$Element)

    if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
        return ConvertFrom-GerberJsonConfigurationObject -Element $Element
    }
    if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
        return ,(ConvertFrom-GerberJsonConfigurationArray -Element $Element)
    }
    if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::String) {
        return $Element.GetString()
    }
    return ,(ConvertFrom-Json -InputObject $Element.GetRawText() -AsHashtable -NoEnumerate)
}

function ConvertFrom-GerberJsonConfigurationObject {
    param([System.Text.Json.JsonElement]$Element)

    $value = [System.Management.Automation.OrderedHashtable]::new()
    foreach ($property in $Element.EnumerateObject()) {
        $value[$property.Name] = ConvertFrom-GerberJsonConfigurationElement -Element $property.Value
    }
    return $value
}

function ConvertFrom-GerberJsonConfigurationArray {
    param([System.Text.Json.JsonElement]$Element)

    $value = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $Element.EnumerateArray()) {
        $value.Add((ConvertFrom-GerberJsonConfigurationElement -Element $item))
    }
    return ,$value.ToArray()
}
