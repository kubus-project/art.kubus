# Quick Start Script for Development with Cloudflare Tunnel
# No port forwarding or firewall configuration needed!

Write-Host "🚀 Starting art.kubus Backend with Cloudflare Tunnel" -ForegroundColor Cyan
Write-Host ""

# Check if .env exists
if (!(Test-Path ".env")) {
    Write-Host "⚠️  No .env file found. Creating from .env.example..." -ForegroundColor Yellow
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Host "✅ Created .env file. Please review and update if needed." -ForegroundColor Green
    } else {
        Write-Host "❌ .env.example not found. Please create .env manually." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

# Start services with Cloudflare Tunnel
Write-Host "Starting services..." -ForegroundColor Cyan
docker-compose --profile tunnel up -d postgres redis backend cloudflared

Write-Host ""
Write-Host "✅ Services started!" -ForegroundColor Green
Write-Host ""
Write-Host "📡 Your API is now accessible at:" -ForegroundColor Cyan
Write-Host "   https://api.kubus.site" -ForegroundColor White
Write-Host ""
Write-Host "Test with:" -ForegroundColor Yellow
Write-Host "   curl https://api.kubus.site/health" -ForegroundColor White
Write-Host ""
Write-Host "View logs:" -ForegroundColor Yellow
Write-Host "   docker-compose logs -f backend" -ForegroundColor White
Write-Host "   docker-compose logs -f cloudflared" -ForegroundColor White
Write-Host ""
Write-Host "Stop services:" -ForegroundColor Yellow
Write-Host "   docker-compose --profile tunnel down" -ForegroundColor White
Write-Host ""
