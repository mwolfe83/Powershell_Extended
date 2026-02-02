[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [string[]]$user,
    [Parameter(Mandatory=$True)]
    [string[]]$filename
)


Start-Transcript -Path C:\Users\Public\$filename.txt -Append

$errormessage = "There were no errors."
$scriptoutcome = "The session ended successfully."

Add-PSSnapin Citrix.Broker.Admin.V2
#$users = Import-Csv "\\nw02\userdata$\mlively\Temp\CCOutlookIssueUsernames.csv"

#foreach ($user in $users)
#{

$num = $user -replace '\D+([0-9]*).*','$1'
$div = $user -replace '[^a-zA-Z]'
$flip = $div + $num

    $Username = "NT_GENESCO\$flip"
    $continue = $true

    ##Must be able to account for multiple sessions going. Can use something like 
    ##(Get-BrokerSession -UserName $Username).SessionState.Count to weed out anything greater than 1
    $session = Get-BrokerSession -AdminAddress "p01-wc-brk-01.genesco.local" -UserName $Username
    $sessionstatus = $session.SessionState

    if (($sessionstatus -eq "Active") -or ($sessionstatus -eq "Disconnected"))
    {
       #Write-Host "$Username has active or disconnected session." -ForegroundColor Red
       #$endsession = (Read-Host "User has at least one session active or disconnected. Has user saved all needed information and agreed to be logged out (y/n)?").ToLower()
    
       # if ($endsession -eq "y")
       # {
       #     Write-Host "Sessions will now be ended."
            $session | Stop-BrokerSession
            
            $counter = 0
            do {
                Start-Sleep -Seconds 10
                $sessioncount = (Get-BrokerSession -AdminAddress "p01-wc-brk-01.genesco.local" -UserName $Username).count
                $counter += 1
            } Until (($sessioncount -eq 0) -or ($counter -ge 7))
    
            if ($counter -ge 7)
           {
                $errormessage = "Timeout has been reached waiting for session to end, please send the ticket to Platform Systems (Server Support)."
                $continue = $false
                $scriptoutcome = "fail (see below)"
            }
        
       
    }
    else
    {
        $errormessage = "There were no sessions found to be cleared."
        $scriptoutcome = "fail (see below)"
    }
    
Write-Host "<error>$errormessage</error>"
Write-Host "<scriptoutcome>$scriptoutcome</scriptoutcome>"

Stop-Transcript