# Database Migration Script for art.kubus Backend (PowerShell)
# Run this script to set up or update the database schema

param(
    [string]$DbUser = "artkubus",
    [string]$DbName = "artkubus",
    [string]$DbHost = "localhost",
    [int]$DbPort = 5432,
    [string]$DockerContainer = "artkubus-postgres"
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }
function Write-Info { Write-Host $args -ForegroundColor Cyan }

Write-Success "=== art.kubus Database Migration ==="
Write-Host ""

# Check if running in Docker or direct PostgreSQL
$UseDocker = $false
try {
    $containerCheck = docker ps --filter "name=$DockerContainer" --format "{{.Names}}" 2>$null
    if ($containerCheck -eq $DockerContainer) {
        Write-Success "✓ Found Docker container: $DockerContainer"
        $UseDocker = $true
    }
} catch {
    Write-Warning "⚠ Docker not available or container not found. Using direct PostgreSQL connection."
}

# Function to run SQL command
function Invoke-Sql {
    param([string]$SqlCommand)
    
    if ($UseDocker) {
        $SqlCommand | docker exec -i $DockerContainer psql -U $DbUser -d $DbName
    } else {
        $env:PGPASSWORD = Read-Host "Enter PostgreSQL password" -AsSecureString
        $SqlCommand | psql -U $DbUser -d $DbName -h $DbHost -p $DbPort
    }
}

# Function to run SQL file
function Invoke-SqlFile {
    param([string]$FilePath)
    
    if ($UseDocker) {
        Get-Content $FilePath | docker exec -i $DockerContainer psql -U $DbUser -d $DbName
    } else {
        psql -U $DbUser -d $DbName -h $DbHost -p $DbPort -f $FilePath
    }
}

Write-Host ""
Write-Warning "Step 1: Checking database connection..."
try {
    Invoke-Sql "SELECT 1;" | Out-Null
    Write-Success "✓ Database connection successful"
} catch {
    Write-Error "✗ Database connection failed"
    Write-Error $_.Exception.Message
    exit 1
}

Write-Host ""
Write-Warning "Step 2: Enabling required extensions..."
Invoke-Sql 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";' | Out-Null
Write-Success "✓ uuid-ossp extension enabled"

Write-Host ""
Write-Warning "Step 3: Checking existing schema..."
$existingTablesQuery = "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('collections', 'notifications', 'search_history');"
$existingTables = (Invoke-Sql $existingTablesQuery | Select-String -Pattern '^\s*\d+\s*$' | Select-Object -First 1).ToString().Trim()
Write-Host "   Found $existingTables existing tables"

if ([int]$existingTables -gt 0) {
    Write-Warning "⚠ Some tables already exist. This migration will update them."
    $backup = Read-Host "   Create backup before proceeding? (y/n)"
    if ($backup -eq 'y' -or $backup -eq 'Y') {
        $backupFile = "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"
        Write-Host "   Creating backup: $backupFile"
        if ($UseDocker) {
            docker exec $DockerContainer pg_dump -U $DbUser $DbName | Out-File -FilePath $backupFile -Encoding utf8
        } else {
            pg_dump -U $DbUser -d $DbName -h $DbHost -p $DbPort | Out-File -FilePath $backupFile -Encoding utf8
        }
        Write-Success "✓ Backup created: $backupFile"
    }
}

Write-Host ""
Write-Warning "Step 4: Running migration 008_wallet_address_schema.sql..."
$migrationFile = Join-Path $PSScriptRoot "008_wallet_address_schema.sql"
if (Test-Path $migrationFile) {
    try {
        Invoke-SqlFile $migrationFile | Out-Null
        Write-Success "✓ Migration completed successfully"
    } catch {
        Write-Error "✗ Migration failed"
        Write-Error $_.Exception.Message
        exit 1
    }
} else {
    Write-Error "✗ Migration file not found: $migrationFile"
    exit 1
}

Write-Host ""
Write-Warning "Step 5: Verifying migration..."

# Check tables
$tablesQuery = "SELECT COUNT(*) FROM pg_tables WHERE schemaname='public' AND tablename IN ('collections', 'collection_artworks', 'notifications', 'search_history');"
$tables = (Invoke-Sql $tablesQuery | Select-String -Pattern '^\s*\d+\s*$' | Select-Object -First 1).ToString().Trim()
Write-Host "   Tables created: $tables/4"
if ([int]$tables -eq 4) {
    Write-Success "✓ All tables created"
} else {
    Write-Warning "⚠ Some tables missing"
}

# Check columns (wallet_address based)
$walletColsQuery = "SELECT COUNT(*) FROM information_schema.columns WHERE table_name IN ('collections', 'notifications', 'search_history') AND column_name LIKE '%wallet%';"
$walletCols = (Invoke-Sql $walletColsQuery | Select-String -Pattern '^\s*\d+\s*$' | Select-Object -First 1).ToString().Trim()
Write-Host "   Wallet address columns found: $walletCols"
if ([int]$walletCols -ge 3) {
    Write-Success "✓ Schema uses wallet_address (correct)"
} else {
    Write-Warning "⚠ Schema may still use old UUID columns"
}

# Check indexes
$indexesQuery = "SELECT COUNT(*) FROM pg_indexes WHERE tablename IN ('collections', 'notifications', 'search_history');"
$indexes = (Invoke-Sql $indexesQuery | Select-String -Pattern '^\s*\d+\s*$' | Select-Object -First 1).ToString().Trim()
Write-Host "   Indexes created: $indexes"
if ([int]$indexes -gt 10) {
    Write-Success "✓ Indexes created"
}

# Check triggers
$triggersQuery = "SELECT COUNT(*) FROM pg_trigger WHERE tgrelid::regclass::text IN ('collections', 'collection_artworks', 'notifications') AND tgisinternal = false;"
$triggers = (Invoke-Sql $triggersQuery | Select-String -Pattern '^\s*\d+\s*$' | Select-Object -First 1).ToString().Trim()
Write-Host "   Triggers created: $triggers"
if ([int]$triggers -ge 3) {
    Write-Success "✓ Triggers created"
}

Write-Host ""
Write-Success "=== Migration Summary ==="
Write-Host "Database: $DbName"
Write-Host "User: $DbUser"
Write-Host "Tables: $tables/4"
Write-Host "Indexes: $indexes"
Write-Host "Triggers: $triggers"
Write-Host ""

if ([int]$tables -eq 4 -and [int]$walletCols -ge 3) {
    Write-Success "✓ Migration completed successfully!"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. Restart backend: docker-compose restart backend"
    Write-Host "2. Test endpoints: Invoke-WebRequest http://localhost:3000/api/collections"
    Write-Host "3. Verify data: docker exec -i $DockerContainer psql -U $DbUser -d $DbName -c '\d collections'"
    exit 0
} else {
    Write-Warning "⚠ Migration completed with warnings"
    Write-Host "Please check the output above for details"
    exit 1
}
