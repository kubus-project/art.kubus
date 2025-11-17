# art.kubus - AI Coding Agent Instructions

## Project Overview
**art.kubus** is a Flutter-based AR art platform connecting artists and institutions, featuring:
- Cross-platform mobile app (Android/iOS) with AR capabilities
- Solana blockchain integration (KUB8 token, NFT minting)
- Node.js backend with IPFS/HTTP hybrid storage
- Geospatial artwork discovery with real-world AR placement

**Stack:** Flutter 3.3.4+, Node.js 20+, Solana Web3, ARCore/ARKit, Express.js, PostgreSQL

---

## Architecture Patterns

### State Management: Provider Pattern
All state lives in `ChangeNotifier` providers in `lib/providers/`:
- **Dependency injection via ProxyProvider**: `Web3Provider` depends on `MockupDataProvider`, passed via constructor
- **Provider initialization**: Call `await provider.initialize()` in `AppInitializer` before first route
- **Cross-provider communication**: Use `ProxyProvider` or pass provider instances through constructors

```dart
// Example: Provider with dependencies
ChangeNotifierProxyProvider<MockupDataProvider, Web3Provider>(
  create: (context) => Web3Provider(mockupProvider: context.read<MockupDataProvider>()),
  update: (context, mockupProvider, web3Provider) {
    web3Provider?.setMockupProvider(mockupProvider);
    return web3Provider ?? Web3Provider(mockupProvider: mockupProvider);
  },
)
```

### Feature Flag System
All features controlled via `lib/config/config.dart` - **NEVER hardcode feature states**:
- `AppConfig.useMockData` - Mock data vs real backend (default: false)
- `AppConfig.useRealBlockchain` - Real Solana vs simulated (default: true)
- `AppConfig.enableWeb3` / `enableMarketplace` / `enableARViewer` - Feature toggles
- Check with `AppConfig.isFeatureEnabled('featureName')`

### Onboarding Flow
**3-tier user experience** (see `lib/core/app_initializer.dart`):
1. **First-time users**: OnboardingScreen → MainApp (wallet optional)
2. **Returning users**: Direct to MainApp (skip onboarding if `skipOnboardingForReturningUsers` = true)
3. **Explore mode**: Users can browse artworks without wallet connection

**Keys**: `first_time`, `has_seen_welcome`, `completed_onboarding`, `has_wallet` (SharedPreferences)

### AR Architecture
**Dual implementation** for reliability:
1. **Simple AR Viewer** (`lib/services/ar_service.dart`): Uses platform APIs (ARCore Scene Viewer/AR Quick Look)
   - Call `ARService().launchARViewer(modelUrl: ipfsUrl)` - handles IPFS → HTTP gateway conversion
2. **Advanced AR** (`lib/widgets/ar_view.dart`): Custom ARCore/ARKit integration for in-app placement
   - Platform-specific: `arcore_flutter_plugin` (Android), `arkit_plugin` (iOS - disabled due to vector_math conflict)

**IPFS URLs**: Always convert `ipfs://CID` → `https://ipfs.io/ipfs/CID` before passing to AR viewers

---

## Critical Development Workflows

### Building & Running
```powershell
# Install dependencies
flutter pub get

# Run debug (use physical device for AR)
flutter run --debug

# Build release APK
flutter build apk --release

# Backend (from backend/ directory)
npm install --production
pm2 start ecosystem.config.js  # Production
npm run dev  # Development with nodemon
```

### Testing AR Features
- **Simulator will NOT work** - AR requires physical device with ARCore/ARKit
- Android: minSdkVersion 24+, ARCore installed from Play Store
- iOS: Requires USDZ format for AR Quick Look (GLB for Android)

### Mock Data Toggle
**Runtime switching** (no rebuild needed):
1. Settings → Developer Options → Toggle "Use Mock Data"
2. Changes propagate via `ConfigProvider` → `MockupDataProvider` → dependent providers
3. `ArtworkProvider`, `InstitutionProvider`, `DAOProvider` check `useMockData` flag

---

## Project-Specific Conventions

### Code Quality Standards
**CRITICAL RULES - Always Follow**:
1. ✅ **Professional Code Only**: Write clean, production-ready code. No placeholder comments like "// TODO", "// Implementation here", "// Add logic"
2. ✅ **Check Before Creating**: Always verify if a file, class, function, or feature already exists before creating new ones. Use grep_search, file_search, or semantic_search
3. ✅ **Maintain App Structure**: Keep the existing directory structure. Don't create duplicate files or reorganize without explicit request
4. ✅ **No Purple AI Color**: Never use purple (#8B5CF6, #A855F7, #9333EA, etc.) for UI elements. It's reserved for system/AI indicators only
5. ✅ **Use Theme Colors**: Always use `Theme.of(context).colorScheme.*` or `themeProvider.accentColor` - never hardcode colors except in ThemeProvider
6. ✅ **Complete Implementations**: Every function must have full working code, not stubs or placeholders

### Theme System
**ALWAYS use theme colors** - never hardcode colors:
```dart
// ✅ CORRECT
color: Theme.of(context).colorScheme.primaryContainer
color: themeProvider.accentColor  // For accent color
color: Theme.of(context).colorScheme.primary  // Primary brand color

// ❌ WRONG
color: Color(0xFF00838F)  // Hardcoded color
color: Color(0xFF8B5CF6)  // Purple (AI color - forbidden in UI)
color: Colors.purple  // Forbidden
```

**Current accent**: Deep blue-cyan (#00838F) with 8 cyan/teal variations in `ThemeProvider.availableAccentColors`
**Forbidden**: All purple shades - reserved for AI/system indicators only

### Model Structure
All models have:
- `fromJson()` / `toJson()` for serialization
- Immutable fields (prefer `final`)
- Optional AR fields: `arMarkerId`, `model3DCID`, `model3DURL`, `arScale`

**Example**: `Artwork` model (`lib/models/artwork.dart`) includes social metrics (`likesCount`, `viewsCount`) and AR metadata

### Backend Integration
**Single API client** at `lib/services/backend_api_service.dart`:
- Base URL from `ApiKeys.backendUrl` (defined in `lib/config/api_keys.dart`)
- Authentication via `setAuthToken(jwt)` - adds Bearer header to all requests
- All endpoints return `Future<Map<String, dynamic>>` or throw exceptions
- **Endpoints**: `/api/ar-markers`, `/api/artworks`, `/api/community`, `/api/upload`, `/api/auth`

**Storage abstraction**: Backend supports IPFS/HTTP/Hybrid via `?targetStorage=hybrid` query parameter

### Achievement System
**Token-based rewards** via `lib/services/achievement_service.dart`:
```dart
// Trigger achievement check
await AchievementService().checkAchievements(
  userId: userId,
  action: 'artwork_discovered',  // or 'ar_viewed', 'nft_minted', 'event_attended'
  data: {'discoverCount': count},
);
```
- Saves to SharedPreferences: `unlocked_achievements_${userId}`, `kub8_balance`
- Shows push notification on unlock
- Syncs to backend `/api/achievements/unlock`

---

## Integration Points

### Web3 (Solana) - PAIN POINT AREA ⚠️

#### Wallet Creation & Management
**Two wallet flows**:
1. **Mnemonic wallet** (`lib/services/solana_wallet_service.dart`): 
   - BIP39 mnemonic generation via `generateMnemonic()`
   - Key pair derivation: `generateKeyPairFromMnemonic(mnemonic, accountIndex: 0)`
   - Returns `SolanaKeyPair` with public/private keys + bytes
   - Store mnemonic securely in SharedPreferences (encrypted recommended)
   
2. **WalletConnect** (`lib/services/solana_walletconnect_service.dart`): 
   - Connect external wallets (Phantom, Solflare)
   - QR code pairing via `mobile_scanner`
   - Session management with reown_walletkit

#### Network Configuration
```dart
// In Web3Provider or SolanaWalletService
void switchNetwork(String network) {
  switch (network.toLowerCase()) {
    case 'mainnet': _rpcUrl = ApiKeys.solanaMainnetRpc; break;
    case 'devnet': _rpcUrl = ApiKeys.solanaDevnetRpc; break;
    case 'testnet': _rpcUrl = ApiKeys.solanaTestnetRpc; break;
  }
  _rpcClient = RpcClient(_rpcUrl);
}
```
- Default network: `ApiKeys.defaultSolanaNetwork` (typically 'devnet')
- RPC URLs stored in `lib/config/api_keys.dart`
- Network persisted in SharedPreferences

#### Token Operations (KUB8)
**SPL Token**: Custom token, address in `Web3Provider._kub8TokenAddress`
```dart
// Get KUB8 balance
Future<double> getKUB8Balance(String publicKey) async {
  final tokenBalances = await getTokenBalances(publicKey);
  return tokenBalances.firstWhere(
    (t) => t.mint == _kub8TokenAddress,
    orElse: () => TokenBalance(amount: 0, mint: _kub8TokenAddress),
  ).amount;
}

// Transfer KUB8
Future<String> transferKUB8(String toAddress, double amount) async {
  // Use SPL Token Program
  // Convert amount to smallest unit
  // Sign and send transaction
}
```

#### Common Web3 Issues
1. **Devnet airdrop failures**: 
   - Rate limited (2 SOL per request)
   - Use `requestDevnetAirdrop(publicKey, amount: 1.0)`
   - Check balance with `getSolBalance(publicKey)`

2. **Transaction signing**:
   - Extract private key bytes from keyPair
   - Use `Ed25519HDKeyPair` from solana package
   - Sign with `signTransaction(transaction, keyPair)`

3. **Balance conversions**:
   - Always convert lamports ↔ SOL: `lamports / 1000000000`
   - Token decimals vary: Check mint metadata

4. **Provider state sync**:
   - Call `notifyListeners()` after wallet operations
   - Update both `Web3Provider` and `WalletProvider`
   - Propagate changes via `ProxyProvider`

### AR Integration - PAIN POINT AREA ⚠️

#### Platform-Specific Setup
**Android (ARCore)**:
```gradle
// android/app/build.gradle
android {
  defaultConfig {
    minSdkVersion 24  // Required by ARCore
  }
}
```
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera.ar" android:required="true"/>
<meta-data android:name="com.google.ar.core" android:value="required" />
```

**iOS (ARKit)** - Currently disabled due to vector_math 2.1.4 conflict:
```xml
<!-- Info.plist -->
<key>NSCameraUsageDescription</key>
<string>Camera is required for AR experiences</string>
<key>UIRequiredDeviceCapabilities</key>
<array><string>arkit</string></array>
```

#### AR Service Architecture
**Simple AR (Production-ready)**:
```dart
// lib/services/ar_service.dart - Uses platform APIs
await ARService().launchARViewer(
  modelUrl: 'ipfs://QmX...abc',  // Auto-converts to HTTP gateway
  title: 'Monument AR',
  resizable: true,
);
```
- Android: Launches ARCore Scene Viewer (intent-based)
- iOS: Uses AR Quick Look (file:// URL to temp USDZ)
- Handles IPFS → HTTP gateway conversion automatically

**Advanced AR** (In-app):
```dart
// lib/widgets/ar_view.dart - Custom implementation
final arManager = ARManager();
await arManager.addModel(
  modelPath: 'https://cdn.art-kubus.io/model.glb',
  position: Vector3(0, 0, -2),
  scale: Vector3.all(1.5),
  name: 'artwork_model',
);
```

#### AR Content Loading
**IPFS Gateway Resolution**:
```dart
String _resolveIPFSUrl(String url) {
  if (url.startsWith('ipfs://')) {
    final cid = url.replaceFirst('ipfs://', '');
    return 'https://ipfs.io/ipfs/$cid';
  }
  return url;
}
```
- Tries gateways: Pinata → ipfs.io → Cloudflare → dweb.link
- Backend supports `?targetStorage=hybrid` for redundancy
- Cache 3D models locally after first load

#### AR Marker System
**Geospatial Discovery**:
```dart
// Backend: GET /api/ar-markers?lat=46.05&lng=14.50&radius=1
// Returns markers within 1km radius
final markers = await BackendApiService().fetchARMarkers(
  lat: currentLat,
  lng: currentLng,
  radius: 1.0, // kilometers
);

// Check proximity
for (final marker in markers) {
  final distance = calculateDistance(userLocation, marker.position);
  if (distance <= marker.activationRadius) {
    // Show AR prompt
  }
}
```

#### Common AR Issues
1. **Permission denied**: Request camera permission before AR
   ```dart
   final status = await Permission.camera.request();
   if (status.isPermanentlyDenied) await openAppSettings();
   ```

2. **Model not loading**:
   - Verify format: GLB for Android, USDZ for iOS
   - Check URL accessibility (CORS, gateway health)
   - Test with curl: `curl -I https://ipfs.io/ipfs/CID`

3. **AR not available**:
   - Check device compatibility: ARCore/ARKit support
   - Verify meta-data in AndroidManifest.xml
   - Must test on physical device (simulator unsupported)

4. **IPFS timeout**:
   - Switch to HTTP storage temporarily
   - Use hybrid mode: `?targetStorage=hybrid`
   - Pin content to Pinata for reliability

### Community Features
**All in `lib/community/`**:
- Likes/comments/shares stored in `CommunityPost` model
- Backend endpoints: `/api/community/posts`, `/api/community/like`, `/api/community/comment`
- Real-time updates via Socket.IO (backend has socket support)

---

## Key Files Reference

### Configuration
- `lib/config/config.dart` - Feature flags, environment config (70+ settings)
- `lib/config/api_keys.dart` - API keys (gitignored, use template)
- `pubspec.yaml` - Dependencies, versions (note: arkit_plugin disabled)

### State Management
- `lib/main.dart` - Provider setup with dependencies
- `lib/core/app_initializer.dart` - App startup logic, route decisions
- `lib/providers/themeprovider.dart` - Theme colors, dark/light mode

### Services
- `lib/services/ar_service.dart` - Simple AR launcher (production-ready)
- `lib/services/backend_api_service.dart` - All API calls (1078 lines)
- `lib/services/achievement_service.dart` - Gamification logic
- `lib/services/nft_minting_service.dart` - Solana NFT minting

### Backend
- `backend/src/server.js` - Express app with security (Helmet, CORS, rate limiting)
- `backend/src/services/storageService.js` - IPFS/HTTP abstraction
- `backend/src/routes/` - RESTful API routes

### Documentation
- `docs/AR_IMPLEMENTATION.md` - AR setup guide
- `docs/BACKEND_API_SPEC.md` - API endpoints (401 lines)
- `docs/ACHIEVEMENT_INTEGRATION_COMPLETE.md` - Achievement system guide
- `docs/OPTIMIZATION_REPORT.md` - Project status

---

## Common Pitfalls

1. **Don't use simulator for AR** - Always test on physical device
2. **Check feature flags** - Respect `AppConfig` settings, don't bypass
3. **Handle IPFS URLs** - Convert ipfs:// to HTTP gateway before display/AR
4. **Initialize providers** - Call `await initialize()` in AppInitializer, not in build()
5. **Theme consistency** - Use `Theme.of(context)` instead of hardcoded colors
6. **Backend auth** - Call `BackendApiService().setAuthToken()` after login
7. **SharedPreferences keys** - Use constants from `PreferenceKeys` class
8. **AR permissions** - Request camera permission before AR features (handled in ARService)
9. **Network detection** - Backend uses Solana network from environment, not client
10. **Mock data propagation** - Update all dependent providers when toggling mock mode

---

## Deployment Workflows

### Flutter App Deployment

#### Android APK Build
```powershell
# Clean build
flutter clean; flutter pub get

# Build release APK
flutter build apk --release

# Build app bundle (for Play Store)
flutter build appbundle --release

# Output locations:
# APK: build/app/outputs/flutter-apk/app-release.apk
# AAB: build/app/outputs/bundle/release/app-release.aab
```

#### iOS Build (macOS only)
```bash
# Install CocoaPods dependencies
cd ios; pod install; cd ..

# Build for iOS
flutter build ios --release

# Archive with Xcode
# Product → Archive → Distribute App
```

#### Build Configuration
- **Version**: Update in `pubspec.yaml` (version: 0.0.1+1)
- **App signing**: Configure in `android/app/build.gradle` (release signing config)
- **Icons**: Use flutter_launcher_icons (configured in pubspec.yaml)
- **Splash**: Use flutter_native_splash (configured in pubspec.yaml)

### Backend Deployment (Node.js)

#### cPanel/Shared Hosting
```bash
# 1. Upload code via Git/FTP to ~/public_html/api/

# 2. Install dependencies (production only)
cd ~/public_html/api
npm install --production

# 3. Configure environment
cp .env.example .env
nano .env  # Edit with production values

# 4. Generate secure keys
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"

# 5. Start with PM2
pm2 start src/server.js --name artkubus-api
pm2 save
pm2 startup  # Configure auto-start

# 6. Configure Nginx reverse proxy (cPanel → Apache → Nginx)
# See docs/CPANEL_DEPLOYMENT.md for full guide
```

#### Docker Deployment
```bash
# Build image
docker build -t artkubus-api:latest .

# Run with docker-compose
docker-compose up -d

# Check logs
docker-compose logs -f backend

# Environment variables in .env or docker-compose.yml
```

#### PM2 Process Management
```bash
# Start application
pm2 start src/server.js --name artkubus-api -i 2  # 2 instances (cluster mode)

# Status and monitoring
pm2 status                    # List all processes
pm2 logs artkubus-api        # View logs (tail -f style)
pm2 monit                    # Real-time monitoring

# Application control
pm2 restart artkubus-api     # Restart with downtime
pm2 reload artkubus-api      # Zero-downtime reload (cluster mode)
pm2 stop artkubus-api        # Stop app
pm2 delete artkubus-api      # Remove from PM2

# Persistence
pm2 save                     # Save current process list
pm2 startup                  # Configure auto-start on boot
pm2 resurrect                # Restore saved processes
```

#### Environment Variables (Critical)
```bash
# .env file (backend/)
NODE_ENV=production
DATABASE_URL=postgresql://user:pass@host:5432/dbname
JWT_SECRET=<64-char-hex>  # Generate with crypto.randomBytes(64)
ENCRYPTION_KEY=<32-char-hex>

# Storage Configuration
DEFAULT_STORAGE_PROVIDER=hybrid  # or 'ipfs' or 'http'
PINATA_API_KEY=your_key
PINATA_SECRET=your_secret
IPFS_GATEWAY_URL=https://gateway.pinata.cloud

# Backend URL
HTTP_BASE_URL=https://api.art-kubus.io

# Solana Network (backend uses for validation)
SOLANA_NETWORK=devnet  # or 'mainnet' or 'testnet'
```

#### Nginx Configuration (Reverse Proxy)
```nginx
# /etc/nginx/sites-available/artkubus-api
upstream artkubus_backend {
    server 127.0.0.1:3001;
}

server {
    listen 443 ssl http2;
    server_name api.art-kubus.io;
    
    ssl_certificate /etc/letsencrypt/live/api.art-kubus.io/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.art-kubus.io/privkey.pem;
    
    location / {
        proxy_pass http://artkubus_backend;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $host;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
    }
}
```

#### Database Migrations
```bash
# Create migration (if using migration tool)
npm run migrate:create add_ar_markers_table

# Run migrations
npm run migrate:up

# Rollback
npm run migrate:down

# Or manual SQL
psql -U user -d artkubus_prod < migrations/001_init.sql
```

#### Health Checks
```bash
# Backend health
curl https://api.art-kubus.io/health
# Expected: {"status":"ok","uptime":12345,...}

# Storage stats (requires auth)
curl -H "Authorization: Bearer TOKEN" \
  https://api.art-kubus.io/api/storage/stats

# PM2 health
pm2 ping
```

#### Backup & Maintenance
```bash
# Database backup
pg_dump -U user artkubus_prod > backup_$(date +%Y%m%d).sql

# Uploads backup
tar -czf uploads_backup_$(date +%Y%m%d).tar.gz uploads/

# Update application
git pull origin main
npm install --production
pm2 reload artkubus-api  # Zero downtime

# View logs
pm2 logs artkubus-api --lines 100
tail -f logs/combined.log
tail -f logs/error.log
```

---

## Quick Commands

```powershell
# Flutter Development
flutter clean; flutter pub get       # Clean and reinstall dependencies
flutter run --debug                   # Run debug (use physical device for AR)
flutter format lib/                   # Format code
flutter analyze                       # Analyze code for issues
flutter pub outdated                  # Check for package updates

# Flutter Build
flutter build apk --release           # Build Android APK
flutter build appbundle --release     # Build Android App Bundle
flutter build ios --release           # Build iOS (macOS only)

# Backend Development (from backend/ directory)
npm install --production              # Install dependencies
npm run dev                           # Development mode with nodemon
npm start                             # Production mode
node src/server.js                    # Direct start

# Backend Production (PM2)
pm2 start src/server.js --name artkubus-api
pm2 logs artkubus-api                 # View logs
pm2 reload artkubus-api               # Zero-downtime restart
pm2 restart artkubus-api              # Restart with downtime
pm2 monit                             # Real-time monitoring
pm2 status                            # List processes

# Database
psql -U user -d artkubus_prod         # Connect to PostgreSQL
pg_dump -U user artkubus_prod > backup.sql  # Backup database
```

---

## Development Workflow

### Branch Strategy
**Current**: Single `master` branch (monorepo approach)

**Future** (post-launch):
- `live` - Production branch (deployed to app stores + live backend)
- `dev` - Development branch (staging environment)
- Feature branches: `feature/ar-improvements`, `feature/web3-integration`

**Recommended workflow**:
```bash
# Create feature branch
git checkout -b feature/achievement-system

# Make changes, commit frequently
git add .
git commit -m "Add KUB8 token rewards to achievements"

# Push to GitHub
git push origin feature/achievement-system

# Merge to master (currently) or dev (post-launch)
git checkout master
git merge feature/achievement-system
```

### Code Review (Recommended)
While not currently enforced, consider:
1. Pull Requests for all features
2. Review checklist:
   - [ ] Feature flags respected (`AppConfig`)
   - [ ] Theme colors used (no hardcoded colors)
   - [ ] Provider initialization in correct order
   - [ ] IPFS URLs converted to HTTP gateways
   - [ ] AR tested on physical device
   - [ ] Mock data toggle works
   - [ ] Compilation errors: 0
   - [ ] `flutter analyze` warnings addressed

### Project Links
- **Website**: https://art.kubus.site (project showcase + download links)
- **Main site**: https://kubus.site (portfolio + team info)
- **GitHub**: https://github.com/kubus-project/art.kubus
- **Instagram**: @art.kubus
- **LinkedIn**: @kubustech

---

## Code Health & Cleanup Guide

### 🔴 Critical Issues (Fix Immediately)

#### 1. Duplicate Service Classes
**Problem**: `AchievementService` exists in TWO locations:
- ✅ `lib/services/achievement_service.dart` (113 lines, comprehensive, KEEP THIS)
- ❌ `lib/models/achievements.dart` (line 64, stub implementation, DELETE THIS)

**Action**: Remove duplicate from `achievements.dart`, use import instead:
```dart
// In lib/models/achievements.dart - REMOVE class AchievementService
// ADD: import '../services/achievement_service.dart';
```

#### 2. Duplicate Service Classes (Additional)
**Problem**: `CommunityService` exists in model file:
- ❌ `lib/community/community_interactions.dart` (line 111)
- Should be in `lib/services/community_service.dart` (if not exists, create it)

**Problem**: `TaskService` exists in model file:
- ❌ `lib/models/task.dart` (line 99)
- Should be in `lib/services/task_service.dart` (if not exists, create it)

**Action**: Extract service logic from model files → Create dedicated service files

#### 3. Vector3 Implementation Conflict
**Problem**: Custom `Vector3` class in `lib/widgets/ar_view.dart` (line 856) conflicts with `vector_math` package
```dart
// Current: Custom implementation
class Vector3 {
  final double x, y, z;
  const Vector3(this.x, this.y, this.z);
}

// Issue: arkit_plugin uses vector_math 2.1.4 which removed scaleByVector3
```

**Action**:
- Keep custom `Vector3` for simple AR use cases
- Use `vector_math.Vector3` (imported as `vector.Vector3`) for ARCore/ARKit plugins
- Document when to use which (see AR integration section above)

### 🟡 Important Cleanup (Next Sprint)

#### 4. Replace `print()` with `debugPrint()` or Logger
**Violations**: 50+ instances across codebase
```dart
// ❌ BAD
print('Debug message');

// ✅ GOOD - Use AppConfig helper
AppConfig.debugPrint('Debug message');

// ✅ GOOD - Use Flutter's debugPrint
import 'package:flutter/foundation.dart';
debugPrint('Debug message');

// ✅ BEST - Use logger package
final logger = Logger();
logger.d('Debug message');
```

**Files with most violations**:
- `lib/community/community_interactions.dart` (14 instances)
- `lib/core/app_initializer.dart` (12 instances)
- `lib/providers/mockup_data_provider.dart` (4 instances)

#### 5. Fix Async BuildContext Usage
**Problem**: Using `BuildContext` after `await` without checking `mounted`
```dart
// ❌ BAD
await someAsyncOperation();
Navigator.of(context).push(...);  // Context might be invalid

// ✅ GOOD
await someAsyncOperation();
if (!mounted) return;
Navigator.of(context).push(...);
```

**Violations in**:
- `lib/core/app_initializer.dart` (multiple instances)
- `lib/onboarding/permissions_screen.dart` (line 594)

#### 6. Deprecated Color Methods
**Problem**: Using `color.withOpacity()` instead of `color.withValues()`
```dart
// ❌ DEPRECATED
color.withOpacity(0.5)

// ✅ NEW (Flutter 3.27+)
color.withValues(alpha: 0.5)
```

**Violations in**:
- `lib/core/app_initializer.dart` (3 instances)
- `lib/main_app.dart` (4 instances)

#### 7. Constant Naming Convention
**Problem**: Snake_case constants instead of lowerCamelCase
```dart
// ❌ BAD
const platform_update = 'platform_update';
const gallery_opening = 'gallery_opening';

// ✅ GOOD
const platformUpdate = 'platform_update';
const galleryOpening = 'gallery_opening';
```

**Violations in**:
- `lib/models/dao.dart` (2 instances)
- `lib/models/institution.dart` (2 instances)
- `lib/models/wallet.dart` (1 instance)

### 🟢 Technical Debt (Plan for Refactor)

#### 8. AR Service Fragmentation
**Problem**: 4 separate AR-related services with overlapping responsibilities:
- `ar_service.dart` (187 lines) - Simple platform API launcher ✅ KEEP
- `ar_manager.dart` (130 lines) - Scene management (ARCore/ARKit) ✅ KEEP
- `ar_integration_service.dart` (450+ lines) - High-level orchestration ⚠️ BLOATED
- `ar_content_service.dart` (300+ lines) - IPFS/HTTP content loading ⚠️ BLOATED

**Recommendation**:
1. Keep `ar_service.dart` for simple use cases (production-ready)
2. Keep `ar_manager.dart` for advanced in-app AR
3. **Refactor**: Merge `ar_integration_service.dart` + `ar_content_service.dart` into single `AROrchestrator` class
4. Extract IPFS logic to general `StorageService` (reusable for non-AR content)

#### 9. Web3 Service Duplication
**Services**: Multiple Web3-related services with unclear boundaries:
- `solana_wallet_service.dart` - Mnemonic wallet operations
- `solana_walletconnect_service.dart` - External wallet connections
- `nft_minting_service.dart` (323 lines) - NFT operations + TradingService class
- `web3provider.dart` (369 lines) - State management

**Issue**: `nft_minting_service.dart` contains nested `TradingService` class (line 323) - should be separate file

**Recommendation**:
1. Extract `TradingService` to `lib/services/trading_service.dart`
2. Create facade pattern: `Web3Service` that delegates to specialized services
3. Keep providers thin (state only), move logic to services

#### 10. Screen File Sizes
**Large files** (potential to split):
- `lib/screens/profile_screen.dart` (1375+ lines) - Contains nested `EditProfileScreen`
- `lib/screens/home_screen.dart` (2107+ lines) - Contains nested `ActivityScreen`
- `lib/web3/connectwallet.dart` (1640 lines)
- `lib/services/backend_api_service.dart` (1078 lines)

**Recommendation**:
1. Extract nested screens to separate files
2. Split large screens into widget files: `profile_screen.dart` + `profile_widgets.dart`
3. Split `backend_api_service.dart` by domain: `artworks_api.dart`, `markers_api.dart`, etc.

#### 11. Unused/Commented Code
**Found**:
- `lib/web3/marketplace/marketplace.dart` (line 2117): "Unused - keeping for reference"
- `lib/web3/connectwallet.dart` (line 1437): "UNUSED function - kept for reference"

**Action**: Remove commented code blocks (use git history if needed)

#### 12. TODO Items Needing Implementation
**High Priority TODOs**:
- `lib/web3/wallet/wallet_home.dart:116` - Implement wallet connection
- `lib/web3/wallet/wallet_home.dart:212` - Add clipboard functionality
- `lib/services/push_notification_service.dart:715-773` - 6 notification types unimplemented:
  - Auction notifications
  - Collaboration notifications
  - AR event notifications
  - Challenge notifications
  - Staking notifications

### 🔧 Architecture Improvements

#### 13. Service Layer Organization
**Current structure**: Flat services directory (12 files)

**Proposed structure**:
```
lib/services/
  ├── ar/
  │   ├── ar_service.dart (simple launcher)
  │   ├── ar_manager.dart (scene management)
  │   └── ar_orchestrator.dart (merged integration + content)
  ├── web3/
  │   ├── wallet_service.dart (renamed from solana_wallet_service)
  │   ├── walletconnect_service.dart
  │   ├── nft_service.dart (renamed from nft_minting)
  │   └── trading_service.dart (extracted)
  ├── backend/
  │   ├── artworks_api.dart
  │   ├── markers_api.dart
  │   ├── community_api.dart
  │   └── auth_api.dart
  └── core/
      ├── achievement_service.dart
      ├── notification_service.dart (renamed from push_notification)
      └── storage_service.dart (new - IPFS/HTTP abstraction)
```

#### 14. Model/Service Separation
**Anti-pattern**: Service classes inside model files

**Files to refactor**:
- `lib/models/achievements.dart` → Remove `AchievementService` class
- `lib/models/task.dart` → Extract `TaskService` to `lib/services/task_service.dart`
- `lib/community/community_interactions.dart` → Extract `CommunityService` to `lib/services/community_service.dart`

**Rule**: Models = data structures only. Services = business logic.

### 📊 Cleanup Checklist

#### Phase 1: Critical Fixes ✅ COMPLETED
- [x] Remove duplicate `AchievementService` from `models/achievements.dart`
- [x] Extract `TaskService` to `services/task_service.dart` (singleton pattern)
- [ ] Extract `CommunityService` from `community_interactions.dart` (720 lines)
- [x] Fix Vector3 usage conflicts (documented in AR section)

#### Phase 2: Code Quality ✅ COMPLETED
- [x] Replace all `print()` with `debugPrint()` (70+ instances fixed)
- [x] Fix async BuildContext usage (added `if (!mounted) return;`)
- [x] Replace deprecated `withOpacity()` in critical files (app_initializer, main_app)
- [x] Fix constant naming (all 5 enum instances to camelCase)
- [x] Remove commented "unused" code blocks (marketplace, connectwallet)
- [x] Fix all compilation errors (enum references, service imports, method calls)

#### Phase 3: Architecture Refactor (1-2 weeks)
- [ ] Merge `ar_integration_service` + `ar_content_service` → `ar_orchestrator`
- [ ] Extract `TradingService` from `nft_minting_service.dart`
- [ ] Split `backend_api_service.dart` by domain (artworks, markers, community, auth)
- [ ] Reorganize services into subdirectories (ar/, web3/, backend/, core/)
- [ ] Split large screens (profile, home, connectwallet)

#### Phase 4: Feature Completion (Ongoing)
- [ ] Implement 6 TODO notification types
- [ ] Implement wallet connection (`wallet_home.dart:116`)
- [ ] Add clipboard functionality (`wallet_home.dart:212`)
- [ ] Complete ARKit iOS support (when vector_math conflict resolved)

### 🛠️ Quick Wins (Do First)

**Easy fixes that improve code health immediately**:

1. **Global Find & Replace**:
   ```powershell
   # Replace print with debugPrint
   # Find: ^\s*print\(
   # Replace: debugPrint(
   ```

2. **Add mounted checks** (template):
   ```dart
   await someAsyncOperation();
   if (!mounted) return;  // ADD THIS LINE
   // ... use context here
   ```

3. **Fix constants** (5 files, 5 minutes each):
   ```dart
   // Before: const platform_update = '...';
   // After:  const platformUpdate = '...';
   ```

4. **Remove unused imports** (auto-fix):
   ```powershell
   flutter pub run dart fix --apply
   ```

### 📈 Metrics

**Current State** (After Phase 1-2 Cleanup):
- Total Dart files: ~100+
- Service files: 13 (TaskService extracted, CommunityService pending)
- Lint warnings: ~400 (mostly `deprecated_member_use` for withOpacity, `use_build_context_synchronously`)
- Compilation errors: 0 ✅
- Large files (>500 lines): 8 files
- Duplicate services: 0 ✅ (all fixed)
- TODOs: Documented but not blocking compilation

**Target State** (Phase 3 goals):
- Lint warnings: <100 (fix critical withOpacity warnings)
- Extract CommunityService (720 lines)
- Merge AR services (ar_integration + ar_content → ar_orchestrator)
- Split backend_api_service by domain
- All TODOs categorized (high/medium/low priority)

---

**Last Updated:** November 12, 2025
**App Version:** 0.0.2
**Flutter SDK:** >=3.3.4 <4.0.0
**Node.js:** 20+
**Author:** Rok Černezel (Founder & Lead Developer)
