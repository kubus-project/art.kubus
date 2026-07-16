param(
  [string]$BaseHref = '/',
  [switch]$DisableServiceWorker,
  [switch]$EnableSourceMaps
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$webArgs = @(
  'build',
  'web',
  "--base-href=$BaseHref",
  '--no-web-resources-cdn',
  '--dart-define=PUBLIC_FLUTTER_TAKEOVER_ENABLED=true',
  '--dart-define=SEO_PUBLIC_PAGES_ENABLED=true'
)

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
