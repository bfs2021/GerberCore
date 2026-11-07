function Test-GerberPluginUpdateEligibility {
    param([object]$Entry)
    $Entry.IsDiscovered -and $Entry.IsAssociated -and
    $Entry.IsEnabled -and $Entry.ApprovalStatus -eq 'Approved'
}
