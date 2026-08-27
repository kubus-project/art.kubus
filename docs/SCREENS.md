# App Screens

This inventory describes the current client structure. Mobile and desktop use shared providers and services, with desktop-specific layouts where noted. Feature flags and backend permissions can hide or limit individual actions.

## Primary navigation

| Area | Mobile | Desktop | Purpose |
|---|---|---|---|
| Home | `HomeScreen` | `DesktopHomeScreen` | Discovery rails, activity and entry points |
| Map | `MapScreen` | `DesktopMapScreen` | Public-art discovery and marker interaction |
| Community | `CommunityScreen` | `DesktopCommunityScreen` | Posts, people, follows and messages |
| Wallet | `WalletHome` | `DesktopWalletScreen` | Optional wallet and digital-edition tools |

## Discovery and artwork

- `lib/screens/home_screen.dart`: discovery-focused home surface.
- `lib/screens/map_screen.dart`: interactive map; desktop layout is `lib/screens/desktop/desktop_map_screen.dart`.
- `lib/screens/art/art_detail_screen.dart`: artwork metadata, media, discussion, sharing, optional AR and digital-edition action for authorised creators.
- `lib/screens/art/artwork_edit_screen.dart`: artwork editing and visibility controls.
- `lib/screens/web3/artist/artwork_creator_screen.dart`: draft and publication workflow. It separates artwork creation from optional location, AR/spatial layers, attendance records and digital editions.

Public visibility makes an artwork discoverable and eligible for public archive publication. It does not require an additional archival action. Draft and private artworks are not public archive content.

## AR and spatial

- `lib/screens/art/ar_screen.dart`: mobile AR entry point when supported.
- `lib/screens/web3/artist/artwork_ar_manager_screen.dart` and related AR components: artwork AR and spatial workflows when enabled.

These screens support optional media or spatial layers. They are not required to create or publish an artwork.

## Community and profiles

- `lib/screens/community/community_screen.dart`: community feed and discovery.
- `lib/screens/community/profile_screen.dart`: profile, artworks, activity and public statistics.
- `lib/screens/community/profile_edit_screen.dart`: profile editing.
- `lib/screens/community/messages_screen.dart` and `conversation_screen.dart`: private messaging.

Private messaging and profile data are application data, not public archive content.

## Institutions, events and exhibitions

- `lib/screens/web3/institution/institution_hub.dart`: institution workspace where enabled.
- `lib/screens/events/event_detail_screen.dart` and `exhibition_detail_screen.dart`: public programme views and attendance-related actions.
- Creator screens for events and exhibitions: authorised programme editing and attendance configuration.

Attendance and visit records are distinct from both artworks and digital editions.

## Wallet and digital editions

- `lib/screens/web3/wallet/wallet_home.dart`: optional wallet overview.
- `lib/screens/web3/wallet/nft_gallery.dart`: digital-edition inventory. The filename preserves an internal legacy identifier.
- `lib/screens/web3/marketplace/marketplace.dart`: digital-edition listings and edition series where enabled.
- `lib/screens/desktop/web3/desktop_wallet_screen.dart` and `desktop_marketplace_screen.dart`: desktop equivalents.

Wallet setup, recovery and transaction features apply only to wallet-linked actions. Map browsing and ordinary community participation do not require a wallet. The UI uses “digital edition”; internal APIs and model names may still use NFT or collectible.

## Settings and onboarding

- `lib/screens/settings_screen.dart` and `lib/screens/desktop/desktop_settings_screen.dart`: account, privacy, notification, theme and wallet-related settings.
- `lib/screens/onboarding/`: account, profile and optional wallet onboarding.

Onboarding starts with discovery and an account. Wallet steps are secondary and do not grant archival status to artworks.

## Supporting screens

- Search, notifications, achievements, governance and availability-node views live under `lib/screens/` and `lib/screens/web3/`.
- The kubus Node operator screen configures scoped operator access. It does not provide a general wallet, mining or payment interface.

For screen registration and navigation metadata, see `lib/providers/navigation_provider.dart` and `lib/main.dart`.
