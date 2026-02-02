# Prompt user for questions
$division = Read-Host "Enter the Division code (JY/JK/US/LB/JM)"
$country = Read-Host "Enter the Country code (US/CA/PR)"
$storeNumber = Read-Host "Enter the Store Number"
$storeName = Read-Host "Enter the Store Name"
$state = Read-Host "Enter the State"
$registers = Read-Host "Enter number of registers"
$setupSolarWinds = Read-Host "Would you like to create a SolarWinds Monitor? Y/N"

# Define the global variable for TemplateID
$global:TemplateID = 670


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

        $SolarWindsServer = 'p01-wa-sol-01.genesco.local'
        $solarWindsUsername = 'solarwinds_poller'
        $PasswordstateUrl = 'https://pwstate.genesco.local/api/passwords/4256'
        $apiKey = 'afc6e4b2338d957a9352bd38c4f76ee2'
        $response = Invoke-RestMethod -Method GET -Uri $PasswordstateUrl -Header @{ "APIKey" = $apiKey }
        $solarwindsPassword = $response.password
        # Create a connection to the SolarWinds API

        $swis = Connect-Swis -Hostname $SolarWindsServer -Username $solarWindsUsername -Password $solarWindsPassword
        if (-not $swis) {
            Write-Host "Failed to connect to SolarWinds. Please check your credentials and server details."
            return
        }
        
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

    function klep_guid($ip) {
        $ipParts = $ip.Split('.')
        if ($ipParts.Length -ne 4) {
            throw "Invalid IP address format"
        }
        $ipHex = ($ipParts | ForEach-Object { '{0:X2}' -f [int]$_ }) -join ''
        $guidString = "$ipHex-0000-0000-0000-000000000000"
        return [guid]::Parse($guidString)
    }

    for ($i = 1; $i -le $registers; $i++) {
        $nodeName = "$nodenameprefix-$i"
        $ipAddress = "10.$($storeNumber.Substring(0, 2)).$($storeNumber.Substring(2, 2)).$([int]$i + 68)"
        $snmpPort = 161
        $snmpVersion = 3
        Write-Host "IP Address: $ipAddress"

        try {
            $NodeProperties = @{
                IPAddress = $ipAddress
                Caption = $nodeName
                NodeDescription = $state
                IPAddressGUID = klep_guid($ipAddress)
                Status = 1
                Unmanaged = $false
                Allow64BitCounters = $true
                sysObjectID = ''
                StatCollection = 10
                EngineID = 2
                ObjectSubType = 'SNMP'
                SysName = $nodeName
                SNMPv3Username = $SNMPv3Username
                SNMPV3PrivKey = $SNMPv3Password
                SNMPV3PrivMethod = 'AES128'
                snmpv3AuthKey = $SNMPv3Password
                snmpv3AuthMethod = "SHA1"
                SNMPVersion = 3
                SNMPV3PrivKeyisPwd = $true
                snmpv3AuthKeyIsPwd = $true
            }

            $NewNodeUri = New-SwisObject -SwisConnection $swis -EntityType 'Orion.Nodes' -Properties $NodeProperties

            # Add custom properties to the newly created node
            $CustomProperties = @{
                Site = $site
                Stakeholder = $stakeholder
                Environment = $environment
            }
            Set-SwisObject -SwisConnection $swis -Uri ($NewNodeUri + "/CustomProperties") -Properties $CustomProperties
            Write-Host "Node $nodeName added successfully with custom properties (Site and Stakeholder)."

        } catch {
            Write-Host "Failed to create node '$nodeName': $_"
            continue
        }

        Write-Host "Node '$nodeName' created with IP address '$ipAddress'"

        $nodeId = Get-SwisData $swis "SELECT NodeID FROM Orion.Nodes WHERE IPAddress = '$ipAddress'"
        if (-not $nodeId) {
            Write-Host "Failed to retrieve NodeID for node '$nodeName'. Skipping node addition to group."
            continue
        }

        $nodeUri = "swis://P01-WA-SOL-01.genesco.local/Orion/Orion.Nodes/NodeID=$nodeId"
        
        $groupId = Get-SwisData $swis "SELECT ContainerID FROM Orion.Container WHERE Name=@name" @{ name = $groupName }
        if (-not $groupId) {
            Write-Host "Group '$groupName' not found. Skipping node addition to group."
            continue
        }

        $groupUri = Get-SwisData $swis "SELECT Uri FROM Orion.Container WHERE ContainerID=@id" @{ id = $groupId }

        $definitionXml = @"
<MemberDefinitionInfo xmlns='http://schemas.solarwinds.com/2008/Orion'>
    <Name>$nodeName</Name>
    <Definition>$nodeUri</Definition>
</MemberDefinitionInfo>
"@

    Run-SolarwindsListResources -ipaddress $ipAddress -division $divsion -country $country -storeNumber $storeNumber -state $state -fulldivision $fulldivision -groupname $groupName -parentgroupname $parentGroupName -swis $swis -registers $registers
        }
    Add-SolarwindsDynamicQuery -division $divsion -country $country -storeNumber $storeNumber -state $state -fulldivision $fulldivision -groupname $groupName -parentgroupname $parentGroupName -swis $swis -registers $registers
}
function Add-SolarwindsDynamicQuery {
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
        
                try {
                $parentGroupName = "$fulldivision - $country"
                Write-Output "Parent Group Name: $parentGroupName"
                $subGroupName = $parentgroupname
                Write-Output "Sub Group Name: $subGroupName"
                $groupName = $groupname
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
            catch {
                write-host "Adding Dynamic Query Faild"	
        
    }
}
function Run-SolarwindsListResources {
    param (
        [string]$division,
        [string]$country,
        [string]$storeNumber,
        [string]$state,
        [string]$fulldivision,
        [string]$groupName,
        [string]$parentGroupName,
        [object]$swis,
        [int]$registers,  # Number of registers
		[string]$ipaddress

    )
	
	$nodeIP = $ipaddress
    Write-Host "Processing node with IP: $nodeIP"

    # Get the NodeID for the current node
    $nodeID = Get-NodeID -swis $swis -nodeIP $nodeIP
    Write-Host "NodeID for node with IP $nodeIP is: $nodeID"

    # Schedule the list resources job for the specified node
    Write-Host "Scheduling list resources job for node with IP: $nodeIP"
    $jobId = Schedule-ListResourcesJob -swis $swis -nodeID $nodeID
    Write-Host "Scheduled job ID: $jobId"

    # Wait for the job to be ready for import
    Write-Host "Waiting for job completion for node with IP: $nodeIP"
    Wait-ForJobCompletion -swis $swis -jobId $jobId -nodeIP $nodeIP

    # Import the resources
    Write-Host "Importing resources for node with IP: $nodeIP"
    Import-Resources -swis $swis -jobId $jobId -nodeIP $nodeIP -nodeid $nodeid
	
}
function Get-NodeID {
    param (
        [Object]$swis,
        [string]$nodeIP
    )

    # Query SolarWinds for the NodeID using the IP address
    $query = "SELECT NodeID FROM Orion.Nodes WHERE IPAddress = '$nodeIP'"
    Write-Host "Executing query: $query"
    $nodeInfo = Get-SwisData $swis $query
    Write-Host "NodeInfo result: $nodeInfo"
    $nodeID = $nodeinfo
    return $nodeInfo
}
function Schedule-ListResourcesJob {
    param (
        [Object]$swis,
        [int]$nodeID
    )
    # Schedule the list resources job
    Write-Host "Invoking ScheduleListResources verb for NodeID: $nodeID"
    $result = Invoke-SwisVerb $swis "Orion.Nodes" "ScheduleListResources" @($nodeID)
    return $result.'#text'
}
function Wait-ForJobCompletion {
    param (
        [Object]$swis,
        [string]$jobId,
        [string]$nodeIP,
        [int]$timeout = 30,
        [int]$timeBetweenChecks = 2
    )
    # Wait until job status is 'ReadyForImport'
    Write-Host "Waiting for job with ID: $jobId for node with IP: $nodeIP to be ready for import"
    do {
        Start-Sleep -Seconds $timeBetweenChecks
        $status = Invoke-SwisVerb $swis "Orion.Nodes" "GetScheduledListResourcesStatus" @($jobId, $nodeid)
        Write-Host "Job status for node with IP $nodeIP $($status.'#text')"
    } while ($status.'#text' -ne "ReadyForImport")
}
function Import-Resources {
    param (
        [Object]$swis,
        [string]$jobId,
        [string]$nodeIP,
        [int]$NodeID
    )
    # Import the list resources
    Write-Host "Importing resources for node with IP: $nodeIP"
    $importResult = Invoke-SwisVerb $swis "Orion.Nodes" "ImportListResourcesResult" @($jobId, $nodeid)
    if (![System.Convert]::ToBoolean($importResult.'#text')) {
        throw ("Import of ListResources result for NodeIP: $nodeIP $nodeIP finished with errors.")
    }
    Write-Host -ForegroundColor Green ("Import of ListResources for NodeIP: $nodeIP finished successfully")+
    Attach-solarwinds-SAM -swis $swis -ipaddress $ipaddress -nodeid $nodeID
}
function Attach-SolarWinds-SAM {
    param (
        [object]$swis,
        [string]$ipAddress,
        [int]$NodeID
    )
        $credentialSetId = -3
        
    try {
        Write-Host "Starting Attach-SolarWinds-SAM for IP address: $ipAddress"

        Write-Host "Queried NodeID: $nodeID"

        if (-not $nodeID) {
            Write-Host "Node with IP address $ipAddress not found."
            return
        }

        # Use the global TemplateID variable
        $templateID = $global:TemplateID

        # Select the template
        $template = "POSSupport - Register Application Monitors"
        $applicationTemplateId = Get-SwisData $swis "SELECT ApplicationTemplateID FROM Orion.APM.ApplicationTemplate WHERE Name=@template" @{ template = $template }

        if (!$applicationTemplateId) {
	    Write-Host "Can't find template with name '$template'."
	    exit 1
        }
        Write-Host "Creating application on node '$nodeId' using template '$applicationTemplateId' and credential '$credentialSetId'."

        # Assign the application template to a node to create the application
        $applicationId = (Invoke-SwisVerb $swis "Orion.APM.Application" "CreateApplication" @(
            # Node ID
            $nodeId,
            
            # Application Template ID
            $applicationTemplateId,
            
            # Credential Set ID
            $credentialSetId,
            
            # Skip if duplicate (in lowercase)
            "false"
        )).InnerText

        # Check if the application was created
        if ($applicationId -eq -1) {
            Write-Host "Application wasn't created. Likely the template is already assigned to node and the skipping of duplications are set to 'true'."
            exit 1
        }
        else {
            Write-Host "Application created with ID '$applicationId'."
        }

        #
        # EXECUTING "POLL NOW"
        #
        # Execute "Poll Now" on created application.
        #
        Write-Host "Executing Poll Now for application '$applicationId'."
        Invoke-SwisVerb $swis "Orion.APM.Application" "PollNow" @($applicationId) | Out-Null
        Write-Host "Poll Now for application '$applicationId' was executed."




        Write-Host "SAM Application Monitor attached to node with IP address: $ipAddress using template ID: $templateID, resulting in Application ID: $appID"
    } catch {
        Write-Host "Error attaching SAM Application Monitor to node: $_"
    }
}

# Call the Setup-SolarWinds function
Setup-SolarWinds -division $division -country $country -storeNumber $storeNumber -state $state -storeName $storeName -setupSolarWinds $setupSolarWinds -registers $registers
