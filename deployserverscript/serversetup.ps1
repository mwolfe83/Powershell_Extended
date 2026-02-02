############################################################################################
# Server 2019 GUI Basic Setup and Deployment
#
# v1.0 written by Ken Blankenship 2018-12-20 - RIP
#
# Modified by Mike Scruggs 9/5/2023
#
############################################################################################

#-----------------------------------Supporting Functions-----------------------------------#

function Convert-NetMaskToCIDR([string] $dottedAddressMaskString)
{
    $result=0
    #ensure we have a valid mask
    [IPAddress] $mask = $dottedAddressMaskString
    $octets = $mask.IPAddressToString.Split('.')
    foreach($octet in $octets)
    {
        while (0 -ne $octet)
        {
            $octet = ($octet -shl 1) -band [byte]::MaxValue
            $result++;
        }
    }
    return $result
}

#------------------------------------------------------------------------------------------#

#*************************************** Main Routine *************************************#

# 1. Prompt for Static or DHCP, set appropriately if Static
$setIP=Read-Host "Do you want to set a static IP (y/n)?"
if (($setIP -eq "y" ) -or ($setIP -eq "Y"))
{
    $getIPAddress=Read-Host "IP Address"
    $getNetMask=Read-Host "Network Mask (ex. 255.255.0.0)"
    if ($getNetMask -eq "")
    {
        $getNetMask="255.255.0.0"
    }
    $getGateway=Read-Host "Gateway Address (ex. 10.1.0.4)"
    if($getGateway -eq "")
    {
        $getGatway="10.1.0.4"
    }
    $getDNSServerList=Read-Host "DNS Server Order separated by comma (ex. 10.1.2.177,10.1.0.210,10.1.0.211)"
    if ($getDNSServerList -eq "")
    {
        $getDNSServerList="10.1.2.177,10.1.0.210,10.1.0.211"
    }
    $MaskLength = Convert-NetMaskToCIDR $getNetMask
    Set-NetIPInterface -InterfaceAlias "Ethernet0 2" -Dhcp Disabled
    New-NetIPAddress -InterfaceAlias "Ethernet0 2" -IPAddress $getIPAddress -DefaultGateway $getGateway -PrefixLength $MaskLength
    Set-DnsClientServerAddress -InterfaceAlias "Ethernet0 2" -ServerAddresses $getDNSServerList
    #wait a few seconds for IP change to take effect
    Start-Sleep 5
}


# 2. Check if this server is joined to the domain and move to the Servers OU if it is still in the default Computers container
$domainJoined=(Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
if ($domainJoined)
{
    $domainFQDN=(Get-WmiObject -Class Win32_ComputerSystem).Domain
    if ($domainFQDN -eq "genesco.local")
    {
        $computerOUCheck='*,CN=Computers,DC=genesco,DC=local'
        $serverOU="OU=Servers,DC=genesco,DC=local"
        $localGroupsOU="OU=ServerLocalGroups,OU=Groups,DC=genesco,DC=local"
        $domainShort="NT_GENESCO"
        $catchServer="P01-WI-ADC-01"

    }
    if ($domainFQDN -eq "gco.local")
    {
        $computerOUCheck='*,CN=Computers,DC=gco,DC=local'
        $serverOU="OU=Servers,OU=MIS,DC=gco,DC=local"
        $localGroupsOU="OU=ServerLocalGroups,OU=Groups,DC=gco,DC=local"
        $domainShort="GCO"
        $catchServer="P09-WI-ADC-01"
    }
    try
    {
        $thisComputer=Get-ADComputer $env:COMPUTERNAME
    }
    catch
    {
        $thisComputer=Get-ADComputer $env:COMPUTERNAME -server $catchServer
    }
    if($thisComputer.DistinguishedName -like $computerOUCheck)
    {
        Write-Host "Moving this computer to the Servers OU in AD..." -ForegroundColor Green
        Move-ADObject -Identity $thisComputer.ObjectGUID -TargetPath $serverOU
    }
    else
    {
        Write-Host "This computer was not in the default Computers OU, so we will not be moving it to the Servers OU." -ForegroundColor Yellow
    }
    #Since this is domain joined, now we are going to create the Local Administrative Groups 
    $adminGroup=$thisComputer.Name + "_Administrators"
    $remoteGroup=$thisComputer.Name + "_RemoteDesktopUsers"
    New-ADGroup -Name $adminGroup -SamAccountName $adminGroup -DisplayName $adminGroup -GroupCategory Security -GroupScope Global -Path $localGroupsOU
    New-ADGroup -Name $remoteGroup -SamAccountName $remoteGroup -DisplayName $remoteGroup -GroupCategory Security -GroupScope Global -Path $localGroupsOU
    Start-Sleep 5
    }
else
{
    Write-Host "This computer is not joined to the domain. If that is unexpected, you may need to perform that step later and move it to the correct OU." -ForegroundColor Red
}

# 3. Change the Network Location Awareness Service to Automatic (Delayed Start)
#get the current state of the service
$nlaSvc=Get-Service -Name NlaSvc | Select -property name,starttype
if ($nlaSvc.StartType -eq "Automatic")
{
    Write-Host "Changing the Network Location Awareness Service to Automatic Delayed Start..." -ForegroundColor Green
    sc.exe config NlaSvc start=delayed-auto
}


# 4. Prompt to set Windows Update schedule, if yes request day and time and then create the scheduled task
$scheduleWindowsUpdate=Read-Host "Would you like to configure a schedule for Windows Update to run (y/n)?"
if(($scheduleWindowsUpdate -eq "y") -or ($scheduleWindowsUpdate -eq "Y"))
{
    $dayToRun=Read-Host "Specify the day of the week to run the update (1=Sunday, 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday, 7=Saturday [default])"
    switch ($dayToRun)
    {
        "1" {$dayOfWeek="Sunday"; break}
        "2" {$dayOfWeek="Monday"; break}
        "3" {$dayOfWeek="Tuesday"; break}
        "4" {$dayOfWeek="Wednesday"; break}
        "5" {$dayOfWeek="Thursday"; break}
        "6" {$dayOfWeek="Friday"; break}
        "7" {$dayOfWeek="Saturday"; break}
        default {$dayOfWeek="Saturday"; break}
    }
    $timeToRun=Read-Host "Specify the time to run in 24 hour format (HH:MM)"

    $taskName="Scheduled Windows Update"
    $taskDescription="Scheduled Windows Update based on Maintenance Window"
    $action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -command "& Get-WUInstall -Install -AcceptAll -AutoReboot"'
    $trigger= New-ScheduledTaskTrigger -Weekly -DaysOfWeek $dayOfWeek -At $timeToRun
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description $taskDescription -User "System"
}


# 5. Install Alert Logic - prompt for target AL server
$installAlertLogic=Read-Host "Does Alert Logic need to be installed (y/n)?"
$waitForWinPcap=$false
if (($installAlertLogic -eq "y") -or ($installAlertLogic -eq "Y"))
{
    $alTargetAnswer=Read-Host "Which Alert Logic sensor host shoud be used (1 GPAB1 = 10.1.0.9   2 GPAB2 = 10.1.0.16  3 GPAB3 = 10.1.0.128  4 = GPAB4 = 10.1.0.132  5 = JDC  6 = Little Burgundy  7 = Chapel Hill  8 = Fayetteville  9 = 535)?"
    switch($alTargetAnswer)
    {
        "1" {$sensorHost="10.1.0.9"; break}
        "2" {$sensorHost="10.1.0.16"; break}
        "3" {$sensorHost="10.1.0.128"; break}
        "4" {$sensorHost="10.1.0.132"; break}
        "5" {$sensorHost="10.201.219.32"; break}
        "6" {$sensorHost="10.5.199.132"; break}
        "7" {$sensorHost="10.160.0.42"; break}
        "8" {$sensorHost="10.5.229.132"; break}
        "9" {$sensorHost="10.1.30.22.17"; break}
        default {$sensorHost="10.1.0.9"; break}
    } 
    $alertLogicPath = "\\nw01\NW01\Data\IS Security Compliance & Privacy\Latest Agents\Alert Logic\Windows\current windows agent\al_agent.msi"
        if (Test-Path $alertLogicPath) {
    Write-Host "Installing Alert Logic agent..." -ForegroundColor Green
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$alertLogicPath`" /passive /norestart /l*vx `"$env:Temp\al_agent_install.log`" PROV_KEY=48fc878ac574f6af6dce84ecc57969070be1d170e31a5fa3d1 REBOOT=ReallySuppress sensor_host=$sensorHost sensor_port=443" -Wait
        } else {
    Write-Host "Alert Logic MSI file not found at $alertLogicPath!" -ForegroundColor Red
    }

}

# 6. Install Rapid7 Agent 
$installRapid7=Read-Host "Does Rapid7 need to be installed (y/n)?"
if (($installRapid7 -eq "y") -or ($installRapid7 -eq "Y")) {
        $rapid7Path = "\\nw01\NW01\Data\IS Security Compliance & Privacy\Latest Agents\Rapid7\Windows\current windows agent\rapid7agent.msi"
        if (Test-Path $rapid7Path) {
            Write-Host "Installing Rapid7 agent..." -ForegroundColor Green
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$rapid7Path`" /l*v `"$env:Temp\insight_agent_install_log.log`" /quiet CUSTOMTOKEN=us:6c91926a-a42f-4f0c-8359-ddd67b784282" -Wait
        } else {
            Write-Host "Rapid7 MSI file not found at $rapid7Path!" -ForegroundColor Red
        }

}

# 7. Is .Net 3.5 Needed? If so, install
$installDotNet35=Read-Host "Has .Net 3.5 been requested for this server (y/n)?"
if (($installDotNet35 -eq "y") -or ($installDotNet35 -eq "Y"))
{
    Write-Host "We will attempt to install .Net 3.5..." -ForegroundColor Green
    Install-WindowsFeature -Name NET-Framework-Core -Source c:\Deploy\sxs
    Write-Host ".Net 3.5 feature should now be installed." -ForegroundColor White
}
# 8. Sometimes Win 2016 server network is broken after a restart, prompt for our work around script
write-host "Sometimes Windows Server 2016 or greater has issues with network failing to function correctly after a server restart. We have a script that can be scheduled to run after each restart to evaluate the network state and fix it when the server cannot reach the gateway." -ForegroundColor White 
$installNetworkCheck=Read-Host "Do you want to install the network restart workaround (y/n)?"
if (($installNetworkCheck -eq "y") -or ($installNetworkCheck -eq "Y"))
{
    $taskName="Genesco Network Test"
    $taskDescription="Checks to make sure network is functioning after restart"
    $action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -File c:\networkCheck.ps1'
    $trigger= New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description $taskDescription -User "System"

}

# 9. Install Cortex
$installCortex=Read-Host "Do you want to install Cortex (y/n)?"
if(($installCortex -eq "y") -or ($installCortex -eq "Y")) {
    $cortexPath = "\\nw01\NW01\Data\IS Security Compliance & Privacy\Latest Agents\Cortex XDR\windows\current windows agent\Cortex.msi"
    if (Test-Path $cortexPath) {
        Write-Host "Installing Cortex agent..." -ForegroundColor Green
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$cortexPath`" /quiet /norestart" -Wait
        Start-Sleep 10
    } else {
        Write-Host "Cortex MSI file not found at $cortexPath!" -ForegroundColor Red
    }
         Write-Host "Cortex MSI file not found at $cortexPath!" -ForegroundColor Red
    }



# 10. Install BigFix Agent

$installBFX=Read-Host "Do you want to the BigFix Agent (y/n)?"
if(($installBFX -eq "y") -or ($installBFX -eq "Y")){
    $BFXDMZ=Read-Host "Is this server in the DMZ (y/n)?"
    if(($BFXDMZ -eq "y") -or ($BFXDMZ -eq "Y")){ 
          Write-Host "Installing BigFix DMZ agent..."
          cd C:\Deploy\BigFix\Bigfix-Install-Package-Proxy\
          C:\Deploy\BigFix\Bigfix-Install-Package-Proxy\setup.exe /s /v" REBOOT=ReallySuppress MSIRESTARTMANAGERCONTROL=Disable /qn"
    }
    else
    {
        Write-Host "Installing BigFix agent..."
        C:\Deploy\BigFix\Bigfix-Install-Package\setup.exe /s /v" REBOOT=ReallySuppress MSIRESTARTMANAGERCONTROL=Disable /qn"
}
}

if($domainJoined)
{
    #Check for Admin and Remote Access Groups on Domain and then add to the corresponding local group
    If (Get-ADGroup $adminGroup)
    {
        Add-LocalGroupMember -Group "Administrators" -Member "$domainShort\$adminGroup"
    }
    Else
    {
        write-host "Could not locate the AD Group $adminGroup to add it to the local administrators group." -ForegroundColor Red
    }
    If (Get-ADGroup $remoteGroup)
    {
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member "$domainShort\$remoteGroup"
    }
    else
    {
        write-host "Could not locate the AD Group $remoteGroup to add it to the local remote desktop users group." -ForegroundColor Red
    }
}
# 10. Cleanup - Delete the c:\Deploy folder if requested
$cleanupDeployFolder=Read-Host "Would you like to remove the c:\Deploy folder and its contents (y/n)?"
if (($cleanupDeployFolder -eq "y") -or ($cleanupDeployFolder -eq "Y"))
{
    #need to check for anything that would block the folder deletion like WinPCap install in background
    if ($waitForWinPcap)
    {
        while ($waitForWinPcap -eq $true)
        {
            $wpcapInstalled=((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall")|Where-Object {$_.GetValue( "DisplayName" ) -like "Npcap*" }).Length -gt 0
            if ($wpcapInstalled)
            {
                $waitForWinPcap=$false
            }
            else
            {
                write-host "Waiting for WinPcap Installation that is part of Alert Logic to complete..." -ForegroundColor Gray
                write-host "We will check again in 15 seconds." -ForegroundColor Gray
                Start-Sleep 15
            }
        }
    }
    cd c:\
    Remove-Item c:\Deploy -Force -Recurse -Confirm:$false
}

