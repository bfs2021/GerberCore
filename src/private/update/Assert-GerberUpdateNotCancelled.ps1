function Assert-GerberUpdateNotCancelled {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)
    if ($ErrorRecord.Exception -is [System.OperationCanceledException] -or
        $ErrorRecord.Exception -is [System.Management.Automation.PipelineStoppedException]) {
        throw $ErrorRecord
    }
}
