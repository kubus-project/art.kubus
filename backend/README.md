# Art.Kubus Backend API

Production-ready Node.js backend for Art.Kubus with comprehensive security features, IPFS/HTTP storage abstraction, and easy cPanel deployment.

## 🔒 Security Features

### Built-in Security (Production-Ready)

- ✅ **Helmet.js** - Security headers (XSS, clickjacking, MIME sniffing protection)
- ✅ **CORS** - Configurable cross-origin resource sharing
- ✅ **Rate Limiting** - DDoS protection (100 req/15min default)
- ✅ **Input Validation** - Express-validator with sanitization
- ✅ **SQL Injection Protection** - Parameterized queries
- ✅ **XSS Protection** - Input sanitization and CSP headers
- ✅ **JWT Authentication** - Secure token-based auth
- ✅ **Password Hashing** - bcrypt with 12 rounds
- ✅ **HTTP Parameter Pollution** - HPP middleware
- ✅ **Compression** - Gzip compression for responses
- ✅ **Secure File Uploads** - Type validation, size limits
- ✅ **Environment Variables** - All secrets in .env (never committed)
- ✅ **Logging** - Winston with log rotation
- ✅ **Error Handling** - Centralized error middleware

### Security Best Practices Implemented

1. **No Hardcoded Secrets** - All keys in environment variables
2. **Secure Key Generation** - Crypto.randomBytes for JWT/encryption
3. **HTTPS Only** - Redirects HTTP to HTTPS (Nginx config provided)
4. **Strict CORS** - No wildcards in production
5. **Content Security Policy** - Restrictive CSP headers
6. **Least Privilege** - Database users with minimal permissions
7. **Regular Updates** - Dependency vulnerability scanning
8. **Graceful Shutdown** - Proper SIGTERM/SIGINT handling
9. **File Permissions** - .env with 600 permissions
10. **API Key Rotation** - Easy credential rotation support

## 🏗️ Architecture

### Tech Stack

- **Runtime**: Node.js 20+
- **Framework**: Express.js 4.18+
- **Database**: PostgreSQL 12+ (or MySQL)
- **Cache**: Redis 7+ (optional)
- **Process Manager**: PM2
- **Web Server**: Nginx (reverse proxy)
- **Storage**: IPFS (Pinata) + HTTP (hybrid)

### Directory Structure

```
backend/
├── src/
│   ├── server.js              # Main application entry
│   ├── middleware/
│   │   ├── auth.js           # JWT & API key authentication
│   │   ├── errorHandler.js   # Global error handling
│   │   └── validation.js     # Input validation rules
│   ├── routes/
│   │   ├── arMarkers.js      # AR marker CRUD
│   │   ├── artworks.js       # Artwork management
│   │   ├── community.js      # Community posts
│   │   ├── upload.js         # File upload handling
│   │   ├── storage.js        # Storage provider info
│   │   ├── auth.js           # Auth endpoints
│   │   └── health.js         # Health checks
│   ├── services/
│   │   └── storageService.js # IPFS/HTTP abstraction
│   └── utils/
│       └── logger.js          # Winston logger
├── logs/                      # Application logs
├── uploads/                   # Local file storage
├── .env.example              # Environment template
├── .gitignore                # Git exclusions
├── package.json              # Dependencies
├── ecosystem.config.js       # PM2 configuration
└── Dockerfile                # Docker container

```

## 🚀 Quick Start

### Option 1: Development with Cloudflare Tunnel (Easiest!)

**Perfect for testing - no port forwarding or firewall configuration needed!**

```powershell
# Run the quick start script
.\start-dev-tunnel.ps1

# Or manually with Docker:
docker-compose --profile tunnel up -d postgres redis backend cloudflared

# Test from anywhere:
curl https://api.kubus.site/health
```

✅ Automatic HTTPS via Cloudflare  
✅ Works behind any firewall/NAT  
✅ No router configuration needed  
✅ ISP-proof (even if ports blocked)  

### Option 2: Traditional Installation

**For production or when you need direct connection**

#### Prerequisites

- Node.js 20+
- PostgreSQL (or MySQL)
- PM2 (`npm install -g pm2`)

#### Installation

```bash
# 1. Clone repository
git clone https://github.com/your-repo/art-kubus-backend.git
cd art-kubus-backend

# 2. Install dependencies
npm install

# 3. Configure environment
cp .env.example .env
nano .env  # Edit with your values

# 4. Generate secure keys
node -e "console.log('JWT_SECRET:', require('crypto').randomBytes(64).toString('hex'))"
node -e "console.log('ENCRYPTION_KEY:', require('crypto').randomBytes(32).toString('hex'))"

# 5. Configure database
# Create database and update DATABASE_URL in .env

# 6. Start application
pm2 start ecosystem.config.js

# 7. Check status
pm2 status
pm2 logs artkubus-api
```

#### Development Mode

```bash
npm run dev  # Uses nodemon for auto-reload
```

## 📦 Storage Provider Configuration

### Option 1: HTTP Only (Simplest)

Start with traditional HTTP storage - no external dependencies needed.

```bash
# .env
DEFAULT_STORAGE_PROVIDER=http
ENABLE_IPFS=false
HTTP_BASE_URL=https://api.art-kubus.io
HTTP_STORAGE_PATH=./uploads
```

**Use When:**
- Initial launch/testing
- Cost predictability needed
- No blockchain/Web3 requirements

### Option 2: IPFS Only (Fully Decentralized)

Use IPFS for all content - requires Pinata account.

```bash
# .env
DEFAULT_STORAGE_PROVIDER=ipfs
ENABLE_IPFS=true
PINATA_API_KEY=your_key
PINATA_SECRET=your_secret
IPFS_GATEWAY_URL=https://gateway.pinata.cloud/ipfs/
```

**Use When:**
- Full decentralization required
- Censorship resistance needed
- Content permanence critical

### Option 3: Hybrid (Recommended for Production)

Best of both worlds - IPFS with HTTP fallback.

```bash
# .env
DEFAULT_STORAGE_PROVIDER=hybrid
ENABLE_IPFS=true
PINATA_API_KEY=your_key
PINATA_SECRET=your_secret
HTTP_BASE_URL=https://api.art-kubus.io
```

**Advantages:**
- ✓ High availability (multiple fallbacks)
- ✓ IPFS benefits with HTTP reliability
- ✓ Seamless provider switching
- ✓ Future-proof architecture

### Switching Providers (Zero Downtime)

```bash
# Update .env
DEFAULT_STORAGE_PROVIDER=hybrid  # or ipfs, or http

# Reload app (zero downtime with PM2 cluster mode)
pm2 reload artkubus-api
```

## 🔐 Environment Variables Reference

### Critical (Required)

```bash
NODE_ENV=production              # Environment mode
DATABASE_URL=postgresql://...    # Database connection
JWT_SECRET=<64-char-hex>        # JWT signing key
ENCRYPTION_KEY=<32-char-hex>    # Data encryption key
```

### Storage (Choose One or Both)

```bash
# HTTP Storage
HTTP_BASE_URL=https://...       # Public URL for uploads
HTTP_STORAGE_PATH=./uploads     # Local storage directory

# IPFS Storage
PINATA_API_KEY=...              # Pinata API key
PINATA_SECRET=...               # Pinata secret
IPFS_GATEWAY_URL=https://...    # IPFS gateway URL
```

### Optional

```bash
CORS_ORIGIN=https://...         # Allowed origins (comma-separated)
PORT=3000                       # Server port
RATE_LIMIT_MAX_REQUESTS=100     # Rate limit threshold
MAX_UPLOAD_SIZE=52428800        # Max file size (bytes)
LOG_LEVEL=info                  # Logging level
```

## 📡 API Endpoints

### Health Check

```bash
GET /health
# Response: { status: 'ok', uptime: 12345, ... }
```

### Authentication

```bash
POST /api/auth/register
Body: { username, email, password }

POST /api/auth/login
Body: { email, password }
# Response: { token, user }
```

### AR Markers

```bash
GET /api/ar-markers?lat=46.05&lng=14.50&radius=1
# Get nearby AR markers

POST /api/ar-markers
Headers: { Authorization: Bearer <token> }
Body: { name, position, artworkId, modelCID, ... }
# Create new marker
```

### File Upload

```bash
POST /api/upload
Headers: { Authorization: Bearer <token> }
Body: FormData with 'file' field
Query: ?targetStorage=hybrid
# Upload file to storage
```

### Storage Info

```bash
GET /api/storage/info
# Get storage provider configuration

GET /api/storage/stats
Headers: { Authorization: Bearer <token> }
# Get storage statistics
```

## 🔧 Configuration

### PM2 Ecosystem

```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'artkubus-api',
    script: './src/server.js',
    instances: 2,  // 2x CPU cores recommended
    exec_mode: 'cluster',
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3001,
    },
  }],
};
```

### Nginx Reverse Proxy

```nginx
upstream artkubus_backend {
    server 127.0.0.1:3001;
}

server {
    listen 443 ssl http2;
    server_name api.art-kubus.io;
    
    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/api.art-kubus.io/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.art-kubus.io/privkey.pem;
    
    # Proxy to Node.js
    location / {
        proxy_pass http://artkubus_backend;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $host;
    }
}
```

## 📊 Monitoring

### PM2 Commands

```bash
pm2 status                    # List all processes
pm2 logs artkubus-api        # View logs
pm2 monit                    # Real-time monitoring
pm2 restart artkubus-api     # Restart app
pm2 reload artkubus-api      # Zero-downtime reload
pm2 stop artkubus-api        # Stop app
```

### Health Monitoring

```bash
# Check health
curl https://api.art-kubus.io/health

# Monitor storage
curl -H "Authorization: Bearer TOKEN" \
  https://api.art-kubus.io/api/storage/stats
```

## 🚀 Deployment

### Docker Deployment

#### Development with Cloudflare Tunnel

```powershell
# Start everything with tunnel (no port forwarding)
.\start-dev-tunnel.ps1

# Or manually:
docker-compose --profile tunnel up -d postgres redis backend cloudflared

# View logs
docker-compose logs -f cloudflared
docker-compose logs -f backend

# Stop
docker-compose --profile tunnel down
```

#### Production with Nginx

```bash
# Build image
docker build -t artkubus-api .

# Run full stack (Nginx + backend + database)
docker-compose up -d

# Check logs
docker-compose logs -f backend
```

### cPanel Deployment

See [CPANEL_DEPLOYMENT.md](../docs/CPANEL_DEPLOYMENT.md) for complete guide.

Quick steps:
1. Upload code via Git/FTP
2. `npm install --production`
3. Configure `.env` file
4. `pm2 start ecosystem.config.js`
5. Setup Nginx reverse proxy
6. Install SSL certificate

## 🧪 Testing

```bash
# Unit tests
npm test

# Coverage
npm run test:coverage

# Linting
npm run lint
```

## 📝 Logging

Logs are stored in `logs/` directory:
- `combined.log` - All logs
- `error.log` - Error logs only

PM2 also maintains logs:
```bash
~/.pm2/logs/artkubus-api-out.log   # stdout
~/.pm2/logs/artkubus-api-error.log # stderr
```

## 🔄 Updates & Maintenance

### Update Application

```bash
git pull origin main
npm install --production
pm2 reload artkubus-api  # Zero downtime
```

### Database Migrations

```bash
# Run migrations
node src/db/migrate.js

# Or with custom SQL
psql -U user -d database < migrations/001_init.sql
```

### Backup

```bash
# Database backup
pg_dump -U user database > backup.sql

# Uploads backup
tar -czf uploads-backup.tar.gz uploads/
```

## 🐛 Troubleshooting

### App Won't Start

```bash
# Check logs
pm2 logs artkubus-api --err

# Common fixes:
# 1. Port in use
lsof -i :3001

# 2. Missing .env
cp .env.example .env

# 3. Database connection
node -e "require('dotenv').config(); console.log(process.env.DATABASE_URL)"
```

### IPFS Upload Failing

```bash
# Test Pinata credentials
curl -X GET https://api.pinata.cloud/data/testAuthentication \
  -H "pinata_api_key: YOUR_KEY" \
  -H "pinata_secret_api_key: YOUR_SECRET"

# Fallback to HTTP
# In .env: DEFAULT_STORAGE_PROVIDER=http
pm2 restart artkubus-api
```

## 📚 Documentation

- [API Specification](../docs/BACKEND_API_SPEC.md)
- [cPanel Deployment Guide](../docs/CPANEL_DEPLOYMENT.md)
- [AR Integration Guide](../docs/AR_INTEGRATION_GUIDE.md)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🔒 Security Policy

### Reporting Security Issues

**DO NOT** create public GitHub issues for security vulnerabilities.

Email: security@art-kubus.io

### Security Updates

- Monitor `npm audit` regularly
- Update dependencies monthly
- Rotate JWT_SECRET quarterly
- Review access logs weekly

## 🌟 Credits

Built with ❤️ by the Art.Kubus team.
