# Repo Debt Follow-Up Audit

Date: 2026-04-09

## Completed Since Initial Audit

- `lib/services/backend_api_service.dart`
  Split large auth/account, profile/presence, messages, parser, and upload slices into helper parts.
- `lib/widgets/community/community_post_card.dart`
  Decomposed into companion part files and repaired the split regressions.
- `lib/widgets/detail/detail_shell_components.dart`
  Split into smaller detail-shell files.
- `lib/widgets/map/nearby/kubus_nearby_art_panel.dart`
  Split into body, header, items, states, and types files.
- `lib/widgets/common/kubus_marker_overlay_card.dart`
  Split into support, header, media, body, and footer files.
- `lib/widgets/auth_methods_panel.dart`
  Split helper and section logic out of the main widget.
- `lib/widgets/map/panels/kubus_marker_form_content.dart`
  Split content parts out of the main widget.
- Community/settings/profile/home/map screens all had targeted duplication extractions.

## Current Priority Order

1. `lib/providers/chat_provider.dart`
2. `lib/screens/community/community_screen.dart` and `lib/screens/desktop/community/desktop_community_screen.dart`
3. `lib/screens/map_screen.dart` and `lib/screens/desktop/desktop_map_screen.dart`
4. `lib/services/backend_api_service.dart`
5. `lib/screens/settings_screen.dart` and `lib/screens/desktop/desktop_settings_screen.dart`

## Remaining Findings

### 1. Chat Provider Is Still A Root-Cause Monolith

Files:
- `lib/providers/chat_provider.dart`
- `lib/providers/chat_provider_cache_helpers.dart`
- `lib/providers/chat_provider_lifecycle_helpers.dart`

Status:
- Cache/session maintenance is extracted.
- Lifecycle methods `bindToRefresh`, `bindAuthContext`, `_startSubscriptionMonitor`, `setCurrentWallet`, `openConversation`, and `closeConversation` are extracted.
- Main file is still about 2422 lines.

Remaining debt:
- `initialize()` is still a giant orchestration block with auth restoration, socket subscription, member prefetch, wallet resolution, and EventBus wiring.
- Conversation/member mutation flow is still concentrated in the provider:
  `fetchMembers`, `_prefetchUsersForWallets`, `mergeUserCache`, `createConversation`, `addMember`, `removeMember`, `renameConversation`, `transferOwnership`, `markRead`, `markMessageRead`, `markMessageReadLocal`, `toggleReaction`.
- Socket event handlers still own a lot of state mutation and list rewriting.

Recommended next split:
- `chat_provider_conversation_helpers.dart`
  Move the conversation/member CRUD and read/reaction mutation methods there.
- Then take a separate `chat_provider_init_helpers.dart`
  Move `initialize()` and EventBus/socket subscription wiring there.

### 2. Chat Provider Has A New Lifecycle Smell

Files:
- `lib/providers/chat_provider.dart`

New finding:
- Socket listeners are registered in the constructor and again in `initialize()`.

Why it matters:
- Current comments say `SocketService` deduplicates listeners, so it is probably safe.
- Even if behavior is safe today, the lifecycle ownership is still unclear and this duplication makes the provider harder to reason about.

Recommended follow-up:
- Pick one owner for socket listener registration.
- Keep the current behavior stable unless `SocketService` listener dedupe is verified end-to-end.

### 3. Community Screens Are Still The Largest UI Duplication Hotspot

Files:
- `lib/screens/community/community_screen.dart`
- `lib/screens/desktop/community/desktop_community_screen.dart`

Current size:
- about 6053 lines
- about 7322 lines

What improved:
- Shared group-card, search-bar, search-action, and composer-layout extractions landed.

Remaining debt:
- Composer flow is still screen-owned in multiple places.
- Search/result routing is still spread between screen and helper layers.
- Tab/feed/group assembly is still too large and still split across mobile and desktop shells.

Recommended next split:
- Shared feed/tab assembly widgets and controller-style orchestration for composer/search state.

### 4. Map Screens Still Own Too Much Orchestration

Files:
- `lib/screens/map_screen.dart`
- `lib/screens/desktop/desktop_map_screen.dart`
- `lib/features/map/shared/map_screen_shared_helpers.dart`

Current size:
- about 4922 lines
- about 4862 lines

What improved:
- Shared lifecycle/style/source-sync/discovery/overlay/search-filter helpers exist.

Remaining debt:
- Mobile and desktop screens still own a lot of overlay wrapper composition.
- Screen-level orchestration around style loading, marker selection, and top-overlay assembly is still heavy.
- These screens still violate the intended “layout-only” target from `AGENTS.md`.

Recommended next split:
- Shared overlay wrapper assembly and search/top-overlay assembly.
- Then move more style/selection orchestration into `KubusMapController` or a map-specific coordinator.

### 5. BackendApiService Is Better But Still Huge

Files:
- `lib/services/backend_api_service.dart`

Current size:
- about 9696 lines

What improved:
- The worst domain-specific blocks were extracted into part files.

Remaining debt:
- The core transport/auth/failover/token layer is still very large.
- Promotion-related API blocks are still concentrated here.
- Small wrapper methods like `createProfile()` are not a problem by themselves, but the file is still oversized enough to slow future refactors.

Recommended next split:
- Keep the existing low-level request layer in place.
- Next extract either promotion APIs or a dedicated auth/request-core helper layer, depending on what blocks the UI/provider cleanup next.

### 6. Settings Pair Is Still Oversized

Files:
- `lib/screens/settings_screen.dart`
- `lib/screens/desktop/desktop_settings_screen.dart`

Current size:
- about 4633 lines
- about 3819 lines

What improved:
- Shared settings widgets reduced repeated row/toggle/dropdown shells.

Remaining debt:
- Section-level orchestration and screen-owned assembly are still large.

Recommended next split:
- Config-driven shared settings section assembly, leaving only shell/layout differences in the two screens.

### 7. Auth Methods Panel Is Smaller But Still A Secondary Widget Hotspot

Files:
- `lib/widgets/auth_methods_panel.dart`

Current size:
- about 905 lines

What improved:
- Helpers and section logic were split out.

Remaining debt:
- Main public widget still holds a lot of branching UI flow.

Recommended next split:
- Extract one more layer around modal/form-state presentation if it keeps growing.

## Resolved Or Deprioritized Findings

- `community_post_card.dart` is no longer a top hotspot.
- `detail_shell_components.dart` is no longer a monolith.
- `kubus_nearby_art_panel.dart` is no longer a monolith.
- `kubus_marker_overlay_card.dart` is no longer a monolith.
- `kubus_marker_form_content.dart` is materially improved.

## Best Resume Point

If continuing later, start here:

1. Finish the `ChatProvider` extraction by moving conversation/member/read/reaction operations into a dedicated helper part.
2. After that, return to the community screen pair for feed/tab/composer orchestration extraction.
