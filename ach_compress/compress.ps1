# Define the source and destination folders
$sourceFolder = "$PSScriptRoot\ACH"
$destinationFolder = "$PSScriptRoot\ACH_compressed"

# Check if the source folder exists
if (-Not (Test-Path -Path $sourceFolder)) {
    Write-Host "Source folder '$sourceFolder' does not exist."
    Exit 1
}

# Create the destination folder if it doesn't exist
if (-Not (Test-Path -Path $destinationFolder)) {
    New-Item -ItemType Directory -Path $destinationFolder
}

# Define the fiscal year start and end dates
$fiscalYearStart = Get-Date "7/1/2012"
$fiscalYearEnd = $fiscalYearStart.AddYears(1).AddDays(-1) # Last day of fiscal year

# Define the end date for processing files
$endDateForProcessing = Get-Date "7/1/2023"

# Loop through each fiscal year
while ($fiscalYearEnd -le $endDateForProcessing) {
    $startYear = $fiscalYearStart.Year
    $endYear = $fiscalYearEnd.Year
    $archiveName = "Archive_${startYear}-${endYear}.zip"
    $archivePath = Join-Path -Path $destinationFolder -ChildPath $archiveName

    # Get the files within the fiscal year range
    $fileList = Get-ChildItem -Path $sourceFolder | Where-Object { $_.Attributes -eq 'Archive' -and $_.LastWriteTime -ge $fiscalYearStart -and $_.LastWriteTime -lt $fiscalYearEnd }

    Write-Host "Files for the fiscal year ${startYear}-${endYear}:"
    $fileList | ForEach-Object { Write-Host $_.Name }

    if ($fileList.Count -gt 0) {
        # Compress the files into the archive
        Compress-Archive -Path $fileList.FullName -DestinationPath $archivePath
    }
    else {
        Write-Host "No files found for the fiscal year ${startYear}-${endYear}."
    }

    # Move to the next fiscal year
    $fiscalYearStart = $fiscalYearStart.AddYears(1)
    $fiscalYearEnd = $fiscalYearEnd.AddYears(1)
}

# Process the last fiscal year separately if it extends beyond the end date for processing
$archiveName = "Archive_${fiscalYearStart.Year}-to-${endDateForProcessing.Year}.zip"
$archivePath = Join-Path -Path $destinationFolder -ChildPath $archiveName

$fileList = Get-ChildItem -Path $sourceFolder | Where-Object { $_.Attributes -eq 'Archive' -and $_.LastWriteTime -ge $fiscalYearStart -and $_.LastWriteTime -lt $endDateForProcessing }

Write-Host "Files for the last fiscal year ${fiscalYearStart.Year}-to-${endDateForProcessing.Year}:"
$fileList | ForEach-Object { Write-Host $_.Name }

if ($fileList.Count -gt 0) {
    Compress-Archive -Path $fileList.FullName -DestinationPath $archivePath
}
else {
    Write-Host "No files found for the last fiscal year ${fiscalYearStart.Year}-to-${endDateForProcessing.Year}."
}
