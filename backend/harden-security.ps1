#!/usr/bin/env pwsh
# Security Hardening Script for art.kubus Backend
# Run this script to fix critical security issues

Write-Host "🔒 art.kubus Security Hardening Script" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$backendDir = "g:\WorkingDATA\art.kubus\art.kubus\backend"
Set-Location $backendDir

# Step 1: Generate Strong Secrets
Write-Host "Step 1: Generating strong secrets..." -ForegroundColor Yellow

$jwtSecret = node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
$encryptionKey = node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
$dbPassword = node -e "console.log(require('crypto').randomBytes(32).toString('base64').replace(/[+/=]/g, ''))"
$redisPassword = node -e "console.log(require('crypto').randomBytes(32).toString('base64').replace(/[+/=]/g, ''))"

Write-Host "✅ Generated strong secrets" -ForegroundColor Green

# Step 2: Backup current .env
Write-Host "`nStep 2: Backing up current .env..." -ForegroundColor Yellow

if (Test-Path ".env") {
    Copy-Item ".env" ".env.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Write-Host "✅ Backed up to .env.backup.*" -ForegroundColor Green
}

# Step 3: Create secure .env
Write-Host "`nStep 3: Creating secure .env file..." -ForegroundColor Yellow

$secureEnv = @"
NODE_ENV=production
PORT=3000

# API Base URL
HTTP_BASE_URL=https://api.kubus.site

# Database Configuration
DATABASE_URL=postgresql://artkubus:${dbPassword}@postgres:5432/artkubus

# Redis Configuration
REDIS_URL=redis://:${redisPassword}@redis:6379

# Security - KEEP THESE SECRET!
JWT_SECRET=${jwtSecret}
ENCRYPTION_KEY=${encryptionKey}

# CORS - Restrict to your domains
CORS_ORIGIN=https://art.kubus.site,https://kubus.site,https://api.kubus.site

# Storage Configuration
DEFAULT_STORAGE_PROVIDER=http
ENABLE_IPFS=false
ENABLE_HTTP_STORAGE=true
HTTP_STORAGE_PATH=./uploads

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
UPLOAD_RATE_LIMIT=20

# Solana Network
SOLANA_NETWORK=devnet
"@

$secureEnv | Out-File -FilePath ".env" -Encoding utf8
Write-Host "✅ Created secure .env with strong secrets" -ForegroundColor Green

# Step 4: Save secrets to secure file
Write-Host "`nStep 4: Saving secrets to secure file..." -ForegroundColor Yellow

$secretsFile = @"
# BACKUP THESE SECRETS SECURELY!
# Store in a password manager, never commit to git

JWT_SECRET=${jwtSecret}
ENCRYPTION_KEY=${encryptionKey}
DB_PASSWORD=${dbPassword}
REDIS_PASSWORD=${redisPassword}

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@

$secretsFile | Out-File -FilePath ".secrets.txt" -Encoding utf8
Write-Host "✅ Secrets saved to .secrets.txt (keep this file secure!)" -ForegroundColor Green

# Step 5: Update docker-compose.yml for security
Write-Host "`nStep 5: Updating docker-compose.yml..." -ForegroundColor Yellow

$dockerCompose = Get-Content "docker-compose.yml" -Raw

# Bind postgres to localhost only
$dockerCompose = $dockerCompose -replace '- "5432:5432"', '- "127.0.0.1:5432:5432"'

# Bind redis to localhost only and add password
$redisCmd = "command: redis-server --appendonly yes --requirepass " + "`${REDIS_PASSWORD}"
$dockerCompose = $dockerCompose -replace 'command: redis-server --appendonly yes', $redisCmd
$dockerCompose = $dockerCompose -replace '- "6379:6379"', '- "127.0.0.1:6379:6379"'

# Change backend to expose only (not publicly accessible)
$dockerCompose = $dockerCompose -replace '- "3000:3000"', '# - "3000:3000"  # Commented for security - use nginx'

$dockerCompose | Out-File -FilePath "docker-compose.yml" -Encoding utf8
Write-Host "Secured Docker container ports" -ForegroundColor Green

# Step 6: Verify .gitignore
Write-Host "`nStep 6: Verifying .gitignore..." -ForegroundColor Yellow

$gitignoreContent = @"
# Environment files
.env
.env.local
.env.production
.env.*.local
.env.backup.*
.secrets.txt

# SSL certificates
ssl/
certbot/

# Uploads
uploads/
*.log

# Node modules
node_modules/
"@

if (!(Test-Path ".gitignore")) {
    $gitignoreContent | Out-File -FilePath ".gitignore" -Encoding utf8
    Write-Host "✅ Created .gitignore" -ForegroundColor Green
} else {
    Write-Host "⚠️  .gitignore exists, please verify it includes sensitive files" -ForegroundColor Yellow
}

# Step 7: Update environment variables in docker-compose.production.yml
Write-Host "`nStep 7: Updating production compose file..." -ForegroundColor Yellow

if (Test-Path "docker-compose.production.yml") {
    Write-Host "Production compose file found - manual update recommended" -ForegroundColor Yellow
    Write-Host "Add DB_PASSWORD and REDIS_PASSWORD to docker-compose.production.yml manually" -ForegroundColor Yellow
}

# Step 8: Restart containers
Write-Host "`nStep 8: Restarting Docker containers..." -ForegroundColor Yellow

docker-compose down
$env:DB_PASSWORD = $dbPassword
$env:REDIS_PASSWORD = $redisPassword
docker-compose up -d --build

Write-Host "✅ Containers restarted with new configuration" -ForegroundColor Green

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "🎉 Security Hardening Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "What was done:" -ForegroundColor White
Write-Host "  ✅ Generated strong JWT_SECRET (128 chars)" -ForegroundColor Green
Write-Host "  ✅ Generated strong ENCRYPTION_KEY (64 chars)" -ForegroundColor Green
Write-Host "  ✅ Generated strong DB_PASSWORD" -ForegroundColor Green
Write-Host "  ✅ Generated strong REDIS_PASSWORD" -ForegroundColor Green
Write-Host "  ✅ Restricted database port to localhost" -ForegroundColor Green
Write-Host "  ✅ Restricted Redis port to localhost" -ForegroundColor Green
Write-Host "  ✅ Removed backend direct port access" -ForegroundColor Green
Write-Host "  ✅ Added Redis authentication" -ForegroundColor Green
Write-Host "  ✅ Restricted CORS to your domains" -ForegroundColor Green
Write-Host "  ✅ Backed up old configuration" -ForegroundColor Green

Write-Host "`nIMPORTANT NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. BACKUP .secrets.txt to a secure location (password manager)" -ForegroundColor White
Write-Host "  2. NEVER commit .env or .secrets.txt to git" -ForegroundColor White
Write-Host "  3. Enable SSL/HTTPS (see SSL_SETUP.md)" -ForegroundColor White
Write-Host "  4. Test your application" -ForegroundColor White
Write-Host "  5. Delete .env.backup.* files after verification" -ForegroundColor White
Write-Host "  6. Run security audit: npm audit" -ForegroundColor White

Write-Host "`nTest your setup:" -ForegroundColor Cyan
Write-Host "  curl http://localhost/health" -ForegroundColor White
Write-Host "  docker ps  # Verify all containers running" -ForegroundColor White

Write-Host "`n⚠️  WARNING: Keep .secrets.txt secure and delete after backing up!" -ForegroundColor Red
