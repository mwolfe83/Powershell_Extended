# ------------- CONNECT TO SWIS ------------- #

Import-Module SwisPowerShell

# Define target host and credentials
$SolarWindsServer = 'p01-wa-sol-01.genesco.local'
$solarwindsUsername = 'solarwinds_poller'
$solarwindsPassword = '&Uqih%5Uowd@^8B@'

# SNMP Credentials
$SNMPv3Username = 'genesco'
$SNMPv3Password = 'Genesco123'

# Create a connection to the SolarWinds API
$Swis = Connect-Swis -Hostname $SolarWindsServer -Username $solarwindsusername -password $solarwindsPassword

$groupInfo = Import-Csv -Path "\\p01-wf-tch-01\data$\Marshall\Scripts\Solarwinds\Bulk_Group\groups.csv"

# Loop through each group name in the CSV file
foreach ($group in $groupInfo) {
    $groupName = $group.Name
    $groupDescription = $group.Description
    $refreshFrequency = $group.RefreshFrequency
    $pollingEnabled = $group.PollingEnabled

    # Create an empty array for member definitions
    $memberDefinitions = @()

    # Construct the members as XML
    $membersXml = @"
<ArrayOfMemberDefinitionInfo xmlns='http://schemas.solarwinds.com/2008/Orion'>
    $($memberDefinitions | ForEach-Object {
        "<MemberDefinitionInfo><Name>$($_.Name)</Name><Definition>$($_.Definition)</Definition></MemberDefinitionInfo>"
    })
</ArrayOfMemberDefinitionInfo>
"@

    # Output debugging information
    Write-Host "Creating group with name: '$groupName', description: '$groupDescription', refresh frequency: $refreshFrequency, polling enabled: $pollingEnabled"

    # Invoke the CreateContainer verb
    $groupId = (Invoke-SwisVerb $swis "Orion.Container" "CreateContainer" @(
        $groupName,
        "Core",
        $refreshFrequency,
        0,
        $groupDescription,
        [System.Boolean]::Parse($pollingEnabled),  # Explicit conversion to boolean
        ([xml]$membersXml).DocumentElement
    )).InnerText

    # Output debugging information
    Write-Host "Group '$groupName' created with ID: $groupId"
}
