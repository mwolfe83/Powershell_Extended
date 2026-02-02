
# Get the list of usernames from the file
$usernamesFilePath = Join-Path $PSScriptRoot "usernames.txt"
$usernames = Get-Content $usernamesFilePath

foreach ($username in $usernames) {
    # Construct the folder path for the current username
    $folderPath = "\\nw01\userdata$\$username"

    
    # Get the current ACL of the folder
    $acl = Get-Acl -Path $folderPath

    
    # Remove existing permissions for the specified username
    $existingPermissions = $acl.Access | Where-Object { $_.IdentityReference.Value -eq "NT_GENESCO\$username" }
    Write-Host $existingPermissions
    foreach ($existingPermission in $existingPermissions) {


        $acl.RemoveAccessRule($existingPermission)
        
    }

    # Add a new permission for Read access only
    $readPermission = New-Object System.Security.AccessControl.FileSystemAccessRule($username, 'Read', 'Allow')
    $acl.AddAccessRule($readPermission)

    # Apply the modified ACL to the folder
    Set-Acl -Path $folderPath -AclObject $acl

    # Get all items (files and folders) within the specified folder
    $items = Get-ChildItem -Path $folderPath -Recurse

    foreach ($item in $items) {
        $itemAcl = Get-Acl -Path $item.FullName

        # Remove existing permissions for the specified username
        $itemExistingPermissions = $itemAcl.Access | Where-Object { $_.IdentityReference.Value -eq "NT_GENESCO\$username" }
        foreach ($itemExistingPermission in $itemExistingPermissions) {
            $itemAcl.RemoveAccessRule($itemExistingPermission)
        }

        # Add a new permission for Read access only
        $itemAcl.AddAccessRule($readPermission)

        # Apply the modified ACL to the item
        Set-Acl -Path $item.FullName -AclObject $itemAcl
    }

    # Display the updated ACL for verification
    Get-Acl -Path $folderPath | Format-List
}
