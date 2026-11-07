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
    if ($null -eq $Module -or $Module.Name -ne 'Gerber' -or $null -eq $Module.Version) {
        throw [System.InvalidOperationException]::new($unresolved)
    }

    $prerelease = $null
    if ($null -ne $Module.PrivateData) {
        $psData = $Module.PrivateData['PSData']
        if ($null -ne $psData) {
            $prerelease = $psData['Prerelease']
        }
    }

    $build = [Math]::Max($Module.Version.Build, 0)
    $core = '{0}.{1}.{2}' -f $Module.Version.Major, $Module.Version.Minor, $build
    if ([string]::IsNullOrWhiteSpace([string]$prerelease)) {
        return $core
    }

    return ('{0}-{1}' -f $core, $prerelease)
}
