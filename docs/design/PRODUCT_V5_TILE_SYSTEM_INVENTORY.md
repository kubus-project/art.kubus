# PRODUCT v5 tile system: migration inventory (0.8.0 visual hardening)

Audit method: `ListTile(`, `Card(`, chevron and arrow icons, local
`*Action*/*Option*/*Shortcut*/*Feature*` card classes (159 occurrences in 73
files at `dev@0f957f60`) plus a structural scan for hand-written icon squares
(29 sites). Each meaningful user-facing case was classified by what it *is*
(see the surface classification in `PRODUCT_V5_SEMANTIC_VISUAL_SYSTEM.md`).
Utility controls (back, close, search, overflow, zoom, password visibility,
media/AR controls, switches) were never candidates.

## Migrated

| File / component | Role | Was | Now |
| --- | --- | --- | --- |
| `settings_screen_parts` `_buildSettingsTile` (about 25 rows) | dense management destination | bordered panel, neutral icon, subtitle, chevron | `SharedSettingsDestinationTile` (compact) |
| `settings_screen_p3/p4` `_buildActionTile` (3) | dialog destination | `Card` + `SharedSettingsRowTile` | `SharedSettingsDestinationTile` |
| `desktop_settings_screen_parts` `_buildSettingsRow` (about 19) | dense management destination | icon box + title + subtitle + chevron | `SharedSettingsDestinationTile`; destination groups no longer sit inside a `DesktopCard` |
| `season0_screen` `_ActionCard` (3) | hub destination | tinted card, icon box, chevron | `KubusActionTile` stacked + subtitle |
| `artist_studio_create_screen` `_CreateOptionCard` (4) | hub destination | glass card, icon box, chevron | `KubusActionTile` stacked + subtitle |
| `home_screen` `_HomeWeb3Card` (4) | hub destination | gradient card, icon box, centred text | `KubusActionTile` stacked; Labs and lock as `status` |
| `KubusWalletActionCard` (mobile and desktop) | primary shortcut with states | flat card, neutral icon | `KubusActionTile` compact with `enabled` / `loading` |
| wallet "Actions" section | grouping | `KubusWalletSectionCard` around tiles | unframed section (heading over tiles) |
| `auth_wallet_entry_menu`, `connectwallet_screen` options (6) | destination | glass row, gradient icon square | `WalletOptionTile` (compact, "Advanced" as status) |
| `community_season0_banner` (2 screens) | destination | surface + icon + chevron | compact `KubusActionTile` (structural colour, not the personal accent) |
| `profile_screen` `_buildOptionItem` (4) | destination | glass card, icon box, chevron | compact `KubusActionTile` |
| `share_sheet` (4) | destination | glass card, icon box | compact `KubusActionTile` |
| `support_section` links (3) | destination | chip card inside a card | compact tiles; outer card removed |
| `desktop_profile_screen` analytics dialog (2) | destination | `ListTile` | compact `KubusActionTile` |
| `desktop_home_screen` platform stats (4) | metric | icon box rows in a card | `KubusStatCard` |
| `desktop_community` error / empty states (2) | empty state | hand-built icon square | `EmptyStateCard` |
| `GradientIconCard` hero icons (12 sites, 5 files) | page identity | 100 px gradient square | `KubusContextIcon.hero` |
| `desktop_connect_wallet_screen` explanation icon | page identity | tinted square | `KubusContextIcon.hero` |
| settings dialog switch and dropdown wrappers | form control | raw `Card` | ruled settings panel |

## Removed

`GradientIconCard`, `MenuItemWidget` (unreferenced), `ExploreOnlyApp` and
`WalletPromptScreen` (unreferenced wallet wall that contradicts guest-first),
and the local classes `_ActionCard`, `_CreateOptionCard`,
`_WalletEntryOptionTile` body, `_SupportLinkChip`, the custom `_HomeWeb3Card`
body, the `KubusWalletDensity` knob and the `CommunitySeason0Banner`
`accentColor`/`variant` parameters.

## Intentionally kept

| Where | Why |
| --- | --- |
| `ar_screen` lists, sheets and switches | spatial/media utility controls and AR entity rows |
| `kubus_node_screen`, `marketplace`, `collection_settings`, `event_creator` switch / checkbox rows | form controls |
| settings switch, dropdown and read-only rows | form controls; aligned with the tiles (no icon) |
| settings theme, accent, language selectors; network and visibility option rows | choice controls |
| community search results, composer subject and group pickers, `marker_editor_view` pickers, `user_persona_picker_content`, `spatial_capture_target_picker` | result and picker rows (selection, not navigation) |
| `view_history`, `saved_items`, `manage_markers`, `exhibition_list`, institution event rows, marketplace edition rows, `community_group_card`, spatial record cards, transaction cards | entity rows |
| `availability_node_operator_screen` token list | administrative entity rows |
| `security_method_row`, `security_summary_card`, `permissions_request_widget` | status rows with their own actions |
| `secure_account_banner_card`, support tier cards | prompt / information content |
| desktop sidebar navigation | `KubusActionSidebarTile` / navigation chrome |
| profile "About" dialog logo mark | brand mark |

`test/design/product_v5_tile_system_guard_test.dart` fails if a one-off
navigation card class, a raw `Card(child: ListTile)` or a hand-written icon
square with a chevron appears outside the allowlist above.
