#set params for the script
Param(
    [Parameter(Mandatory=$true)][string]$incidentid,
    [Parameter(Mandatory=$true)][string]$mailstart,
    [Parameter(Mandatory=$true)][string]$members,
    [Parameter(Mandatory=$true)][string]$owners
     )
#Start Transcript
Start-Transcript -Path C:\Users\Public\$incidentid.txt -Append

#Set TLS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#connect to exchange online with service account
function Connect-Exchange {
    param (
        #OptionalParameters
    )
    $username = "svccw365@genesco.onmicrosoft.com"
    $PasswordstateUrl = 'https://pwstate.genesco.local/api/passwords/2874'
    $account = Invoke-Restmethod -Method GET -Uri $PasswordstateUrl -Header @{ "APIKey" = "739bf634258ecdac253ed736ba948f7d" }
    $creds = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $userName, $(convertto-securestring $account.password -asplaintext -force)
    Connect-ExchangeOnline -Credential $creds
}
#function Connect-Exchange {
#    param (
#        #OptionalParameters
#    )
#    $username = "jhatman@genescoinc.onmicrosoft.com"
#    #$PasswordstateUrl = 'https://pwstate.genesco.local/api/passwords/1386'
#    #$account = Invoke-Restmethod -Method GET -Uri $PasswordstateUrl -Header @{ "APIKey" = "739bf634258ecdac253ed736ba948f7d" }
#    $password = "DeathlyHallows4$"
#    $creds = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $userName, $(convertto-securestring $password -asplaintext -force)
#    Connect-ExchangeOnline -Credential $creds 
#}
#import module and connect to cloud exchange
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Import-Module PowerShellGet #-RequiredVersion 2.2.4 -SkipPublisherCheck -Confirm:$false -Force
Import-Module ExchangeOnlineManagement #-Confirm:$false -Force
Write-Host "Beginning"
Write-Host "<header>$incidentid $mailstart</header>"
$membersarray = $members -split ","
$ownersarray = $owners -split ","
try
    {
    Connect-Exchange
    }
catch { $errormessage = $errormessage + "`nExchange Error: $Error[0]" }
#Create Distribution Group with Options
try
    {
    new-distributiongroup -name "$mailstart" -displayname "$mailstart" -managedby $ownersarray -PrimarySmtpAddress "$mailstart@genesco.com" -confirm:$false -RequireSenderAuthenticationEnabled:$false 
    }
catch { $errormessage = $errormessage + "`nCreate Error: $Error[0]" }

    foreach ($user in $membersarray)
        {
        try
            {
        add-distributiongroupmember -identity "$mailstart" -member $user -confirm:$false
            }
        catch { $errormessage = $errormessage + "`nMember Error: $Error[0]" }
    }

Start-Sleep 10
try
    {
    $results = (Get-DistributionGroup -Identity $mailstart | select guid, name, primarysmtpaddress)
    }
catch { $errormessage = "Results Error: $Error[0]" ; Add-Content -Path "c:\users\public\$incidentid.txt" "$errormessage" }
if ( $errormessage -eq $null ) { $errormessage = "There were no errors." }
Write-Host "<guid>$($results.guid)</guid><name>$($results.name)</name><PrimarySmtpAddress>$($results.PrimarySmtpAddress)</PrimarySmtpAddress><error>$($errormessage)</error>"
Stop-Transcript
Get-PSSession | Remove-PSSession