# ------------- CONNECT TO SWIS ------------- #

# Import the SwisPowerShell module if not already loaded
if (-not (Get-Module -Name SwisPowerShell -ListAvailable)) {
    Import-Module SwisPowerShell
}

# Define target host and credentials
$SolarWindsServer = 'p01-wa-sol-01.genesco.local'
$solarwindsUsername = 'solarwinds_poller'
$solarwindsPassword = '&Uqih%5Uowd@^8B@'

# SNMP Credentials
$SNMPv3Username = 'genesco'
$SNMPv3Password = 'Genesco123'

# Create a connection to the SolarWinds API
$Swis = Connect-Swis -Hostname $SolarWindsServer -Username $solarwindsusername -password $solarwindsPassword

# Load group information from CSV
$groupInfo = Import-Csv -Path "$PSScriptRoot\groups.csv"

# Loop through each group in the CSV file
foreach ($group in $groupInfo) {
    try {
        # Extract group details from CSV
        $groupName = $group.Name
        $parentGroupName = $group.ParentGroupName  # Assuming you have a column for ParentGroupName in the CSV

        # Output debugging information
        Write-Host "Moving group '$groupName' under '$parentGroupName'"

        # Get the group ID of the parent group
        $parentGroupId = Get-SwisData $swis "SELECT ContainerID FROM Orion.Container WHERE Container.Name = '$parentGroupName'"
        Write-Host "Parent GroupID: $parentGroupId "
        if (-not $parentGroupId) {
            Write-Host "Parent group '$parentGroupName' not found."
            continue
        }

        # Get the group ID of the group to be moved
        $groupId = Get-SwisData $swis "SELECT ContainerID FROM Orion.Container WHERE Container.Name = '$groupName'"
        Write-Host "Group ID: $groupId"
        if (-not $groupId) {
            Write-Host "Group '$groupName' not found."
            continue
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
            $parentgroupId,

            # group member to add
            ([xml]$definitionXml).DocumentElement
        ) | Out-Null 

    } catch {
        # Handle any errors that occur during the process
        Write-Host "Error: $_"
    }
}

# Disconnect from the SolarWinds API if the connection is valid
if ($swis) {
    $swis.Dispose()
}
