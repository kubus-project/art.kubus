# Art.Kubus - Architecture Documentation

## Overview
Art.Kubus is a Flutter-based AR art platform with real-time messaging, Solana blockchain integration, and geospatial artwork discovery.

**Stack:**
- Frontend: Flutter 3.3.4+ (Android/iOS/Web)
- Backend: Node.js 20+ with Express.js
- Database: PostgreSQL
- Real-time: Socket.IO v4
- Blockchain: Solana (KUB8 token, NFT minting)
- Storage: IPFS/HTTP hybrid via Pinata

---

## Core Architecture

### Frontend (Flutter)

#### State Management: Provider Pattern
All state managed through `ChangeNotifier` providers in `lib/providers/`:

**Key Providers:**
- `ChatProvider` - Messaging, conversations, read receipts
- `ProfileProvider` - User profiles and authentication
- `Web3Provider` - Solana wallet and blockchain operations
- `ThemeProvider` - UI theming and accent colors
- `NotificationProvider` - Push notifications and badges

**Provider Dependencies:**
```dart
// Web3Provider depends on MockupDataProvider
ChangeNotifierProxyProvider<MockupDataProvider, Web3Provider>(
  create: (context) => Web3Provider(mockupProvider: context.read<MockupDataProvider>()),
  update: (context, mockupProvider, web3Provider) {
    web3Provider?.setMockupProvider(mockupProvider);
    return web3Provider ?? Web3Provider(mockupProvider: mockupProvider);
  },
)
```

#### Project Structure
```
lib/
├── main.dart                  # App entry point
├── main_app.dart             # Main app scaffold with navigation
├── config/
│   ├── api_keys.dart         # API endpoints and keys
│   └── config.dart           # Feature flags and app configuration
├── core/
│   ├── app_initializer.dart  # Startup logic and route decisions
│   └── conversation_navigator.dart  # Chat navigation helpers
├── models/                    # Data models (immutable classes)
│   ├── message.dart          # ChatMessage model
│   ├── conversation.dart     # Conversation model
│   ├── user.dart             # User model
│   └── ...
├── providers/                 # State management (ChangeNotifier)
│   ├── chat_provider.dart    # Chat state and logic
│   ├── profile_provider.dart # User/profile state
│   └── ...
├── services/                  # Business logic and API clients
│   ├── socket_service.dart   # WebSocket client (singleton)
│   ├── backend_api_service.dart  # REST API client
│   ├── solana_wallet_service.dart  # Wallet operations
│   └── ...
├── screens/                   # UI screens
│   ├── conversation_screen.dart  # Individual chat view
│   ├── messages_screen.dart     # Chat list
│   └── ...
└── widgets/                   # Reusable UI components
```

#### Feature Flag System
All features controlled via `lib/config/config.dart`:
```dart
AppConfig.useMockData = false;        // Mock data vs real backend
AppConfig.useRealBlockchain = true;   // Real Solana vs simulated
AppConfig.enableWeb3 = true;          // Web3 features
AppConfig.enableMarketplace = true;   // NFT marketplace
AppConfig.enableARViewer = true;      // AR capabilities
```

Check features with:
```dart
if (AppConfig.isFeatureEnabled('web3')) {
  // Feature code
}
```

---

### Backend (Node.js/Express)

#### Project Structure
```
backend/
├── src/
│   ├── server.js             # Main server, Socket.IO setup
│   ├── db/
│   │   ├── index.js          # PostgreSQL connection pool
│   │   └── schema.sql        # Database schema
│   ├── middleware/
│   │   ├── auth.js           # JWT verification
│   │   └── errorHandler.js  # Error handling
│   ├── routes/
│   │   ├── messages.js       # Chat endpoints
│   │   ├── profiles.js       # User profiles
│   │   ├── auth.js           # Authentication
│   │   └── ...
│   ├── services/
│   │   └── storageService.js # IPFS/HTTP abstraction
│   └── utils/
│       ├── avatar.js         # DiceBear avatar generation
│       ├── logger.js         # Winston logger
│       └── usernameGenerator.js  # Random usernames
├── migrations/               # SQL migrations
└── package.json
```

#### API Endpoints

**Authentication:**
- `POST /api/auth/register` - Create account with wallet
- `POST /api/auth/login` - Login with wallet signature
- `POST /api/auth/token` - Issue JWT for wallet

**Messages:**
- `GET /api/messages` - List conversations
- `GET /api/messages/:conversationId/messages` - Get messages with readers
- `POST /api/messages/:conversationId/messages` - Send message
- `PUT /api/messages/:conversationId/read` - Mark conversation as read
- `PUT /api/messages/:conversationId/messages/:messageId/read` - Mark message as read
- `GET /api/messages/:conversationId/members` - Get conversation members
- `POST /api/messages/:conversationId/members` - Add member
- `POST /api/messages` - Create conversation

**Profiles:**
- `GET /api/profiles/me` - Get current user profile
- `GET /api/profiles/:wallet` - Get user by wallet
- `PUT /api/profiles/:wallet` - Update profile
- `GET /api/profiles/username/:username` - Get user by username

**Full API documentation:** See `docs/BACKEND_API_SPEC.md`

---

## Messaging System (Read Receipts)

### Architecture Flow

```
1. User opens conversation
   ↓
2. ConversationScreen subscribes to conversation room
   ↓
3. User views message (enters viewport)
   ↓
4. Frontend: ChatProvider.markMessageRead(conversationId, messageId)
   ↓
5. Backend: Updates conversation_members.last_read
   ↓
6. Backend emits socket events:
   - message:read → conversation:<id>
   - message:read → user:<wallet> (for each member)
   ↓
7. Frontend: SocketService receives event
   ↓
8. ChatProvider._onMessageRead() updates message.readers[]
   ↓
9. ConversationScreen rebuilds with read receipts
```

### Socket Event Specifications

#### Server Events (Backend → Frontend)

**`message:read`** - Sent when a user reads a message
```javascript
{
  message_id: "uuid",
  messageId: "uuid",          // Duplicate for compatibility
  conversation_id: "uuid",
  conversationId: "uuid",     // Duplicate for compatibility
  reader: "wallet_address",
  wallet: "wallet_address",   // Duplicate for compatibility
  read_at: "2025-11-18T16:02:39.899Z",
  last_read_at: "2025-11-18T16:02:39.899Z"  // Duplicate
}
```

**`conversation:member:read`** - Sent when a user reads conversation
```javascript
{
  wallet: "wallet_address",
  conversationId: "uuid",
  conversation_id: "uuid",
  last_read_at: "2025-11-18T16:02:39.899Z"
}
```

**`message:received`** - Sent when a new message is posted
```javascript
{
  id: "uuid",
  conversation_id: "uuid",
  sender_wallet: "wallet_address",
  message: "text",
  created_at: "2025-11-18T16:02:39.899Z",
  sender_username: "username",
  sender_display_name: "Display Name",
  sender_avatar: "https://..."
}
```

#### Client Events (Frontend → Backend)

**`subscribe:user`** - Subscribe to personal notification room
```javascript
socket.emit('subscribe:user', walletAddress);
// Response: { room: 'user:wallet_address' }
```

**`subscribe:conversation`** - Subscribe to conversation room
```javascript
socket.emit('subscribe:conversation', conversationId);
// Response: { room: 'conversation:uuid' }
```

**`leave:conversation`** - Unsubscribe from conversation
```javascript
socket.emit('leave:conversation', conversationId);
```

### Database Schema

**`messages` table:**
```sql
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id),
  sender_wallet TEXT NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**`conversation_members` table:**
```sql
CREATE TABLE conversation_members (
  conversation_id UUID NOT NULL REFERENCES conversations(id),
  wallet_address TEXT NOT NULL,
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_read TIMESTAMP DEFAULT to_timestamp(0),  -- Used for read receipts
  PRIMARY KEY (conversation_id, wallet_address)
);
```

**Read receipt logic:**
A message is "read by user X" if:
```sql
SELECT 1 FROM conversation_members cm
WHERE cm.conversation_id = $1
  AND cm.wallet_address = $2
  AND cm.last_read >= messages.created_at
```

### Frontend Implementation

**ChatProvider Read Flow:**
```dart
// 1. Mark message as read
await ChatProvider().markMessageRead(conversationId, messageId);

// 2. Updates local state optimistically
markMessageReadLocal(conversationId, messageId);

// 3. Sends to backend
await BackendApiService().markMessageRead(conversationId, messageId);

// 4. Backend emits socket event
// 5. SocketService receives and forwards to ChatProvider
// 6. ChatProvider updates message.readers[] list
// 7. UI rebuilds automatically via Provider pattern
```

**ConversationScreen Auto-Read:**
```dart
void _checkVisibleMessages() {
  for (var i = 0; i < _messages.length; i++) {
    final msg = _messages[i];
    final isVisible = _isMessageInViewport(msg);
    
    if (isVisible && !msg.readByCurrent && msg.senderWallet != myWallet) {
      // Optimistic local update
      _chatProvider.markMessageReadLocal(conversationId, msg.id);
      
      // Queue backend update (throttled)
      _queueMarkMessageRead(msg.id);
    }
  }
}
```

---

## AR Integration

### Architecture Options

**1. Simple AR Viewer (Production-ready)**
Uses platform APIs: ARCore Scene Viewer (Android) / AR Quick Look (iOS)

```dart
await ARService().launchARViewer(
  modelUrl: 'ipfs://QmX...abc',  // Auto-converts to HTTP gateway
  title: 'Monument AR',
  resizable: true,
);
```

**2. Advanced AR (In-app)**
Custom ARCore/ARKit integration for in-app placement

```dart
final arManager = ARManager();
await arManager.addModel(
  modelPath: 'https://cdn.art-kubus.io/model.glb',
  position: Vector3(0, 0, -2),
  scale: Vector3.all(1.5),
  name: 'artwork_model',
);
```

### Platform Requirements

**Android:**
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

**iOS (Currently disabled due to vector_math conflict):**
```xml
<!-- Info.plist -->
<key>NSCameraUsageDescription</key>
<string>Camera is required for AR experiences</string>
```

### IPFS Gateway Resolution
```dart
String _resolveIPFSUrl(String url) {
  if (url.startsWith('ipfs://')) {
    final cid = url.replaceFirst('ipfs://', '');
    return 'https://ipfs.io/ipfs/$cid';
  }
  return url;
}
```

Tries gateways in order:
1. Pinata → ipfs.io → Cloudflare → dweb.link
2. Backend supports `?targetStorage=hybrid` for redundancy
3. Cache 3D models locally after first load

---

## Blockchain Integration (Solana)

### Wallet Creation & Management

**Two wallet flows:**

**1. Mnemonic Wallet:**
```dart
// Generate new wallet
final mnemonic = SolanaWalletService().generateMnemonic();
final keyPair = SolanaWalletService().generateKeyPairFromMnemonic(mnemonic);

// Store mnemonic securely (use flutter_secure_storage in production)
await SharedPreferences.getInstance().setString('mnemonic', mnemonic);
```

**2. WalletConnect:**
```dart
// Connect external wallet (Phantom, Solflare)
await SolanaWalletConnectService().connect();
```

### Network Configuration
```dart
Web3Provider.switchNetwork('devnet');  // or 'mainnet', 'testnet'
```

Configured in `lib/config/api_keys.dart`:
```dart
static const solanaMainnetRpc = 'https://api.mainnet-beta.solana.com';
static const solanaDevnetRpc = 'https://api.devnet.solana.com';
static const solanaTestnetRpc = 'https://api.testnet.solana.com';
```

### KUB8 Token Operations
```dart
// Get KUB8 balance
final balance = await Web3Provider().getKUB8Balance(publicKey);

// Transfer KUB8
final signature = await Web3Provider().transferKUB8(toAddress, amount);
```

---

## Deployment

### Flutter App

**Android APK:**
```powershell
flutter clean
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Android App Bundle (Play Store):**
```powershell
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Backend (Node.js)

**cPanel/Shared Hosting:**
```bash
# Upload to ~/public_html/api/
npm install --production
cp .env.example .env
# Edit .env with production values

# Start with PM2
pm2 start src/server.js --name artkubus-api
pm2 save
pm2 startup
```

**Docker:**
```bash
docker-compose up -d
```

**PM2 Process Management:**
```bash
pm2 start src/server.js --name artkubus-api -i 2  # Cluster mode
pm2 status
pm2 logs artkubus-api
pm2 reload artkubus-api  # Zero-downtime restart
```

### Environment Variables (Backend)

**Critical variables:**
```env
NODE_ENV=production
DATABASE_URL=postgresql://user:pass@host:5432/dbname
JWT_SECRET=<64-char-hex>  # Generate with: node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
ENCRYPTION_KEY=<32-char-hex>

# Storage
DEFAULT_STORAGE_PROVIDER=hybrid
PINATA_API_KEY=your_key
PINATA_SECRET=your_secret
HTTP_BASE_URL=https://api.art-kubus.io

# Network
SOLANA_NETWORK=devnet
CORS_ORIGIN=https://art.kubus.site,https://kubus.site
```

---

## Troubleshooting

### Read Receipts Not Showing

**1. Check Backend Logs:**
```bash
pm2 logs artkubus-api | grep "message:read"
```

Should see:
```
Emitting message:read to conversation:uuid
Emitting message:read to user:wallet_address
```

**2. Check Frontend Logs:**
```dart
# Look for:
SocketService: Received message:read
ChatProvider._onMessageRead: convId=..., messageId=..., reader=...
ConversationScreen._onChatProviderUpdated: msgsInProvider=2, localMsgs=2
```

**3. Verify Socket Connection:**
```dart
# In Flutter:
debugPrint('Socket connected: ${SocketService().isConnected}');
```

**4. Check Database:**
```sql
SELECT wallet_address, last_read
FROM conversation_members
WHERE conversation_id = 'uuid';
```

### Socket Connection Issues

**Symptoms:** Events not received, connection drops

**Solutions:**
1. Verify backend is running: `pm2 status`
2. Check CORS configuration in backend `.env`
3. Ensure client uses correct backend URL:
   ```dart
   flutter run --dart-define=BACKEND_URL=http://localhost:3000
   ```
4. Check firewall rules (port 3000 or configured PORT)

### AR Not Working

**Symptoms:** AR viewer fails to launch

**Solutions:**
1. Must test on physical device (simulators don't support AR)
2. Check camera permissions
3. Verify ARCore/ARKit installed
4. For IPFS models, ensure gateway is accessible:
   ```bash
   curl -I https://ipfs.io/ipfs/CID
   ```

### Blockchain Connection Issues

**Symptoms:** Wallet operations fail, devnet airdrop fails

**Solutions:**
1. Devnet airdrop rate limited (2 SOL per request)
2. Check RPC endpoint health:
   ```dart
   final client = RpcClient(ApiKeys.solanaDevnetRpc);
   final health = await client.getHealth();
   ```
3. Switch to different RPC if needed
4. For testnet, use official faucets

---

## Performance Optimization

### Frontend

**Image Caching:**
```dart
// Use cached_network_image for avatars and artwork
CachedNetworkImage(
  imageUrl: avatarUrl,
  cacheManager: CustomCacheManager(), // 30-day cache
)
```

**List Virtualization:**
```dart
// Use ListView.builder for long lists
ListView.builder(
  itemCount: messages.length,
  itemBuilder: (context, index) => MessageTile(messages[index]),
)
```

**Provider Optimization:**
```dart
// Use Selector to rebuild only affected widgets
Selector<ChatProvider, int>(
  selector: (_, provider) => provider.unreadCounts[convId] ?? 0,
  builder: (context, unreadCount, child) => Badge(count: unreadCount),
)
```

### Backend

**Database Indexing:**
```sql
CREATE INDEX idx_messages_conversation_created ON messages(conversation_id, created_at DESC);
CREATE INDEX idx_conversation_members_wallet ON conversation_members(wallet_address);
CREATE INDEX idx_conversation_members_read ON conversation_members(conversation_id, last_read);
```

**Connection Pooling:**
```javascript
// db/index.js
const pool = new Pool({
  max: 20,  // Maximum connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

**Rate Limiting:**
Already configured in `server.js`:
- API: 100 requests per 15 minutes
- Upload: 50 uploads per hour

---

## Security

### Authentication Flow

```
1. User signs message with wallet
   ↓
2. Frontend sends signature + wallet to /api/auth/login
   ↓
3. Backend verifies signature
   ↓
4. Backend issues JWT with 24h expiry
   ↓
5. Frontend stores JWT in SharedPreferences
   ↓
6. All API requests include: Authorization: Bearer <JWT>
   ↓
7. Backend verifies JWT on protected routes
```

### Best Practices

**Frontend:**
- Never store private keys in SharedPreferences (use flutter_secure_storage)
- Validate all user input
- Use HTTPS for all API calls
- Implement proper error handling

**Backend:**
- JWT secrets from environment variables
- Hash/encrypt sensitive data at rest
- Helmet.js for security headers
- Rate limiting on all endpoints
- SQL injection prevention via parameterized queries
- CORS whitelist in production

---

## Testing

### Frontend (Flutter)

```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage
```

### Backend (Node.js)

```bash
# Run tests
npm test

# Run with coverage
npm run test:coverage
```

**Smoke test backend:**
```powershell
# From backend/scripts/
./smoke-test.ps1
```

---

## Links

- **Website:** https://art.kubus.site
- **Main site:** https://kubus.site
- **GitHub:** https://github.com/kubus-project/art.kubus
- **Instagram:** @art.kubus
- **LinkedIn:** @kubustech

---

## License

Copyright © 2025 Kubus Tech. All rights reserved.

**Author:** Rok Černezel (Founder & Lead Developer)
