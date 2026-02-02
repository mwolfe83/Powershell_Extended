# Path to input file
$importPath = Join-Path $PSScriptRoot 'import.txt'

# Path to the persistent log file
$logPath = Join-Path $PSScriptRoot 'AddSMTPProxyAddress.log'

# Who ran the script
$currentUser = "$env:USERDOMAIN\$env:USERNAME"

# Write-Log function with log levels
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "ERROR", "WARN", "SUCCESS")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$Level] $timestamp [$currentUser] $Message"
    Add-Content -Path $logPath -Value $entry
    # Optionally, echo INFO/WARN/SUCCESS to host
    if ($Level -eq "ERROR") {
        Write-Host $entry -ForegroundColor Red
    } elseif ($Level -eq "WARN") {
        Write-Host $entry -ForegroundColor Yellow
    } else {
        Write-Host $entry
    }
}

Write-Log "Script started." "INFO"

# Ensure the import file exists
if (-not (Test-Path $importPath)) {
    Write-Log "Input file not found at $importPath" "ERROR"
    exit 1
}

# Read usernames from file
$usernames = Get-Content $importPath | Where-Object { $_ -and $_.Trim() -ne '' }

if ($usernames.Count -eq 0) {
    Write-Log "No usernames found in $importPath" "WARN"
    exit 0
}

Import-Module ActiveDirectory

foreach ($username in $usernames) {
    try {
        $user = Get-ADUser -Identity $username -Properties UserPrincipalName, ProxyAddresses
        if ($null -eq $user) {
            Write-Log "User not found: $username" "ERROR"
            continue
        }

        $upn = $user.UserPrincipalName
        if ([string]::IsNullOrWhiteSpace($upn)) {
            Write-Log "No UPN for user: $username" "ERROR"
            continue
        }

        $smtpAddress = "SMTP:$upn"

        # Check if it already exists
        if ($user.ProxyAddresses -contains $smtpAddress) {
            Write-Log "User $username already has proxyAddress $smtpAddress" "INFO"
        } else {
            Set-ADUser -Identity $username -Add @{ proxyAddresses = $smtpAddress }
            Write-Log "Added $smtpAddress to $username" "SUCCESS"
        }
    }
    catch {
        Write-Log "Error processing $($username): $($_.Exception.Message)" "ERROR"
    }
}
Write-Log "Script complete." "INFO"
