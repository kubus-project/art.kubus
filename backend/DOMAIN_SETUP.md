# Domain Setup Guide for api.kubus.site

This guide will help you point `api.kubus.site` to your Docker containers using Cloudflare DNS.

## Current Configuration

**Domain:** `api.kubus.site`  
**Backend:** Node.js Express (port 3000)  
**Containers:** PostgreSQL, Redis, Backend, Nginx  
**SSL:** Let's Encrypt (auto-renewal via Certbot)

---

## Option 1: Local Development with Tailscale (Recommended for Testing)

Use Tailscale to expose your local Docker containers to the internet temporarily.

### Step 1: Install Tailscale

```powershell
# Download and install Tailscale from https://tailscale.com/download/windows
# Or use Chocolatey:
choco install tailscale

# Start Tailscale
tailscale up
```

### Step 2: Get Your Tailscale IP

```powershell
tailscale ip -4
# Example output: 100.64.0.1
```

### Step 3: Start Docker Containers

```powershell
cd backend

# Start with development config (uses localhost URLs)
docker-compose up -d postgres redis backend nginx

# Verify containers are running
docker ps
```

### Step 4: Configure Cloudflare DNS (Development)

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Select your domain `kubus.site`
3. Go to **DNS** → **Records**
4. Add/Update A record:
   - **Type:** A
   - **Name:** api
   - **IPv4 address:** Your Tailscale IP (e.g., 100.64.0.1)
   - **Proxy status:** ❌ DNS only (gray cloud)
   - **TTL:** Auto
5. Click **Save**

### Step 5: Test the Connection

```powershell
# Test from your local machine
curl http://api.kubus.site/health

# Test from Flutter app (update api_keys.dart to use kDebugMode = false)
flutter run --debug
```

**Note:** Tailscale DNS only works while Tailscale is running. This is perfect for development/testing but not for production.

---

## Option 2: Production Deployment with cPanel/VPS

Deploy to a VPS or cPanel server for permanent hosting.

### Prerequisites

- A VPS/cPanel server with Docker installed
- SSH access to the server
- Root or sudo privileges

### Step 1: Deploy to Server via SSH

```powershell
# Connect to your server
ssh user@your-server-ip

# Install Docker (if not installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Clone your repository
git clone https://github.com/kubus-project/art.kubus.git
cd art.kubus/backend
```

### Step 2: Configure Environment

```bash
# Copy production environment template
cp .env.production .env

# Generate secure secrets
DB_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -hex 64)
ENCRYPTION_KEY=$(openssl rand -hex 32)

# Update .env file
nano .env

# Add these values:
# DATABASE_URL=postgresql://artkubus:${DB_PASSWORD}@postgres:5432/artkubus
# REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379
# JWT_SECRET=${JWT_SECRET}
# ENCRYPTION_KEY=${ENCRYPTION_KEY}
```

### Step 3: Get SSL Certificate (Let's Encrypt)

```bash
# First, start nginx without SSL to get certificate
docker-compose -f docker-compose.production.yml up -d nginx

# Get SSL certificate
docker-compose -f docker-compose.production.yml run --rm certbot certonly \
  --webroot --webroot-path /var/www/certbot \
  -d api.kubus.site \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email

# Restart nginx to use SSL
docker-compose -f docker-compose.production.yml restart nginx
```

### Step 4: Start All Services

```bash
# Set environment variables
export DB_PASSWORD="your_db_password"
export REDIS_PASSWORD="your_redis_password"

# Start all services
docker-compose -f docker-compose.production.yml up -d

# Check status
docker-compose -f docker-compose.production.yml ps

# View logs
docker-compose -f docker-compose.production.yml logs -f backend
```

### Step 5: Configure Cloudflare DNS (Production)

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Select domain `kubus.site`
3. Go to **DNS** → **Records**
4. Add/Update A record:
   - **Type:** A
   - **Name:** api
   - **IPv4 address:** Your server's public IP
   - **Proxy status:** ✅ Proxied (orange cloud) - Recommended for DDoS protection
   - **TTL:** Auto
5. Click **Save**

### Step 6: Configure Cloudflare SSL/TLS

1. Go to **SSL/TLS** → **Overview**
2. Set SSL/TLS encryption mode to: **Full (strict)**
3. Go to **SSL/TLS** → **Edge Certificates**
4. Enable:
   - ✅ Always Use HTTPS
   - ✅ HTTP Strict Transport Security (HSTS)
   - ✅ Automatic HTTPS Rewrites

### Step 7: Test Production Deployment

```bash
# Test health endpoint
curl https://api.kubus.site/health

# Test API endpoint
curl https://api.kubus.site/api/artworks

# Check SSL certificate
openssl s_client -connect api.kubus.site:443 -servername api.kubus.site
```

---

## Option 3: cPanel Subdomain Setup

If you have cPanel hosting and want to use a subdomain.

### Step 1: Create Subdomain in cPanel

1. Log in to cPanel
2. Go to **Domains** → **Subdomains**
3. Create subdomain:
   - **Subdomain:** api
   - **Domain:** kubus.site
   - **Document Root:** /home/username/api.kubus.site
4. Click **Create**

### Step 2: Point to Docker Container

If Docker is running on the same cPanel server:

```bash
# Edit .htaccess in subdomain root
nano /home/username/api.kubus.site/.htaccess

# Add reverse proxy rules:
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

RewriteCond %{HTTP:Upgrade} =websocket [NC]
RewriteRule /(.*)           ws://localhost:3000/$1 [P,L]

RewriteCond %{HTTP:Upgrade} !=websocket [NC]
RewriteRule /(.*)           http://localhost:3000/$1 [P,L]
```

### Step 3: Install SSL Certificate

1. Go to cPanel → **Security** → **SSL/TLS Status**
2. Select `api.kubus.site`
3. Click **Run AutoSSL**

---

## Changing Domain Later

To change from `api.kubus.site` to a different domain:

### Backend Configuration

1. Update `backend/.env.production`:
   ```bash
   HTTP_BASE_URL=https://new-api-domain.com
   CORS_ORIGIN=https://new-frontend-domain.com
   ```

2. Update `backend/nginx.conf`:
   ```nginx
   server_name new-api-domain.com;
   ```

3. Rebuild containers:
   ```bash
   docker-compose -f docker-compose.production.yml down
   docker-compose -f docker-compose.production.yml up -d --build
   ```

### Flutter App Configuration

1. Update `lib/config/api_keys.dart`:
   ```dart
   return kDebugMode ? 'http://localhost:3000' : 'https://new-api-domain.com';
   ```

2. Rebuild app:
   ```powershell
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

### DNS Configuration

1. Add A record for new domain in Cloudflare
2. Get new SSL certificate:
   ```bash
   docker-compose -f docker-compose.production.yml run --rm certbot certonly \
     -d new-api-domain.com
   ```

---

## Monitoring & Maintenance

### Check Container Status

```bash
docker-compose -f docker-compose.production.yml ps
```

### View Logs

```bash
# All services
docker-compose -f docker-compose.production.yml logs -f

# Specific service
docker-compose -f docker-compose.production.yml logs -f backend
```

### Restart Services

```bash
# All services
docker-compose -f docker-compose.production.yml restart

# Specific service
docker-compose -f docker-compose.production.yml restart backend
```

### Update Application

```bash
# Pull latest code
git pull origin master

# Rebuild and restart
docker-compose -f docker-compose.production.yml up -d --build backend

# View logs
docker-compose -f docker-compose.production.yml logs -f backend
```

### Database Backup

```bash
# Backup database
docker exec artkubus-postgres pg_dump -U artkubus artkubus > backup_$(date +%Y%m%d).sql

# Restore database
docker exec -i artkubus-postgres psql -U artkubus artkubus < backup_20251113.sql
```

---

## Troubleshooting

### DNS not resolving

```bash
# Check DNS propagation
nslookup api.kubus.site
dig api.kubus.site

# Clear DNS cache (Windows)
ipconfig /flushdns
```

### SSL certificate errors

```bash
# Renew certificate manually
docker-compose -f docker-compose.production.yml run --rm certbot renew

# Restart nginx
docker-compose -f docker-compose.production.yml restart nginx
```

### Backend not responding

```bash
# Check backend logs
docker logs artkubus-backend

# Check nginx logs
docker logs artkubus-nginx

# Verify network connectivity
docker network inspect artkubus_artkubus-network
```

### CORS errors in Flutter app

1. Update `backend/.env.production`:
   ```
   CORS_ORIGIN=https://art.kubus.site,https://kubus.site,*
   ```

2. Restart backend:
   ```bash
   docker-compose -f docker-compose.production.yml restart backend
   ```

---

## Security Checklist

- ✅ Change default passwords in `.env.production`
- ✅ Enable Cloudflare Proxy (orange cloud)
- ✅ Configure SSL/TLS to "Full (strict)"
- ✅ Enable HSTS in Cloudflare
- ✅ Restrict CORS origins in production
- ✅ Set up database backups (cron job)
- ✅ Enable firewall rules (UFW/iptables)
- ✅ Configure rate limiting in nginx
- ✅ Monitor logs for suspicious activity
- ✅ Keep Docker images updated

---

## Next Steps

1. ✅ Update Flutter app API URL to `api.kubus.site`
2. ⬜ Choose deployment method (Tailscale for dev, VPS for production)
3. ⬜ Configure Cloudflare DNS
4. ⬜ Start Docker containers
5. ⬜ Test API connectivity
6. ⬜ Deploy Flutter app with new API URL

---

**Need Help?**

- Check backend logs: `docker-compose logs -f backend`
- Test health endpoint: `curl https://api.kubus.site/health`
- Verify DNS: `nslookup api.kubus.site`
- Check SSL: `openssl s_client -connect api.kubus.site:443`
