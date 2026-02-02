# Prompt user for Division, Country, and Store Number
$division = Read-Host "Enter the Division code (JY/JK/US/LB/JM)"
$country = Read-Host "Enter the Country code (e.g., US, CA, UK)"
$storeNumber = Read-Host "Enter the Store Number"

# Define SolarWinds connection details
$SolarWindsServer = 'p01-wa-sol-01.genesco.local'
$solarWindsUsername = 'solarwinds_poller'
$PasswordstateUrl = 'https://pwstate.genesco.local/api/passwords/4256'
$apiKey = 'afc6e4b2338d957a9352bd38c4f76ee2'

# Fetch SolarWinds password
$response = Invoke-RestMethod -Method GET -Uri $PasswordstateUrl -Header @{ "APIKey" = $apiKey }
$solarwindsPassword = $response.password

# Connect to SolarWinds API
$swis = Connect-Swis -Hostname $SolarWindsServer -Username $solarWindsUsername -Password $solarwindsPassword
if (-not $swis) {
    Write-Host "Failed to connect to SolarWinds. Please check your credentials and server details."
    return
}

# Construct group name based on Division, Country, and Store Number
$groupName = "$division$country$($storeNumber.PadLeft(4, '0'))"


# Function to delete nodes in a group and then the group
function Delete-SolarWindsNodesAndGroup {
    param (
        [string]$groupName,
        [object]$swis
    )

    try {
        # Get the group ID
        $groupId = Get-SwisData $swis "SELECT ContainerID FROM Orion.Container WHERE Name = '$groupName'"
        if (-not $groupId) {
            Write-Host "Group '$groupName' not found."
            return
        }

        # Ensure $groupId is a single value
        if ($groupId.Count -gt 1) {
            Write-Host "Multiple group IDs found. Using the first one."
            $groupId = $groupId[0]
        } elseif ($groupId.Count -eq 0) {
            Write-Host "Group '$groupName' not found."
            return
        }

        # Get all nodes associated with the group
        $nodeIds = Get-SwisData $swis "SELECT Nodes.NodeID FROM Orion.ContainerMembers AS Members JOIN Orion.Nodes AS Nodes ON Members.MemberPrimaryID = Nodes.NodeID WHERE Members.ContainerID = $groupId"

        # Delete nodes
        foreach ($nodeId in $nodeIds) {
            $nodeUri = "swis://$SolarWindsServer/Orion/Orion.Nodes/NodeID=$nodeId"
            Remove-SwisObject -SwisConnection $swis -Uri $nodeUri
            Write-Host "Node with ID $nodeId deleted."
        }

        # Delete the group using Orion.Container.DeleteContainer verb
        Invoke-SwisVerb -SwisConnection $swis "Orion.Container" "DeleteContainer" @($groupId) | Out-Null

        Write-Host "Group '$groupName' deleted."

    } catch {
        Write-Host "Error: $_"
    }
}

# Call the function to delete nodes and the group
Delete-SolarWindsNodesAndGroup -groupName $groupName -swis $swis
