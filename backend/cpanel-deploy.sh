#!/bin/bash

# ============================================
# art.kubus Backend - cPanel Deployment Script
# ============================================
# This script sets up the backend on cPanel hosting with Node.js
# 
# Prerequisites:
# - cPanel with Node.js support (version 20+)
# - PostgreSQL database access
# - SSH access (recommended)
#
# Usage:
#   chmod +x cpanel-deploy.sh
#   ./cpanel-deploy.sh

set -e  # Exit on error

echo "🚀 art.kubus Backend - cPanel Deployment"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="artkubus-backend"
APP_DIR="$HOME/art.kubus/backend"
NODE_VERSION="20"

# Step 1: Check Node.js version
echo -e "\n${YELLOW}Step 1: Checking Node.js version...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js not found. Please install Node.js $NODE_VERSION via cPanel.${NC}"
    exit 1
fi

CURRENT_NODE_VERSION=$(node -v | cut -d 'v' -f 2 | cut -d '.' -f 1)
if [ "$CURRENT_NODE_VERSION" -lt "$NODE_VERSION" ]; then
    echo -e "${RED}❌ Node.js version too old. Required: v$NODE_VERSION+, Current: v$CURRENT_NODE_VERSION${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Node.js version: $(node -v)${NC}"

# Step 2: Check environment file
echo -e "\n${YELLOW}Step 2: Checking environment configuration...${NC}"
if [ ! -f "$APP_DIR/.env" ]; then
    echo -e "${YELLOW}⚠️  .env file not found. Creating from template...${NC}"
    
    if [ -f "$APP_DIR/.env.example" ]; then
        cp "$APP_DIR/.env.example" "$APP_DIR/.env"
        echo -e "${YELLOW}⚠️  Please edit $APP_DIR/.env with your credentials:${NC}"
        echo "   - DATABASE_URL"
        echo "   - JWT_SECRET (generate with: node -e \"console.log(require('crypto').randomBytes(64).toString('hex'))\")"
        echo "   - ENCRYPTION_KEY (generate with: node -e \"console.log(require('crypto').randomBytes(32).toString('hex'))\")"
        echo "   - PINATA_API_KEY and PINATA_SECRET (if using IPFS)"
        echo ""
        read -p "Press Enter after editing .env file..."
    else
        echo -e "${RED}❌ .env.example not found. Cannot proceed.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Environment file exists${NC}"

# Step 3: Install dependencies
echo -e "\n${YELLOW}Step 3: Installing dependencies...${NC}"
cd "$APP_DIR"

if [ -f "package-lock.json" ]; then
    npm ci --production
else
    npm install --production
fi

echo -e "${GREEN}✅ Dependencies installed${NC}"

# Step 4: Create required directories
echo -e "\n${YELLOW}Step 4: Creating required directories...${NC}"
mkdir -p "$APP_DIR/uploads"
mkdir -p "$APP_DIR/logs"
chmod 755 "$APP_DIR/uploads"
chmod 755 "$APP_DIR/logs"

echo -e "${GREEN}✅ Directories created${NC}"

# Step 5: Database setup
echo -e "\n${YELLOW}Step 5: Setting up database...${NC}"
echo "Please ensure your PostgreSQL database is created in cPanel."
echo "Database details should be in your .env file as DATABASE_URL"
echo ""
read -p "Has the database been created in cPanel? (y/n): " db_created

if [ "$db_created" != "y" ]; then
    echo -e "${YELLOW}Please create the database in cPanel:${NC}"
    echo "1. Login to cPanel"
    echo "2. Go to 'PostgreSQL Databases'"
    echo "3. Create a new database (e.g., 'artkubus')"
    echo "4. Create a user with password"
    echo "5. Add user to database with ALL PRIVILEGES"
    echo "6. Update DATABASE_URL in .env file"
    echo ""
    exit 1
fi

# Run migrations
echo "Running database migrations..."
node src/db/migrate.js

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Database setup completed${NC}"
else
    echo -e "${RED}❌ Database migration failed${NC}"
    exit 1
fi

# Step 6: PM2 Setup
echo -e "\n${YELLOW}Step 6: Setting up PM2 process manager...${NC}"

if ! command -v pm2 &> /dev/null; then
    echo "Installing PM2..."
    npm install -g pm2
fi

# Stop existing process if running
pm2 delete $APP_NAME 2>/dev/null || true

# Start application with PM2
pm2 start src/server.js --name $APP_NAME \
    --max-memory-restart 500M \
    --time \
    --merge-logs \
    --log "$APP_DIR/logs/pm2.log" \
    --error "$APP_DIR/logs/pm2-error.log"

# Save PM2 configuration
pm2 save

echo -e "${GREEN}✅ PM2 configured${NC}"

# Step 7: Setup PM2 startup script
echo -e "\n${YELLOW}Step 7: Setting up PM2 auto-start...${NC}"
pm2 startup

echo -e "${YELLOW}⚠️  If the command above shows a command to run, copy and execute it.${NC}"

# Step 8: Display status
echo -e "\n${GREEN}=========================================="
echo "✅ Deployment completed successfully!"
echo "==========================================${NC}"
echo ""
echo "Application Status:"
pm2 list
echo ""
echo "View logs:"
echo "  pm2 logs $APP_NAME"
echo ""
echo "Stop application:"
echo "  pm2 stop $APP_NAME"
echo ""
echo "Restart application:"
echo "  pm2 restart $APP_NAME"
echo ""
echo "Monitor application:"
echo "  pm2 monit"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Configure Apache/Nginx reverse proxy to forward traffic to port 3000"
echo "2. Set up SSL certificate (Let's Encrypt via cPanel)"
echo "3. Test API endpoint: curl http://localhost:3000/health"
echo "4. Configure firewall rules if needed"
echo "5. Set up backup cron jobs for database"
echo ""
echo -e "${GREEN}Happy deploying! 🚀${NC}"
