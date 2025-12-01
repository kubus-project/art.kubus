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

### OrbitDB Sync & Storage Resilience *(November 2025 update)*
- `backend/src/services/publicSyncService.js` mirrors Postgres data into OrbitDB docstores (`artworks`, `ar_markers`, `profiles`, `community_posts`, `collections`). Keep this dual-write flow intact whenever schemas or routes change.
- Sync behavior is controlled by `ORBITDB_SYNC_MODE` (`dual-write`, `catch-up`, `off`), `ORBITDB_REPO_PATH`, `ORBITDB_SERVER_PRIVATE_KEY`, and `ORBITDB_PEER_SYNC_INTERVAL_MS`. Default is `dual-write`; do not bypass unless explicitly requested.
- `backend/src/services/orbitdbService.js` now retries remote IPFS connections (`IPFS_REMOTE_RETRIES`, `IPFS_REMOTE_RETRY_DELAY_MS`) and automatically falls back to an embedded `ipfs-core` node when `IPFS_REMOTE_FALLBACK=true`.
- Always use the gateway resolver helpers (`IPFS_GATEWAY_URL` supports comma-separated priority lists such as Pinata → ipfs.io → Cloudflare → dweb.link → localhost) through `StorageService`, `ARService`, or `UserService.safeAvatarUrl`. Never hardcode a single CID URL.
- If IPFS is degraded, keep assets reachable via the HTTP/S3 hybrid path (`DEFAULT_STORAGE_PROVIDER=hybrid`, S3 credentials). Fallback-friendly code prevents AR regressions.

---

## Project Structure & Key Files

### Flutter App Structure
```
lib/
├── config/              # Configuration & API keys
│   ├── config.dart      # Feature flags (70+ settings)
│   └── api_keys.dart    # API keys (gitignored)
├── core/                # Core app initialization
│   └── app_initializer.dart  # Startup, routing, onboarding
├── providers/           # State management (19 providers)
│   ├── themeprovider.dart    # Theme & colors
│   ├── web3provider.dart     # Web3 state
│   ├── wallet_provider.dart  # Wallet management
│   ├── artwork_provider.dart # Artwork data
│   ├── config_provider.dart  # Runtime config toggle
│   ├── dao_provider.dart     # DAO state
│   ├── profile_provider.dart # User profiles
│   └── ...               # notification, chat, task, etc.
├── services/            # Business logic & integrations
│   ├── backend_api_service.dart    # All backend calls
│   ├── ar_service.dart             # Platform AR launcher
│   ├── achievement_service.dart    # Token rewards
│   ├── solana_wallet_service.dart  # Wallet operations
│   ├── nft_minting_service.dart    # NFT creation
│   └── ...               # notifications, socket, telemetry
├── screens/             # Main app screens
├── web3/                # Web3 feature modules
│   ├── artist/          # Studio, gallery, analytics
│   ├── dao/             # Governance, voting, proposals
│   ├── institution/     # Hub, analytics, events
│   ├── marketplace/     # NFT marketplace
│   ├── wallet/          # Send, receive, connect
│   └── achievements/    # Achievement system
├── community/           # Social features
├── onboarding/          # First-time user flow
├── widgets/             # Reusable UI components
├── models/              # Data models (artwork, user, etc.)
└── utils/               # Helpers & utilities
```

### Backend Structure
```
backend/src/
├── server.js            # Express app (Helmet, CORS, rate limit)
├── routes/              # API endpoints (15 route files)
│   ├── auth.js          # JWT authentication
│   ├── artworks.js      # Artwork CRUD
│   ├── arMarkers.js     # Geospatial AR markers
│   ├── community.js     # Posts, likes, comments
│   ├── achievements.js  # Achievement system
│   ├── profiles.js      # User profiles
│   ├── collections.js   # Collection management
│   ├── messages.js      # Direct messaging
│   ├── notifications.js # Push notifications
│   ├── storage.js       # File uploads
│   └── ...              # avatar, search, upload, health
├── services/            # Business logic
│   └── storageService.js  # IPFS/HTTP/Hybrid abstraction
├── middleware/          # Auth, validation, error handling
├── db/                  # Database layer (PostgreSQL)
├── scripts/             # Utility scripts
└── utils/               # Shared utilities
```

### Critical Files Reference

**Configuration:**
- `lib/config/config.dart` - All feature flags & environment settings
- `lib/config/api_keys.dart` - Backend/Solana/IPFS credentials
- `pubspec.yaml` - Dependencies (arkit_plugin disabled, see ARKIT_FIX.md)
- `backend/.env` - Backend environment variables

**State Management:**
- `lib/main.dart` - Provider dependency injection tree
- `lib/core/app_initializer.dart` - App startup, onboarding logic
- `lib/providers/config_provider.dart` - Runtime feature toggle

**Key Services:**
- `lib/services/backend_api_service.dart` - Single API client for all backend calls
- `lib/services/ar_service.dart` - Platform-specific AR launcher (production-ready)
- `lib/services/achievement_service.dart` - Token-based rewards
- `lib/services/solana_wallet_service.dart` - Mnemonic wallet creation

**Backend Core:**
- `backend/src/server.js` - Express with security middleware
- `backend/src/services/storageService.js` - Storage layer abstraction
- `backend/src/routes/*.js` - RESTful API (15 endpoint files)

**Documentation:**
- `docs/OPTIMIZATION_REPORT.md` - Current project status
- `docs/WEB3_FIXES_SUMMARY.md` - Recent fixes & solutions
- `docs/ARKIT_FIX.md` - iOS AR compatibility issue
- `docs/BACKEND_API_SPEC.md` - Complete API reference

---

## Common Pitfalls & Pain Points

### Critical Development Rules
1. **AR testing** - MUST use physical device (ARCore/ARKit unavailable in simulator)
2. **Feature flags** - Always check `AppConfig.isFeatureEnabled()`, never hardcode bypasses
3. **Theme colors** - Use `Theme.of(context).colorScheme.*` - NO hardcoded colors (especially purple)
4. **Provider init** - Call `await provider.initialize()` in AppInitializer, NOT in build()
5. **IPFS URLs** - Convert `ipfs://CID` via the gateway resolver helpers (never hardcode a single endpoint)
6. **Mock data** - Check `MockupDataProvider.isMockDataEnabled` in ALL data-fetching methods
7. **OrbitDB sync** - Any Postgres mutation that should surface in Web3/AR (artworks, AR markers, profiles, collections, community posts) must call the relevant `publicSyncService` helper so OrbitDB stays up to date. Respect `ORBITDB_SYNC_MODE`.
8. **Storage fallback** - Always go through the storage/AR helpers so remote IPFS retries, gateway rotation, and HTTP/S3 fallback (`DEFAULT_STORAGE_PROVIDER=hybrid`) keep working.

### Known Issues & Solutions

**1. iOS AR (ARKit) - DISABLED** ⚠️
- **Issue**: `arkit_plugin` incompatible with `vector_math` 2.1.4 (scaleByVector3 missing)
- **Status**: iOS AR disabled in `pubspec.yaml`, code commented in `ar_manager.dart`
- **Workaround**: Use `ar_service.dart` for simple AR (platform APIs work)
- **Reference**: `docs/ARKIT_FIX.md`

**2. Web3 Light Mode Text** ✅ FIXED
- **Issue**: White text on light backgrounds (gradient headers)
- **Solution**: All gradient headers now use `Colors.white`, regular text uses `onSurface`
- **Reference**: `docs/WEB3_FIXES_SUMMARY.md`
- **Files**: artist_studio.dart, governance_hub.dart, institution_hub.dart

**3. Mock Data Toggle** ✅ FIXED
- **Issue**: Mock data showing even when toggle OFF
- **Solution**: All providers check `isMockDataEnabled` flag
- **Affected**: WalletProvider, DAOProvider, Marketplace, ArtworkProvider, EventManager

**4. Devnet Airdrop Limits**
- **Issue**: Solana devnet rate-limits airdrops (2 SOL max)
- **Solution**: Use `requestDevnetAirdrop(publicKey, amount: 1.0)` with retry logic
- **Fallback**: Switch to testnet or use faucet websites

**5. IPFS Gateway Timeouts**
- **Issue**: ipfs.io gateway slow/unreliable
- **Solution**: Backend supports `?targetStorage=hybrid` for redundancy
- **Gateways**: Pinata → ipfs.io → Cloudflare → dweb.link (fallback chain)

**6. Android Core Library Desugaring**
- **Issue**: `flutter_local_notifications` requires Java 8+ features
- **Solution**: Enabled coreLibraryDesugaring in `android/app/build.gradle`
- **Required**: `coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.3'`

### Architecture Gotchas
7. **Provider dependencies** - Use `ProxyProvider` for provider-to-provider communication
8. **Backend auth** - Set token with `BackendApiService().setAuthToken(jwt)` after login
9. **SharedPreferences** - Use `PreferenceKeys` constants, not magic strings
10. **Network switching** - Backend detects from env, client switches in `Web3Provider.switchNetwork()`
11. **AR permissions** - ARService handles camera permission requests automatically
12. **Onboarding flow** - Respects `skipOnboardingForReturningUsers` flag in config

### Performance & Build
13. **Web build** - Requires `--web-renderer html` for AR compatibility
14. **Release builds** - Always `flutter clean; flutter pub get` before building
15. **Hot reload limits** - Provider initialization changes require full restart

---

## Development Workflow

### Quick Start
```powershell
# Initial setup
flutter pub get
cd backend; npm install --production; cd ..

# Run app (debug - use physical device for AR)
flutter run --debug

# Backend dev server (from backend/)
npm run dev  # Nodemon with auto-reload

# Build & test
flutter analyze              # Check for issues
flutter test                 # Run unit tests
flutter build apk --debug   # Test build
```

### Feature Development Pattern
1. **Check existing**: Use grep_search/file_search BEFORE creating new files
2. **Feature flag**: Add to `AppConfig` if new major feature
3. **Provider setup**: Create provider in `lib/providers/`, add to main.dart
4. **Service layer**: Business logic in `lib/services/`
5. **UI screens**: Place in appropriate folder (screens/web3/community/)
6. **Theme colors**: Use `Theme.of(context).colorScheme.*` only
7. **Test**: Physical device for AR, emulator for general UI

### Common Tasks
```powershell
# Toggle mock data (runtime - no rebuild needed)
# Settings → Developer Options → "Use Mock Data"

# Switch Solana network
# Settings → Wallet & Web3 → Network Selection

# Test AR features
flutter run --release  # Debug mode has performance issues with AR

# Check compilation errors
flutter analyze lib/
flutter analyze backend/  # If using Dart analysis

# Format code
flutter format lib/

# Backend logs
cd backend; pm2 logs artkubus-api  # Production
tail -f logs/combined.log          # Development
```

### Debugging Web3 Issues
```powershell
# Check wallet connection
# Settings → Wallet & Web3 → Connection Status

# Verify Solana balance
curl https://api.devnet.solana.com -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getBalance","params":["YOUR_PUBLIC_KEY"]}'

# Test backend connection
curl https://api.art-kubus.io/health

# View provider state
# Add print() statements in provider methods temporarily
```

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

# Backend PM2 (Process Management)
pm2 start src/server.js --name artkubus-api  # Start app
pm2 restart artkubus-api              # Restart with downtime
pm2 reload artkubus-api               # Zero-downtime reload
pm2 logs artkubus-api                 # View logs
pm2 status                            # Check status

# Testing & Quality
flutter test                          # Run unit tests
flutter analyze lib/                  # Analyze Flutter code
flutter doctor                        # Check Flutter setup

# Debugging
flutter run --debug --verbose         # Verbose debug output
flutter logs                          # View device logs
pm2 monit                             # Monitor backend processes

# Docker (Backend)
docker-compose up -d --build backend  # Build and start backend
docker-compose logs -f backend        # Follow backend logs
docker-compose down                   # Stop all containers
```

---

## Project Links & Info

### Code Review Checklist
When reviewing changes or before deployment:
- [ ] Feature flags respected (`AppConfig`)
- [ ] Theme colors used (no hardcoded colors, especially purple)
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
- **Agent playbook**: `AGENTS.md` (Codex-friendly quick start for AI agents)

---

**Last Updated:** November 26, 2025
**App Version:** 0.0.2
**Flutter SDK:** >=3.3.4 <4.0.0
**Node.js:** 20+
**Author:** Rok Černezel (Founder & Lead Developer)
