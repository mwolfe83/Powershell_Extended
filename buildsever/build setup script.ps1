$newServerName = "p01-wa-prnt-01"
$operatingSystem = "Windows Server 2022"
$networkLocation = "Corporate LAN"
$numCPU = 2
$memoryGB = 8
$HD1sizeGB = 120
$serverOwner = "Platform Systems"
$appName = "Print Server"
$environment = "Production"
$maintenanceDay = "Saturday"
$maintenanceStartTime = "01:00"
& "$PSScriptRoot\buildVMfromTemplate.ps1" -newServerName $newServerName -OperatingSystem $operatingSystem -networkLocation $networkLocation -numCPU $numCPU -memoryGB $memoryGB -HD1sizeGB $HD1sizeGB -serverOwner $serverOwner -appName $appName -environment $environment -maintenanceDay $maintenanceDay -maintenanceStartTime $maintenanceStartTime