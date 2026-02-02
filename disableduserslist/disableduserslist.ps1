Import-Module ActiveDirectory

$inputPath  = Join-Path $PSScriptRoot 'usernames.txt'
$outputPath = Join-Path $PSScriptRoot 'user_status_report.csv'

$usernames = Get-Content -Path $inputPath
$output = @()

foreach ($username in $usernames) {
    $trimmed = $username.Trim()

    $user = Get-ADUser -Identity $trimmed -Properties Enabled -ErrorAction SilentlyContinue

    if ($user) {
        $output += [pscustomobject]@{
            Username = $trimmed
            Enabled  = $user.Enabled
        }
    } else {
        $output += [pscustomobject]@{
            Username = $trimmed
            Enabled  = 'Not Found'
        }
    }
}

$output | Export-Csv -Path $outputPath -NoTypeInformation
