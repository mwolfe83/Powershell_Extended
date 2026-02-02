# Prompt user for questions
$division = Read-Host "Enter the Division code (JY/JK/US/LB/JM)"
$country = Read-Host "Enter the Country code (US/CA/PR)"
$storeNumber = Read-Host "Enter the Store Number"
$storeName = Read-Host "Enter the Store Name"
$state = Read-Host "Enter the State"
$registers = Read-Host "Enter number of registers"
$setupSolarWinds = Read-Host "Would you like to create a SolarWinds Monitor? Y/N"

# Function to setup SolarWinds
function Setup-SolarWinds {
    param (
        [string]$division,
        [string]$country,
        [string]$storeNumber,
        [string]$state,
        [string]$storeName,
        [string]$setupSolarWinds,
        [int]$registers
    )

    # Prompt user if they want to set up SolarWinds
    if ($setupSolarWinds -eq "Y" -or $setupSolarWinds -eq "y") {
        # Placeholder for SolarWinds setup
        Write-Host "Placeholder for SolarWinds setup script..."

        # Define target host and credentials
        $SolarWindsServer = 'p01-wa-sol-01.genesco.local'
        $solarWindsUsername = 'solarwinds_poller'
        $solarWindsPassword = '&Uqih%5Uowd@^8B@'

        # Create a connection to the SolarWinds API
        $swis = Connect-Swis -Hostname $SolarWindsServer -Username $solarWindsUsername -Password $solarWindsPassword

        Create-SolarWindsGroup -division $division -country $country -storeNumber $storeNumber -state $state -swis $swis -registers $registers
        
    }
    else {
        Write-Host "SolarWinds setup skipped."
    }
}
function Create-SolarWindsGroup {
    param (
        [string]$division,
        [string]$country,
        [string]$storeNumber,
        [string]$state,
        [object]$swis,
        [int]$registers
    )

    write-host "List of Variables Division $division Country $country Store Number $storeNumber State $state Swis $swis"
    # Construct group name and description
    $groupName = "$division$country$($storeNumber.PadLeft(4, '0'))"

    switch ($division) {
        "JY" { $fulldivision = "Journeys" }
        "JK" { $fulldivision = "Journeys Kids" }
        "UG" { $fulldivision = "Journeys Underground" }
        "LB" { $fulldivision = "Little Burgundy" }
        "JM" { $fulldivision = "J&M" }
        default { $fulldivision = "Unknown Division" }  # Optional: handle unexpected values
    }

    $groupDescription = "$division$country - $state"
    $parentgroupname = "$division$country - $state"

    # Check if the group already exists
    $groupExists = $false  # Assume group doesn't exist initially

    try {
        $existingGroup = Get-SwisData $swis "SELECT ContainerID FROM Orion.Container WHERE Name = '$groupName'"
        if ($existingGroup) {
            $groupExists = $true
            Write-Host "Group '$groupName' already exists. Skipping creation."
            continue
        }
    }
    catch {
        Write-Host "Error checking group existence: $_"
    }

    if (-not $groupExists) {
        # Construct the members as XML (currently empty as per your example)
        $membersXml = @"
<ArrayOfMemberDefinitionInfo xmlns='http://schemas.solarwinds.com/2008/Orion'>
</ArrayOfMemberDefinitionInfo>
"@

        # Output debugging information
        Write-Host "Creating group with name: '$groupName', description: '$groupDescription', refresh frequency: 60, polling enabled: True"

        # Invoke the CreateContainer verb
        $groupId = (Invoke-SwisVerb $swis "Orion.Container" "CreateContainer" @(
            $groupName,
            "Core",
            60,  # Refresh frequency
            0,   # Parent container ID (if any)
            $groupDescription,
            $true,  # Polling enabled
            ([xml]$membersXml).DocumentElement
        )).InnerText

        # Output debugging information
        Write-Host "Group '$groupName' created with ID: $groupId"
        Nest-SolarwindsGroup -division $division -country $country -storeNumber $storeNumber -state $state -swis $swis -fulldivision $fulldivision -groupname $groupname -parentgroupname $parentgroupname -registers $registers
    }
}
function Nest-SolarwindsGroup {
    param (
        [string]$division,
        [string]$country,
        [string]$storeNumber,
        [string]$state,
        [string]$fulldivision,
        [string]$groupName,
        [string]$parentGroupName,
        [object]$swis,
        [int]$registers
    )

    try {
        # Output debugging information
        Write-Host "Moving group '$groupName' under '$parentGroupName'"

        # Get the group ID of the parent group
        $parentGroupId = Get-SwisData $swis "SELECT ContainerID FROM Orion.Container WHERE Container.Name = '$parentGroupName'"
        Write-Host "Parent GroupID: $parentGroupId "
        if (-not $parentGroupId) {
            Write-Host "Parent group '$parentGroupName' not found."
            return
        }

        # Get the group ID of the group to be moved
        $groupId = Get-SwisData $swis "SELECT ContainerID FROM Orion.Container WHERE Container.Name = '$groupName'"
        Write-Host "Group ID: $groupId"
        if (-not $groupId) {
            Write-Host "Group '$groupName' not found."
            return
        }

        $subgroupUri = Get-SwisData $swis "SELECT Uri FROM Orion.Container WHERE ContainerID=@id" @{ id = $groupId }

        $definitionXml = @"
        <MemberDefinitionInfo xmlns='http://schemas.solarwinds.com/2008/Orion'>
        <Name>$groupName</Name>
        <Definition>$subgroupUri</Definition>
        </MemberDefinitionInfo>
"@

        Write-Host "Definition XML: $definitionXml"

        Invoke-SwisVerb $swis "Orion.Container" "AddDefinition" @(
            # Parent group ID
            $parentGroupId,

            # Group member to add
            ([xml]$definitionXml).DocumentElement
        ) | Out-Null 

    } catch {
        # Handle any errors that occur during the process
        Write-Host "Error: $_"
    }

    Create-Solarwinds-Node -division $division -country $country -storeNumber $storeNumber -state $state -swis $swis -fulldivision $fulldivision -groupname $groupname -parentgroupname $parentgroupname -registers $registers
}
function Create-Solarwinds-Node {
    param (
        [string]$division,
        [string]$country,
        [string]$storeNumber,
        [string]$state,
        [string]$fulldivision,
        [string]$groupName,
        [string]$parentGroupName,
        [object]$swis,
        [int]$registers  # Number of registers

    )

    $site = "$division$country$storeNumber"
    $stakeholder = 'Store Devices'
    $environment = 'Prod'
    $SNMPv3Username = 'genesco'
    $SNMPv3Password = 'Genesco123'
    $SNMPV3PrivKey = 'Genesco123'
    if (-not $division -or -not $country -or -not $storeNumber -or -not $state -or -not $fulldivision -or -not $groupName -or -not $parentGroupName -or -not $registers) {
        throw "All parameters must be provided"
    }

    $divisionshort = "$division$country"
    
    switch ($divisionshort) {
        "UGUS" { $storecode = "s01" }
        "JKUS" { $storecode = "s05" }
        "JMUS" { $storecode = "s07" }
        "JYUS" { $storecode = "s08" }
        "LBCA" { $storecode = "s43" }
        "JMCA" { $storecode = "s73" }
        "JYCA" { $storecode = "s83" }
        default { $storecode = "Unknown Division" }  # Optional: handle unexpected values
    }

    if ($storecode -eq "Unknown Division") {
        throw "Invalid division and country combination"
    }

    $nodenameprefix = "$storecode$storeNumber"

    function klep_guid($ip)
