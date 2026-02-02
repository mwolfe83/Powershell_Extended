param([switch]$WhatIf)

# --- Config ---
$SolarWindsServer = 'p01-wa-sol-01.genesco.local'
$SolarWindsUser   = 'solarwinds_poller'
$PasswordstateUrl = 'https://pwstate.genesco.local/api/passwords/4256'
$ApiKey           = 'afc6e4b2338d957a9352bd38c4f76ee2'
$NodesFile        = Join-Path $PSScriptRoot 'Nodes.txt'  # "Caption  IP_Address"
# ---------------

if (-not (Test-Path $NodesFile)) { Write-Error "Missing $NodesFile"; exit 1 }

# Parse file (tabs/spaces/commas; skip blanks/comments/header)
$rows = @()
Get-Content $NodesFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -eq '' -or $line -match '^[#;]') { return }
  $p = $line -split '[,`\t ]+' | Where-Object { $_ -ne '' }
  if ($p.Count -ge 2) {
    $cap=$p[0].Trim(); $ip=$p[1].Trim()
    if ($cap -match '^(caption)$' -and $ip -match '^(ip|ip_address)$') { return }
    $rows += [pscustomobject]@{ Caption=$cap; IP=$ip }
  }
}
if (-not $rows) { Write-Error "No valid Caption/IP pairs found in $NodesFile"; exit 1 }

# Auth + connect
try {
  $pw = (Invoke-RestMethod -Uri $PasswordstateUrl -Header @{ APIKey=$ApiKey }).password
  $sw = Connect-Swis -Hostname $SolarWindsServer -Username $SolarWindsUser -Password $pw
} catch { Write-Error "Failed to connect/authenticate: $($_.Exception.Message)"; exit 1 }

# Query: match by caption or IP (node primary or interface), return NodeID & Uri
$query = @"
SELECT DISTINCT n.NodeID, n.Caption, n.Uri
FROM Orion.Nodes n
LEFT JOIN Orion.NodeIPAddresses ipa ON ipa.NodeID = n.NodeID
WHERE n.Caption = @cap
   OR n.IPAddress = @ip
   OR n.IP_Address = @ip
   OR ipa.IPAddress = @ip
"@

$deleted=0; $notFound=@(); $errs=@()
Write-Host "Processing $($rows.Count) entries from $NodesFile ..."

foreach ($r in $rows) {
  $cap=$r.Caption; $ip=$r.IP
  try {
    $nodes = @( Get-SwisData -SwisConnection $sw -Query $query -Parameters @{ cap=$cap; ip=$ip } )
    if (-not $nodes) { $notFound += "$cap|$ip"; continue }

    # de-dup by NodeID
    $seen=@{}
    foreach ($n in $nodes) {
      $nid=[int]$n.NodeID
      if ($seen.ContainsKey($nid)) { continue }
      $seen[$nid]=$true

      $uri=$n.Uri
      $c  = if ($n.Caption) { $n.Caption } else { '<no caption>' }

      if ($WhatIf) {
        Write-Host "[WhatIf] Would delete NodeID=$nid Caption='$c' IP=$ip"
        continue
      }

      try {
        if (-not $uri) { throw "No Uri for NodeID=$nid" }
        Remove-SwisObject -SwisConnection $sw -Uri $uri -ErrorAction Stop

        # verify: re-query by NodeID
        $check = Get-SwisData -SwisConnection $sw -Query "SELECT NodeID FROM Orion.Nodes WHERE NodeID=@id" -Parameters @{ id = $nid }
        if ($check) {
          Write-Warning "STILL PRESENT after delete attempt: NodeID=$nid Caption='$c' IP=$ip"
          $errs += "$cap|$ip (NodeID=$nid) -> delete attempted, but node still present"
        } else {
          Write-Host "Deleted NodeID=$nid Caption='$c' IP=$ip"
          $deleted++
        }
      } catch {
        $errs += "$cap|$ip (NodeID=$nid) -> $($_.Exception.Message)"
      }
    }
  } catch {
    $errs += "$cap|$ip -> $($_.Exception.Message)"
  }
}

Write-Host "-----"
if ($WhatIf) { Write-Host "WhatIf complete." } else { Write-Host "Deleted: $deleted node(s)." }
if ($notFound) { Write-Host "No match for:`n - " + ($notFound -join "`n - ") }
if ($errs)    { Write-Warning ("Errors:`n - " + ($errs -join "`n - ")) }
