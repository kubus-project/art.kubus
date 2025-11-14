#!/bin/bash
# Database Migration Script for art.kubus Backend
# Run this script to set up or update the database schema

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DB_USER="${DB_USER:-artkubus}"
DB_NAME="${DB_NAME:-artkubus}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DOCKER_CONTAINER="${DOCKER_CONTAINER:-artkubus-postgres}"

echo -e "${GREEN}=== art.kubus Database Migration ===${NC}"
echo ""

# Check if running in Docker or direct PostgreSQL
if docker ps | grep -q "$DOCKER_CONTAINER"; then
    echo -e "${GREEN}✓${NC} Found Docker container: $DOCKER_CONTAINER"
    USE_DOCKER=true
    PSQL_CMD="docker exec -i $DOCKER_CONTAINER psql -U $DB_USER -d $DB_NAME"
else
    echo -e "${YELLOW}⚠${NC} Docker container not found. Using direct PostgreSQL connection."
    USE_DOCKER=false
    PSQL_CMD="psql -U $DB_USER -d $DB_NAME -h $DB_HOST -p $DB_PORT"
fi

# Function to run SQL command
run_sql() {
    if [ "$USE_DOCKER" = true ]; then
        echo "$1" | docker exec -i $DOCKER_CONTAINER psql -U $DB_USER -d $DB_NAME
    else
        echo "$1" | psql -U $DB_USER -d $DB_NAME -h $DB_HOST -p $DB_PORT
    fi
}

# Function to run SQL file
run_sql_file() {
    if [ "$USE_DOCKER" = true ]; then
        docker exec -i $DOCKER_CONTAINER psql -U $DB_USER -d $DB_NAME < "$1"
    else
        psql -U $DB_USER -d $DB_NAME -h $DB_HOST -p $DB_PORT -f "$1"
    fi
}

echo ""
echo -e "${YELLOW}Step 1: Checking database connection...${NC}"
if run_sql "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Database connection successful"
else
    echo -e "${RED}✗${NC} Database connection failed"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 2: Enabling required extensions...${NC}"
run_sql 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'
echo -e "${GREEN}✓${NC} uuid-ossp extension enabled"

echo ""
echo -e "${YELLOW}Step 3: Checking existing schema...${NC}"
EXISTING_TABLES=$(run_sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('collections', 'notifications', 'search_history');" | grep -oP '\d+' | head -1)
echo "   Found $EXISTING_TABLES existing tables"

if [ "$EXISTING_TABLES" -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC} Some tables already exist. This migration will update them."
    read -p "   Create backup before proceeding? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
        echo "   Creating backup: $BACKUP_FILE"
        if [ "$USE_DOCKER" = true ]; then
            docker exec $DOCKER_CONTAINER pg_dump -U $DB_USER $DB_NAME > "$BACKUP_FILE"
        else
            pg_dump -U $DB_USER -d $DB_NAME -h $DB_HOST -p $DB_PORT > "$BACKUP_FILE"
        fi
        echo -e "${GREEN}✓${NC} Backup created: $BACKUP_FILE"
    fi
fi

echo ""
echo -e "${YELLOW}Step 4: Running migration 008_wallet_address_schema.sql...${NC}"
if [ -f "008_wallet_address_schema.sql" ]; then
    run_sql_file "008_wallet_address_schema.sql"
    echo -e "${GREEN}✓${NC} Migration completed successfully"
else
    echo -e "${RED}✗${NC} Migration file not found: 008_wallet_address_schema.sql"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 5: Verifying migration...${NC}"

# Check tables
TABLES=$(run_sql "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename IN ('collections', 'collection_artworks', 'notifications', 'search_history');" | grep -E '^(collections|collection_artworks|notifications|search_history)$' | wc -l)
echo "   Tables created: $TABLES/4"
if [ "$TABLES" -eq 4 ]; then
    echo -e "${GREEN}✓${NC} All tables created"
else
    echo -e "${YELLOW}⚠${NC} Some tables missing"
fi

# Check columns (wallet_address based)
WALLET_COLS=$(run_sql "SELECT COUNT(*) FROM information_schema.columns WHERE table_name IN ('collections', 'notifications', 'search_history') AND column_name LIKE '%wallet%';" | grep -oP '\d+' | head -1)
echo "   Wallet address columns found: $WALLET_COLS"
if [ "$WALLET_COLS" -ge 3 ]; then
    echo -e "${GREEN}✓${NC} Schema uses wallet_address (correct)"
else
    echo -e "${YELLOW}⚠${NC} Schema may still use old UUID columns"
fi

# Check indexes
INDEXES=$(run_sql "SELECT COUNT(*) FROM pg_indexes WHERE tablename IN ('collections', 'notifications', 'search_history');" | grep -oP '\d+' | head -1)
echo "   Indexes created: $INDEXES"
if [ "$INDEXES" -gt 10 ]; then
    echo -e "${GREEN}✓${NC} Indexes created"
fi

# Check triggers
TRIGGERS=$(run_sql "SELECT COUNT(*) FROM pg_trigger WHERE tgrelid::regclass::text IN ('collections', 'collection_artworks', 'notifications') AND tgisinternal = false;" | grep -oP '\d+' | head -1)
echo "   Triggers created: $TRIGGERS"
if [ "$TRIGGERS" -ge 3 ]; then
    echo -e "${GREEN}✓${NC} Triggers created"
fi

echo ""
echo -e "${GREEN}=== Migration Summary ===${NC}"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Tables: $TABLES/4"
echo "Indexes: $INDEXES"
echo "Triggers: $TRIGGERS"
echo ""

if [ "$TABLES" -eq 4 ] && [ "$WALLET_COLS" -ge 3 ]; then
    echo -e "${GREEN}✓ Migration completed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Restart backend: docker-compose restart backend"
    echo "2. Test endpoints: curl http://localhost:3000/api/collections"
    echo "3. Verify data: docker exec -i $DOCKER_CONTAINER psql -U $DB_USER -d $DB_NAME -c '\d collections'"
    exit 0
else
    echo -e "${YELLOW}⚠ Migration completed with warnings${NC}"
    echo "Please check the output above for details"
    exit 1
fi
