



Param(
    [Parameter (Mandatory=$true)][ValidateLength(1,15)][string]$newServerName,
    [Parameter (Mandatory=$true)][string]$operatingSystem,
    [Parameter (Mandatory=$true)][string]$networkLocation,
    [Parameter (Mandatory=$false)][ValidateRange(1,16)][Int] $numCPU,
    [Parameter (Mandatory=$false)][ValidateRange(1,64)][Int] $memoryGB,
    [Parameter (Mandatory=$false)][ValidateRange(0,2048)][Int] $HD1sizeGB,
    [Parameter (Mandatory=$false)][ValidateRange(0,2048)][Int] $HD2sizeGB,
    [Parameter (Mandatory=$false)][string] $serverOwner,
    [Parameter (Mandatory=$false)][string] $appName,
    [Parameter (Mandatory=$false)][string] $environment,
    [Parameter (Mandatory=$false)][string] $maintenanceDay,
    [Parameter (Mandatory=$false)][string] $maintenanceStartTime
)
switch ($networkLocation)
{
   "Corporate LAN" {$clusterName="CoLo-Win";$osCustomizationName="Server2016-svcVMdomainJoin";$folderName="Staging";$guestUser=".\addministrator";$changeNetwork=$false; break}
   "CDE" {$clusterName="CoLo_PCI";$osCustomizationName="WindowsGCO-svccvmdomainjoingco";$folderName="CDEStaging"; $guestUser=".\addministrator";$changeNetwork=$true; $newNetworkName="PCINetwork"; break}
   "DMZ" {$clusterName="CoLo-Win";$osCustomizationName="WindowsDMZ-nojoin";$folderName="Staging"; $guestUser=".\administrator"; $changeNetwork=$true; $newNetworkName="Secure_DMZ_131";break}
   default {$clusterName="CoLo-Win";$osCustomizationName="Server2016-svcVMdomainJoin";$folderName="Staging"; $guestUser=".\addministrator"; $changeNetwork=$false; break}
}
switch ($operatingSystem)
{
    "Windows Server 2022" {$sourceVM="WIN2022GUITemplate";break}
    "Windows Server 2019" {$sourceVM="WIN2019GUITemplate";break}
    "Windows Server 2016" {$sourceVM="WIN2016 GUI Template";break}
    default {$sourceVM="WIN2019GUITemplate";break}
}

switch ($environment)
{
    "Development" {$resourcePoolName = "Non-Production";break}
    "QA" {$resourcePoolName = "Non-Production";break}
    "Proof of Concept" {$resourcePoolName = "Non-Production";break}
    "Production" {$resourcePoolName = "Production";break}
    default {$resourcePoolName = "Resources";break}
}


if ($networkLocation -eq "CDE")
{
    $resourcePoolName="Resources"
}

#Production system on CoLo-Win
if (($environment -eq "Production") -and ($clusterName -eq "CoLo-Win"))
{
    if ($newServerName -ilike 'P01-WC-*')
    {
        $storageFolder="CitrixStorage"
    }
    else
    {
        $storageFolder="ProductionStorage"
    }
}

#NonProduction system on CoLo-Win
if (($environment -ne "Production") -and ($clusterName -eq "CoLo-Win"))
{
    if ($newServerName -ilike '*01-WC-*')
    {
        $storageFolder="CitrixStorage"
    }
    else
    {
        $storageFolder="NonProductionStorage"
    }
}

#CDE only has one storage folder to pick from
if ($clusterName -eq "CoLo_PCI")
{
    $storageFolder="CDEStorage"
}

$resizeDrive1=$false
#Normalize any input hard drive sizes based on OS, default values are zero
if (($HD1sizeGB -le 60) -and (($operatingSystem -eq "Windows Server 2016") -or ($operatingSystem -eq "Windows Server 2019")))
{
    #requested HD size is less than base hard drive normalize to standard size
    $HD1sizeGBcheck=60
}
if (($HD1sizeGB -gt 60) -and (($operatingSystem -eq "Windows Server 2016") -or ($operatingSystem -eq "Windows Server 2019")))
{
    #requested HD size is more than base hard drive
    $HD1sizeGBcheck=$HD1sizeGB
    $resizeDrive1=$true
}

$sizeCheckGB = $HD1sizeGBcheck + $HD2sizeGB

# At this point necessary logic has been applied to get the VM general destination figured out
# Now we need to connect to vCenter and determine more specifics such as disk requirements to choose the right datastore
# based on the cluster the VM will run on
# for now we will prompt for credentials
$vCenterConnection=Connect-VIserver -server GPPAVCSAPR1.genesco.local

#choose a backup group
#Get list of VMs in the Cluster
$annotatedList=@()
foreach ($vmview in (get-view -ViewType VirtualMachine))
{
    $vmCheck =  New-Object PsObject
    Add-Member -InputObject $vmCheck -MemberType NoteProperty -Name VM -Value $vmview.Name
    Add-Member -InputObject $vmCheck -MemberType NoteProperty -Name BackupGroup -Value ($vmview.Summary.CustomValue|Where-Object Key -eq 202).value
    $annotatedList+=$vmCheck
}

# Get the VM count per backup group
$backupGroups=@()
if ($environment -eq "Production")
{
    #PW1 Through PW7
    for ($i=1;$i -le 7;$i++)
    {
        $checkValue = "PW$i"
        $objBkgroup= New-Object PsObject
        Add-Member -InputObject $objBkgroup -MemberType NoteProperty -Name BackupGroup -Value $checkValue
        Add-Member -InputObject $objBkgroup -MemberType NoteProperty -Name Count -Value ($annotatedList|Where-Object BackupGroup -eq $checkValue).Count
        $backupGroups+=$objBkgroup

    }
}
else
{
    #non production backup groups
    #NW1
    $objBkgroup= New-Object PsObject
    Add-Member -InputObject $objBkgroup -MemberType NoteProperty -Name BackupGroup -Value "NW1"
    Add-Member -InputObject $objBkgroup -MemberType NoteProperty -Name Count -Value ($annotatedList|Where-Object BackupGroup -eq "NW1").Count
    $backupGroups+=$objBkgroup
    #NW2
    $objBkgroup= New-Object PsObject
    Add-Member -InputObject $objBkgroup -MemberType NoteProperty -Name BackupGroup -Value "NW2"
    Add-Member -InputObject $objBkgroup -MemberType NoteProperty -Name Count -Value ($annotatedList|Where-Object BackupGroup -eq "NW2").Count
    $backupGroups+=$objBkgroup
}
$sortedGroups=$backupGroups|Sort-Object Count,BackupGroup
$targetBackupGroup=$sortedGroups[0].BackupGroup


#get the available datastores
$datastores=Get-Datastore -Location $storageFolder
$storageObj=@()
foreach ($datastore in $datastores)
{
    $tmpObj = New-Object -TypeName psobject
    $tmpObj | Add-Member -MemberType NoteProperty -Name Name -Value $datastore.Name
    $tmpObj | Add-Member -MemberType NoteProperty -Name FreeSpaceGB -Value $datastore.FreeSpaceGB
    $tmpObj | Add-Member -MemberType NoteProperty -Name CapacityGB -Value $datastore.CapacityGB
    $tmpObj | Add-Member -MemberType NoteProperty -Name FreePercentage -Value ($datastore.FreeSpaceGB / $datastore.CapacityGB * 100)
    $storageObj+=$tmpObj
}
$storageSorted=$storageObj | Sort-Object FreePercentage -Descending
$storageSelected=$false
$i=0
while (($storageSelected -ne $true) -and ($i -lt $storageSorted.count))
{
    #find a datstore with sufficient free space to accommodate the VM request
    if ($storageSorted[$i].FreeSpaceGB -gt $sizeCheckGB)
    {
        $storageSelected=$true
        $chosenStorageName = $storageSorted[$i].Name
        $targetStorage = $storageSorted[$i]
    }
    $i++
}

if ($storageSelected)
{
    #build the VM
    write-host "VM will be provisioned on Datastore $chosenStorageName." -ForegroundColor Green
    #$resourcePool=Get-ResourcePool -Location $clusterName -Name $resourcePoolName
    $targetStorage=Get-Datastore -Location $storageFolder -Name $chosenStorageName
    $provisionStartTime=Get-Date

    $colohosts = Get-Cluster -Name $clusterName | Get-VMHost
    $esxhost = $colohosts | Get-Random
    
    $newVMStep=New-VM -Name $newServerName -VM $sourceVM -OSCustomizationSpec $osCustomizationName -Datastore $targetStorage -Location $folderName -VMHost $esxhost #-ResourcePool $resourcePool 
    #get current VM hardware info
    $vm=Get-VM -Name $newServerName
    $customizeCPUMem=$false
    #build hardware customization command
    $hwCustomCmd= "Get-VM -Name $newServerName | Set-VM"
    if ($vm.MemoryGB -ne $memoryGB)
    {
        $hwCustomCmd+=" -MemoryGB $memoryGB"
        $customizeCPUMem=$true
    }
    if ($vm.NumCpu -ne $numCPU)
    {
        $hwCustomCmd+=" -NumCpu $numCPU"
        $customizeCPUMem=$true
    }
    $hwCustomCmd+=" -Confirm:0"
    if ($customizeCPUMem)
    {
        #apply Hardware customization
        $customizeCPUMemStep=Invoke-Expression $hwCustomCmd
    }
    #If needed, resize Hard Disk 1
    if ($resizeDrive1)
    {
        $resizeDrive1Step=Get-HardDisk -vm $vm -Name "Hard disk 1" | Set-HardDisk -CapacityGB $HD1sizeGB -Confirm:$false
    }
    #If needed, add Hard Disk 2
    if ($HD2sizeGB -gt 0)
    {
        $addHDStep=New-HardDisk -VM $vm -CapacityGB $HD2sizeGB -Confirm:$false
    }
    #if needed change the network that the VM is connected to.
    if ($changeNetwork)
    {
        $changeNetworkStep=Get-NetworkAdapter -VM $vm -Name "Network adapter 1" | Set-NetworkAdapter -NetworkName $newNetworkName -Confirm:$false
    }
    #set the backup group
    $vm | Set-Annotation -CustomAttribute "BackupGroup" -Value $targetBackupGroup
    #update custom properties if provided
    if($serverOwner -ne "")
    {
        $vm | Set-Annotation -CustomAttribute "1 Owner" -Value $serverOwner
    }
    if($appName -ne "")
    {
         $vm | Set-Annotation -CustomAttribute "2 Application" -Value $appName
    }
    if ($maintenanceDay -ne "")
    {
        $vm | Set-Annotation -CustomAttribute "MaintenanceDay" -Value $maintenanceDay
    }
    if ($maintenanceStartTime -ne "")
    {
        $vm | Set-Annotation -CustomAttribute "MaintenanceTime" -Value $maintenanceStartTime
    }
    $startVMstep=Start-VM -VM $vm
    write-host "Waiting for VM to boot..." 
    Start-Sleep -Seconds 25
    $waitForTools=Wait-Tools -VM $vm -TimeoutSeconds 300
    write-host "VM has booted and VM Tools should be running. We will wait for the VM OS customization to complete. This can take a few minutes..."
    Start-Sleep -Seconds 60
    $customizationComplete=$false
    $checkName=$vm.Name + "*"
    While ($customizationComplete -ne $true)
    {
        $vmGuestInfo=Get-VMGuest -VM $vm
        if ($vmGuestInfo.Hostname -like $checkName)
        {
            $customizationComplete=$true
        }
        else
        {
            Start-Sleep -Seconds 5
        }
    }
    write-host "VM OS Customization is complete. We will now perform any disk resize and relettering tasks that are needed."
    
    Write-Host "Changing the CD/DVD drive letter to e:.." -ForegroundColor Green
    $reletterCmd='Get-WmiObject -Class Win32_Volume -Filter "DriveType=5"|Set-WmiInstance -Arguments @{DriveLetter="E:"}'
    Try
    {
        Invoke-VMScript -VM $vm -ScriptType Powershell -ScriptText $reletterCmd -GuestUser $guestUser -GuestPassword T3h3wd98hd94094q53e!
    }
    Catch
    {
        write-host "Sometimes the first execution fails, we will retry." -ForegroundColor Yellow
        Start-Sleep 5
        Invoke-VMScript -VM $vm -ScriptType Powershell -ScriptText $reletterCmd -GuestUser $guestUser -GuestPassword T3h3wd98hd94094q53e!
    }

    #If needed, resize c partition
    if ($resizeDrive1)
    {
        write-host "Since the first hard drive was enlarged beyond the default, we will now expand the c: partition..." -ForegroundColor Green
        $resizeDriveCmd='$size=(Get-Partition | Where-Object DriveLetter -eq C | Get-PartitionSupportedSize).SizeMax;
                         Resize-Partition -DriveLetter C -Size $size;
                         write-host "C: drive has been expanded to maximum size."'
        Invoke-VMScript -VM $vm -ScriptText $resizeDriveCmd -ScriptType Powershell -GuestUser $guestUser -GuestPassword T3h3wd98hd94094q53e!
    }
    
    
    #if a second hard drive was added, lets partition and format GPT
    if ($HD2sizeGB -gt 0)
    {
        $formatDcmd='Get-Disk|Where-Object PartitionStyle -eq "RAW" | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -DriveLetter D -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel “Data” -Confirm:$false'
        write-host "Since a second hard drive was added, we will now initialize and format as GPT partition for drive d:." -ForegroundColor Green
        write-host "Pausing for 20 seconds to allow time for the previous drive letter change for the CD/DVD to clear the availablity of letter D." -ForegroundColor White
        Start-Sleep -Seconds 20
        Invoke-VMScript -VM $vm -ScriptType Powershell -ScriptText $formatDcmd -GuestUser $guestUser -GuestPassword T3h3wd98hd94094q53e!
    }
    write-host "VM creation and customization has completed." -ForegroundColor Green
    #restart the VM since we have the default administrator account logged in
    write-host "Restarting the VM to prepare for first normal login. Once the reboot is complete you may login to perform any other preparation needed." -ForegroundColor Green
    $restartVM=Restart-VMGuest -VM $vm -Confirm:$false
    $totalProvisionTime= "{0:n2}" -f ((Get-Date) - $provisionStartTime).TotalMinutes
    write-host "It took $totalProvisionTime minutes to provision the VM."
}
else
{
    write-host "No datastore in the class needed by the VM has sufficient free space. The VM will not be provisioned. You may need to provision additional storage." -ForegroundColor Red
}
#Disconnect from vCenter
$vCenterConnection|Disconnect-VIserver -Confirm:$false