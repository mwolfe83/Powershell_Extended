# Retrieve members of the IT_ALL distribution group
$mailingListMembers = Get-DistributionGroupMember -Identity "IT_ALL@genesco.com" -ResultSize unlimited

# Output directory
$outputDirectory = "C:\temp\photos"
if (-not (Test-Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

# Start Loop
write-host "Starting loop"
$i = 0
foreach ($mailbox in $mailingListMembers) {
    write-host "$mailbox.Name"
    # Iterate Progress
    $i++

    # Start Try
    try {
        # Get Photo
        write-host "$mailbox.name with ExtenralDirectoryObjectID of $mailbox.ExternalDirectoryObjectId"
        $user = Get-UserPhoto $mailbox.ExternalDirectoryObjectId -ErrorAction Stop

        # If successful
        if ($user) {
            $photoPath = Join-Path -Path $outputDirectory -ChildPath ("Photo-" + $mailbox.PrimarySmtpAddress + ".jpg")
            $user.PictureData | Set-Content -Path $photoPath -Encoding Byte
        }
    }
    # Catch Error
    catch {
        # Log photo failure
        Add-Content -Path "C:\temp\photo_errors.log" -Value "No photo for user $($mailbox.PrimarySmtpAddress)"
    }

    # Update progress
    Write-Progress -Activity "Processing User Photos" -Status "Progress: $i out of $($mailingListMembers.count)" -PercentComplete (($i / $mailingListMembers.count) * 100)
}
