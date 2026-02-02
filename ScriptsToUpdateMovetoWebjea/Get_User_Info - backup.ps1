Param(
    [Parameter(Mandatory=$true)][string]$empid,
    [Parameter(Mandatory=$true)][string]$LastName,
    [Parameter(Mandatory=$true)][string]$FirstName,
    [Parameter(Mandatory=$true)][string]$CompanyCode,
    [Parameter(Mandatory=$true)][string]$dept,
    [Parameter(Mandatory=$true)][string]$JobTitle,
    [Parameter(Mandatory=$true)][string]$superempid,
    [Parameter(Mandatory=$true)][string]$filename
     )

##Import AD module
#Import-Module ActiveDirectory

Start-Transcript -Path C:\scripts\ultipro_changes\Logs\$filename.txt

#First name apostrophe correction
$FirstName = $FirstName -replace "'","''"
$LastName = $LastName -replace "'","''"

$empidexiststest = Get-ADUser -Filter "EmployeeID -eq '$empid'" -Properties EmployeeID | select -ExpandProperty EmployeeID
if ($empidexiststest -eq $null)
    {
    $empid = $empid.TrimStart("0"," ")
    $empidexiststest = Get-ADUser -Filter "EmployeeID -eq '$empid'" -Properties EmployeeID | select -ExpandProperty EmployeeID
    }

if ($empidexiststest -ne $null)
    {
    $empidexists = "yes"
    }
else
    {
    $empidexists = "no"
    }
$usercount = @(Get-ADUser -Filter "(Surname -eq '$LastName') -and (GivenName -eq '$FirstName')").Count

Write-Host "<empidexists>$empidexists</empidexists>"

if ($empidexists -eq "yes")
    {
    try
        {
        $LastNameAD = Get-ADUser -Filter "EmployeeID -eq '$empid'" -Properties Surname | select -ExpandProperty Surname
        $CompanyCodeAD = Get-ADUser -Filter "EmployeeID -eq '$empid'" -Properties Company | select -ExpandProperty Company
        $DeptAD = Get-ADUser -Filter "EmployeeID -eq '$empid'" -Properties Department | select -ExpandProperty Department
        $JobTitleAD = Get-ADUser -Filter "EmployeeID -eq '$empid'" -Properties Title | select -ExpandProperty Title
        $ManagerAD = Get-ADUser -Filter "EmployeeID -eq '$empid'" -Properties Manager | select -ExpandProperty Manager
        $superempidAD = Get-ADUser -Filter "DistinguishedName -eq '$ManagerAD'" -Properties "EmployeeID" | select -ExpandProperty EmployeeID
        $enabled = Get-ADUser -Filter "EmployeeID -eq '$empid'" -Properties Enabled | select -ExpandProperty Enabled
        $fullnamead = Get-ADUser -Filter "EmployeeID -eq '$empid'" -Properties name | select -ExpandProperty name
        $displaynamead = Get-ADUser -Filter "EmployeeID -eq '$empid'" -Properties displayname | select -ExpandProperty displayname
        $samaccountname = Get-ADUser -Filter "EmployeeID -eq '$empid'" -Properties samaccountname | select -ExpandProperty samaccountname
        $notice = "Option A"
        }
    catch
        {
        $errormessage += "Option A" + $Error[0]
        }
    }
elseif ($usercount.count -eq 1)
    {
    try
        {
        $empidname = Get-ADUser -Filter "(Surname -eq '$LastName') -and (GivenName -eq '$FirstName')" -Properties EmployeeID | select -ExpandProperty EmployeeID
        if ($empidname -eq $null)
            {
            $samaccountname = Get-ADUser -Filter "(Surname -eq '$LastName') -and (GivenName -eq '$FirstName')" -Properties SamAccountName | select -ExpandProperty SamAccountName
            $LastNameAD = Get-ADUser -Filter "(Surname -eq '$LastName') -and (GivenName -eq '$FirstName')" -Properties Surname | select -ExpandProperty Surname
            $CompanyCodeAD = Get-ADUser -Filter "(Surname -eq '$LastName') -and (GivenName -eq '$FirstName')" -Properties Company | select -ExpandProperty Company
            $DeptAD = Get-ADUser -Filter "(Surname -eq '$LastName') -and (GivenName -eq '$FirstName')" -Properties Department | select -ExpandProperty Department
            $JobTitleAD = Get-ADUser -Filter "(Surname -eq '$LastName') -and (GivenName -eq '$FirstName')" -Properties Title | select -ExpandProperty Title
            $ManagerAD = Get-ADUser -Filter "(Surname -eq '$LastName') -and (GivenName -eq '$FirstName')" -Properties Manager | select -ExpandProperty Manager
            $superempidAD = Get-ADUser -Filter "DistinguishedName -eq '$ManagerAD'" -Properties "EmployeeID" | select -ExpandProperty EmployeeID
            $enabled = Get-ADUser -Filter "(Surname -eq '$LastName') -and (GivenName -eq '$FirstName')" -Properties Enabled | select -ExpandProperty Enabled
            $fullnamead = Get-ADUser -Filter "(Surname -eq '$LastName') -and (GivenName -eq '$FirstName')" -Properties name | select -ExpandProperty name
            $displaynamead = Get-ADUser -Filter "(Surname -eq '$LastName') -and (GivenName -eq '$FirstName')" -Properties displayname | select -ExpandProperty displayname
            $notice = "Option B"
            }
        else
            {
            $ManagercheckAD = Get-ADUser -Filter "EmployeeID -eq '$superempid'" -Properties DistinguishedName | select -ExpandProperty DistinguishedName
            $samaccountname = Get-ADUser -Filter "(Surname -eq '$LastName') -and (Company -eq '$CompanyCode') -and (Manager -eq '$ManagercheckAD')" -Properties SamAccountName | select -ExpandProperty SamAccountName
            $LastNameAD = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties Surname | select -ExpandProperty Surname
            $CompanyCodeAD = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties Company | select -ExpandProperty Company
            $DeptAD = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties Department | select -ExpandProperty Department
            $JobTitleAD = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties Title | select -ExpandProperty Title
            $ManagerAD = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties Manager | select -ExpandProperty Manager
            $superempidAD = Get-ADUser -Filter "DistinguishedName -eq '$ManagerAD'" -Properties "EmployeeID" | select -ExpandProperty EmployeeID
            $enabled = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties Enabled | select -ExpandProperty Enabled
            $fullnamead = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties name | select -ExpandProperty name
            $displaynamead = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties displayname | select -ExpandProperty displayname
            $notice = "Option C"
            }
        }
    catch
        {
        $errormessage += "Option B or C" + $Error[0]
        }
    }
else
    {
    try
        {
        $ManagercheckAD = Get-ADUser -Filter "EmployeeID -eq '$superempid'" -Properties DistinguishedName | select -ExpandProperty DistinguishedName
        $samaccountname = Get-ADUser -Filter "(Surname -eq '$LastName') -and (Company -eq '$CompanyCode') -and (Manager -eq '$ManagercheckAD')" -Properties SamAccountName | select -ExpandProperty SamAccountName
        if ($samaccountname -ne $null)
            {
            $LastNameAD = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties Surname | select -ExpandProperty Surname
            $CompanyCodeAD = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties Company | select -ExpandProperty Company
            $DeptAD = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties Department | select -ExpandProperty Department
            $JobTitleAD = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties Title | select -ExpandProperty Title
            $ManagerAD = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties Manager | select -ExpandProperty Manager
            $superempidAD = Get-ADUser -Filter "DistinguishedName -eq '$ManagerAD'" -Properties "EmployeeID" | select -ExpandProperty EmployeeID
            $enabled = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties Enabled | select -ExpandProperty Enabled
            $fullnamead = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties name | select -ExpandProperty name
            $displaynamead = Get-ADUser -Filter "SamAccountName -eq '$samaccountname'" -Properties displayname | select -ExpandProperty displayname
            $notice = "Option C"
            }
        }
    catch
        {
        $errormessage += "Option C" + $Error[0]
        }
    }

if ($notice -eq $null) { $notice = "not_found" }
if ($errormessage -eq $null) { $errormessage = "There were no errors." }
Write-Host "<errormessage>$errormessage</errormessage>"
Write-Host "<notice>$notice</notice>"
write-host "<lastname>$LastNameAD</lastname>"
Write-Host "<empid>$empidexiststest</empid>"
Write-Host "<company>$CompanyCodeAD</company>"
Write-Host "<dept>$DeptAD</dept>"
Write-Host "<title>$JobTitleAD</title>"
Write-Host "<managerid>$superempidAD</managerid>"
Write-Host "<samaccountname>$samaccountname</samaccountname>"
Write-Host "<enabled>$enabled</enabled>"
Write-Host "<fullname>$fullnamead</fullname>"
Write-Host "<displayname>$displaynamead</displayname>"

Stop-Transcript