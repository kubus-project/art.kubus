# SSL Certificate Setup for api.kubus.site

This guide will help you get a free SSL certificate from Let's Encrypt for your Docker containers.

## Prerequisites

✅ Docker containers running (postgres, redis, backend, nginx)  
✅ Domain `api.kubus.site` pointing to your server's public IP via Cloudflare DNS  
✅ Port 80 accessible from the internet (for ACME HTTP challenge)

---

## Step 1: Configure Cloudflare DNS

1. **Go to Cloudflare Dashboard**: https://dash.cloudflare.com
2. **Select domain**: `kubus.site`
3. **Add/Update A Record**:
   - **Type**: A
   - **Name**: `api`
   - **IPv4**: Your server's public IP (find at: https://api.ipify.org)
   - **Proxy status**: ⚠️ **DNS only (gray cloud)** - IMPORTANT for Let's Encrypt
   - **TTL**: Auto
   - Click **Save**

**Why DNS only?** Let's Encrypt needs direct access to port 80 for HTTP challenge. Cloudflare proxy blocks this.

4. **Verify DNS propagation**:
```powershell
nslookup api.kubus.site
# Should return your server's IP
```

---

## Step 2: Ensure Port 80 is Accessible

### For Local Development (Windows):

```powershell
# Check if port 80 is available
netstat -ano | findstr :80

# If Windows is using port 80, stop IIS or other services:
net stop http
```

### For Router/Firewall:

1. **Port forwarding**: Forward port 80 to your PC's local IP
2. **Windows Firewall**: Allow inbound on port 80
   ```powershell
   New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow
   ```

### Test accessibility:

```powershell
# From another computer or phone (not on your network):
curl http://api.kubus.site
# Should reach your nginx container
```

---

## Step 3: Restart Nginx with Updated Config

```powershell
cd g:\WorkingDATA\art.kubus\art.kubus\backend

# Restart nginx with new configuration
docker-compose restart nginx

# Check nginx logs
docker logs artkubus-nginx

# Test HTTP access
curl http://api.kubus.site/health
# Should return: {"status":"ok",...}
```

---

## Step 4: Get SSL Certificate from Let's Encrypt

### Option A: Standalone Certbot (Recommended for Local)

Stop nginx temporarily, get certificate, then restart:

```powershell
# Stop nginx (port 80 will be used by certbot)
docker stop artkubus-nginx

# Run certbot standalone
docker run -it --rm --name certbot `
  -v "${PWD}/ssl:/etc/letsencrypt" `
  -v "${PWD}/certbot/www:/var/www/certbot" `
  -p 80:80 `
  certbot/certbot certonly --standalone `
  -d api.kubus.site `
  --email your-email@example.com `
  --agree-tos `
  --no-eff-email `
  --verbose

# Certificate saved to: ssl/live/api.kubus.site/

# Start nginx again
docker start artkubus-nginx
```

### Option B: Webroot Method (If nginx is running)

```powershell
# Ensure nginx is running and serving /.well-known/
docker-compose up -d nginx

# Run certbot with webroot
docker run -it --rm --name certbot `
  -v "${PWD}/ssl:/etc/letsencrypt" `
  -v "${PWD}/certbot/www:/var/www/certbot" `
  --network backend_artkubus-network `
  certbot/certbot certonly --webroot `
  -w /var/www/certbot `
  -d api.kubus.site `
  --email your-email@example.com `
  --agree-tos `
  --no-eff-email `
  --verbose
```

---

## Step 5: Configure Nginx to Use SSL

After certificates are obtained, update `nginx.conf`:

```powershell
# Open nginx.conf in editor
code nginx.conf
```

**Uncomment the HTTPS server block** (lines with #) and **comment out HTTP proxy**:

```nginx
# HTTP server - Redirect to HTTPS
server {
    listen 80;
    server_name api.kubus.site;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }
    
    # Redirect to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server - Uncomment after getting certificates
server {
    listen 443 ssl http2;
    server_name api.kubus.site;
    
    ssl_certificate /etc/letsencrypt/live/api.kubus.site/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.kubus.site/privkey.pem;
    
    # ... rest of HTTPS config ...
}
```

---

## Step 6: Update Docker Compose and Restart

Update `docker-compose.yml` nginx volumes:

```yaml
nginx:
  volumes:
    - ./nginx.conf:/etc/nginx/nginx.conf:ro
    - ./ssl:/etc/letsencrypt:ro  # Let's Encrypt certificates
    - ./certbot/www:/var/www/certbot:ro
```

Restart nginx:

```powershell
docker-compose restart nginx

# Check nginx logs
docker logs artkubus-nginx

# If errors, check nginx config syntax:
docker exec artkubus-nginx nginx -t
```

---

## Step 7: Test SSL Connection

```powershell
# Test HTTPS endpoint
curl https://api.kubus.site/health

# Check SSL certificate
curl -vI https://api.kubus.site 2>&1 | Select-String "SSL certificate"

# Or use online SSL checker:
# https://www.ssllabs.com/ssltest/analyze.html?d=api.kubus.site
```

---

## Step 8: Enable Cloudflare Proxy (Optional)

After SSL is working, you can enable Cloudflare proxy for DDoS protection:

1. **Go to Cloudflare DNS settings**
2. **Click on api.kubus.site A record**
3. **Change proxy status**: ☁️ **Proxied (orange cloud)**
4. **Go to SSL/TLS settings**:
   - **Encryption mode**: Full (strict)
   - **Enable**: Always Use HTTPS
   - **Enable**: Automatic HTTPS Rewrites

---

## Auto-Renewal Setup

Let's Encrypt certificates expire in 90 days. Set up auto-renewal:

### Windows Task Scheduler:

```powershell
# Test renewal (dry run)
docker run --rm --name certbot `
  -v "${PWD}/ssl:/etc/letsencrypt" `
  -v "${PWD}/certbot/www:/var/www/certbot" `
  certbot/certbot renew --dry-run

# Create renewal script: renew-ssl.ps1
@"
cd g:\WorkingDATA\art.kubus\art.kubus\backend
docker run --rm --name certbot ``
  -v "`${PWD}/ssl:/etc/letsencrypt" ``
  -v "`${PWD}/certbot/www:/var/www/certbot" ``
  certbot/certbot renew --quiet
docker-compose restart nginx
"@ | Out-File -FilePath renew-ssl.ps1 -Encoding utf8

# Schedule task to run monthly
schtasks /create /tn "RenewSSL" /tr "powershell.exe -File g:\WorkingDATA\art.kubus\art.kubus\backend\renew-ssl.ps1" /sc monthly /mo 1
```

### Linux/VPS (cron):

```bash
# Add to crontab
crontab -e

# Add this line (runs daily at 3am):
0 3 * * * docker run --rm -v /path/to/ssl:/etc/letsencrypt -v /path/to/certbot/www:/var/www/certbot certbot/certbot renew --quiet && docker-compose -f /path/to/docker-compose.yml restart nginx
```

---

## Troubleshooting

### Certificate request failed

**Error**: "Connection refused" or "Timeout"

**Solutions**:
1. Verify DNS: `nslookup api.kubus.site` returns correct IP
2. Check port 80 is open: `curl http://api.kubus.site` works
3. Disable Cloudflare proxy (gray cloud)
4. Check firewall rules
5. Verify nginx is serving `/.well-known/acme-challenge/`

### Nginx won't start with SSL

**Error**: "cannot load certificate" or "PEM_read_bio"

**Solutions**:
1. Verify certificate files exist:
   ```powershell
   ls ssl/live/api.kubus.site/
   # Should show: fullchain.pem, privkey.pem
   ```
2. Check file permissions (Linux):
   ```bash
   chmod 644 ssl/live/api.kubus.site/fullchain.pem
   chmod 600 ssl/live/api.kubus.site/privkey.pem
   ```
3. Verify nginx config syntax:
   ```powershell
   docker exec artkubus-nginx nginx -t
   ```

### Certificate not trusted

**Error**: "NET::ERR_CERT_AUTHORITY_INVALID"

**Solutions**:
1. Verify you're using the correct certificate files
2. Check certificate chain: `curl -vI https://api.kubus.site`
3. Ensure `fullchain.pem` (not `cert.pem`) is used
4. Clear browser cache

### Port 80 still in use

```powershell
# Find process using port 80
netstat -ano | findstr :80

# Kill process (replace PID)
taskkill /F /PID <PID>

# Or stop common services
net stop http  # IIS
net stop w3svc  # IIS
```

---

## Quick Commands Reference

```powershell
# Get certificate (standalone)
docker stop artkubus-nginx; docker run -it --rm -v "${PWD}/ssl:/etc/letsencrypt" -v "${PWD}/certbot/www:/var/www/certbot" -p 80:80 certbot/certbot certonly --standalone -d api.kubus.site --email your@email.com --agree-tos --no-eff-email; docker start artkubus-nginx

# Renew certificate
docker run --rm -v "${PWD}/ssl:/etc/letsencrypt" -v "${PWD}/certbot/www:/var/www/certbot" certbot/certbot renew

# Test renewal
docker run --rm -v "${PWD}/ssl:/etc/letsencrypt" -v "${PWD}/certbot/www:/var/www/certbot" certbot/certbot renew --dry-run

# Restart nginx
docker-compose restart nginx

# Check nginx config
docker exec artkubus-nginx nginx -t

# View nginx logs
docker logs artkubus-nginx -f

# Test HTTPS
curl https://api.kubus.site/health

# Check certificate expiry
docker run --rm -v "${PWD}/ssl:/etc/letsencrypt" certbot/certbot certificates
```

---

## Next Steps

✅ SSL certificate obtained  
✅ Nginx configured with HTTPS  
✅ HTTP redirects to HTTPS  
✅ Auto-renewal scheduled  
✅ Cloudflare proxy enabled (optional)  
✅ Flutter app updated to use https://api.kubus.site

**Test your setup:**
- https://api.kubus.site/health
- https://www.ssllabs.com/ssltest/analyze.html?d=api.kubus.site

---

**Need help?** Check nginx logs: `docker logs artkubus-nginx`
