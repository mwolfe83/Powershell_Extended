$users = Get-ADUser -Filter {Enabled -eq $true} -Properties Manager,AccountExpirationDate
$results = @()
foreach ($user in $users) {
    if($user.Manager -ne $null -and $user.AccountExpirationDate -ne null) {
        $manager = (Get-ADUser -Identity $user.Manager -Properties Enabled).Enabled
        if ($manager -eq $false) {
            $results += [PSCustomObject]@{
                User = $user.Name
                Manager = (Get-ADUser -Identity $user.Manager).Name
            }
        }
    }
}
$results | Select-Object User, Manager | Export-Csv -Path "$PSScriptRoot\EnabledUsersWithDisabledManagers.csv" -NoTypeInformation

$attachment = "$PSScriptRoot\EnabledUsersWithDisabledManagers.csv"
$to = "mwolfe@genesco.com"
$from = "ADAutomation@genesco.com"
$subject = "List of users with disabled managers"
$body = "Please find the list of users with disabled managers" + (Import-Csv $attachment | Convertto-html | Out-String)
$smtpServer = "10.1.0.250"

Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpServer -Attachments $attachment -BodyAsHtml