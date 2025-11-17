# art.kubus - GPT-5-mini Coding Instructions

**Token-Optimized Guide** | Last Updated: Nov 14, 2025 | v0.0.1+1

## Project Identity
**art.kubus** - AR art platform: Flutter app (Android/iOS) + Node.js backend + Solana blockchain
- **Stack**: Flutter 3.3.4+, Node.js 20+, Express, PostgreSQL, Solana, ARCore/ARKit
- **Purpose**: Geospatial AR artwork discovery with NFT minting, token rewards, DAO governance

## Critical File Paths

### Flutter App Structure
```
lib/
├── main.dart                    # Entry point, provider setup
├── main_app.dart                # Root widget, navigation
├── core/
│   └── app_initializer.dart     # 🔴 App startup logic, onboarding flow
├── config/
│   ├── config.dart              # 🔴 Feature flags (70+ settings)
│   └── api_keys.dart            # API keys (gitignored)
├── providers/                   # 🔴 All state management (ChangeNotifier)
│   ├── web3provider.dart        # Web3/Solana state
│   ├── wallet_provider.dart     # Wallet operations
│   ├── artwork_provider.dart    # Artwork data
│   ├── themeprovider.dart       # Theme/colors
│   ├── config_provider.dart     # Runtime config toggle
│   ├── profile_provider.dart    # User profiles
│   ├── dao_provider.dart        # DAO governance
│   └── institution_provider.dart # Institutions
├── services/                    # 🔴 Business logic layer
│   ├── backend_api_service.dart # All API calls (1078 lines)
│   ├── ar_service.dart          # Simple AR launcher (production)
│   ├── ar_manager.dart          # Advanced AR scene management
│   ├── ar_integration_service.dart # AR orchestration (450+ lines)
│   ├── ar_content_service.dart  # IPFS/HTTP content loading
│   ├── achievement_service.dart # Gamification/rewards
│   ├── solana_wallet_service.dart # Mnemonic wallets
│   ├── solana_walletconnect_service.dart # External wallets
│   ├── nft_minting_service.dart # NFT operations (323 lines)
│   ├── task_service.dart        # Task management (singleton)
│   └── push_notification_service.dart # Notifications
├── screens/                     # UI screens
│   ├── home_screen.dart         # Main feed (2107 lines)
│   ├── profile_screen.dart      # User profile (1375 lines)
│   ├── map_screen.dart          # Geospatial map
│   └── ar_screen.dart           # AR viewer
├── models/                      # Data models (fromJson/toJson)
│   ├── artwork.dart             # Artwork model
│   ├── ar_marker.dart           # AR marker model
│   ├── user.dart                # User model
│   └── achievements.dart        # Achievement definitions
├── onboarding/
│   ├── onboarding_screen.dart   # First-time user flow
│   └── permissions_screen.dart  # Permission requests
└── web3/                        # Web3 UI components
    ├── connectwallet.dart       # Wallet connection (1640 lines)
    └── wallet/wallet_home.dart  # Wallet dashboard
```

### Backend Structure
```
backend/
├── src/
│   ├── server.js                # 🔴 Express app entry point
│   ├── routes/                  # 🔴 API endpoints
│   │   ├── artworks.js          # /api/artworks
│   │   ├── arMarkers.js         # /api/ar-markers
│   │   ├── community.js         # /api/community
│   │   ├── auth.js              # /api/auth
│   │   ├── achievements.js      # /api/achievements
│   │   ├── upload.js            # /api/upload
│   │   └── storage.js           # /api/storage
│   ├── services/
│   │   └── storageService.js    # IPFS/HTTP abstraction
│   ├── middleware/              # Auth, validation, rate limiting
│   └── db/
│       └── schema_complete.sql  # PostgreSQL schema
├── .env                         # Environment config (gitignored)
├── package.json                 # Dependencies
└── ecosystem.config.js          # PM2 config
```

## Key Providers & Dependencies

### Provider Initialization Order
```dart
// In main.dart - CRITICAL: Dependencies must be initialized in this order
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => ConfigProvider()),
    ChangeNotifierProvider(create: (_) => ConnectionProvider()),
    ChangeNotifierProvider(create: (_) => PlatformProvider()),
    ChangeNotifierProvider(create: (_) => MockupDataProvider()), // 🔴 Must init before Web3Provider
    ChangeNotifierProxyProvider<MockupDataProvider, Web3Provider>( // 🔴 Depends on MockupDataProvider
      create: (ctx) => Web3Provider(mockupProvider: ctx.read<MockupDataProvider>()),
      update: (ctx, mockup, web3) => web3?..setMockupProvider(mockup) ?? Web3Provider(mockupProvider: mockup),
    ),
    ChangeNotifierProvider(create: (_) => WalletProvider()),
    ChangeNotifierProvider(create: (_) => ArtworkProvider()),
    ChangeNotifierProvider(create: (_) => ProfileProvider()),
    // ... others
  ],
)
```

### Provider State Access Patterns
```dart
// Read once (in build method)
final theme = context.read<ThemeProvider>();

// Watch for changes (rebuilds on update)
final wallet = context.watch<WalletProvider>();

// Access without rebuilding
Provider.of<Web3Provider>(context, listen: false).someMethod();
```

## Feature Flags (lib/config/config.dart)

**NEVER hardcode feature states - always check AppConfig**

```dart
// Core flags
AppConfig.useBackendMockData    // Backend mock data (default: true)
AppConfig.useRealBlockchain     // Real Solana vs simulated (default: true)
AppConfig.enableWeb3            // Web3 features (default: true)
AppConfig.enableMarketplace     // NFT marketplace (default: true)
AppConfig.enableARViewer        // AR features (default: true)
AppConfig.enableWalletConnect   // External wallets (default: true)
AppConfig.enforceWalletOnboarding // Force wallet setup (default: false)

// Runtime check
if (AppConfig.isFeatureEnabled('marketplace')) {
  // Show marketplace UI
}

// Debug logging
AppConfig.debugPrint('Message'); // Only logs in debug mode
```

## Critical Code Rules

### 1. ✅ Professional Code ONLY
```dart
// ❌ FORBIDDEN
// TODO: Add implementation
// Implementation here
if (condition) {
  // Add logic later
}

// ✅ REQUIRED
if (condition) {
  final result = await apiService.fetchData();
  setState(() => data = result);
}
```

### 2. ✅ Theme Colors - NO Hardcoding
```dart
// ❌ WRONG
color: Color(0xFF8B5CF6)           // Hardcoded
color: Colors.purple                // Purple forbidden (AI color)
color: Color(0xFF00838F)           // Hardcoded cyan

// ✅ CORRECT
color: Theme.of(context).colorScheme.primary
color: Theme.of(context).colorScheme.primaryContainer
color: themeProvider.accentColor    // For accent
color: Theme.of(context).colorScheme.surface
```

**Forbidden**: All purple shades - reserved for AI/system indicators only

### 3. ✅ Check Before Creating
```bash
# Always search first
grep -r "class ArtworkService" lib/services/
# Use file_search, grep_search, semantic_search tools
```

### 4. ✅ Async Context Safety
```dart
// ❌ WRONG
await someOperation();
Navigator.of(context).push(...); // Context may be invalid

// ✅ CORRECT
await someOperation();
if (!mounted) return;
Navigator.of(context).push(...);
```

### 5. ✅ Provider Updates
```dart
// After state changes
notifyListeners(); // Required in ChangeNotifier

// In widgets
setState(() {
  // Update local state
});
```

## AR Integration

### Simple AR (Production-Ready)
```dart
// Use this for 99% of cases
import 'package:art_kubus/services/ar_service.dart';

await ARService().launchARViewer(
  modelUrl: 'ipfs://QmX...abc',  // Auto-converts to HTTP gateway
  title: 'Artwork Title',
  resizable: true,
);
```

### IPFS URL Handling
```dart
String resolveIPFS(String url) {
  if (url.startsWith('ipfs://')) {
    final cid = url.replaceFirst('ipfs://', '');
    return 'https://ipfs.io/ipfs/$cid';
  }
  return url;
}
```

### AR Requirements
- **Android**: minSdkVersion 24+, ARCore installed
- **iOS**: ARKit capable device (currently disabled due to vector_math conflict)
- **Testing**: Physical device ONLY (simulator unsupported)

## Web3/Solana Integration

### Wallet Creation
```dart
// Mnemonic wallet
final service = SolanaWalletService();
final mnemonic = service.generateMnemonic(); // 12 words
final keyPair = service.generateKeyPairFromMnemonic(mnemonic);
final publicKey = keyPair.publicKey.toBase58();

// Store mnemonic securely
await FlutterSecureStorage().write(key: 'mnemonic', value: mnemonic);
```

### Network Configuration
```dart
// Default: devnet (see lib/config/api_keys.dart)
void switchNetwork(String network) {
  switch (network) {
    case 'mainnet': _rpcUrl = ApiKeys.solanaMainnetRpc; break;
    case 'devnet': _rpcUrl = ApiKeys.solanaDevnetRpc; break;
    case 'testnet': _rpcUrl = ApiKeys.solanaTestnetRpc; break;
  }
  _rpcClient = RpcClient(_rpcUrl);
  notifyListeners();
}
```

### KUB8 Token Operations
```dart
// Get balance
final balance = await web3Provider.getKUB8Balance(publicKey);

// Transfer (SPL token)
final txHash = await web3Provider.transferKUB8(toAddress, amount);
```

## Backend API Integration

### API Service Setup
```dart
// In lib/services/backend_api_service.dart
final api = BackendApiService();

// Set auth token after login
api.setAuthToken(jwtToken);

// API calls
final artworks = await api.fetchArtworks(page: 1, limit: 20);
final markers = await api.fetchARMarkers(lat: 46.05, lng: 14.50, radius: 1.0);
final profile = await api.fetchUserProfile(userId);
```

### Backend Endpoints
```
GET  /api/artworks?page=1&limit=20
GET  /api/ar-markers?lat=46.05&lng=14.50&radius=1
POST /api/artworks
GET  /api/community/posts
POST /api/community/like
POST /api/community/comment
POST /api/auth/login
POST /api/auth/register
GET  /api/achievements/:userId
POST /api/achievements/unlock
POST /api/upload (multipart/form-data)
GET  /api/storage/stats
```

## Achievement System

```dart
// Trigger achievement check
await AchievementService().checkAchievements(
  userId: userId,
  action: 'artwork_discovered', // or 'ar_viewed', 'nft_minted', 'event_attended'
  data: {'discoverCount': 5},
);

// Stored in SharedPreferences
// Keys: unlocked_achievements_${userId}, kub8_balance
```

## Common Issues & Fixes

### 1. Provider Not Found
```dart
// ❌ WRONG - Provider not in widget tree
final provider = context.read<Web3Provider>();

// ✅ FIX - Ensure provider is initialized in main.dart
// Check provider order in MultiProvider setup
```

### 2. IPFS Timeout
```dart
// Use hybrid storage mode
final url = await api.uploadFile(file, targetStorage: 'hybrid');
// Falls back to HTTP if IPFS fails
```

### 3. AR Camera Permission
```dart
// Request before AR
final status = await Permission.camera.request();
if (status.isPermanentlyDenied) {
  await openAppSettings();
}
```

### 4. Async BuildContext
```dart
// Always check mounted
await asyncOperation();
if (!mounted) return;
// Use context here
```

## Development Commands

```powershell
# Flutter
flutter pub get                    # Install dependencies
flutter run --debug                # Run (use physical device for AR)
flutter build apk --release        # Build Android APK
flutter analyze                    # Check for issues
flutter format lib/                # Format code

# Backend (in backend/ directory)
npm install --production           # Install dependencies
npm run dev                        # Dev mode with nodemon
pm2 start src/server.js --name artkubus-api  # Production
pm2 logs artkubus-api             # View logs
pm2 reload artkubus-api           # Zero-downtime restart
```

## Current TODO List

### Phase 1: Critical Cleanup ✅ COMPLETED
- [x] Remove duplicate services (AchievementService, TaskService)
- [x] Fix all compilation errors
- [x] Replace print() with debugPrint()
- [x] Fix async BuildContext usage

### Phase 2: Architecture Refactor 🚧 IN PROGRESS
- [ ] Extract CommunityService from community_interactions.dart (720 lines)
- [ ] Merge ar_integration_service + ar_content_service → ar_orchestrator
- [ ] Split backend_api_service by domain (artworks_api, markers_api, etc.)
- [ ] Extract TradingService from nft_minting_service.dart
- [ ] Split large screens (home_screen.dart, profile_screen.dart, connectwallet.dart)

### Phase 3: Feature Implementation 📋 PLANNED
- [ ] Complete 6 notification types (auction, collaboration, AR events, challenges, staking)
- [ ] Implement wallet connection UI (wallet_home.dart:116)
- [ ] Add clipboard functionality (wallet_home.dart:212)
- [ ] DAO voting power calculation (governance_hub.dart:145)
- [ ] Real-time community stats (governance_hub.dart:147)
- [ ] Backend analytics integration (institution_analytics.dart)

### Phase 4: Web3 Completion 🔮 FUTURE
- [ ] POAP NFT minting (achievement_service.dart:663)
- [ ] Real Solana transaction sending (wallet_provider.dart:703)
- [ ] DEX swap integration (wallet_provider.dart:714)
- [ ] Blockchain data loading (dao_provider.dart:70, institution_provider.dart:58)

## Recommended Improvements

### 1. Service Layer Organization
**Current**: Flat services/ directory (13 files)
**Proposed**:
```
lib/services/
├── ar/
│   ├── ar_service.dart          # Keep simple launcher
│   ├── ar_manager.dart          # Keep scene management
│   └── ar_orchestrator.dart     # Merge integration + content
├── web3/
│   ├── wallet_service.dart      # Rename from solana_wallet_service
│   ├── nft_service.dart         # Rename from nft_minting_service
│   └── trading_service.dart     # Extract from nft_service
├── backend/
│   ├── artworks_api.dart        # Split from backend_api_service
│   ├── markers_api.dart
│   ├── community_api.dart
│   └── auth_api.dart
└── core/
    ├── achievement_service.dart
    ├── notification_service.dart
    └── storage_service.dart     # New - IPFS/HTTP abstraction
```

### 2. Real-time Features
```dart
// Add Socket.IO client for live updates
import 'package:socket_io_client/socket_io_client.dart';

Socket socket = io('https://api.art-kubus.io', <String, dynamic>{
  'transports': ['websocket'],
  'autoConnect': true,
});

socket.on('artwork_liked', (data) {
  // Update UI in real-time
});
```

### 3. Caching Layer
```dart
// Add dio with cache interceptor
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

final dio = Dio()..interceptors.add(CacheInterceptor(options: cacheOptions));
```

### 4. Error Handling Wrapper
```dart
// Create lib/core/error_handler.dart
class ErrorHandler {
  static Future<T?> handle<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on SocketException {
      showSnackbar('No internet connection');
    } on TimeoutException {
      showSnackbar('Request timeout');
    } catch (e) {
      logError(e);
      showSnackbar('An error occurred');
    }
    return null;
  }
}
```

### 5. Backend Optimization
```javascript
// Add Redis caching in backend
const redis = require('ioredis');
const client = new redis(process.env.REDIS_URL);

// Cache frequently accessed data
app.get('/api/artworks', async (req, res) => {
  const cacheKey = `artworks:${req.query.page}`;
  const cached = await client.get(cacheKey);
  if (cached) return res.json(JSON.parse(cached));
  
  const data = await fetchArtworks(req.query);
  await client.setex(cacheKey, 300, JSON.stringify(data)); // 5min TTL
  res.json(data);
});
```

### 6. Testing Infrastructure
```dart
// Add integration tests
// test/integration/artwork_flow_test.dart
testWidgets('Complete artwork discovery flow', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.byIcon(Icons.explore));
  await tester.pumpAndSettle();
  expect(find.byType(ArtworkCard), findsWidgets);
});
```

### 7. Performance Monitoring
```dart
// Add Firebase Performance Monitoring
import 'package:firebase_performance/firebase_performance.dart';

final trace = FirebasePerformance.instance.newTrace('ar_loading');
await trace.start();
// AR loading logic
await trace.stop();
```

### 8. Analytics Events
```dart
// Add custom analytics events
class AnalyticsService {
  static Future<void> logArtworkView(String artworkId) async {
    if (!AppConfig.enableAnalytics) return;
    await FirebaseAnalytics.instance.logEvent(
      name: 'artwork_view',
      parameters: {'artwork_id': artworkId},
    );
  }
}
```

### 9. Offline Support
```dart
// Add local database with drift
import 'package:drift/drift.dart';

@DataClassName('LocalArtwork')
class Artworks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get imageUrl => text()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}
```

### 10. CI/CD Pipeline
```yaml
# .github/workflows/ci.yml
name: CI/CD
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter test
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v3
        with:
          name: release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

## Project Metrics

**Current State** (Nov 14, 2025):
- Flutter files: 98 .dart files
- Backend routes: 13 endpoints
- Services: 13 files
- Providers: 15 files
- Models: 12 files
- Compilation errors: 0 ✅
- Large files: 8 (>500 lines each)

**Links**:
- Website: https://art.kubus.site
- Main: https://kubus.site
- GitHub: https://github.com/kubus-project/art.kubus
- Social: @art.kubus (Instagram), @kubustech (LinkedIn)

---

## Internet Search Guidelines

**CRITICAL**: GPT-5-mini has limited context - use web search for:

### When to Search Web 🔍
1. **Package Documentation**: Latest API changes, migration guides
   - Search: "flutter [package_name] [version] documentation"
   - Example: "flutter solana 0.31.2 documentation"

2. **Error Messages**: Unknown compilation/runtime errors
   - Search: "flutter [error_message] solution"
   - Example: "flutter vector_math 2.1.4 scaleByVector3 removed"

3. **Best Practices**: Current Flutter/Dart patterns (2024-2025)
   - Search: "flutter [feature] best practices 2025"
   - Example: "flutter provider state management best practices 2025"

4. **API Changes**: Breaking changes in dependencies
   - Search: "[package] breaking changes [version]"
   - Example: "arcore_flutter_plugin breaking changes 0.1.0"

5. **Solana/Web3**: Blockchain protocol updates
   - Search: "solana [feature] dart sdk"
   - Example: "solana spl token transfer dart sdk"

6. **AR Technology**: ARCore/ARKit updates
   - Search: "arcore [feature] flutter implementation"
   - Example: "arcore scene viewer android flutter"

### Search Query Templates
```
# Package issues
"flutter [package] [error] github issues"
"[package] [version] changelog"

# Implementation examples
"flutter [feature] example code"
"dart [pattern] best practice"

# Backend
"express.js [feature] security best practice"
"postgresql [query] optimization"

# Web3
"solana [operation] javascript sdk"
"spl token [action] web3.js"
```

### Trusted Sources (Priority Order)
1. **Official Docs**: 
   - flutter.dev, dart.dev
   - docs.solana.com
   - expressjs.com
   - postgresql.org

2. **Package Repos**:
   - pub.dev (Flutter packages)
   - npmjs.com (Node packages)
   - github.com (source code)

3. **Community**:
   - stackoverflow.com (code solutions)
   - medium.com (tutorials)
   - dev.to (articles)

### Search-First Scenarios
- "I don't have docs for [package]" → Search official docs
- "Error I haven't seen" → Search error + flutter
- "New package version" → Search changelog
- "Deprecated method" → Search migration guide
- "Performance issue" → Search optimization techniques

## Quick Reference Card

```dart
// Provider Access
context.read<Provider>()    // Read once, no rebuild
context.watch<Provider>()   // Watch changes, rebuilds

// Feature Flags
AppConfig.isFeatureEnabled('feature')
AppConfig.debugPrint('msg')

// API Calls
await BackendApiService().fetchArtworks()
await BackendApiService().setAuthToken(jwt)

// AR Launch
await ARService().launchARViewer(modelUrl: url)

// IPFS Convert
url.startsWith('ipfs://') ? 'https://ipfs.io/ipfs/${url.substring(7)}' : url

// Achievement Trigger
await AchievementService().checkAchievements(userId, action, data)

// Theme Color
Theme.of(context).colorScheme.primary
themeProvider.accentColor
```

**Token-Saving Tips**: 
- Reference this file instead of re-explaining patterns
- Use `grep_search` to find existing implementations
- **Search web FIRST** for package docs, errors, and new patterns
- Always cite sources when using web search results

---

**Author**: Rok Černezel | **Version**: 0.0.2 | **Updated**: Nov 14, 2025
