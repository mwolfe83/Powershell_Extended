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

# Path to the CSV file
$CsvFilePath = "$PSScriptRoot\newnode.csv"

# Read nodes from CSV and add them to SolarWinds with custom properties
$Nodes = Import-Csv -Path $CsvFilePath

function klep_guid($ip)
{
    $ipx = @()
    foreach ($ipa in $ip.split("."))
    {
        $ipx += "{0:X2}" -f [int]$ipa #Hex
    }
    $ipy = $ipx[3] + $ipx[2] + $ipx[1] + $ipx[0] + "-0000-0000-0000-000000000000"
    $ipy = $ipy.replace(' ', '')  
    return $ipy
}



foreach ($Node in $Nodes) {
    Write-Host "$node.NodeName - Starting work"
    try {
        # Check if the node already exists in SolarWinds
        $ExistingNode = Get-SwisData -SwisConnection $Swis -Query "SELECT NodeID FROM Orion.Nodes WHERE IPAddress = '$($Node.NodeIPAddress)'"

        if ($ExistingNode) {
            # Node already exists, update custom properties
            $NodeID = $ExistingNode.NodeID
            $CustomProperties = @{
                'Site' = $Node.Site
                'Stakeholder' = $Node.Stakeholder
            }
            Set-SwisObject -SwisConnection $Swis -Uri "swis://localhost/Orion/Orion.Nodes/NodeID=$NodeID" -Properties $CustomProperties
            Write-Host "Custom properties (Site and Stakeholder) updated for existing Node $($Node.NodeName)."
        } else {
            # Node doesn't exist, create it

                # If polling method is SNMP, use SNMPv3 credentials defined as variables
            if ($Node.PollingMethod -eq "SNMP") {
                $NodeProperties = @{
                    'IPAddress' = $Node.NodeIPAddress
                    'Caption' = $Node.NodeName
                    'NodeDescription' = $Node.State
                    'IPAddressGuid' = klep_guid($Node.NodeIPAddress)
                    'Status' = 1
                    'Unmanaged' = $false
                    'Allow64BitCounters'='true'
                    'sysObjectID' = ''
                    'StatCollection' = 10
                    'EngineID' = $Node.Poller
                    'ObjectSubType' = $Node.PollingMethod
                    'SysName' = $Node.NodeName
                    'SNMPV3Username' = $SNMPv3Username
                    'SNMPV3PrivKey' = $SNMPv3Password
                    'SNMPV3PrivMethod' = 'AES128'   # Adjusted to match expected value
                    'SNMPV3AuthKey' = $SNMPv3Password
                    'SNMPV3AuthMethod' = 'SHA1'      # Adjusted to match expected value
                    'SNMPVersion' = '3'
                    'SNMPV3PrivKeyisPwd' = $true
                    'snmpv3AuthKeyIsPwd' = $true
                    }
                    
                }
                else {
                # For other polling methods, create node properties without SNMPv3 credentials
                $NodeProperties = @{
                    'IPAddress' = $Node.NodeIPAddress
                    'Caption' = $Node.NodeName
                    'NodeDescription' = $Node.State
                    'IPAddressGuid' = klep_guid($Node.NodeIPAddress)
                    'Status' = 1
                    'Unmanaged' = $false
                    'Allow64BitCounters'='true'
                    'sysObjectID' = ''
                    'StatCollection' = 10
                    'EngineID' = $Node.Poller
                    'ObjectSubType' = $Node.PollingMethod
                    'SysName' = $Node.NodeName
                }
            }

            # Add the node and get its URI
            $NewNodeUri = New-SwisObject -SwisConnection $Swis -EntityType 'Orion.Nodes' -Properties $NodeProperties

            # Add custom properties to the newly created node
            $CustomProperties = @{
                Site = $Node.Site
                Stakeholder = $Node.Stakeholder
            }
            Set-SwisObject -SwisConnection $Swis -Uri ($NewNodeUri + "/CustomProperties") -Properties $CustomProperties
            Write-Host "Node $($Node.NodeName) added successfully with custom properties (Site and Stakeholder)."
        }

    } catch {
        Write-Host "Error adding or updating node $($Node.NodeName): $_"
    }
    Write-host "$node.NodeName - Work Complete"
}
