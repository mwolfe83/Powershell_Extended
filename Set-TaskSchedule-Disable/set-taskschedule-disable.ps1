# Replace 'Scheduled Windows Update' with the actual name of your scheduled task
$taskName = 'Scheduled Windows Update'
$logFile = '\\p01-wf-tch-01\data$\Marshall\Scripts\Set-TaskSchedule-Disable\output.log'

try {
    # Get the existing task
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop

    # Disable the task
    Disable-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName

    Write-Host "Task '$taskName' has been disabled."

    # Log the success to the specified log file
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $env:COMPUTERNAME Task '$taskName' has been disabled."
    Add-Content -Path $logFile -Value $logMessage

} catch {
    $errorMessage = "Failed to disable task '$taskName'. Error: $_"
    Write-Host $errorMessage

    # Log the error to the specified log file
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $env:COMPUTERNAME $errorMessage"
    Add-Content -Path $logFile -Value $logMessage
}
