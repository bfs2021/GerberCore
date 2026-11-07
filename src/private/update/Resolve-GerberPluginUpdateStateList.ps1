function Resolve-GerberPluginUpdateStateList {
    param()
    foreach ($entry in @(Get-GerberPluginInventory)) {
        if (Test-GerberPluginUpdateEligibility $entry) {
            Resolve-GerberPluginUpdateState -Entry $entry
        }
    }
}
