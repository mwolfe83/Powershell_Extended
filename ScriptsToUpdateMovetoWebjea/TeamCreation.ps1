#documentatoin of mapping on Cherwel
#Pass Incident ID from CW "Incident.Incident ID" -> $incidentid
#Choose a Team Field: Specifics - Genesco - Create Team.Team name -> $mailstart
#Choose member field: Specifics - Genesco - Create Team.Options -> $members
#Choose member field: Specifics - Genesco - Create Team.List -> $Owners



#set params for the script
Param(
    [Parameter(Mandatory=$true)][string]$incidentid, 
    [Parameter(Mandatory=$true)][string]$mailstart,
    [Parameter(Mandatory=$true)][string]$members,
    [Parameter(Mandatory=$true)][string]$owners
     )



#Start Transcript
Start-Transcript -Path "$PSScriptRoot\output\TeamCreation\$incidentid.txt" -Append
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
    #$Credential=$creds
    #$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Credential -Authentication Basic -AllowRedirection
    #write-host "SessionID During Create: $Session.Id"
    #Import-PSSession $Session -AllowClobber  
}



#import module and connect to cloud exchange
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Import-Module PowerShellGet #-RequiredVersion 2.2.4 -SkipPublisherCheck -Confirm:$false -Force
Import-Module ExchangeOnlineManagement #-Confirm:$false -Force
$errormessage = "There were no errors."
Write-Host "Beginning"
Write-Host "<header>$incidentid $mailstart</header>"
$membersarray = $members -split ","
Import-Module MicrosoftTeams




#Connect to Teams Online
try
    {
    ConnectTeams
    }
catch { $errormessage = "Exchange Error: $Error[0]" ; Add-Content -Path "$PSScriptRoot\output\365GroupCreateModify\$incidentid.txt" -Append "$errormessage" }



#Create a Team
try
    {
    New-Team -DisplayName $mailstart -AllowGiphy:$true -GiphyContentRating Strict -AllowUserEditMessages:$true -AllowUserDeleteMessages:$true -AllowCreateUpdateChannels:$true
    }
catch { $errormessage = "Welcome Error: $Error[0]" ; Add-Content -Path "$PSScriptRoot\output\365GroupCreateModify\$incidentid.txt" -Append "$errormessage" 
    
    $attachment = "d$PSScriptRoot\AD_GetEnabledUsersWithDisabledManagers.csv"
    #$to = "platform_systems@genesco.com"
    $to = "mwolfe@genesco.com"
    $from = "Cherwell_Automation@genesco.com"
    $subject = "List of users with disabled managers"
    $body = "The following users have a manager that is disabled.  Please review these users and resolve the exception. <br /><br />" + (Import-Csv $attachment | Convertto-html | Out-String) + "<br /><br /><br /><br />-Automation originated from server $server."
    $smtpServer = "10.1.0.250"

    Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpServer -BodyAsHtml

    exit
    }





#Set options for the new 365 Group
try
    {
    Connect-Exchange
    }
catch { $errormessage = $errormessage + "`nExchange Error: $Error[0]" }

try
    {
    set-unifiedgroup -Identity "$mailstart" -UnifiedGroupWelcomeMessageEnabled:$false -autoSubscribeNewMembers:$true -HiddenFromExchangeClientsEnabled:$true -HiddenFromAddressListsEnabled:$true
    }
catch { $errormessage = "Welcome Error: $Error[0]" ; Add-Content -Path "$PSScriptRoot\output\365GroupCreateModify\$incidentid.txt" -Append "$errormessage" }




#Add members to the Group
try
    {
add-UnifiedGroupLinks -Identity "$mailstart" -LinkType Members -Links "$members"
            }
catch { $errormessage = $errormessage + "`nMember Error: $Error[0]" ; Add-Content -Path "$PSScriptRoot\output\365GroupCreateModify\$incidentid.txt" -Append "$errormessage" }




#Add owners to the group
try
    {
add-UnifiedGroupLinks -Identity "$mailstart" -LinkType Owners -Links "$owners"
            }
catch { $errormessage = $errormessage + "`nMember Error: $Error[0]" ; Add-Content -Path "$PSScriptRoot\output\365GroupCreateModify\$incidentid.txt" -Append "$errormessage" }




$results = (Get-UnifiedGroup -Identity "$mailstart" | select autoSubscribeNewMembers, HiddenFromExchangeClientsEnabled, PrimarySmtpAddress, HiddenFromAddressListsEnabled, WelcomeMessageEnabled)
Add-Content -Path "$PSScriptRoot\output\365GroupCreateModify\$incidentid.txt" -Append "<autoSubscribeNewMembers>$($results.autoSubscribeNewMembers)</autoSubscribeNewMembers><HiddenFromExchangeClientsEnabled>$($results.HiddenFromExchangeClientsEnabled)</HiddenFromExchangeClientsEnabled><PrimarySmtpAddress>$($results.PrimarySmtpAddress)</PrimarySmtpAddress><HiddenFromAddressListsEnabled>$($results.HiddenFromAddressListsEnabled)</HiddenFromAddressListsEnabled><WelcomeMessageEnabled>$($results.WelcomeMessageEnabled)</WelcomeMessageEnabled><error>$($errormessage)</error>"

Stop-Transcript
Get-PSSession | Remove-PSSession