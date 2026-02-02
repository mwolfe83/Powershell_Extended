$folderPath = "\\nw01\userdata$\mwolfe"
# Specify the username for which you want to modify permissions
$username = "MWolfe"

# Get the current ACL of the folder
$acl = Get-Acl -Path $folderPath

# Find and remove existing permissions for the specified username
$existingPermission = $acl.Access | Where-Object { $_.IdentityReference.Value -eq $username }
if ($existingPermission -ne $null) {
    $acl.RemoveAccessRule($existingPermission)
}

# Add a new permission for Read access only
$readPermission = New-Object System.Security.AccessControl.FileSystemAccessRule($username, 'Read', 'Allow')
$acl.AddAccessRule($readPermission)

# Apply the modified ACL to the folder
Set-Acl -Path $folderPath -AclObject $acl

# Display the updated ACL for verification
Get-Acl -Path $folderPath | Format-List