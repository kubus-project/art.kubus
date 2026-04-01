param()

$ErrorActionPreference = 'Stop'

$exitCode = 1
$cleanupScript = Join-Path $PSScriptRoot 'cleanup_flutter_machine_test_processes.ps1'
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

try {
  & $cleanupScript -Phase 'pre'

  $testFiles = @($args)

  if ($testFiles.Count -gt 0) {
    Write-Host "safe_flutter_test: running -> flutter test $($testFiles -join ' ')"
    & flutter test $testFiles
  } else {
    Write-Host 'safe_flutter_test: running -> flutter test'
    & flutter test
  }
  $exitCode = $LASTEXITCODE
} catch {
  Write-Error "safe_flutter_test: test run failed: $($_.Exception.Message)"
  $exitCode = 1
} finally {
  try {
    & $cleanupScript -Phase 'post'
  } catch {
    Write-Warning "safe_flutter_test: cleanup failed: $($_.Exception.Message)"
  }
  Pop-Location
}

exit $exitCode
