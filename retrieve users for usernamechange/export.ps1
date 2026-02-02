Import-Module ActiveDirectory

$inputPath  = Join-Path $PSScriptRoot 'import_users.csv'
$outputPath = Join-Path $PSScriptRoot 'output_users.csv'

$users = Import-Csv -Path $inputPath
$output = @()

foreach ($user in $users) {
    $first = ($user.First -as [string]).Trim()
    $last  = ($user.Last -as [string]).Trim()

    Write-Host "Searching for: $first $last"

    $adUser = Get-ADUser -Filter {
        GivenName -like $first -and Surname -like $last
    } -Properties Department, CanonicalName, Manager, mail, GivenName, Surname, sAMAccountName -ErrorAction SilentlyContinue

    if ($adUser) {
        $manager = if ($adUser.Manager) {
            Get-ADUser -Identity $adUser.Manager -Properties DisplayName, sAMAccountName
        }

        $output += [pscustomobject]@{
            Department             = $adUser.Department
            CanonicalName          = $adUser.CanonicalName
            ManagerName            = $manager.DisplayName
            ManagerSamAccountName  = $manager.sAMAccountName
            Email                  = $adUser.mail
            'First Name'           = $adUser.GivenName
            'Last Name'            = $adUser.Surname
            Username               = $adUser.sAMAccountName
        }
    } else {
        Write-Warning "No AD user found for $first $last"
    }
}

$output | Export-Csv -Path $outputPath -NoTypeInformation
