# art.kubus Backend - cPanel Deployment Guide

## Prerequisites

### 1. cPanel Requirements
- **Node.js**: Version 20+ (available in cPanel Node.js selector)
- **PostgreSQL**: Database access (create via cPanel)
- **SSH Access**: Recommended but not required
- **Domain**: Configured with SSL certificate

### 2. Get API Keys
Before deployment, obtain:
- **Pinata API keys** (for IPFS): https://app.pinata.cloud/keys
- Generate secure secrets (see below)

### 3. Generate Secure Keys
Run these commands locally to generate secure keys:

```bash
# JWT Secret (64 bytes)
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"

# Encryption Key (32 bytes)
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

---

## Step-by-Step Deployment

### Step 1: Upload Backend Code

#### Option A: Via Git (Recommended)
```bash
# SSH into your cPanel server
ssh username@yourdomain.com

# Clone repository
cd ~
git clone https://github.com/kubus-project/art.kubus.git
cd art.kubus/backend
```

#### Option B: Via cPanel File Manager
1. Login to cPanel
2. Go to **File Manager**
3. Navigate to home directory
4. Upload `backend.zip`
5. Extract files

### Step 2: Create PostgreSQL Database

1. Login to cPanel
2. Go to **PostgreSQL Databases**
3. Create database:
   - Database name: `artkubus` (or your choice)
   - Click "Create Database"
4. Create user:
   - Username: `artkubus_user`
   - Password: Generate strong password
   - Click "Create User"
5. Add user to database:
   - Select database and user
   - Grant **ALL PRIVILEGES**
   - Click "Add"
6. Note connection details:
   ```
   Host: localhost (or provided host)
   Port: 5432
   Database: username_artkubus
   Username: username_artkubus_user
   Password: [your generated password]
   ```

### Step 3: Configure Environment

```bash
cd ~/art.kubus/backend

# Copy environment template
cp .env.example .env

# Edit environment file
nano .env  # or use cPanel File Manager editor
```

**Required .env variables:**

```env
NODE_ENV=production
PORT=3000
HTTP_BASE_URL=https://api.yourdomain.com

# Database (from Step 2)
DATABASE_URL=postgresql://username_artkubus_user:password@localhost:5432/username_artkubus

# Security (from prerequisites)
JWT_SECRET=your_64_byte_hex_secret
ENCRYPTION_KEY=your_32_byte_hex_secret

# IPFS (Pinata)
PINATA_API_KEY=your_pinata_api_key
PINATA_SECRET=your_pinata_secret_key
IPFS_GATEWAY_URL=https://gateway.pinata.cloud/ipfs/

# Storage
DEFAULT_STORAGE_PROVIDER=hybrid
ENABLE_IPFS=true
ENABLE_HTTP_STORAGE=true

# CORS (your Flutter app domain)
CORS_ORIGIN=https://yourdomain.com,https://www.yourdomain.com

# Mock data (disable in production)
USE_MOCK_DATA=false
```

### Step 4: Install Node.js via cPanel

1. Go to **Setup Node.js App**
2. Click "Create Application"
3. Settings:
   - **Node.js version**: 20.x
   - **Application mode**: Production
   - **Application root**: `art.kubus/backend`
   - **Application URL**: Your domain or subdomain
   - **Application startup file**: `src/server.js`
4. Click "Create"

### Step 5: Install Dependencies

```bash
cd ~/art.kubus/backend

# Load Node.js environment (path shown in cPanel Node.js app)
source /home/username/nodevenv/art.kubus/backend/20/bin/activate

# Install dependencies
npm install --production
```

### Step 6: Initialize Database

```bash
# Run migration script
npm run migrate

# Expected output:
# ✅ Database artkubus created successfully
# ✅ Database migrations completed successfully
# ✅ Database setup verification passed
```

### Step 7: Configure Reverse Proxy

#### Option A: Using cPanel Node.js App (Automatic)
If you created the app in Step 4, cPanel automatically configures Apache reverse proxy.

#### Option B: Manual Apache Configuration
Edit `.htaccess` in your document root:

```apache
RewriteEngine On
RewriteCond %{REQUEST_URI} ^/api/ [OR]
RewriteCond %{REQUEST_URI} ^/health
RewriteRule ^(.*)$ http://localhost:3000/$1 [P,L]
```

#### Option C: Nginx Configuration (if available)
```nginx
location /api/ {
    proxy_pass http://localhost:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_cache_bypass $http_upgrade;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

### Step 8: Start Application

#### Using PM2 (Recommended)
```bash
# Install PM2 globally
npm install -g pm2

# Start application
pm2 start src/server.js --name artkubus-api

# Save PM2 configuration
pm2 save

# Setup startup script
pm2 startup
# Follow the command shown

# Check status
pm2 status
pm2 logs artkubus-api
```

#### Using cPanel Node.js App
1. Go to **Setup Node.js App**
2. Click your application
3. Click "Start App" or "Restart App"

### Step 9: Configure SSL Certificate

1. Go to cPanel **SSL/TLS Status**
2. Find your domain
3. Click "Run AutoSSL" (Let's Encrypt)
4. Wait for certificate issuance
5. Verify HTTPS works: `https://api.yourdomain.com/health`

### Step 10: Test Deployment

```bash
# Test health endpoint
curl http://localhost:3000/health

# Test from outside
curl https://api.yourdomain.com/health

# Expected response:
# {"status":"ok","timestamp":"2025-11-13T...","uptime":123}
```

---

## Post-Deployment Tasks

### 1. Setup Monitoring

```bash
# PM2 monitoring
pm2 monit

# View logs
pm2 logs artkubus-api

# Application logs
tail -f ~/art.kubus/backend/logs/combined.log
```

### 2. Configure Backups

#### Database Backup Cron Job
Add to cPanel **Cron Jobs**:

```bash
# Daily database backup at 2 AM
0 2 * * * pg_dump -U username_artkubus_user username_artkubus > ~/backups/db-$(date +\%Y\%m\%d).sql
```

#### Cleanup old backups
```bash
# Keep only last 7 days
0 3 * * * find ~/backups -name "db-*.sql" -mtime +7 -delete
```

### 3. Update Application

```bash
cd ~/art.kubus/backend

# Pull latest code
git pull origin main

# Install new dependencies
npm install --production

# Run migrations (if schema changed)
npm run migrate

# Restart application
pm2 restart artkubus-api

# Or via cPanel
# Setup Node.js App > Your App > Restart
```

### 4. Security Hardening

- [ ] Disable `USE_MOCK_DATA` in production
- [ ] Set specific `CORS_ORIGIN` (never use `*`)
- [ ] Enable firewall rules (port 3000 should NOT be public)
- [ ] Regularly update dependencies: `npm audit fix`
- [ ] Rotate JWT_SECRET quarterly
- [ ] Monitor logs for suspicious activity
- [ ] Enable rate limiting (already configured)

---

## Troubleshooting

### Application won't start

```bash
# Check PM2 logs
pm2 logs artkubus-api --err

# Check Node.js version
node -v  # Should be 20+

# Check environment
cat .env | grep DATABASE_URL

# Test database connection
node -e "const {Client}=require('pg'); const c=new Client(process.env.DATABASE_URL); c.connect().then(()=>console.log('✅ DB OK')).catch(e=>console.error('❌',e.message))"
```

### Database connection fails

```bash
# Check PostgreSQL is running
ps aux | grep postgres

# Test connection manually
psql -h localhost -U username_artkubus_user -d username_artkubus

# Check DATABASE_URL format
# Should be: postgresql://user:password@host:5432/database
```

### Port 3000 already in use

```bash
# Find process using port
lsof -i :3000

# Kill process
kill -9 PID

# Or change port in .env
echo "PORT=3001" >> .env
pm2 restart artkubus-api
```

### SSL certificate issues

1. Verify domain DNS points to cPanel server
2. Check AutoSSL status in cPanel
3. Wait 10-15 minutes for certificate issuance
4. Force HTTPS in `.htaccess`:
   ```apache
   RewriteCond %{HTTPS} off
   RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
   ```

### High memory usage

```bash
# Restart application
pm2 restart artkubus-api

# Set memory limit
pm2 start src/server.js --name artkubus-api --max-memory-restart 500M

# Check memory usage
pm2 monit
```

---

## Maintenance Commands

```bash
# View application status
pm2 status

# View logs (live)
pm2 logs artkubus-api

# Restart application
pm2 restart artkubus-api

# Stop application
pm2 stop artkubus-api

# Update application
cd ~/art.kubus/backend && git pull && npm install && pm2 restart artkubus-api

# Database backup (manual)
pg_dump -U username_artkubus_user username_artkubus > backup.sql

# Database restore
psql -U username_artkubus_user -d username_artkubus < backup.sql

# Clear logs
pm2 flush artkubus-api

# Monitor resources
pm2 monit
```

---

## Support

- **Documentation**: `docs/BACKEND_API_SPEC.md`
- **GitHub**: https://github.com/kubus-project/art.kubus
- **Issues**: https://github.com/kubus-project/art.kubus/issues

---

**Last Updated**: November 13, 2025
**Deployment Platform**: cPanel with Node.js 20+
**Database**: PostgreSQL 15+
