function Get-GerberModuleSemanticVersion {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [System.Management.Automation.PSModuleInfo]$Module
    )

    if ($null -eq $Module) {
        $Module = $MyInvocation.MyCommand.Module
    }
    $unresolved = 'Unable to resolve the executing Gerber module version. The plugin MinimumGerberVersion cannot be generated; rebuild or reinstall Gerber and retry.'
    if ($null -eq $Module) {
        throw [System.InvalidOperationException]::new($unresolved)
    }
    if ($Module.Name -ne 'Gerber') {
        throw [System.InvalidOperationException]::new($unresolved)
    }
    if ($null -eq $Module.Version) {
        throw [System.InvalidOperationException]::new($unresolved)
    }

    $psData = Get-GerberModulePrivateDataValueOrNull -InputObject $Module.PrivateData -Name 'PSData'
    $prerelease = Get-GerberModulePrivateDataValueOrNull -InputObject $psData -Name 'Prerelease'
    if ([string]::IsNullOrWhiteSpace([string]$prerelease)) {
        return [string]$Module.Version
    }

    return ('{0}-{1}' -f $Module.Version, $prerelease)
}
