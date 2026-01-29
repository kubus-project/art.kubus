param(
  [string]$BaseHref = '/',
  [ValidateSet('canvaskit', 'html', 'auto')][string]$Renderer = 'canvaskit',
  [switch]$DisableServiceWorker,
  [switch]$EnableSourceMaps
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$webArgs = @('build', 'web', "--base-href=$BaseHref", "--web-renderer=$Renderer", '--no-web-resources-cdn')

if ($DisableServiceWorker) {
  $webArgs += '--pwa-strategy=none'
}

if ($EnableSourceMaps) {
  $webArgs += '--source-maps'
}

& flutter @webArgs
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$buildDir = Join-Path $root 'build\web'
$htaccess = Join-Path $root 'web\.htaccess'
if (Test-Path $htaccess) {
  Copy-Item $htaccess -Destination $buildDir -Force
}
