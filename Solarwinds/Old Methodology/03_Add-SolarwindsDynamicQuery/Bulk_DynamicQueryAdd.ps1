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
# Iterate through each group in the CSV
$groupInfo = Import-Csv -Path "$psscriptroot\dynamicgroups.csv"

Write-Output "entering foreach loop"
foreach ($group in $groupInfo) {
    $parentGroupName = $group.ParentGroupName
    Write-Output "Parent Group Name: $parentGroupName"
    $subGroupName = $group.SubGroupName
    Write-Output "Sub Group Name: $subGroupName"
    $groupName = $group.Name
    Write-Output "Group Name: $groupName"
 
    Write-Output "Processing group: $groupName"

    # Get the group ID of the parent group
    $parentGroupId = Get-SwisData $swis "SELECT ContainerID FROM Orion.Container WHERE Container.Name = '$parentGroupName'"
    Write-Host "Parent GroupID: $parentGroupId "
    if (-not $parentGroupId) {
        Write-Host "Parent group '$parentGroupName' not found."
        continue
    }

    # Get the group ID of the sub group
    $subGroupId = Get-SwisData $swis "SELECT ContainerID FROM Orion.Container WHERE Container.Name = '$subGroupName'"
    Write-Host "Sub GroupID: $subGroupId "
    if (-not $subGroupId) {
        Write-Host "Sub group '$subGroupName' not found."
        continue
    }

    # Get the group ID of the main group
    $GroupId = Get-SwisData $swis "SELECT ContainerID FROM Orion.Container WHERE Container.Name = '$groupName'"
    Write-Host "GroupID: $GroupId "
    if (-not $GroupId) {
        Write-Host "Group '$GroupName' not found."
        continue
    }

    # Construct dynamic query
    #$query = "IP_Address LIKE '$ipPrefix'"
    #Write-Output "Dynamic Query: $query"

    # Check if the group already exists
    if ($groupname -ne $null) {
        Write-Output "Creating dynamic query for subgroup: $groupName"

        # Creating dynamic queries to populate group
        $members = @(
            @{
                Name = "Site_$Groupname"
                Definition = "filter:/Orion.Nodes[CustomProperties.Site='$($groupName)']"
            }
        )

        # Invoke the AddDefinitions verb to add member definitions to the group
        Invoke-SwisVerb $swis "Orion.Container" "AddDefinitions" @(
            $GroupId, # group ID
            ([xml]@(
                "<ArrayOfMemberDefinitionInfo xmlns='http://schemas.solarwinds.com/2008/Orion'>",
                [string]($members | % {
                        "<MemberDefinitionInfo><Name>$($_.Name)</Name><Definition>$($_.Definition)</Definition></MemberDefinitionInfo>"
                    }
                ),
                "</ArrayOfMemberDefinitionInfo>"
            )).DocumentElement
        ) | Out-Null

        Write-Output "Dynamic query created for subgroup: $groupName"
    }
}
