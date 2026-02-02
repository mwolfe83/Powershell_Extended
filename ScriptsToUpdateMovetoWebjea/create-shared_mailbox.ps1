Param(
    [Parameter (Mandatory=$true)][ValidateLength(11,74)][string]$emailAddress,
    [Parameter (Mandatory=$true)][string]$incidentID    
     )

Start-Transcript -Path "C:\Users\Public\SharedMailboxCreation\$incidentid.txt" -Append

Import-Module ActiveDirectory

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#$evalexo = Get-EXOMailbox journeys -ErrorAction SilentlyContinue

#if ($evalexo -eq $null){

    $username = "svcexo@genesco.onmicrosoft.com"
    $PasswordstateUrl = 'https://pwstate.genesco.local/api/passwords/2979'
    $account = Invoke-Restmethod -Method GET -Uri $PasswordstateUrl -Header @{ "APIKey" = "43f356bce9827da468d3e59facb327b2" }
    $creds = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $userName, $(convertto-securestring $account.password -asplaintext -force)
    ("$account.password")
    Connect-exchangeonline -UserPrincipalName $username -credential $creds
#}

$sharedMailboxOU = "OU=Shared Mailboxes,DC=genesco,DC=local"
$mailboxName = $emailAddress.Split("@")[0]
$domain = $emailAddress.Split("@")[1]
$password = "Genesco!@#"
$invalidChars = '[^a-z0-9\.@_]'
$validDomains = @("genesco.com","journeys.com","johnstonmurphy.com","littleburgundyshoes.com","trask.com","dockersshoes.com","nashvilleshoewarehouse.com")
$permissionsCSV = Import-CSV "c:\users\public\SharedMailboxCreation\$incidentID-permissions.csv"
$theCSV = "c:\users\public\SharedMailboxCreation\$incidentID-permissions.csv"
#$permissionsCSV = Import-CSV "c:\users\public\SharedMailboxCreation\testing.csv"
$errormessage = ""
$finalcheck = ""

#--- Check for valid format ---

<#
if ($emailAddress -as [System.Net.Mail.MailAddress]){

         #--- Check for invalid characters ---

        if ($emailAddress -match $invalidChars){
            ('Invalid character in email address: {0}' -f $matches[0])

            exit
        }

         #--- Check if domain is valid ---

        if ($validDomains -notcontains $domain){
            ('Invalid domain.')
            exit
        } 

        #--- Check if email address already exists ---

        $emailCheck = Get-ADObject -LDAPFilter "proxyAddresses=smtp:$emailAddress"
        if ($emailCheck -ne $null){
            ("$emailAddress already exists.")
            exit 
        }
}else{

        ('Invalid email address format.')
        exit
}

#>

if (Test-Path $theCSV){

    #--- Create account in AD ---

    ("Creating $mailboxName in Active Directory...")
    if ( $mailboxName.Length -gt 20 )
        {
        $sam = $mailboxName.SubString(0,20)
        }
    else
        {
        $sam = $mailboxName
        }
    try{New-ADUser -Name $mailboxName -Description "Cherwell Automation - $incidentID" -UserPrincipalName $emailAddress -DisplayName $mailboxName -SamAccountName $sam -GivenName $mailboxName -Surname $mailboxName -accountPassword (ConvertTo-SecureString -AsPlainText $password -Force) -Path $sharedMailboxOU -ChangePasswordAtLogon $false -Enabled $true}
    catch{$errormessage = $errormessage + "`nUser Creation Error: $Error[0]"}

    #--- Add to O365_E3_Exchange security group to license ---

    ('Adding to O365_E3_Default security group to license...')

    try{$licenseUser = Add-ADGroupMember -Identity "o365_e3_exchange" -Members $sam}
    catch {$errormessage = $errormessage + "`nAdd to O365 Licensing Group Error: $Error[0]"}
 
    #--- Sync to Azure AD ---

    ("Syncing to Azure AD...")
    Start-sleep 5
    $error.clear()

    try {$startAzureSync = Invoke-Command -ComputerName "p01-wa-add-01" -ErrorAction Stop -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta } }
    #Catch { $_.Exception.GetType() | select FullName } 
    catch [System.Management.Automation.RemoteException]{  
 
         write-host "Sync is already running. Waiting 60 seconds to try again..."
         start-sleep 60
         $startAzureSync = Invoke-Command -ComputerName "p01-wa-add-01" -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta }
    }

    #--- Wait until Exchange is aware ---

    ("Waiting for mailbox to be created...")
    $mailboxCreated = Get-mailbox $emailAddress -ErrorAction SilentlyContinue
    while ($mailboxCreated -eq $null) 
    {
    $mailboxCreated = Get-mailbox $emailAddress -ErrorAction SilentlyContinue
    start-sleep 5
    }

    #---Convert to shared mailbox ---

    ("Converting to shared mailbox...")
    start-sleep 10
    try{$convertToShared = Set-Mailbox $emailAddress -Type Shared}
    catch {$errormessage = $errormessage + "`nConvert to Shared Mailbox Error: $Error[0]"}

    #--- Wait for conversion ---

    ("Waiting for conversion to complete...")
    $conversion = Get-Mailbox $emailAddress | select -ExcludeProperty IsShared
    while ($conversion -eq "False") 
    {
    $conversion = Get-Mailbox $emailAddress | select -ExcludeProperty IsShared
    start-sleep 5
    }

    #--- Set delegate permissions ---

    ("Adding delegation permissions...")
    Start-Sleep 5
    foreach($line in $permissionsCSV){
            $delegateUser = $line.user
            try{
            Add-MailboxPermission -identity $emailAddress -User $delegateUser -AccessRights FullAccess
            Add-RecipientPermission -Identity $emailAddress -Trustee $delegateUser -AccessRights SendAs -confirm:$false
            }
            catch {$errormessage = $errormessage + "`nDelgation Permission Assignment Error: $Error[0]"}
    }

    #--- Save sent items to shared mailbox ---
    try{
    $saveSentBehalf = Set-mailbox $emailAddress -MessageCopyForSendOnBehalfEnabled $True
    $saveSent = Set-mailbox $emailAddress -MessageCopyForSentAsEnabled $True
    }
    catch {$errormessage = $errormessage + "`nSave Items to Sent Folder Error: $Error[0]"}

    #--- Set primary SMTP address (reverts to genesco.onmicrosoft.com if not set) ---


    try{Set-ADUser -identity $sam -add @{ProxyAddresses="SMTP:" + $emailAddress}}
    catch {$errormessage = $errormessage + "`nSet Primary SMTP Address Error: $Error[0]"}

    #--- Unlicense account ---

    ("Removing $mailboxName from license group...")

    try{$unlicense = Remove-ADGroupMember -Identity "o365_e3_exchange" -Members $sam -Confirm:$false}
    catch {$errormessage = $errormessage + "`nRemoval from O365 Licensing Group Error: $Error[0]"}

    #--- Disable account --

    ("Disabling $mailboxName...")
    try{Disable-ADAccount -Identity $sam}
    catch {$errormessage = $errormessage + "`nDisable AD Account Error: $Error[0]"}

    $finalcheck = Get-mailbox $emailAddress
    if ( $errormessage -eq "" ) { $errormessage = "There were no errors." }
    ("<finalcheck>$finalcheck</finalcheck><error>$($errormessage)</error>")

    Disconnect-ExchangeOnline -Confirm:$false
    Stop-Transcript
    Get-PSSession | Remove-PSSession
   

}
Else
{
    Write-Error "Permissions CSV is missing. ($permissionsCSV)"

    $finalcheck = Get-mailbox $emailAddress
    if ( $errormessage -eq "" ) { $errormessage = "There were no errors." }
    ("<error>$($errormessage)</error>")

    Disconnect-ExchangeOnline -Confirm:$false
    Stop-Transcript
    Get-PSSession | Remove-PSSession







}