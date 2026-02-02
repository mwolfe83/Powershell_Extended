param(
    [Parameter(Mandatory=$true)][string]$filename
)

##Import AD module
Import-Module ActiveDirectory

#creds to make changes in AD
try{
    $username = "<Service Account>"
    $PasswordstateUrl = 'https://pwstate.genesco.local/api/passwords/<pwid>'
    $account = Invoke-Restmethod -Method GET -Uri $PasswordstateUrl -Header @{ "APIKey" = "<api_key>" }
    $creds = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $userName, $(convertto-securestring $account.password -asplaintext -force)
}   catch {("Unable to gather service account credentials to make changes");Stop-Transcript;exit}

#function to make changes
function Update-ADuser {
    param (
        $empid,
        $newdata,
        $field,
        $creds
    )
    $hash = @{
        $field = $newdata
    }

    get-aduser -filter "(EmployeeID -eq '$empid')" -Properties * | ForEach-Object {Set-ADUser -Credential $creds -Server "P01-WI-ADC-01.genesco.local" -identity $_ -Replace $hash}
}
#logging
$log = $filename+"_"+(get-date -Format 'MM-dd-yyyy')
Start-Transcript -Path C:\temp\$log.txt

#import data
$records = import-csv -path $filename

#loop through data
foreach($user in $records){
#pull csv data and declare vars
$empid = $user.EMPLOYEE_ID
$LastName = $user.LAST_NAME
$FirstName = $user.FIRST_NAME
$CompanyCode = $user.BU_DESC
$dept = $user.DEPT_DESC
$JobTitle = $user.JOB_TITLE
$superempid = $user.SUPERVISOR_EMP_ID
$modified = $false
$date = (get-date -Format 'MM-dd-yyyy')

#pull current ad record
try{
    $currentad = get-aduser -filter "(EmployeeID -eq '$empid')" -Properties * ;$desc = "Modified $date by Automation"+$currentad.description
}   catch {("No user found with the Employee ID $empid");$error[0]; continue}
#pull manager info
try{
    $manager = get-aduser -filter "(EmployeeID -eq '$superempid')" -Properties * | Select-Object -ExpandProperty DistinguishedName
}   catch {("No user found with the Employee ID $empid");$error[0]}

#check and update fields with new data
    if($LastName -ne $currentad.surname){ try {Update-ADuser -empid $empid -field "surname" -newdata $lastname;$modified = $true} catch {("Error updating Lastname")};$error[0]}
    if($FirstName -ne $currentad.GivenName){ try {Update-ADuser -empid $empid -field "givenname" -newdata $FirstName;$modified = $true} catch {("Error updating Firstname")};$error[0]}
    if($CompanyCode -ne $currentad.company){ try {Update-ADuser -empid $empid -field "company" -newdata $CompanyCode;$modified = $true} catch {("Error updating Company")};$error[0]}
    if($dept -ne $currentad.Department){ try {Update-ADuser -empid $empid -field "department" -newdata $dept;$modified = $true} catch {("Error updating Department")};$error[0]}
    if($JobTitle -ne $currentad.title){ try {Update-ADuser -empid $empid -field "title" -newdata $JobTitle;$modified = $true} catch {("Error updating Job Title")};$error[0]}
    if($manager -ne $currentad.manager){ try {Update-ADuser -empid $empid -field "manager" -newdata $manager;$modified = $true} catch {("Error updating Manager")};$error[0]}
    if($modified -eq $true){try {Update-ADuser -empid $empid -field "description" -newdata $Desc} catch {("Error updating description")};$error[0]}
}
#stop logging
Stop-Transcript