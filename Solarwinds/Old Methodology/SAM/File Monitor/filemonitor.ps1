param([string]$path, [int]$minutes,[bool]$Recursive)
# Created by Thwack user Chad.Every. See https://thwack.solarwinds.com/docs/DOC- for more detail.

#Example, change this path to the folder/file type you wish to monitor. Wildcard in file name and extension are supported.
#$path="c:\temp\*.txt"

$stat=0
$msg=""

write-host "Path $path"
write-host "time $minutes"
write-host "recurse $recursive"

try
{    
    $LastWrite = $(Get-Date).AddMinutes(-$minutes)
    
    if ($Recursive) {
        $FileArray = $(Get-ChildItem $path -Recurse | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $LastWrite })
    }
    else {
        $FileArray = $(Get-ChildItem $path | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $LastWrite })
    }

    if (($FileArray | Measure-Object).count = "0")
    {
        $msg = "No file found over $($minutes) minutes old"
    }
    else
    {
        $stat= ($FileArray | Measure-Object).count
        $msg = "$($stat) files found older than $($minutes) minutes: "
        foreach ($file in $FileArray)
        {
            $msg+=" " + $file + ","
        }
    }
}
catch
{
    $stat=1
    $msg=$_.Exception.Message
}

Write-Host "Statistic: $stat"
Write-Host "Message: $msg"

exit 0