# Import the Active Directory module
Import-Module ActiveDirectory

# Define the output CSV file path
$outputFile = Join-Path $PSScriptRoot "output.csv"

# Get all departments in Active Directory
$departments = Get-ADUser -Filter * -Properties Department | Select-Object -ExpandProperty Department -Unique

# Initialize an array to store the results
$results = @()

# Iterate through each department
foreach ($department in $departments) {
    Write-Host "Processing department: $department"

    # Get users in the current department
    $departmentUsers = Get-ADUser -Filter { Department -eq $department }

    # Get all groups for the current department
    $departmentGroups = $departmentUsers | ForEach-Object {
        Get-ADUser $_ -Properties MemberOf | Select-Object -ExpandProperty MemberOf
    } | Select-Object -Unique

    # Iterate through each user in the department
    foreach ($user in $departmentUsers) {
        Write-Host "Processing user: $($user.Name)"

        # Initialize an array to store common groups
        $commonGroups = @()

        # Get groups for the current user
        $userGroups = Get-ADUser $user -Properties MemberOf | Select-Object -ExpandProperty MemberOf

        # Iterate through each group in the department
        foreach ($group in $departmentGroups) {
            # Check if the user is a member of the current group
            if ($userGroups -contains $group) {
                # Check if all users in the department are members of the current group
                $allUsersInDepartmentHaveGroup = $true
                foreach ($otherUser in $departmentUsers) {
                    # Skip the current user
                    if ($otherUser.SamAccountName -ne $user.SamAccountName) {
                        # Check if the other user is not a member of the current group
                        if (!(Get-ADUser $otherUser -Properties MemberOf | Select-Object -ExpandProperty MemberOf) -contains $group) {
                            $allUsersInDepartmentHaveGroup = $false
                            break
                        }
                    }
                }

                # If all users in the department have the group, add it to the common groups
                if ($allUsersInDepartmentHaveGroup) {
                    $commonGroups += $group
                }
            }
        }

        # Add the user's common groups to the results
        if ($commonGroups.Count -gt 0) {
            $results += [PSCustomObject]@{
                Department = $department
                UserName = $user.Name
                CommonGroups = $commonGroups -join ", "
            }
        }
    }
}

# Output the results to a CSV file
$results | Export-Csv -Path $outputFile -NoTypeInformation

Write-Host "Output saved to: $outputFile"
