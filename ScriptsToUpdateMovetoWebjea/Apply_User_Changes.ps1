Param(
    [Parameter(Mandatory=$true)][string]$empid,
    [Parameter(Mandatory=$true)][string]$LastName,
    [Parameter(Mandatory=$true)][string]$FirstName,
    [Parameter(Mandatory=$true)][string]$CompanyCode,
    [Parameter(Mandatory=$true)][string]$dept,
    [Parameter(Mandatory=$true)][string]$JobTitle,
    [Parameter(Mandatory=$true)][string]$superempid,
    [Parameter(Mandatory=$true)][string]$filename2,
    [Parameter(Mandatory=$true)][string]$LNDes,
    [Parameter(Mandatory=$true)][string]$FNDes,
    [Parameter(Mandatory=$true)][string]$EmpIDDes,
    [Parameter(Mandatory=$true)][string]$ComDes,
    [Parameter(Mandatory=$true)][string]$DepDes,
    [Parameter(Mandatory=$true)][string]$JobTDes,
    [Parameter(Mandatory=$true)][string]$SupDes
#    [Parameter(Mandatory=$true)][string]$FullNDes,
#    [Parameter(Mandatory=$true)][string]$DisNDes,
#    [Parameter(Mandatory=$true)][string]$LastNameLong
     )

##Import AD module
Import-Module ActiveDirectory

Start-Transcript -Path C:\scripts\ultipro_changes\Logs\$filename2.txt

#First name apostrophe correction
$FirstName = $FirstName -replace "'","''"
$LastName = $LastName -replace "'","''"

#Set a few base variables
$empidAD = $empid

#Employee ID Change and Veify
if ($EmpIDDes -eq "true")
    {
    try
        {
        $usercount = @(Get-ADUser -Filter "(Surname -eq '$LastName') -and (GivenName -eq '$FirstName')")
        if ($usercount.count -eq 1)
            {
            $empidname = Get-ADUser -Filter "(Surname -eq '$LastName') -and (GivenName -eq '$FirstName')" -Properties EmployeeID | select -ExpandProperty EmployeeID
            if ($empidname -eq $null -or $empidname -ne $empid)
                {
                try
                    {
                    Get-ADUser -Filter "(Surname -eq '$LastName') -and (GivenName -eq '$FirstName')" | % {Set-ADUser $_ -EmployeeID $empid}
                    $empidAD = Get-ADUser -Filter "(EmployeeID -eq '$empid')" -Properties EmployeeID | select -ExpandProperty EmployeeID
                    }
                catch
                    {
                    $errormessage += $Error[0]
                    }
                }
            else
                {
                try
                    {
                    $ManagercheckAD = Get-ADUser -Filter "EmployeeID -eq '$superempid'" -Properties DistinguishedName | select -ExpandProperty DistinguishedName
                    Get-ADUser -Filter "(Surname -eq '$LastName') -and (Company -eq '$CompanyCode') -and (Manager -eq '$ManagercheckAD')" | % {Set-ADUser $_ -EmployeeID $empid}
                    $empidAD = Get-ADUser -Filter "(EmployeeID -eq '$empid')" -Properties EmployeeID | select -ExpandProperty EmployeeID
                    }
                catch
                    {
                    $errormessage += $Error[0]
                    }
                }
            }
        else
            {
            try
                {
                $ManagercheckAD = Get-ADUser -Filter "EmployeeID -eq '$superempid'" -Properties DistinguishedName | select -ExpandProperty DistinguishedName
                Get-ADUser -Filter "(Surname -eq '$LastName') -and (Company -eq '$CompanyCode') -and (Manager -eq '$ManagercheckAD')" | % {Set-ADUser $_ -EmployeeID $empid}
                $empidAD = Get-ADUser -Filter "(EmployeeID -eq '$empid')" -Properties EmployeeID | select -ExpandProperty EmployeeID
                }
            catch
                {
                $errormessage += $Error[0]
                }
            }
        }
    catch
        {
        $errormessage += $Error[0]
        }
    }
#if ($LNDes -eq "true")
#    {
#    try
#        {
#        if ($empid -eq $empidAD)
#            {
#            Get-ADUser -Filter "(EmployeeID -eq '$empid')" | % {Set-ADUser $_ -Surname $LastNameLong}
#            $LastNameAD = Get-ADUser -Filter "(EmployeeID -eq '$empid')" -Properties Surname | select -ExpandProperty Surname
#            }
#        else
#            {
#            $errormessage = "No Employee ID was found or set in AD, so the script cannot continue."
#            }
#        }
#    catch
#        {
#        $errormessage += $Error[0]
#        }
#    }
if ($ComDes -eq "true")
    {
    try
        {
        if ($empid -eq $empidAD)
            {
            Get-ADUser -Filter "(EmployeeID -eq '$empid')" | % {Set-ADUser $_ -Company $CompanyCode}
            $CompanyCodeAD = Get-ADUser -Filter "(EmployeeID -eq '$empid')" -Properties Company | select -ExpandProperty Company
            }
        else
            {
            $errormessage = "No Employee ID was found or set in AD, so the script cannot continue."
            }
        }
    catch
        {
        $errormessage += $Error[0]
        }
    }
if ($DepDes -eq "true")
    {
    try
        {
        if ($empid -eq $empidAD)
            {
            Get-ADUser -Filter "(EmployeeID -eq '$empid')" | % {Set-ADUser $_ -Department $dept}
            $deptAD = Get-ADUser -Filter "(EmployeeID -eq '$empid')" -Properties Department | select -ExpandProperty Department
            }
        else
            {
            $errormessage += "No Employee ID was found or set in AD, so the script cannot continue."
            }
        }
    catch
        {
        $errormessage += $Error[0]
        }
    }
if ($JobTDes -eq "true")
    {
    try
        {
        if ($empid -eq $empidAD)
            {
            Get-ADUser -Filter "(EmployeeID -eq '$empid')" | % {Set-ADUser $_ -Title $JobTitle}
            $JobTitleAD = Get-ADUser -Filter "(EmployeeID -eq '$empid')" -Properties Title | select -ExpandProperty Title
            }
        else
            {
            $errormessage += "No Employee ID was found or set in AD, so the script cannot continue."
            }
        }
    catch
        {
        $errormessage += $Error[0]
        }
    }
if ($SupDes -eq "true")
    {
    try
        {
        if ($empid -eq $empidAD)
            {
            $ManagercheckAD = Get-ADUser -Filter "EmployeeID -eq '$superempid'" -Properties DistinguishedName | select -ExpandProperty DistinguishedName
            if ($ManagercheckAD -eq $null)
                {
                $superempid = $superempid.TrimStart("0"," ")
                $ManagercheckAD = Get-ADUser -Filter "EmployeeID -eq '$superempid'" -Properties DistinguishedName | select -ExpandProperty DistinguishedName
                }
            Get-ADUser -Filter "(EmployeeID -eq '$empid')" | % {Set-ADUser $_ -Manager $ManagercheckAD}
            $superempidADDis = Get-ADUser -Filter "(EmployeeID -eq '$empid')" -Properties Manager | select -ExpandProperty Manager
            $superempidAD = Get-ADUser -Filter "DistinguishedName -eq '$superempidADDis'" -Properties "EmployeeID" | select -ExpandProperty EmployeeID
            }
        else
            {
            $errormessage += "No Employee ID was found or set in AD, so the script cannot continue."
            }
        }
    catch
        {
        $errormessage += $Error[0]
        }
    }
#if ($FullNDes -eq "true" -or $LNDes -eq "true")
#    {
#    try
#        {
#        if ($empid -eq $empidAD)
#            {
#            $fullnamevar = $LastNameLong + ", " + $FirstName
#            Get-ADUser -Filter "(EmployeeID -eq '$empid')" | % {Rename-ADObject $_ -NewName "$fullnamevar"}
#            $fullnameAD = Get-ADUser -Filter "(EmployeeID -eq '$empid')" -Properties name | select -ExpandProperty name
#            }
#        else
#            {
#            $errormessage += "No Employee ID was found or set in AD, so the script cannot continue."
#            }
#        }
#    catch
#        {
#        $errormessage += $Error[0]
#        }
#    }
#if ($DisNDes -eq "true" -or $LNDes -eq "true")
#    {
#    try
#        {
#        if ($empid -eq $empidAD)
#            {
#            $displaynamevar = $LastNameLong + ", " + $FirstName
#            Get-ADUser -Filter "(EmployeeID -eq '$empid')" | % {Set-ADUser $_ -displayname "$displaynamevar"}
#            $displaynameAD = Get-ADUser -Filter "(EmployeeID -eq '$empid')" -Properties displayname | select -ExpandProperty displayname
#            }
#        else
#            {
#            $errormessage += "No Employee ID was found or set in AD, so the script cannot continue."
#            }
#        }
#    catch
#        {
#        $errormessage += $Error[0]
#        }
#    }

if ($errormessage -eq $null) { $errormessage = "There were no errors." }
Write-Host "<errormessage>$errormessage</errormessage>"
write-host "<lastname>$LastNameAD</lastname>"
Write-Host "<empid>$empidAD</empid>"
Write-Host "<company>$CompanyCodeAD</company>"
Write-Host "<dept>$deptAD</dept>"
Write-Host "<title>$JobTitleAD</title>"
Write-Host "<managerid>$superempidAD</managerid>"
Write-Host "<fullname>$fullnameAD</fullname>"
Write-Host "<displayname>$displaynameAD</displayname>"

Stop-Transcript