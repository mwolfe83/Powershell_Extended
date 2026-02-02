#set params
    Param (
    [Parameter(Mandatory=$true)][string]$FirstName,
    [Parameter(Mandatory=$true)][string]$LastName,
    [Parameter(Mandatory=$true)][string]$Email, 
    [Parameter(Mandatory=$true)][string]$Company, #use vendor
    [Parameter(Mandatory=$false)][string]$mirror,
    [Parameter(Mandatory=$true)][string]$ticketnumber,
    [Parameter(Mandatory=$true)][string]$expiredate, #use end date
    [Parameter(Mandatory=$true)][string]$samaccountname,
    [Parameter(Mandatory=$true)][string]$manager, #use contact
    [switch]$teams,
    [switch]$O365
    #[Parameter(Mandatory=$true)][switch]$planner
    )
#directory for output
try {
    mkdir -Path "C:\scripts\output\$ticketnumber" -Force -Confirm:$false
    ("Created ticket output directory")
}
catch {
   $direrror = $error ; $error.Clear() ; ++$e
   ("directory creation error")
}

#transcript backup in case out-file fails
    Start-Transcript -Path "C:\scripts\output\$ticketnumber\$ticketnumber.txt"
#clear error log
    $error.clear()
#modules
    Import-Module ActiveDirectory  
    ("Import AD module")
#variables
    $today = (Get-Date).ToString('MM-dd-yy')
    $today2 = (Get-Date).ToString('MM/dd/yyyy')
    if($expiredate -le $today2){$expiredate = (get-date).adddays(90).tostring('MM/dd/yyyy')}
    $DisplayName = "$lastname, $firstname"
    $upn = "$samaccountname@genesco.local"
    $originid = $samaccountname
    $Desc = "Created $today ticket# $ticketnumber"
    $FirstName = $FirstName -replace "'","''"
    $LastName = $LastName -replace "'","''"
    $j = 0
    $e = 0
    $exception = 0
    ("Variables set")
    
    try {
        $managerdn = Get-aduser $manager -Properties * | Select-Object -ExpandProperty DistinguishedName
        ("Set Contact")
    }
    catch {
        $manerror = $error ; $error.Clear() ; ++$e 
        ("Contact set error")
    }
    

#calc password
    $brand = "Adidas","Burton","Dockers","Etnies","Summer","Winter","Spring","Heelys","Jansport","Journeys","Northface","Reebok","Simple","Steadfast","Kickers", "Osiris" | get-random
    $pwnum = (1..10) + "2017" | get-random
    $pwschar = (33..38) + (42..43) | get-random | ForEach-Object {[char]$_}
    $finalpass = $brand + $pwnum + $pwschar
    ("Password generated")



#check if company has folder in vendor ou
    $ouchk = test-path -path "AD:\OU=$company,OU=Vendor Remote Access,DC=genesco,DC=local"
    if($ouchk){$OU = "OU=$company,OU=Vendor Remote Access,DC=genesco,DC=local"}
    else {$OU = "OU=Vendor Remote Access,DC=genesco,DC=local"}
    ("Ou set")
#check if account name exist
    $checkContainer = Get-ADUser -Filter {SamAccountName -eq $samaccountname}
    if ($checkContainer) 
            {
                do 
                {
                    Try 
                    {
                        write-host "$samaccountname exists. Trying next..."
                        $samaccountname = $originid
                        $samaccountname = $samaccountname + ++$j
                        $checkContainer = Get-ADUser -Filter {SamAccountName -eq $samaccountname}
                        Continue
                    }
                    Catch { Break }     
                } 
                While ($checkContainer)
                           }
            #last check for upn to match userid
            $upn = "$samaccountname@genesco.local"

#create user
    try {
        New-ADUser -Name $DisplayName -accountPassword (ConvertTo-SecureString -AsPlainText $finalpass -Force) -ChangePasswordAtLogon $true -Enabled $true -SamAccountName $samaccountname -GivenName $FirstName -Surname $LastName -DisplayName $DisplayName -Path $OU -EmailAddress $Email -Description $Desc -UserPrincipalName $UPN -manager $managerdn
        set-aduser $samaccountname -Replace @{employeetype = "Vendor"}
        ("user created")
    }
    catch {
        $usererror = $error ; $error.Clear() ; ++$e
        ("error creating user")
    }

    Start-Sleep 10
    
    try {
        Set-ADAccountExpiration -Identity $samaccountname -datetime $expiredate -Confirm:$false
        ("expiration date set")
    }
    catch {
        $seterror = $error ; $error.clear() ; ++$e
        ("error setting exipration date")
    }
  

#mirror groups from user
    if($mirror){ try {
        $BaseUserArray = Get-AdUser -Identity $mirror -Properties memberof | Select-Object -ExpandProperty memberof
        $LicenseNeededArray = New-Object System.Collections.ArrayList
        $FinalUserArray = New-Object System.Collections.ArrayList
        ("Mirroring $mirror")
            

        foreach ($memberof in $baseuserarray) {
            $group = get-adgroup -Identity $memberof -Properties *
        
            #switch is to filter out licensed groups via guid, add additional guids here
            switch ($group.ObjectGUID)
            {
                "e56e727f-30a5-4866-b439-97537d1d2bb5"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "d5759b2a-25bb-4391-ad8b-537f114114d2"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "d103beaf-4fa9-4c70-bb62-239dd8db968d"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "748db001-0b1b-4258-8106-29bee5a1beb8"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "a584b975-0d27-4eee-983e-ba8a204b793f"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "da8ae0ed-7316-4fe5-891a-65c7e34708fe"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "8e417984-6f31-4568-87b2-d8dc3768fce1"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "bd9e648f-2bfa-4af4-b402-6bbde6663345"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "ea59337e-3b81-4a48-aeae-d22432fb7eed"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "b75631de-cdb2-4b5d-8a63-6a397c41477e"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "3536063d-b33f-4b7f-a224-363d7177f615"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "b0438518-ee9c-49ff-821c-aa108cf884e9"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "3d542690-da96-4a02-8e6b-55627520c5d0"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "3efb1133-a8a9-494b-af43-b8dcf0833d2c"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "22bd28eb-c986-4a93-9f8b-a9be21e8a8f3"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "922f58b5-2a48-4592-8a5b-47361a7d767a"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "a25f6944-bdc1-4f5c-9410-45fcb34a8814"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "6f79a83c-6df7-4e33-906b-3208580162b9"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "5f10b55e-1071-447b-bb11-2be241defcbf"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "b8d96ac6-d08a-4719-94db-40bd177488d4"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "cf9049d2-96d3-4338-9069-f850868efa9f"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "535b50ef-041f-43f7-b793-6f6cb9cb5646"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "c1c55200-0cd6-4757-98e1-9e7d261ef2a4"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "82f2c1dd-d1a8-4f42-8cde-87d4f950edb8"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "4ff250af-7424-4e4d-984e-29b965b5ac45"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "d5536287-6fad-4ec8-8aa5-3b837115463f"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "3dc0ba25-b8c7-4b85-92a1-bdabce19547e"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "a0ec83b8-bded-4d75-a26e-67741e2620c2"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "5028bc0f-0923-4f81-a91c-2816f86c3752"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "c18c7db6-22c2-4aca-a72e-147adb5b23e4"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "a13de119-0248-4304-93fa-26bf79316ec1"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "69d2e37b-a56a-43d0-85e2-d0f29e5d70e2"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "d700b79d-0a36-4f49-8c1b-9b811cabf9c7"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "699cd6d2-ecb7-4864-b7d7-debb10c32d02"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "5379605a-c86b-4fb5-9f86-457958f7565e"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "abe27321-68d7-4abd-a716-62fc0a5d1c84"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "2d4f2820-680f-4909-8517-487c9437de69"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "c371a3b9-ee7b-4c8a-9151-682ef5b38949"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "89f572e4-4c12-44ee-96d3-105225d6564e"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "a9cb0b95-6649-4e64-9445-c6a289a90ed0"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "76c6240f-5f1b-482a-9beb-ece69dd0eca7"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "9e675a20-b941-4f3d-b166-2ef6dbc27707"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "846b4413-3c31-495c-99a5-94652059a9d9"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "86c1a18b-be40-4252-b9e7-030253e84481"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "7c6e71c0-2601-486d-ba09-00f4ed5341bd"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "fdc9cfac-514a-4022-998d-46ba203d710c"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "dcd9a4dd-b2a2-4961-8ba0-829c279e29df"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "66731a61-746e-4603-b59a-90d87fea5fb0"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "fb381081-9ca7-4d12-b6f4-d4e78eddf73d"{$LicenseNeededArray.Add($memberof) | Out-Null }
                "32d64a0e-0f64-412f-9632-532902ed8c82"{$LicenseNeededArray.Add($memberof) | Out-Null }
                $null {}
                default { try {Add-ADGroupMember -Identity $memberof -Members $samaccountname -Confirm:$false -ErrorAction SilentlyContinue} catch {("The following group was not copied to the new user: $memberof");$finaluserArray.Add($memberof) ;$exception += 1}}
            }
        }
        
        #Add-ADPrincipalGroupMembership -Identity $samaccountname -MemberOf $FinalUserArray 
        
        <#
        if ($licensedGroupNum -ne 0) { 
        
        write-host ""
        write-host "NOTE:" $licensedGroupNum "user groups were not copied because they are licensed. Please add manually." -ForegroundColor Yellow 
        
        } 
        #>             
                     }
                    catch {
                     $mirerror = $error ; $error.Clear() ; ++$e  
                     ("licensing error")
                          }
                }       
#365 licensing
    if($O365){ try {
        $upn = "$samaccountname@genesco.com"
        $email = "$samaccountname@genesco.com"
        $ou = "OU=Vendors with O365,OU=Vendor Remote Access,DC=genesco,DC=local"
        $userid = get-aduser -Filter {sAMAccountNAme -eq $samaccountname} | Select-Object -ExpandProperty DistinguishedName
        add-ADGroupMember "O365_E3_Vendors" -Members $samaccountname
        Move-ADObject -Identity $userid -TargetPath $ou 
        Set-ADUser -Identity $samaccountname -replace @{MailNickName = "$samaccountname"; msExchHideFromAddressLists="TRUE"; employeetype = "Vendor"} -EmailAddress $Email -UserPrincipalName $upn 
        if($teams){add-ADGroupMember "O365_E3_Default" -Members $samaccountname; remove-ADGroupMember -Identity "O365_E3_Vendors" -Members $samaccountname -Confirm:$false}
        ("added 365 licensing")
                   } 
    catch {
        $365error = $error ; $error.clear() ; ++$e
        ("error licensing 365")
    } }


#output for cherwell
    ("
   <displayname>$displayname</displayname>
   <samaccountname>$samaccountname</samaccountname>
   <password>$finalpass</password>
   <manager>$manager</manager>
   <ou>$ou</ou>
   <enddate>$expiredate</enddate>
   <mirror>$mirror</mirror>
   <upn>$upn</upn>
   <email>$email</email>

   Errors:
   <direrror>$direrror</direrror>
   <manerror>$manerror</manerror>
   <usererror>$usererror</usererror>
   <seterror>$seterror</seterror>
   <mirerror>$mirerror</mirerror>
   <365error>$365error</365error>
   <er>$e</er>
   <exceptions>$exception</exceptions>
   <groups>$finaluserarray</groups>

     ")
Stop-Transcript