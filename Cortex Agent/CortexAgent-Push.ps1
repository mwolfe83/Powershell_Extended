# Set the path for the log file
$logFile = "$PSScriptRoot\log.txt"

# Start transcription and append to the log file
Start-Transcript -Path $logFile -Append -Force

# Read the computer names from the computers.txt file
$computers = Get-Content -Path "$PSScriptRoot\computers.txt"

#setup file name
$setupfile = "Windows_agent_ver_8_x64.msi"

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
            Copy-Item -Path "$PSScriptRoot\Cortex-Install-Package" -Destination $tempDirectory -Recurse -Force -ErrorAction Stop
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
            continue
        }

        Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Verifying service 'cyserver' doesn't exist"

        # Check if 'Cortex' service doesn't exist cyserver
        $service = Get-Service -ComputerName $computer -Name "cyserver" -ErrorAction SilentlyContinue
        if ($service) {
            Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Error: 'Cortex' service already exists"
            continue
        }

        Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Running setup.exe on computer"

        # Run the setup.msi in the PSSession with additional flags

            $Result = Invoke-Command -computername $computer -ScriptBlock {(Start-Process "msiexec" -ArgumentList "/i C:\temp\Cortex-Install-Package\Windows_agent_ver_8_x64.msi /quiet /norestart" -Wait -Passthru).ExitCode}
        Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Exit Code $result"
        # Close the PSSession
        Remove-PSSession -Session $session
    } else {
        Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Connection failed"
    }
}

# Stop transcription
Stop-Transcript
