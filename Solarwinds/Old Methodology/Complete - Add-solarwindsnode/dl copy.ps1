# Define the source and destination users
$SourceUser = "usera@genesco.com"
$DestinationUser = "userb@genesco.com"
# Connect to Exchange Online
Connect-ExchangeOnline
# Retrieve all groups the source user is a member of
$Groups = Get-Recipient -Filter "Members -eq '$SourceUser'"
# Filter only distribution groups
$DistributionGroups = $Groups | Where-Object { $_.RecipientTypeDetails -eq 'MailUniversalDistributionGroup' }
# Add the destination user to each distribution group
foreach ($DL in $DistributionGroups) {
   try {
       Add-DistributionGroupMember -Identity $DL.Identity -Member $DestinationUser -ErrorAction Stop
       Write-Host "Added $DestinationUser to $($DL.Identity)"
   } catch {
       Write-Host "Failed to add $DestinationUser to $($DL.Identity): $_" -ForegroundColor Red
   }
}
# Disconnect from Exchange Online
Disconnect-ExchangeOnline -Confirm:$false