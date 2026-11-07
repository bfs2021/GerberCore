function Test-GerberConfigurationTransitionValueEqual {
    param([AllowNull()][object]$First, [AllowNull()][object]$Second)

    $firstJson = ConvertTo-Json -InputObject $First -Depth 100 -Compress
    $secondJson = ConvertTo-Json -InputObject $Second -Depth 100 -Compress
    return [string]::Equals($firstJson, $secondJson, [System.StringComparison]::Ordinal)
}
