# Set the path for the log file
$logFile = "$PSScriptRoot\log.txt"

# Start transcription and append to the log file
Start-Transcript -Path $logFile -Append -Force

# Read the computer names from the computers.txt file
$computers = Get-Content -Path "$PSScriptRoot\computers.txt"

# Loop through each computer
foreach ($computer in $computers) {
    Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Testing connection to computer"
    
    # Test the connection to the target computer
    $connectionTest = Test-Connection -ComputerName $computer -Count 1 -Quiet

    if ($connectionTest) {
        Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Connecting to computer"
        Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Checking if C:\temp directory exists on computer"
        
        # Check if C:\temp directory exists and create it if necessary
        $tempDirectory = "\\$computer\c$\temp"
        if (!(Test-Path -Path $tempDirectory)) {

            Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Creating C:\temp directory on computer"
            New-Item -ItemType Directory -Path $tempDirectory | Out-Null
        }

        Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Copying files to computer"
        
        # Copy the folder to the target computer
        try {
            Copy-Item -Path "$PSScriptRoot\Bigfix-Install-Package" -Destination $tempDirectory -Recurse -Force -ErrorAction Stop
        } catch {
            $errorCode = $_.Exception.ErrorCode
            Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Error: $errorCode"
            continue
        }

        Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Establishing PSSession to computer"

       # Create a PSSession to the target computer
        try {
            $session = New-PSSession -ComputerName $computer -ErrorAction Stop
        } catch {
            $errorCode = $_.Exception.ErrorCode
            Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Error: $errorCode"
            
            # Check for specific error codes and display custom messages
            switch ($errorCode) {
                53 {
                    Write-Host  (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer System error 53 has occurred. The network path was not found."
                }
                51 {
                    Write-Host  (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer  System error 51 has occurred. The remote computer is not available."
                }
                default {
                    # Handle other error codes if needed
                }
            }
            
            continue
        }

        Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Verifying service 'BigFix Agent (32 bit)' doesn't exist"

        # Check if 'BigFix Agent (32 bit)' service doesn't exist
        $service = Get-Service -ComputerName $computer -Name "BESClient" -ErrorAction SilentlyContinue
        if ($service) {
            Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Error: 'BigFix Agent (32 bit)' service already exists"
            continue
        }

        Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Running setup.exe on computer"

        # Run the setup.exe in the PSSession with additional flags
        try {
            $setupPath = "$tempDirectory\Bigfix-Install-Package\setup.exe"
            $arguments = '/S', '/v"/qn"'
            $exitCode = Invoke-Command -Session $session -ScriptBlock {
                $process = Start-Process -FilePath $args[0] -ArgumentList $args[1] -Wait -PassThru
                $process.ExitCode
            } -ArgumentList $setupPath, $arguments -ErrorAction Stop
        } catch {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $errorCode = $_.Exception.ErrorCode
            Write-Host "$timestamp $computer Error: $errorCode"
            continue
        }

        # Check if the setup.exe execution failed
        if ($exitCode -ne 0) {
            Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Error executing setup.exe on computer"
        } else {
            Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer setup.exe executed successfully on computer"
        }

        # Close the PSSession
        Remove-PSSession -Session $session
    } else {
        Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Connection failed"
    }
}

# Stop transcription
Stop-Transcript
