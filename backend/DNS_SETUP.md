# DNS Configuration Guide for api.kubus.site

## Current Issue: DNS Not Configured

Let's Encrypt failed because `api.kubus.site` doesn't have DNS records pointing to your server.

**Error**: "no valid A records found for api.kubus.site"

---

## Quick Setup (10 minutes)

### Step 1: Get Your Public IP

```powershell
# From your local machine
curl https://api.ipify.org; Write-Host ""

# Or visit: https://whatismyipaddress.com
```

**Save this IP address** - you'll need it for DNS configuration.

---

### Step 2: Configure Cloudflare DNS

1. **Login to Cloudflare**: https://dash.cloudflare.com

2. **Select your domain**: `kubus.site`

3. **Go to DNS Settings**: Click "DNS" in left sidebar

4. **Add A Record**:
   - Click **"Add record"** button
   - **Type**: `A`
   - **Name**: `api`
   - **IPv4 address**: [Your Public IP from Step 1]
   - **Proxy status**: ⚠️ **DNS only** (click orange cloud to turn it GRAY)
   - **TTL**: Auto
   - Click **"Save"**

**IMPORTANT**: Must be DNS only (gray cloud) for Let's Encrypt to work!

---

### Step 3: Verify DNS Propagation

Wait 2-5 minutes, then test:

```powershell
# Test DNS resolution
nslookup api.kubus.site

# Expected output should show your IP address
# Name:    api.kubus.site
# Address: [Your IP]
```

If it shows your IP, DNS is configured! ✅

---

### Step 4: Configure Port Forwarding (If on Local Machine)

If you're running on your local PC behind a router:

#### Windows Firewall:
```powershell
# Allow port 80 (HTTP) for Let's Encrypt
New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow

# Allow port 443 (HTTPS)
New-NetFirewallRule -DisplayName "Allow HTTPS" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow
```

#### Router Port Forwarding:
1. Log into your router (usually http://192.168.1.1)
2. Find "Port Forwarding" or "Virtual Server" section
3. Add rules:
   - **External Port**: 80 → **Internal Port**: 80 → **IP**: [Your PC's local IP]
   - **External Port**: 443 → **Internal Port**: 443 → **IP**: [Your PC's local IP]

To find your local IP:
```powershell
ipconfig | findstr IPv4
```

---

### Step 5: Test External Access

```powershell
# From your PC - should work
curl http://localhost/health

# From another network (phone not on wifi) - test external access
# Visit: http://api.kubus.site
# Should show: {"status":"ok",...}
```

If this works, you're ready for SSL! ✅

---

### Step 6: Get SSL Certificate (After DNS Works)

```powershell
cd g:\WorkingDATA\art.kubus\art.kubus\backend

# Stop nginx (certbot needs port 80)
docker stop artkubus-nginx

# Get SSL certificate
docker run -it --rm --name certbot `
  -v "${PWD}/ssl:/etc/letsencrypt" `
  -v "${PWD}/certbot/www:/var/www/certbot" `
  -p 80:80 `
  certbot/certbot certonly --standalone `
  -d api.kubus.site `
  --email your-email@example.com `
  --agree-tos `
  --no-eff-email

# If successful, start nginx
docker start artkubus-nginx
```

**Replace** `your-email@example.com` with your real email!

---

## Alternative: Cloudflare Tunnel (Easiest for Testing!)

**Best for development/testing** - bypasses port forwarding and firewall completely!

### Quick Start with Docker (2 minutes)

```powershell
# Start your backend first
cd g:\WorkingDATA\art.kubus\art.kubus\backend
node src/server.js

# In a new terminal, start Cloudflare Tunnel
docker run cloudflare/cloudflared:latest tunnel --no-autoupdate run --token eyJhIjoiNTY5MzM1OGQ1YzRjOTFjOTQ2ZmNkZDIzZjdkOTA0YmIiLCJ0IjoiYTEwY2YxM2QtNGJmMS00ZWY2LTljNzktNTRkOTYzNTZiMTQxIiwicyI6Ik5EQTJOVFl3TnprdFl6bGhaaTAwTTJZNUxUbG1NRFV0WXpobE1UUTFNV1UwTlRjMSJ9
```

That's it! Your API is now accessible at `https://api.kubus.site` with automatic HTTPS! ✅

### Test It

```powershell
# From anywhere (even your phone on cellular)
curl https://api.kubus.site/health

# Expected: {"status":"ok",...}
```

### Add to docker-compose.yml (Optional)

```yaml
services:
  backend:
    build: .
    ports:
      - "3000:3000"
    env_file: .env

  cloudflared:
    image: cloudflare/cloudflared:latest
    command: tunnel --no-autoupdate run --token eyJhIjoiNTY5MzM1OGQ1YzRjOTFjOTQ2ZmNkZDIzZjdkOTA0YmIiLCJ0IjoiYTEwY2YxM2QtNGJmMS00ZWY2LTljNzktNTRkOTYzNTZiMTQxIiwicyI6Ik5EQTJOVFl3TnprdFl6bGhaaTAwTTJZNUxUbG1NRFV0WXpobE1UUTFNV1UwTlRjMSJ9
    network_mode: host
    restart: unless-stopped
```

Then run: `docker-compose up -d`

### Advantages

✅ **Zero port forwarding** - Works behind any firewall/NAT  
✅ **Free SSL included** - HTTPS automatic via Cloudflare  
✅ **No router config** - Zero network changes needed  
✅ **ISP-proof** - Works even if ISP blocks ports  
✅ **Dynamic IP friendly** - IP changes don't matter  
✅ **DDoS protection** - Cloudflare's network  
✅ **Easy on/off** - Just stop Docker container  

### For Production

Cloudflare Tunnel is **free and production-ready**, but consider:
- All traffic routes through Cloudflare (slight latency ~10-50ms)
- Requires tunnel process running 24/7
- Great for: Testing, development, small-scale production
- Alternative: VPS for more control and direct connection

---

## Alternative: Use a VPS Instead

If you need more control or direct connection, consider deploying to a VPS:

### Budget VPS Options:
- **DigitalOcean**: $6/month (Droplet)
- **Linode**: $5/month
- **Vultr**: $5/month
- **Hetzner**: €4.5/month

### Deploy to VPS:
1. Create VPS with Ubuntu 22.04
2. Install Docker:
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   ```
3. Clone your repo:
   ```bash
   git clone https://github.com/kubus-project/art.kubus.git
   cd art.kubus/backend
   ```
4. Update DNS to point to VPS IP
5. Follow SSL setup from Step 6

---

## Troubleshooting

### DNS not resolving after 5 minutes?

```powershell
# Check DNS propagation globally
# Visit: https://dnschecker.org/#A/api.kubus.site
```

### Port 80 not accessible?

```powershell
# Check if nginx is using port 80
netstat -ano | findstr :80

# Test from outside your network
# Use: https://www.yougetsignal.com/tools/open-ports/
# Check port 80 for your public IP
```

### Firewall blocking?

```powershell
# Check Windows Firewall rules
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*HTTP*"}

# Temporarily disable firewall to test (re-enable after!)
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
```

### ISP blocking port 80?

Some ISPs block port 80 on residential connections. Solutions:
1. Call ISP and ask to unblock port 80
2. Use port 8080 instead (less common)
3. Use a VPS instead

---

## Production Deployment Options

### Option A: Local Development (Current)
- ✅ Free
- ✅ Full control
- ❌ Port forwarding needed
- ❌ Dynamic IP issues
- ❌ Uptime depends on your PC

### Option B: VPS Hosting (Recommended)
- ✅ Static IP
- ✅ No port forwarding
- ✅ 99.9% uptime
- ✅ Easy SSL setup
- ❌ $5-10/month cost

### Option C: cPanel Hosting
- ✅ Managed hosting
- ✅ AutoSSL included
- ✅ No Docker needed
- ❌ Limited control
- ❌ May not support Docker

---

## Quick Decision Tree

**Are you running locally?**
- Yes → Configure DNS + Port Forwarding (Steps 1-5)
- No (VPS/Server) → Just configure DNS (Steps 1-3), skip port forwarding

**Do you have a static IP?**
- Yes → Great! DNS will stay consistent
- No → Consider Dynamic DNS (DuckDNS, No-IP) or use VPS

**Is this for production?**
- Yes → Use VPS (more reliable)
- No (testing) → Local is fine

---

## After DNS Works

Once `nslookup api.kubus.site` returns your IP:

1. ✅ Get SSL certificate (Step 6)
2. ✅ Uncomment HTTPS section in nginx.conf
3. ✅ Update Flutter app to use `https://api.kubus.site`
4. ✅ Enable Cloudflare proxy (orange cloud) for DDoS protection

---

## Need Help?

Common issues:
- DNS not propagating → Wait up to 24 hours (usually 5 min)
- Port 80 blocked → Check firewall and router
- ISP blocking → Contact ISP or use VPS
- Certbot fails → Verify `curl http://api.kubus.site` works first

**Test before SSL**: Always verify `http://api.kubus.site/health` works from an external network before attempting SSL!
