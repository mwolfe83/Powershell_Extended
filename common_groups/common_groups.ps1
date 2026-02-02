# Read the CSV file
Write-Host "Reading the CSV file..."
$data = Import-Csv -Path "$PSScriptRoot\common_groups.csv"

# Group data by department
Write-Host "Grouping data by department..."
$departmentGroups = $data | Group-Object -Property Department

# Initialize an empty array to store the results
$results = @()

# Loop through each department
foreach ($departmentGroup in $departmentGroups) {
    $department = $departmentGroup.Name
    $usersInDepartment = $departmentGroup.Group

    Write-Host "Processing department: $department"

    # Initialize common groups list with the groups of the first user
    $commonGroups = @()
    if ($usersInDepartment.Count -gt 0) {
        $commonGroups = $usersInDepartment[0].Groups -split ','
        Write-Host "Initial common groups in $department $($commonGroups -join ',')"
    }

    # Loop through each user in the department
    foreach ($user in $usersInDepartment) {
        # Split user's groups
        $userGroups = $user.Groups -split ','

        # If $commonGroups is null, initialize it with an empty array
        if (-not $commonGroups) {
            $commonGroups = @()
        }

        # Find common groups with current user
        $commonGroups = Compare-Object -ReferenceObject $commonGroups -DifferenceObject $userGroups -IncludeEqual | Where-Object { $_.SideIndicator -eq '==' } | Select-Object -ExpandProperty InputObject
        Write-Host "Common groups so far in $department $($commonGroups -join ',')"
    }

    # Store the final common groups for the department
    $finalCommonGroups = $commonGroups -join ','
    Write-Host "Final common groups in $department $finalCommonGroups"

    # Add department and common groups to the results array
    $results += [PSCustomObject]@{
        Department = $department
        CommonGroups = $finalCommonGroups
    }
}

# Write results to a new CSV file
Write-Host "Writing results to a new CSV file..."
$results | Export-Csv -Path "$PSScriptRoot\output.csv" -NoTypeInformation

Write-Host "Script execution completed."
