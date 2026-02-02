# Get the path to the computers.txt file
$computersFile = Join-Path $PSScriptRoot "computers.txt"

# Check if the file exists
if (Test-Path $computersFile) {
    foreach ($computer in $computers) {
        # Construct the UNC path for the log file on the remote computer
        $remoteLogFilePath = "\\p01-wf-tch-01\data$\Marshall\Scripts\TaskSchedule_Update\output.log"
        $localLogFilePath = Join-Path $PSScriptRoot "$computer-output.log"

        try {
            # Validate if the computer is reachable
            if (Test-Connection -ComputerName $computer -Count 1 -ErrorAction Stop) {
                # Copy the log file locally
                Invoke-Command -ComputerName $computer -ScriptBlock {
                    param($remoteLogFilePath, $localLogFilePath)
                    Copy-Item -Path $remoteLogFilePath -Destination $using:localLogFilePath
                } -ArgumentList $remoteLogFilePath, $localLogFilePath -ErrorAction Stop

                # Read the content and append it to the main log file
                Get-Content $localLogFilePath | Add-Content -Path $localLogFilePath
                Remove-Item $localLogFilePath -Force

                Write-Output "Script executed remotely on $computer."
            } else {
                Write-Warning "Failed to reach $computer. Ensure the computer is accessible."
            }
        } catch {
            Write-Error "Failed to execute script on $computer. Error: $_"
        }
    }

    Write-Output "Script executed remotely on all reachable computers."
} else {
    Write-Warning "The computers.txt file does not exist at $computersFile."
}
