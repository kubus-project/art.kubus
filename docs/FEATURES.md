# Features

This document provides detailed documentation for the major features in art.kubus.

---

## Table of Contents

1. [Interactive Map](#interactive-map)
2. [Augmented Reality (AR)](#augmented-reality-ar)
3. [Community & Social](#community--social)
4. [Artist Studio](#artist-studio)
5. [Institutions & Events](#institutions--events)
6. [Web3 Integration](#web3-integration)
7. [Achievements & Gamification](#achievements--gamification)
8. [Offline & Local-First](#offline--local-first)

---

## Interactive Map

The map is the primary discovery interface for finding art in the physical world.

### Features

- **Artwork Markers** — View art installations on the map with category-colored pins
- **Exhibition Markers** — Discover exhibitions and events at cultural venues
- **User Presence** — See other online users in real-time
- **AR Scanning** — Tap the AR button to scan nearby markers
- **Direction Cone** — Visual compass showing your viewing direction
- **Clustering** — Markers cluster at low zoom levels for clarity
- **Search** — Find specific artworks, artists, or locations

### How It Works

1. Grant location permission when prompted
2. The map centers on your current location
3. Nearby markers load automatically
4. Tap a marker to see details
5. Tap "AR" to launch the AR viewer (mobile only)

### Providers & Services

- `MapProvider` — Map state and marker management
- `MapMarkerService` — Marker fetching and caching
- `PresenceProvider` — User presence updates
- `LocationService` — GPS and compass data

---

## Augmented Reality (AR)

Experience art in 3D through your device's camera.

### Features

- **Marker Detection** — Scan physical or GPS-based AR markers
- **3D Model Display** — View artwork models in real space
- **Surface Detection** — Place art on detected surfaces
- **Feature Points** — Toggle AR debugging visualization
- **Capture** — Take photos of AR experiences

### Requirements

- **Android:** ARCore-supported device
- **iOS:** ARKit-supported device (iPhone 6s+, iPad 2017+)
- **Web/Desktop:** AR redirects to mobile app download

### How It Works

1. Tap the AR button on a marker or artwork
2. Point your camera at the AR marker or ground
3. Wait for surface detection
4. The 3D model appears in your space
5. Move around to view from different angles

### Providers & Services

- `ARService` — AR session management
- `ARManager` — Model loading and placement
- `ARIntegrationService` — AR marker resolution

---

## Community & Social

Connect with artists and art enthusiasts.

### Features

- **Feed** — Chronological posts from followed users
- **Posts** — Share text, images, and artwork links
- **Comments** — Discuss posts and artworks
- **Groups** — Join interest-based communities
- **Messaging** — Private conversations
- **Notifications** — Real-time activity alerts
- **Following** — Follow artists and collectors
- **Blocking** — Block unwanted users

### Post Types

- Text posts with optional images
- Artwork shares (link to art detail)
- Exhibition announcements
- Event promotions

### Real-Time Features

Posts, comments, and messages update in real-time via WebSocket connections when the feature is enabled.

### Providers & Services

- `CommunityHubProvider` — Feed and post management
- `ChatProvider` — Messaging and conversations
- `NotificationProvider` — Notification handling
- `PresenceProvider` — Online status
- `BlockListService` — User blocking (local)

---

## Artist Studio

Create and manage your art portfolio.

### Features

- **Portfolio View** — See all your artworks, collections, and exhibitions
- **Artwork Creator** — Multi-step wizard for new artwork
- **Collection Creator** — Curate artwork collections
- **Exhibition Creator** — Plan and publish exhibitions
- **Marker Management** — Create AR markers for your art
- **Analytics** — Track views, likes, and engagement
- **Draft Management** — Work on unpublished content

### Artwork Creation Flow

1. **Basic Info** — Title, description, category
2. **Media Upload** — Cover image (required), 3D model (optional)
3. **AR Settings** — Configure AR display options
4. **Pricing** — Set pricing for marketplace (optional)
5. **Visibility** — Draft, private, or public
6. **Publish** — Make it live

### Collections

Group related artworks together:
- Add/remove artworks
- Set collection cover
- Configure privacy
- Enable collaboration

### Exhibitions

Create time-based art experiences:
- Set date range
- Link artworks
- Configure location/venue
- Issue POAP collectibles

### Providers & Services

- `ArtworkProvider` — Artwork CRUD operations
- `CollectionProvider` — Collection management
- `ExhibitionProvider` — Exhibition handling
- `StatsProvider` — Analytics data

---

## Institutions & Events

Features for museums, galleries, and cultural venues.

### Institution Features

- **Dashboard** — Overview of institution activity
- **Event Management** — Create and manage events
- **Exhibition Hosting** — Host exhibitions at your venue
- **Marker Placement** — Place AR markers at your location
- **Analytics** — Venue-level engagement metrics
- **Verification** — Verified institution badge

### Event Creation

1. Basic info (title, description)
2. Date and time selection
3. Location configuration
4. Capacity and pricing
5. Link to exhibition (optional)
6. Publish

### Application Process

Non-verified institutions can apply for verification through the Institution Hub application form.

### Providers & Services

- `InstitutionProvider` — Institution data and events
- `InstitutionStorage` — Local-first caching
- `EventProvider` — Event management

---

## Web3 Integration

Optional blockchain features for digital ownership.

### Wallet

- **Create Wallet** — Generate a new Solana wallet
- **Import Wallet** — Restore via mnemonic phrase
- **WalletConnect** — Connect external wallet apps
- **Send/Receive** — Transfer SOL and tokens
- **Token Swap** — Exchange tokens in-app

### Supported Tokens

- **SOL** — Solana native token
- **KUB8** — Platform points token
- **NFTs** — Artwork collectibles

### Marketplace

- Browse artwork listings
- Filter by category, price, AR-enabled
- Purchase with connected wallet
- List your own artworks for sale

### DAO Governance

- View active proposals
- Vote on community decisions
- Delegate voting power
- Track treasury

### Security

- Mnemonic stored securely on device
- Biometric/PIN protection for sensitive actions
- Transaction confirmation dialogs

### Providers & Services

- `WalletProvider` — Wallet state and operations
- `Web3Provider` — Web3 feature flags
- `SolanaWalletService` — Blockchain interactions
- `CollectiblesProvider` — NFT management

---

## Achievements & Gamification

Earn recognition for your activity.

### KUB8 Points

**Note:** In the current season, KUB8 is a points system for progression, not a financial instrument.

Earn points by:
- Completing profile
- Viewing artworks
- Posting in community
- Attending events
- Scanning AR markers
- Collecting achievements

### Achievement Categories

- **Explorer** — Discovery and map activities
- **Creator** — Artwork and content creation
- **Collector** — NFT and artwork collection
- **Social** — Community engagement
- **Event** — Exhibition and event participation

### Rewards

- Achievement badges (displayed on profile)
- POAP-style collectibles
- Feature unlocks
- Leaderboard recognition

### Providers & Services

- `TaskProvider` — Progress tracking
- `AchievementService` — Reward distribution

---

## Offline & Local-First

The app remains functional without network connectivity.

### Cached Content

- Recently viewed artworks
- Downloaded 3D models
- Map tiles
- Profile data
- NFT metadata

### Local-Only Features

- **Collectibles** — NFT gallery works offline
- **Blocked Users** — Block list stored locally
- **View History** — Browsing history local
- **Saved Items** — Bookmarks stored locally

### Sync Behavior

When connectivity returns:
- Pending actions sync automatically
- New content loads progressively
- Conflicts resolved server-side

### Storage Services

- `CollectiblesStorage` — NFT caching
- `InstitutionStorage` — Institution data
- `TileDiskCache` — Map tile caching
- SharedPreferences — User preferences

---

## Feature Flags

Many features are controlled by feature flags and can be enabled/disabled:

```dart
// Check if feature is enabled
if (AppConfig.isFeatureEnabled('featureName')) {
  // Show feature
}
```

Common flags:
- `presence` — Real-time user presence
- `achievements` — Gamification features
- `dao` — DAO governance
- `marketplace` — NFT marketplace
- `ar` — Augmented reality

This allows gradual rollout and A/B testing of features.
