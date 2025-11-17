param(
  [string]$WalletAddress = "test_wallet_0001",
  [string]$Wallets = "",
  [string]$ConversationId = "",
  [string]$MessageId = "",
  [string]$BaseUrl = "http://localhost:3000/api",
  [string]$OutFile = "./logs/smoke-test.log"
)

# Ensure logs dir exists
$logDir = Split-Path $OutFile -Parent
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Log($line) {
  $ts = (Get-Date).ToString('o')
  $entry = "$ts `t $line"
  $entry | Out-File -FilePath $OutFile -Append -Encoding utf8
  Write-Host $entry
}

Log "Starting smoke test. WalletAddress=$WalletAddress Wallets=$Wallets ConversationId=$ConversationId MessageId=$MessageId BaseUrl=$BaseUrl"

try {
  Log "1) POST /profiles/issue-token with wallet $WalletAddress"
  $body = @{ walletAddress = $WalletAddress } | ConvertTo-Json
  $res = Invoke-RestMethod -Uri "$BaseUrl/profiles/issue-token" -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop
  Log "-> status: success=$($res.success) tokenPresent=$([string]::IsNullOrEmpty($res.token) -eq $false)"
  $token = $res.token
} catch {
  Log "-> ERROR issuing token: $($_.Exception.Message)"
  exit 2
}

# Try GET /profiles/me
try {
  Log "2) GET /profiles/me (with token)"
  $headers = @{ Authorization = "Bearer $token" }
  $me = Invoke-RestMethod -Uri "$BaseUrl/profiles/me" -Method Get -Headers $headers -ErrorAction Stop
  Log "-> /me success=$($me.success) dataPresent=$([string]::IsNullOrEmpty($me.data.walletAddress) -eq $false)"
  Log "-> /me response: $($(ConvertTo-Json $me -Depth 3))"
} catch {
  Log "-> /me ERROR: $($_.Exception.Message)"
}

# Batch
if ($Wallets -ne "") {
  $walletsArr = $Wallets -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
} else {
  $walletsArr = @($WalletAddress)
}

try {
  Log "3) POST /profiles/batch with wallets: $($walletsArr -join ',')"
  $body = @{ wallets = $walletsArr } | ConvertTo-Json
  $batch = Invoke-RestMethod -Uri "$BaseUrl/profiles/batch" -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop
  Log "-> /profiles/batch success=$($batch.success) count=$($batch.count)"
  Log "-> /profiles/batch response: $($(ConvertTo-Json $batch -Depth 3))"
} catch {
  Log "-> /profiles/batch ERROR: $($_.Exception.Message)"
}

# GET /messages
try {
  Log "4) GET /messages (with token)"
  $headers = @{ Authorization = "Bearer $token" }
  $msgs = Invoke-RestMethod -Uri "$BaseUrl/messages" -Method Get -Headers $headers -ErrorAction Stop
  Log "-> /messages success=$($msgs.success) count=$($msgs.count)"
  Log "-> /messages response: $($(ConvertTo-Json $msgs -Depth 2))"
} catch {
  Log "-> /messages ERROR: $($_.Exception.Message)"
}

# Optional: mark specific message read (per-message endpoint)
if ($ConversationId -and $MessageId) {
  try {
    Log "5) PUT /messages/$ConversationId/messages/$MessageId/read (per-message)"
    $headers = @{ Authorization = "Bearer $token" }
    $r = Invoke-RestMethod -Uri "$BaseUrl/messages/$ConversationId/messages/$MessageId/read" -Method Put -Headers $headers -ErrorAction Stop
    Log "-> per-message read response: $($(ConvertTo-Json $r -Depth 2))"
  } catch {
    Log "-> per-message read ERROR: $($_.Exception.Message)"
  }

  try {
    Log "6) PUT /messages/$ConversationId/read (conversation-level)"
    $headers = @{ Authorization = "Bearer $token" }
    $r2 = Invoke-RestMethod -Uri "$BaseUrl/messages/$ConversationId/read" -Method Put -Headers $headers -ErrorAction Stop
    Log "-> conversation-level read response: $($(ConvertTo-Json $r2 -Depth 2))"
  } catch {
    Log "-> conversation-level read ERROR: $($_.Exception.Message)"
  }
}

Log "Smoke test completed"

exit 0
