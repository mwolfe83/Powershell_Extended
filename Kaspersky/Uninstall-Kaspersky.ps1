function Get-InstalledSoftware {
    <#
    .SYNOPSIS
        Retrieves a list of all software installed
    .EXAMPLE
        Get-InstalledSoftware
        
        This example retrieves all software installed on the local computer
    .PARAMETER Name
        The software title you'd like to limit the query to.
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $UninstallKeys = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    $null = New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS
    $UninstallKeys += Get-ChildItem HKU: -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' } | ForEach-Object { "HKU:\$($_.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Uninstall" }
    if (-not $UninstallKeys) {
        Write-Verbose -Message 'No software registry keys found'
    } else {
        foreach ($UninstallKey in $UninstallKeys) {
            if ($PSBoundParameters.ContainsKey('Name')) {
                $WhereBlock = { ($_.PSChildName -match '^{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}$') -and ($_.GetValue('DisplayName') -like "$Name*") }
            } else {
                $WhereBlock = { ($_.PSChildName -match '^{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}$') -and ($_.GetValue('DisplayName')) }
            }
            $gciParams = @{
                Path        = $UninstallKey
                ErrorAction = 'SilentlyContinue'
            }
            $selectProperties = @(
                @{n='GUID'; e={$_.PSChildName}}, 
                @{n='Name'; e={$_.GetValue('DisplayName')}}
            )
            Get-ChildItem @gciParams | Where $WhereBlock | Select-Object -Property $selectProperties
        }
    }
}

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

    $appguid = Get-InstalledSoftware -Name "Kaspersky Endpoint Security"
    if ($appguid -eq $null) {
        $appguid = New-Object PSObject -Property @{
            name = "{93EDBC7E-D73F-4401-84A5-79E8CBB8B843}"
            }
    }

    if ($appguid) {
        Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Found Guid and is :$($appguid.GUID)"

        $arguments = "/x $($appguid.GUID) KLLOGIN=""KLAdmin"" KLPASSWD=""K@sp3rsky"" /qn /norestart"
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -PassThru -Wait

        if ($process.ExitCode -eq 0) {
            Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Uninstall Successful"
        } else {
            Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Uninstall Failed with Exit Code $($process.ExitCode)"
        }
    } else {
        Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") " $computer Kaspersky software not found. Skipping uninstallation."
    }
}


