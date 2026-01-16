# App Screens

This document provides an overview of all screens in the art.kubus app, organized by feature area.

## Navigation Structure

The app uses a bottom navigation bar (mobile) or side rail (desktop) with these main sections:

| Tab | Mobile Screen | Desktop Screen | Purpose |
|-----|--------------|----------------|---------|
| Home | `HomeScreen` | `DesktopHomeScreen` | Dashboard and discovery |
| Map | `MapScreen` | `DesktopMapScreen` | Interactive art map |
| Community | `CommunityScreen` | `DesktopCommunityScreen` | Social feed and groups |
| Web3 | `WalletHome` | `DesktopWalletScreen` | Wallet and marketplace |

---

## Core Screens

### Home

**Purpose:** Main dashboard with activity feed, quick actions, and artwork discovery.

**Key Features:**
- Recent activity feed with stats charts
- Quick navigation to wallet, marketplace, and studio
- Nearby artwork recommendations
- Search functionality

**Files:**
- Mobile: `lib/screens/home_screen.dart`
- Desktop: `lib/screens/desktop/desktop_home_screen.dart`

---

### Map

**Purpose:** Interactive map showing art installations, exhibitions, and AR markers.

**Key Features:**
- Artwork and exhibition markers on map
- User presence indicators (online users)
- AR scanning for nearby markers
- Location-based discovery
- Direction compass cone
- Marker clustering

**Files:**
- Mobile: `lib/screens/map_screen.dart`
- Desktop: `lib/screens/desktop/desktop_map_screen.dart`

---

### Settings

**Purpose:** App configuration and user preferences.

**Key Features:**
- Profile visibility settings
- Privacy controls
- Security (2FA setup)
- Notification preferences
- Wallet management
- Theme customization
- About and legal info

**Files:**
- Mobile: `lib/screens/settings_screen.dart`
- Desktop: `lib/screens/desktop/desktop_settings_screen.dart`

---

## Art & AR Screens

### Art Detail

**Purpose:** Full artwork information view.

**Key Features:**
- High-resolution artwork image
- Artist info and description
- Comments and discussions
- Share functionality
- AR launch button
- Collaboration panel
- Like and save actions

**File:** `lib/screens/art/art_detail_screen.dart`

---

### AR View

**Purpose:** Augmented reality experience for viewing 3D art.

**Key Features:**
- Marker scanning
- 3D model placement
- Surface detection
- Feature points toggle
- AR session controls

**File:** `lib/screens/art/ar_screen.dart`

*Note: AR features require a physical device with ARCore (Android) or ARKit (iOS).*

---

### Artwork Editor

**Purpose:** Create or edit artwork entries.

**Key Features:**
- Title and description editing
- Cover image upload
- 3D model upload
- AR settings configuration
- Category selection
- Visibility controls

**File:** `lib/screens/art/artwork_edit_screen.dart`

---

### Collection Detail

**Purpose:** View a curated artwork collection.

**Key Features:**
- Artwork grid view
- Collection metadata
- Sharing options
- Collaboration features

**File:** `lib/screens/art/collection_detail_screen.dart`

---

## Community Screens

### Community Feed

**Purpose:** Social hub for posts, discussions, and connections.

**Key Features:**
- Post composer
- Chronological feed
- Group discovery
- Notifications
- Real-time updates via WebSocket

**Files:**
- Mobile: `lib/screens/community/community_screen.dart`
- Desktop: `lib/screens/desktop/community/desktop_community_screen.dart`

---

### Profile

**Purpose:** User profile with activity, artworks, and stats.

**Key Features:**
- Profile stats (followers, following, posts)
- Achievement badges
- Artwork portfolio
- Collection showcase
- Post history
- Follow/unfollow actions

**Files:**
- Mobile: `lib/screens/community/profile_screen.dart`
- Desktop: `lib/screens/desktop/community/profile_screen.dart`

---

### Profile Editor

**Purpose:** Edit user profile information.

**Key Features:**
- Avatar and cover image upload
- Bio editing
- Social links
- Privacy settings
- Artist-specific fields

**Files:**
- Mobile: `lib/screens/community/profile_edit_screen.dart`
- Desktop: `lib/screens/desktop/community/profile_edit_screen.dart`

---

### Messages

**Purpose:** Private messaging and conversations.

**Key Features:**
- Conversation list
- Unread indicators
- New conversation creation
- Search contacts

**File:** `lib/screens/community/messages_screen.dart`

---

### Conversation

**Purpose:** Individual chat thread.

**Key Features:**
- Real-time messaging
- File/image sharing
- Message history
- Read receipts

**File:** `lib/screens/community/conversation_screen.dart`

---

### Post Detail

**Purpose:** Full post view with comments.

**Key Features:**
- Post content
- Comments thread
- Like and repost actions
- Edit/delete (own posts)
- Report functionality

**File:** `lib/screens/community/post_detail_screen.dart`

---

### Group Feed

**Purpose:** Community group view.

**Key Features:**
- Group posts
- Member list
- Membership management
- Post composer

**File:** `lib/screens/community/group_feed_screen.dart`

---

## Web3 Screens

### Wallet Home

**Purpose:** Main wallet dashboard.

**Key Features:**
- Token balances (SOL, KUB8)
- Quick actions (send, receive, swap)
- NFT gallery access
- Transaction history

**Files:**
- Mobile: `lib/screens/web3/wallet/wallet_home.dart`
- Desktop: `lib/screens/desktop/web3/desktop_wallet_screen.dart`

---

### Connect Wallet

**Purpose:** Wallet connection wizard.

**Key Features:**
- Create new wallet
- Import via mnemonic
- WalletConnect support
- QR code scanning

**File:** `lib/screens/web3/wallet/connect_wallet.dart`

---

### NFT Gallery

**Purpose:** User's NFT collection display.

**Key Features:**
- Collectible grid
- Rarity indicators
- NFT details
- Transfer options

**File:** `lib/screens/web3/wallet/nft_gallery.dart`

---

### Marketplace

**Purpose:** NFT marketplace for buying and selling art.

**Key Features:**
- Featured and trending listings
- Category filters
- AR-enabled filter
- My listings tab
- Collectibles grid

**Files:**
- Mobile: `lib/screens/web3/marketplace/marketplace.dart`
- Desktop: `lib/screens/desktop/web3/desktop_marketplace_screen.dart`

---

### Artist Studio

**Purpose:** Artist dashboard for managing portfolio.

**Key Features:**
- Portfolio overview
- Analytics tab
- Create new artwork/collection/exhibition
- Draft management

**Files:**
- Mobile: `lib/screens/web3/artist/artist_studio.dart`
- Desktop: `lib/screens/desktop/web3/desktop_artist_studio_screen.dart`

---

### Governance Hub (DAO)

**Purpose:** DAO governance and voting.

**Key Features:**
- Active proposals
- Voting interface
- Delegate management
- Treasury overview
- Create proposal form

**Files:**
- Mobile: `lib/screens/web3/dao/governance_hub.dart`
- Desktop: `lib/screens/desktop/web3/desktop_governance_hub_screen.dart`

---

### Institution Hub

**Purpose:** Dashboard for cultural institutions.

**Key Features:**
- Event management
- Exhibition overview
- Marker management
- Institution analytics
- Application form

**Files:**
- Mobile: `lib/screens/web3/institution/institution_hub.dart`
- Desktop: `lib/screens/desktop/web3/desktop_institution_hub_screen.dart`

---

### Achievements

**Purpose:** Gamification and progress tracking.

**Key Features:**
- Achievement cards
- Progress indicators
- KUB8 points balance
- Unlockable badges

**File:** `lib/screens/web3/achievements/achievements_page.dart`

---

## Events & Exhibitions

### Exhibition Detail

**Purpose:** View exhibition information.

**Key Features:**
- Exhibition metadata
- Artwork gallery
- POAP collectible
- Collaboration features
- Cover upload

**File:** `lib/screens/events/exhibition_detail_screen.dart`

---

### Exhibition Creator

**Purpose:** Create or edit exhibitions.

**Key Features:**
- Multi-step wizard
- Title and description
- Date range selection
- Cover image upload
- Publish toggle

**File:** `lib/screens/events/exhibition_creator_screen.dart`

---

### Event Detail

**Purpose:** Event information page.

**Key Features:**
- Event details
- Location with map
- Linked exhibitions
- Share functionality
- RSVP actions

**File:** `lib/screens/events/event_detail_screen.dart`

---

## Onboarding Screens

### Welcome Onboarding

**Purpose:** First-launch introduction to the app.

**Key Features:**
- Feature highlights carousel
- Skip option
- Progress indicators

**Files:**
- Mobile: `lib/screens/onboarding/onboarding_screen.dart`
- Desktop: `lib/screens/desktop/onboarding/desktop_onboarding_screen.dart`

---

### Permissions

**Purpose:** Request necessary permissions.

**Key Features:**
- Location permission (for map)
- Camera permission (for AR)
- Notification permission
- Storage permission
- Explanations for each

**Files:**
- Mobile: `lib/screens/onboarding/permissions_screen.dart`
- Desktop: `lib/screens/desktop/onboarding/desktop_permissions_screen.dart`

---

### Web3 Onboarding

**Purpose:** Introduction to Web3 features.

**Key Features:**
- DAO explanation
- Marketplace overview
- Artist studio intro
- Institution features

**Files:**
- Mobile: `lib/screens/onboarding/web3/web3_onboarding_screen.dart`
- Desktop: `lib/screens/desktop/onboarding/desktop_web3_onboarding_screen.dart`

---

## Authentication Screens

### Sign In

**Purpose:** User login.

**Key Features:**
- Email/password login
- Google sign-in
- Wallet connection
- Guest mode
- Password reset

**Files:**
- Mobile: `lib/screens/auth/sign_in_screen.dart`
- Desktop: `lib/screens/desktop/auth/desktop_sign_in_screen.dart`

---

### Register

**Purpose:** New user registration.

**Key Features:**
- Username selection
- Email/password creation
- Google sign-up
- Terms acceptance
- Wallet provisioning

**Files:**
- Mobile: `lib/screens/auth/register_screen.dart`
- Desktop: `lib/screens/desktop/auth/desktop_register_screen.dart`

---

## Activity & Analytics

### View History

**Purpose:** Recently viewed content.

**Key Features:**
- Browsing history
- Artwork views
- Collection visits
- Marker interactions

**File:** `lib/screens/activity/view_history_screen.dart`

---

### Saved Items

**Purpose:** Bookmarked content.

**Key Features:**
- Saved artworks
- Saved posts
- Category filtering
- Quick access

**File:** `lib/screens/activity/saved_items_screen.dart`

---

### Analytics

**Purpose:** Personal analytics dashboard.

**Key Features:**
- Interactive charts
- Time period filters
- Engagement metrics
- Export options

**Files:**
- `lib/screens/activity/advanced_analytics_screen.dart`
- `lib/screens/activity/advanced_stats_screen.dart`

---

## Map Marker Management

### Manage Markers

**Purpose:** AR marker administration.

**Key Features:**
- Marker list view
- Search and filter
- Status indicators
- Create/edit/delete

**File:** `lib/screens/map_markers/manage_markers_screen.dart`

---

### Marker Editor

**Purpose:** Create or edit AR markers.

**Key Features:**
- Name and description
- GPS position picker
- Category selection
- Subject linking (artwork/exhibition)
- Activation radius
- Public/private toggle

**File:** `lib/screens/map_markers/marker_editor_screen.dart`

---

## Desktop-Specific

### Desktop Shell

**Purpose:** Main desktop layout wrapper.

**Key Features:**
- Side navigation rail
- In-shell routing
- Notifications panel
- Functions panel
- Responsive layout

**File:** `lib/screens/desktop/desktop_shell.dart`

---

## Screen Parity

All screens maintain parity between mobile and desktop:
- Same underlying providers and services
- Same data models
- Adapted layouts for screen size
- Consistent feature availability
