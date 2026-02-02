# Define the path to the username.txt and export.txt files
$usernameFilePath = Join-Path $PSScriptRoot "username.txt"
$exportFilePath = Join-Path $PSScriptRoot "export.txt"

# Check if the username.txt file exists
if (Test-Path $usernameFilePath) {
    # Read the usernames from the file
    $usernames = Get-Content $usernameFilePath

    # Initialize an array to store results
    $results = @()

    # Iterate through each username
    foreach ($username in $usernames) {
        # Get user details from Active Directory
        $user = Get-ADUser -Filter {SamAccountName -eq $username} -Properties SamAccountName, EmailAddress

        # Check if user is found
        if ($user) {
            # Add user details to results array
            $result = [PSCustomObject]@{
                Username = $user.SamAccountName
                EmailAddress = $user.EmailAddress
            }
            $results += $result
        } else {
            Write-Warning "User '$username' not found in Active Directory."
        }
    }

    # Export results to export.txt
    $results | Export-Csv -Path $exportFilePath -NoTypeInformation
    Write-Host "Results exported to $exportFilePath"
} else {
    Write-Error "username.txt file not found at $usernameFilePath"
}
