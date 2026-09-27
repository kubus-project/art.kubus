# PRODUCT v5 app-wide audit (Wave 4)

Status: audit of `art.kubus@dev` at `c234877a` (post Wave 3.6) plus the
Wave 4A implementation record. Machine-readable companion:
[`product_v5_app_audit.json`](product_v5_app_audit.json), regenerated with

```powershell
py -3 scripts/audit_product_v5_app.py `
  --baseline c234877ad94d58747a11c5c53ef839750d883d1c `
  --output docs/design/product_v5_app_audit.json
```

The JSON holds per-file and per-area occurrence counts for every legacy
pattern named in the brief (Inter/Outfit helpers, glass panels, blur,
gradients, shadows, hex/legacy cyan literals, accent reads, raw Material
buttons, snackbars, dialogs, sheets, semantics, KUB8 text). Counts are
textual Dart source matches under `lib/` (generated `lib/l10n/` excluded),
not runtime widget counts. The baseline block is the pre-Wave-4 state; the
current block is this branch.

Reference contracts: [DESIGN_SYSTEM_V2.md](../DESIGN_SYSTEM_V2.md),
[PRODUCT_V5_TOKEN_MIGRATION.md](PRODUCT_V5_TOKEN_MIGRATION.md),
[SUBJECT_DETAIL_UX_V1.md](SUBJECT_DETAIL_UX_V1.md),
[ECONOMIC_UX_INVENTORY.md](ECONOMIC_UX_INVENTORY.md). Subject Detail is the
reference and was **not** redesigned.

## Method

1. Source inventory (script above) across 342k lines of Dart in `lib/`.
2. Code reading of every shell, navigation, home, community, settings,
   notification and auth-gate path named below.
3. Guest-state browser captures of the release web build, BEFORE (`c234877a`)
   and AFTER (this branch), with `scripts/qa/product_v5_wave4_capture.mjs`:
   390×844 and 1440×900 in light and dark, EN and SL, plus home at
   320/360/430/768/899/900/1024/1280/1920. Public read-only API GETs were
   passed through so screens show real public content; every write and
   analytics call was stubbed locally. Manifests and PNGs live in
   `output/playwright/product-v5-wave4/{before,after}/` (ignored by Git; see
   Evidence below).
4. Widget tests for the changed primitives (semantics, targets, flatness,
   localization, release guard).

Signed-in, artist, institution and wallet-connected states were audited from
source only (no test account was used against production). Android/iOS were
not run on devices in this wave; CI compiles them.

Severity: **P0** broken · **P1** serious UX · **P2** inconsistent · **P3**
polish. Disposition: **4A** fixed in this PR · **4B** next Wave 4 tranche ·
**MAP** later map/globe wave · **W9/W10** institution/lifecycle waves ·
**KEEP** acceptable as is.

## Global system findings

| Area | Finding at `c234877a` | Sev | Disposition |
| --- | --- | --- | --- |
| Typography | Tokens already render Sofia Sans/Space Mono. 726 deprecated `KubusTypography.inter()` calls in 54 files still *read* as Inter-era code; they render Sofia Sans, so they are compatibility debt, not visual debt. Structural Space Mono register almost unused in app chrome. | P3 | 4A migrates the rewritten widgets to `KubusTextStyles`/`content`/`structural`; notion labels (DISCOVER, settings groups) now use the structural register. Remaining 717 calls migrate per screen as touched (no mechanical replace). |
| Colour | All raw hex and legacy cyan/blue literals live in central token files (allowed). Structural chrome, however, was painted from **data/feature colours**: per-route teal/amber/purple nav selection, indigo settings switches, accent-tinted headers. | P1 | 4A: shell selection, tabs, settings and headers use `KubusColorRoles.active/foreground/rule`; data colours stay on data (activity icons, markers, likes). |
| Surfaces | Ordinary content on glass by default: `EmptyStateCard` (83 call sites), `DesktopCard` (75), post cards, notification/activity tiles, settings panels, community header/tabs, desktop community sidebar, desktop rail, mobile nav. | P1 | 4A flattens all of these defaults. Glass stays explicit for map controls, AR/media chrome, sheets and transient overlays. |
| Gradients | Accent gradient slabs: mobile/desktop home hero, desktop rail wallet card, settings identity header, notification tiles, Season 0 banner, support card, community header. | P1 | 4A removes all listed. Remaining: auth shell animated background, download screen, map glass surface, promotion builder (4B). |
| Buttons | `KubusButton` had no explicit minimum target; home hero used raw `ElevatedButton` on accent; empty states used a bare `TextButton`; guest account used three different Material button families. No shared toggle primitive outside `SubjectActionGroup`. | P2 | 4A: 44 px minimum on `KubusButton`; empty-state action is a secondary `KubusButton`; guest account/home use primary + secondary + quiet hierarchy. Toggle semantics follow the `SubjectActionGroup` pattern. |
| Cards | Card-in-card: repost inside post, stat tiles in glass panels, hero inside card. Hover "lift + shadow" on desktop cards. | P2 | 4A: repost becomes a quoted reference (ground + leading rule); `DesktopCard` hover strengthens the rule instead of lifting. |
| Chips | `KubusChip` already neutral. Desktop community sort chips fill with the active colour when selected (legitimate selected state). | P3 | KEEP. |
| Status | Unread notifications expressed by accent tint/gradient only. | P1 (a11y) | 4A: unread = leading rule + dot + weight + spoken "Unread" prefix. |
| Forms | `KubusTextField`/`CreatorTextField` exist; settings/profile edit still mix glass panels and raw fields. | P2 | 4B (profile edit, creator flows). |
| Modals/sheets | `showKubusDialog` + `BackdropGlassSheet` are canonical; 173 dialogs vs 72 sheets. Auth gate is already a bottom sheet on mobile and dialog-sized on desktop. | P3 | KEEP; per-flow review in 4B. |
| Empty states | Generic "Nothing here" copy in places; Saved has its own `_GlassEmptyState` with per-type accent colours and no route to discovery; guest Community opened on an empty *Following* tab. | P1 | 4A: `EmptyStateCard` flat with real action button; guests land on *Discover*. Saved empty CTA → 4B. |
| Loading | Mixed `AppLoading` (page-centre) and `InlineLoading`; home rails use a sized placeholder. No layout-aware skeletons. | P2 | 4B. Public-entry takeover contract untouched. |
| Errors | `KubusSnackBars.wrap` gives consistent visual tone (636 wrapped calls), but 401/403 vs network vs offline are not classified on most screens; `AppModeUnavailableState` covers IPFS fallback. | P2 | 4B error taxonomy. |
| Spacing | Tokens exist; many literal paddings (10/14/18) in legacy desktop widgets. | P3 | Migrate when touched. |
| Breakpoints | Contract compact < 900 ≤ desktop holds. At 900–1199 the rail stayed *expanded* (180 px) because the auto-collapse guard could never fire above 900; the brand wrapped mid-word and BEFORE home hero collapsed to one character per line at 900 px. | **P0** (900 px home) | 4A: intro no longer a fixed-width slab; rail auto-collapses below 1200 px unless the viewer expands it; rail brand is single-line. |
| Accessibility | Mobile nav: `GestureDetector`s with no label, role or selected state. Desktop rail: no selected state, no labels when collapsed. Post actions: no role, no toggle state, ~32 px targets. | P1 | 4A fixes all three with tests. |
| Motion | Nav icon scale 0.92 bounce; post like scale 1.18; hover lift. Reduced motion honoured by `KubusButton` only. | P3 | 4A removes nav scale and hover lift; like-scale removed with the new action widget. |
| Localization | Hard-coded English "Reduce effects" tile on mobile and desktop settings. Guest greeting "Good afternoon, there". | P2 | 4A localizes both (EN/SL). |
| Role simulation | Mobile settings tile and sheet are `kDebugMode`-guarded; desktop has none. | — | 4A adds a source guard test. |

## Screen matrix

Routes: mobile tabs are `MainApp` indexes (0 map, 1 AR, 2 community, 3 home,
4 profile/account); desktop routes are `DesktopShell` routes.

| Screen | Entry (mobile / desktop) | Findings (type · surface · legacy colour · glass/gradient · buttons · states · a11y/responsive) | Sev | Disposition |
| --- | --- | --- | --- | --- |
| Global shell – mobile nav | tab bar | Icon-only, no labels/semantics, per-tab data accent, glass + shadow, scale animation, ~40 px effective targets | P1 | **4A** flat labeled bar, selected semantics, 48 px, active role |
| Global shell – desktop rail | `/home` … | Per-route accent tint, glass tint, no selected semantics, collapsed items unlabeled, wallet balance gradient card (KUB8/SOL) in primary chrome, guest shown as "Art Enthusiast" | P1 | **4A** flat rail, neutral selection + leading rule, tooltips/labels, quiet Wallet entry without balances, guest "Sign in" |
| Public-entry shell | canonical entity URL | No horizontal shift; nav dialog reuses rail | — | KEEP (not modified beyond shared rail styling) |
| Home / discovery – mobile | tab 3 | Accent gradient hero led with wallet ("Wallet and Web3 access"/KUB8+SOL), greeting "there", Web3 block before activity | P1 | **4A** flat discovery intro (notion, title, lede, Explore map + See community), Web3 block moved last |
| Home / discovery – desktop | `/home` | Gradient hero with "Connect wallet" + decorative AR tile; **P0 at 900 px** (hero text one character per line) | P0 | **4A** same intro, rail collapse at 900–1199 |
| Home quick actions / stats | home | Dashboard tiles ("Start here", "Your cultural activity"), coloured icon tiles | P2 | 4B (keep content, flatten tiles) |
| Map surrounding UI – mobile | tab 0 | Search, filters, discovery path, nearby sheet, controls are map overlays (glass valid). Scope model already separates *current viewport* vs *near me radius* (`KubusMapScope`) and the nearby panel labels the active scope ("Map area"). | P2 | KEEP glass; constraint chips + reset → **MAP** (Wave 6 result-constraint work) |
| Map surrounding UI – desktop | `/explore` | Same; desktop nearby list in functions panel. At Europe zoom markers were not visible in either BEFORE or AFTER capture (renderer/LOD timing) | P2 | **MAP** (engine out of scope) |
| Search | home/map/community bars | Unified `KubusGeneralSearch` with typed results; glass result panel with shadow; no recent searches; suggestions not grouped by type | P2 | 4B (grouping + flat panel off-map) |
| Artwork detail | `/a/…` | Subject Detail reference | — | KEEP (no regression; shared buttons now ≥44 px) |
| Event / exhibition detail | `/e/…`, `/x/…` | Subject Detail reference | — | KEEP |
| Collection detail | `/c/…` | Reference grammar; two decorative gradients remain | P3 | KEEP / later |
| Post detail | post route | Comments list, composer, 47 Inter compat calls | P2 | 4B |
| Artist profile | `/u/…` | Stats row cards, highlights grid, many glass empty states (now flat via `EmptyStateCard`); `_buildStatCard` makes KUB8 cards tappable to wallet on *own* profile | P2 | 4B hierarchy per Subject Detail; KUB8 stat on own profile is a real balance (keep, demote) |
| Institution profile | `/i/…` | Shallow model; glass panels | P2 | 4B / **W9** |
| Generic profile | `/u/…` | As artist without works | P2 | 4B |
| Community feed | tab 2 / `/community` | Accent glass header slab + tinted tab indicator with glow; post cards glass; nested repost glass card; post actions inaccessible; guest landed on empty *Following* | P1 | **4A** flat header/tabs, flat posts, quoted repost, accessible actions, guests on Discover |
| Post composer | FAB / sidebar | Guest could open the composer and only failed on submit ("A ready signer is required") | P1 | **4A** contextual account gate before the composer (mobile) and at submit with draft preserved (desktop) |
| Comments / discussion | post detail / subject | Conversational layout exists; reply hierarchy and keyboard on mobile not re-verified | P2 | 4B |
| Messages / DMs | messages icon | Empty state "Start a conversation using the chat button below" | P2 | 4B copy + gating review |
| Groups | community tab | Group directory header, group feed; create-group now gated | P2 | **4A** gate; layout 4B |
| Notifications | bell / desktop panel | Tiles glass + gradient + shadow; unread by colour only | P1 | **4A** flat `KubusActivityRow` |
| Saved | profile menu | Own glass empty state, per-type accent colours, no route to discovery | P2 | 4B |
| Following / followers | profile | Lists via profile screens | P3 | 4B |
| Onboarding | `/onboarding` | 6.1k-line flow; animated gradient background; structured steps and return intent already wired | P2 | 4B (visual), flow KEEP |
| Register / login | `/register`, `/sign-in` | Sign-in flat; desktop auth shell animated gradient + glass | P2 | 4B |
| Gated action flow | any protected action | See table below | P1 → fixed where noted | 4A composer/group; others KEEP |
| Profile edit | profile | Mixed glass panels and fields | P2 | 4B |
| Settings – mobile | account tab / gear | Endless list; gradient identity header with KUB8/SOL balance cards and dead edit icon; indigo switches; per-section data colours; tinted app bar; hard-coded English | P1 | **4A** grouped (ACCOUNT / EXPERIENCE / privacy & analytics / INFRASTRUCTURE / about), flat panels, active role, localized |
| Settings – desktop | gear | Already tabbed; hard-coded English "Reduce effects" | P2 | **4A** localized; visual pass 4B |
| Privacy / analytics settings | settings | Single `ConfigProvider.enableAnalytics` source; reachable logged out; historical "needs enablement" state not reproducible (tests pass: `config_analytics_reactivity_test`) | — | KEEP (regression-tested) |
| Achievements | profile | Glass panel; KUB8 only where definition is explicit | P2 | 4B presentation |
| Wallet | rail / settings | Infrastructure screens: glass, KUB8 balances legitimately shown | P2 | 4B (truthful balances kept) |
| Marketplace | `/marketplace` (labs) | Gradients, raw buttons; legitimate KUB8 prices | P2 | 4B |
| Promotion | promotion builder sheet | Glass + frosted slots; legitimate paid flow | P2 | 4B |
| Artist Studio | `/artist-studio` | Glass cards dashboard | P2 | 4B |
| Institution Hub | `/institution` | Glass cards dashboard | P2 | 4B / **W9** |
| Collaboration | invites inbox | Material list | P3 | 4B |
| DAO | `/governance` (labs) | 3k-line hub; glass; stays labs-flagged in nav | P2 | 4B / **W10** |
| Admin-related product | — | No admin console inside the app beyond node operator/role tools | — | documented |
| AR | tab 1 / `/ar` | Glass chrome over camera is a valid spatial overlay; web redirects to download | — | KEEP |
| Spatial capture / library | spatial routes | `KubusButton` based, flat | P3 | KEEP |
| Node / infrastructure entry | settings, `/web3` guest item | Node operator screen; guest desktop nav shows an "Infrastructure" entry | P2 | 4B IA review (no DAO/wallet promotion added) |
| Error / empty / offline | app-wide | `AppModeUnavailableState`, snackbars; no typed error surfaces | P2 | 4B |

Counts (44 screen rows; 6 reference/KEEP rows carry no severity): **P0 1**,
**P1 8**, **P2 25**, **P3 4**. After Wave 4A: the P0 and 7 of 8 P1 rows are
fixed (the gated-action row is fixed for the two unguarded actions found);
P2/P3 rows are assigned to 4B or later waves.

## Legacy inventory classification

| Pattern | Baseline → current (occurrences / files) | Classification |
| --- | --- | --- |
| `KubusTypography.inter()` | 726/54 → 717/54 | LEGACY COMPATIBILITY (renders Sofia Sans); MIGRATE per screen when touched |
| `KubusTypography.outfit()` | 1/1 → 1/1 | MAP/SPATIAL EXCEPTION (`marker_attribution_section.dart`) |
| `LiquidGlassPanel/Card` | 182/103 → 169/92 | MAP/SPATIAL EXCEPTION for map, AR, media, sheets; MIGRATE for remaining profile/studio/hub/wallet panels (4B). Runtime effect is larger than the textual delta because the shared defaults (`EmptyStateCard`, `DesktopCard`, post card, activity row) changed |
| `BackdropFilter` / `ImageFilter.blur` | 3/2, 4/3 → unchanged | KEEP (canonical glass stack and background only, lint-enforced) |
| `LinearGradient` | 86/54 → 78/48 | MIGRATE decorative (4B list in JSON); KEEP data/media scrims |
| `RadialGradient` | 1/1 | download screen – MIGRATE 4B |
| `AnimatedGradientBackground` | 26/24 → 26/24 | LEGACY; auth/onboarding/transitional consumers → 4B |
| `BoxShadow` | 70/51 → 62/46 | MIGRATE ordinary; KEEP map overlay elevation |
| hex literals | 123/7 | KEEP (all in central token/role/marker files) |
| legacy blue/cyan hex | 8/2 | KEEP as data/gradient tokens (`kubus_accent_gradients.dart`, `design_tokens.dart`) |
| `KubusColors.primaryVariant*` | 8/5 | MAP/SPATIAL EXCEPTION + token wallet identity; support section usage removed |
| `themeProvider.accentColor` reads | 266/41 → 239/38 | MIGRATE structural uses to roles; user accent remains bounded to `userAccent` |
| raw Material buttons | Elevated 132, Text 300, Outlined 78 | MIGRATE when screens are touched; `KubusButton` is the primary API |
| `SnackBar(` | 662/95 | KEEP (wrapped by `showKubusSnackBar` for consistent tone) |
| KUB8 text | 119/42 → 108/38 | Removed only from ordinary chrome (home hero, rail, settings header). Wallet, marketplace, promotion, achievements, DAO untouched |

## Auth and gated actions

| Action | Gate at `c234877a` | Intent after auth | Wave 4A |
| --- | --- | --- | --- |
| Like (artwork, post, marker) | `ContextualAuthGate` | captured, confirmed on return | KEEP |
| Save (artwork, event, exhibition, collection, post, marker) | gate | captured | KEEP |
| Follow | gate | captured | KEEP |
| Comment | gate | captured | KEEP |
| Message | gate | not replayed (privileged-free but no pending type) | KEEP |
| Create post (mobile) | **none** – composer opened, submit failed | — | **gate before composer** |
| Create post (desktop inline) | **none** at submit | draft kept in field | **gate at submit** (draft preserved) |
| Create group | none | — | **gate** |
| Add marker / claim | gate | not replayed | KEEP |
| Attend / POAP | proof flow, gated in feature | — | KEEP |
| Wallet-dependent / management | `requirements: wallet` or feature gates | never replayed by design | KEEP |

The gate never replays work itself; captured intents are offered back as
an explicit confirmation after sign-in, and authenticated accounts missing a
capability resume exactly the missing onboarding step. Google SSO,
provisional users and Firefox sign-in were not changed; their regression
tests remain in the suite.

## Map UI notes (no engine change)

The historical viewport vs travel/radius contradiction is now modelled
explicitly: `KubusMapFilterState.scope` is either `currentViewport` or
`nearMe` with `nearMeRadiusKm`; the mobile nearby panel receives
`viewportScope` and shows the active scope label ("Map area"). Remaining UX
debt belongs to Wave 6 "result constraints": show viewport, radius, quick
filters, search and place framing as separate visible constraints with one
reset. No geospatial backend change is needed for that UI.

## Economic UX checks

- Artwork, map selection and nearby list do not show a generic KUB8 value
  (unchanged from the economic cleanup; no reward UI added).
- Discovery copy claims no KUB8 or points.
- Home, desktop rail and settings header no longer show KUB8/SOL balances;
  the Wallet screens still show actual balances from `WalletProvider`.
- Marketplace prices, promotion payment, achievement KUB8 definitions and
  DAO flows are untouched.
- No contribution ledger, points unit or artist-support transfer was added.

## Evidence

Ten curated before/after pairs and their manifest are committed in
[`docs/evidence/product-v5-wave4/`](../evidence/product-v5-wave4/manifest.json)
(mobile/desktop home, 900 and 320 px home, community light/dark, guest
composer gate, settings, guest account, SL desktop home). The full matrix
(28 scenes per build) is regenerated locally into
`output/playwright/product-v5-wave4/{before,after}/`; each manifest records
screen, route, viewport, locale, theme, auth state, reason,
horizontal-overflow flag and page errors. Both final runs: 28/28 captured, no
horizontal overflow, no page errors.

## Human validation still required

Automation used viewport widths, not browser zoom. A person must check, in
Chromium and Firefox at **200% browser zoom** on a 1280–1440 px window:
mobile-width layout of Home, Community, Settings and the account tab; the
bottom navigation labels; the auth sheet; the desktop rail collapse/expand;
keyboard focus order through the rail and post actions. Android: bottom
navigation safe area with gesture navigation, keyboard over the community
composer, TalkBack announcement of the selected tab and unread notifications.

## Deferred (Wave 4B and later)

- 4B: artist studio, institution hub (without the Institution v2 model),
  wallet, marketplace, promotion, DAO, achievements, saved, search grouping,
  profile hierarchy, post detail/comments, messages, onboarding/auth shell
  visuals, forms, loading skeletons, error taxonomy, quick-action/stat tiles.
- Map/globe engine, marker LOD and result-constraint chips (Wave 6).
- Institution v2 schema (Wave 9), DAO/moderation lifecycle (Wave 10).
- Android App Links (#181, untouched).
- Backend env reconciliation — see
  [docs/ops/BACKEND_DEPLOYMENT_ENV_SOURCE.md](../ops/BACKEND_DEPLOYMENT_ENV_SOURCE.md).
