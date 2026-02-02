# Import the SwisPowerShell module if not already loaded
if (-not (Get-Module -Name SwisPowerShell -ListAvailable)) {
    Import-Module SwisPowerShell
}



# Function to get the NodeID from SolarWinds
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


# Function to schedule the list resources job
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

# Function to wait for job completion
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

# Function to import resources
function Import-Resources {
    param (
        [Object]$swis,
        [string]$jobId,
        [string]$nodeIP
    )
    # Import the list resources
    Write-Host "Importing resources for node with IP: $nodeIP"
    $importResult = Invoke-SwisVerb $swis "Orion.Nodes" "ImportListResourcesResult" @($jobId, $nodeid)
    if (![System.Convert]::ToBoolean($importResult.'#text')) {
        throw ("Import of ListResources result for NodeIP: $nodeIP $nodeIP finished with errors.")
    }
    Write-Host -ForegroundColor Green ("Import of ListResources for NodeIP: $nodeIP finished successfully")
}

# Define target host and credentials
$SolarWindsServer = 'p01-wa-sol-01.genesco.local'
$solarwindsUsername = 'solarwinds_poller'
$solarwindsPassword = '&Uqih%5Uowd@^8B@'

# Create a connection to the SolarWinds API
$Swis = Connect-Swis -Hostname $SolarWindsServer -Username $solarwindsusername -password $solarwindsPassword

# Path to the CSV file
$CsvFilePath = "$PSScriptRoot\newnode.csv"

# Import the CSV file
$nodes = Import-Csv -Path $csvFilePath

# Iterate through each node in the CSV
foreach ($node in $nodes) {
    $nodeIP = $node.NodeIPAddress
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
    Import-Resources -swis $swis -jobId $jobId -nodeIP $nodeIP
}

