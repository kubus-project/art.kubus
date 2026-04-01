param(
  [string]$Phase = 'manual'
)

$ErrorActionPreference = 'Stop'

$processes = @(Get-CimInstance Win32_Process | Where-Object {
  $_.Name -eq 'dart.exe' -and (
    $_.CommandLine -match 'flutter_tools\.snapshot\s+test\s+--machine' -or
    $_.CommandLine -match 'flutter_tools\.snapshot\s+debug_adapter\s+--test'
  )
})

if ($processes.Count -eq 0) {
  Write-Host "cleanup_flutter_machine_test_processes: [$Phase] no stale machine test processes found."
  exit 0
}

$ids = $processes | Select-Object -ExpandProperty ProcessId
Write-Host "cleanup_flutter_machine_test_processes: [$Phase] stopping stale processes: $($ids -join ', ')"

foreach ($process in $processes) {
  try {
    Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
  } catch {
    Write-Warning "cleanup_flutter_machine_test_processes: unable to stop process $($process.ProcessId): $($_.Exception.Message)"
  }
}
