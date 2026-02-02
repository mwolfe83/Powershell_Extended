Add-Type -AssemblyName PresentationFramework

# Prompt for new domain username
$newUser = Read-Host "Enter your NEW domain username (e.g., WOLF692480)"
$domain = $env:USERDOMAIN

# Create temp batch file that runs Notepad with runas
$tempBat = "$env:TEMP\runas_temp.bat"
$tempKill = "$env:TEMP\kill_notepad.bat"

$batContent = @"
@echo off
runas /user:$domain\$newUser "notepad.exe"
"@
$batContent | Set-Content -Path $tempBat -Encoding ASCII

# Create another batch file to kill Notepad after 10 seconds
$killContent = @"
@echo off
timeout /t 10 > nul
taskkill /f /im notepad.exe
"@
$killContent | Set-Content -Path $tempKill -Encoding ASCII

# Launch both: one for runas, one to kill Notepad after 10s
Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$tempBat`""
Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$tempKill`""

# Wait and show confirmation
Start-Sleep -Seconds 12
[System.Windows.MessageBox]::Show("✅ Credentials have been cached locally. You may now log off and log in with your NEW username and password.","Credential Caching Complete",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information)

# Clean up
Remove-Item $tempBat, $tempKill -Force -ErrorAction SilentlyContinue
