Param(
    [Parameter(Mandatory=$true)][string]$sam,
    [Parameter(Mandatory=$true)][string]$incidentid,
    [Parameter(Mandatory=$true)][string]$ext_exp,
    [Parameter(Mandatory=$false)][string]$ext_date
     )

import-module vmware.powercli
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope:all -Confirm:$false

#Start Blank Log File
$logvar = "Beginning of Log"

function Connect-vsphere {
    $username = "svccwadmin"
    $PasswordstateUrl = 'https://pwstate.genesco.local/api/passwords/335'
    $account = Invoke-Restmethod -Method GET -Uri $PasswordstateUrl -Header @{ "APIKey" = "32b5f987ce43da6fb637e359d28a4c3a" }
    $script:creds = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $userName, $(convertto-securestring $account.password -asplaintext -force)
    Connect-VIServer gppavcsapr1 -Credential $creds 
    }

#secure admin creds
    $username = "svcsecurecw"
    $PasswordstateUrl = 'https://pwstate.genesco.local/api/passwords/3231'
    $account = Invoke-Restmethod -Method GET -Uri $PasswordstateUrl -Header @{ "APIKey" = "32b5f987ce43da6fb637e359d28a4c3a" }
    $script:creds2 = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $userName, $(convertto-securestring $account.password -asplaintext -force)
    

try
    {
    Connect-vsphere
    $vsphere = $true
    }
catch { $errormessage = $errormessage + "`nvSphere Error: $Error[0]" }

##Import AD module
Import-Module ActiveDirectory
$logvar = $logvar + "`r`nActive Directory module imported"

#Set initial variables
$errormessage = $null
$date = Get-Date -format "MM/dd/yy"
$logvar = $logvar + "`r`nInitial variable set"

#get secure account if needed
    try{
        $secure = Get-ADUser -Filter "(samaccountname -eq '$sam')" -Properties EmployeeNumber | select -ExpandProperty EmployeeNumber
        if($null -eq $secure){$vsphere = $false}
        }
    catch { $logvar = $logvar + "`r`nno secure account" ; $vsphere = $false}

if ($ext_exp -eq "extend")
    {
    try
        {
        Get-ADUser -Filter "(samaccountname -eq '$sam')" | % {Set-ADUser $_ -AccountExpirationDate "$ext_date"}
        $logvar = $logvar + "`r`nNew expiration date for $sam set"
        Get-ADUser -Filter "(samaccountname -eq '$sam')" -Properties Description | % {Set-ADUser $_ -Description "Extended $date CW#$incidentid $($_.Description)"}
        $logvar = $logvar + "`r`nDescription for $sam updated"
        $newexpdate = Get-ADUser -Filter "(samaccountname -eq '$sam')" -Properties AccountExpirationDate | select -ExpandProperty AccountExpirationDate
        $logvar = $logvar + "`r`nNew Expiration date for $sam in AD is $newexpdate"
        $newdescription = Get-ADUser -Filter "(samaccountname -eq '$sam')" -Properties Description | select -ExpandProperty Description
        $logvar = $logvar + "`r`nNew Description for $sam in AD is $newdescription"
        $resolve = 1
        }
    catch
        {
        $errormessage += $Error[0];$resolve = 0
        }
    }
elseif ($ext_exp -eq "expire")
    {
    try
        {
        Get-ADUser -Filter "(samaccountname -eq '$sam')" -Properties Description | % {Set-ADUser $_ -Description "Allowing Expiration CW#$incidentid $($_.Description)"}
        $logvar = $logvar + "`r`nDescription for $sam updated"
        $newdescription = Get-ADUser -Filter "(samaccountname -eq '$sam')" -Properties Description | select -ExpandProperty Description
        $logvar = $logvar + "`r`nNew Description for $sam in AD is $newdescription"
        $resolve = 1
        }
    catch
        {
        $errormessage += $Error[0];$resolve = 0
        }
    }
#secure extension
    if($vsphere -eq $true){
        try{
        $extend = $ext_date.Split(" ")
        $extend = $extend[0]
        $scripttext = "& c:\temp\AccountExtensions.ps1 -sam '$secure' -incidentid '$incidentid' -ext_exp '$ext_exp' -ext_date '$extend'"
        $results = Invoke-VMScript -ScriptText $scripttext -vm nw03 -GuestCredential $creds2
        $results
        $resolve = 1
        }
        catch { $errormessage += $Error[0];$resolve = 0 }
        }

$logvar = $logvar + "`r`n$results"
if ($errormessage -eq $null) { $errormessage = "There were no errors." }
$logvar = $logvar + "`r`n$errormessage"

#Write the logfile locally
$logvar | Out-File C:\Users\Public\$incidentid.txt


#Send WebHook back to Cherwell
if($resolve -eq 1){
$uri = "https://gdesk/CherwellAPI/api/Webhooks/incidentlogexpiration"
$body = @{incidentid="$incidentid";changetype="AD";body="$logvar"} | ConvertTo-Json
Invoke-WebRequest -Uri $uri -Method Post -Body $body
}
