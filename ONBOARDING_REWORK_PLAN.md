# Onboarding UI/UX Rework Plan

## Table of Contents
1. [Current-State Map](#1-current-state-map)
2. [Proposed-State Map](#2-proposed-state-map)
3. [Component & Layout Spec](#3-component--layout-spec)
4. [UX Copy & UI Structure Per Screen](#4-ux-copy--ui-structure-per-screen)
5. [Implementation Plan](#5-implementation-plan)
6. [QA Acceptance Criteria](#6-qa-acceptance-criteria)

---

## 1. Current-State Map

### 1.1 Screens That Exist Today

```
lib/screens/onboarding/
  onboarding_screen.dart              ← thin wrapper (just returns OnboardingFlowScreen)
  onboarding_flow_screen.dart         ← 4 500-line monolith; ALL steps live here
  onboarding_intro_screen.dart        ← 3-page carousel (welcome, map, AR)
  permissions_screen.dart             ← standalone PageView permissions flow

lib/screens/desktop/onboarding/
  desktop_onboarding_screen.dart      ← thin wrapper (returns OnboardingIntroScreen(forceDesktop))
  desktop_permissions_screen.dart     ← desktop-optimized permissions layout

lib/screens/auth/
  sign_in_screen.dart                 ← sign-in (email/Google/wallet)
  register_screen.dart                ← registration form
  verify_email_screen.dart            ← email verification
  forgot_password_screen.dart
  reset_password_screen.dart
  secure_account_screen.dart
  email_verification_success_screen.dart

lib/widgets/
  auth_methods_panel.dart             ← embedded auth (wallet/email/Google)
  user_persona_onboarding_gate.dart   ← persona gate (post-onboarding)
  user_persona_onboarding_sheet.dart  ← persona selection bottom sheet

lib/services/
  onboarding_state_service.dart       ← SharedPreferences state
  auth_gating_service.dart            ← first-run gating logic

lib/providers/
  deferred_onboarding_provider.dart   ← deep-link cold start deferral

lib/screens/
  onboarding_reset_screen.dart        ← developer tool
```

### 1.2 Current Navigation Graph

```
AppInitializer._initializeApp()
  │
  ├── Deep link (verify-email / reset-password) → /verify-email or /reset-password
  │
  ├── Share deep link → /main (defers onboarding via DeferredOnboardingProvider)
  │
  ├── shouldSkipOnboarding (returning user + completed) → /main or /sign-in
  │
  ├── shouldShowFirstRunOnboarding
  │     ├── Desktop → DesktopOnboardingScreen
  │     │              └── OnboardingIntroScreen(forceDesktop: true)
  │     │                    └── 3-page carousel → OnboardingFlowScreen
  │     │
  │     └── Mobile  → OnboardingScreen
  │                    └── OnboardingFlowScreen
  │                          ├── Step: welcome (DUPLICATES intro carousel content)
  │                          ├── Step: mapDiscovery (inline location permission)
  │                          ├── Step: community (inline notification permission)
  │                          ├── Step: arScan (inline camera permission, conditional)
  │                          ├── Step: daoGovernance (conditional)
  │                          ├── Step: role (persona picker + DAO fields)
  │                          ├── Step: profile (display name, avatar, bio, socials)
  │                          ├── Step: account (embedded AuthMethodsPanel)
  │                          ├── Step: verifyEmail (conditional)
  │                          └── Step: done → /main
  │
  └── else → /main or /sign-in
```

### 1.3 Identified Duplicates & Dead Code

| Issue | Details |
|-------|---------|
| **DUPLICATE: wrapper screens** | `OnboardingScreen` and `DesktopOnboardingScreen` are single-line wrappers adding zero value. |
| **DUPLICATE: welcome content** | `OnboardingIntroScreen` pages 1-3 overlap with `OnboardingFlowScreen.welcome` step. Both use the same l10n keys (`onboardingFlowWelcomeTitle`, `onboardingFlowWelcomeBody`). |
| **DUPLICATE: permissions x3** | Three separate permission implementations: (a) `PermissionsScreen` standalone, (b) `DesktopPermissionsScreen` standalone, (c) inline contextual permissions inside `OnboardingFlowScreen` steps. |
| **DEAD: enum steps** | `_OnboardingStep.permissions`, `_OnboardingStep.artwork`, and `_OnboardingStep.follow` are defined in the enum and have `_buildStepCard` branches but are **never included** in `_buildSteps()`. |
| **DEAD: standalone permissions** | `PermissionsScreen` and `DesktopPermissionsScreen` are not reachable from the current flow (intro screen navigates directly to `OnboardingFlowScreen`). |
| **LEGACY: multiple pref keys** | Migrated-but-still-present legacy keys: `first_time`, `completed_onboarding`, `has_seen_onboarding`, `has_seen_permissions`. |

### 1.4 Current Pain Points (confirmed by code)

1. **Too many steps**: Default flow is 8-10 steps (welcome → mapDiscovery → community → [arScan] → [daoGovernance] → role → profile → account → [verifyEmail] → done).
2. **Welcome appears twice**: Intro carousel page 1 + flow welcome step.
3. **No "Discover art" / guest path**: No clear branch to skip account creation and just explore.
4. **Skip is de-emphasized**: The "Skip for now" button is a small text link in the header, not a prominent action.
5. **Cramped layout**: 22px horizontal padding, cards with `EdgeInsets.fromLTRB(22, 18, 22, 18)`, can feel tight on small phones.
6. **4 500-line monolith**: `onboarding_flow_screen.dart` is extremely hard to maintain.
7. **Desktop path is under-used**: Desktop side rail exists but onboarding still feels like a mobile flow.

---

## 2. Proposed-State Map

### 2.1 Target Flow (Two Branches)

```
AppInitializer._initializeApp()
  │
  ├── Deep link handling (unchanged)
  │
  ├── Returning user (completed onboarding) → /main or /sign-in (unchanged)
  │
  └── First-time user → OnboardingFlowScreen (unified, responsive)
        │
        ├── PHASE 1: Welcome Wizard (2-3 swipeable pages)
        │   Page 1: "Discover art around you" (map/explore value prop)
        │   Page 2: "Create & collect" (creator/collector value prop)
        │   Page 3: "Join the community" + TWO PRIMARY ACTIONS:
        │       ┌──────────────────────────┐  ┌───────────────────────┐
        │       │  🔍 Discover art (Guest) │  │  ✨ Create an account │
        │       └──────────┬───────────────┘  └───────────┬───────────┘
        │                  │                              │
        │     ┌────────────▼──────────┐      ┌────────────▼──────────────────┐
        │     │ BRANCH A: Guest Path  │      │ BRANCH B: Account Creation   │
        │     │                       │      │                               │
        │     │ Permissions (single   │      │ Step 1: Account               │
        │     │  screen, "Not now"    │      │   (AuthMethodsPanel)          │
        │     │  for each toggle)     │      │                               │
        │     │         │             │      │ Step 2: Verify Email          │
        │     │         ▼             │      │   (if email registration)     │
        │     │     /main (guest)     │      │                               │
        │     └───────────────────────┘      │ Step 3: Choose Your Role      │
        │                                    │   (persona picker)            │
        │                                    │                               │
        │                                    │ Step 4: Your Profile          │
        │                                    │   (name, avatar, bio)         │
        │                                    │                               │
        │                                    │ Step 5: Permissions           │
        │                                    │   (single screen)             │
        │                                    │                               │
        │                                    │ Step 6: Done / Welcome Home   │
        │                                    │         │                     │
        │                                    │         ▼                     │
        │                                    │     /main (authenticated)     │
        │                                    └───────────────────────────────┘
```

### 2.2 Key Changes from Current Flow

| Change | Rationale |
|--------|-----------|
| **Merge intro carousel + welcome step** | Eliminate duplicate welcome. The flow screen IS the intro now. |
| **Remove two wrapper screens** | `OnboardingScreen` + `DesktopOnboardingScreen` deleted. `OnboardingFlowScreen` handles responsive layout directly. |
| **Add explicit "Discover art" branch** | Clear guest/browse path on the last welcome page. |
| **Consolidate permissions to ONE screen** | Delete `PermissionsScreen` + `DesktopPermissionsScreen`. Permissions become one step with grouped toggles (not 3 separate sub-pages). |
| **Remove contextual permission prompts from feature steps** | No more inline location/camera/notification prompts in mapDiscovery/community/arScan steps. Those info steps are merged into the welcome wizard pages. |
| **Remove dead steps** | Delete `permissions`, `artwork`, `follow` enum values + their build branches. |
| **Reduce account-creation steps** | Consolidate: role + profile can be one step or two clean steps. Remove `daoGovernance` from onboarding (move to Artist Studio first-launch). |
| **Prominent "Skip"** | Every step after welcome gets a clear "Skip" / "Not now" button in a consistent position. |

### 2.3 Proposed Step Enum

```dart
enum OnboardingStep {
  // Phase 1: Welcome wizard (swipeable, no step indicator)
  welcomeDiscover,     // "Discover art around you"
  welcomeCreate,       // "Create & collect"
  welcomeJoin,         // "Join the community" + branch buttons

  // Phase 2a: Guest branch
  guestPermissions,    // Single permissions screen → /main

  // Phase 2b: Account branch
  account,             // AuthMethodsPanel (email/Google/wallet)
  verifyEmail,         // Conditional: only if email reg
  role,                // Persona picker (artist/collector/institution)
  profile,             // Name, avatar, bio (minimal)
  accountPermissions,  // Same permissions UI as guest
  done,                // "You're all set!" → /main
}
```

### 2.4 What Gets Removed / Merged

| Current | Proposed |
|---------|----------|
| `OnboardingIntroScreen` (3 pages) | **Deleted** — pages become `welcomeDiscover`, `welcomeCreate`, `welcomeJoin` inside `OnboardingFlowScreen` |
| `OnboardingScreen` wrapper | **Deleted** |
| `DesktopOnboardingScreen` wrapper | **Deleted** |
| `PermissionsScreen` | **Deleted** — replaced by `guestPermissions` / `accountPermissions` step |
| `DesktopPermissionsScreen` | **Deleted** — desktop layout handled by responsive scaffold |
| `_OnboardingStep.mapDiscovery` | **Deleted** — value prop moved to `welcomeDiscover` page |
| `_OnboardingStep.community` | **Deleted** — value prop moved to welcome pages |
| `_OnboardingStep.arScan` | **Deleted** — value prop moved to welcome pages |
| `_OnboardingStep.daoGovernance` | **Deleted from onboarding** — DAO info moves to Artist Studio first-launch |
| `_OnboardingStep.artwork` | **Already dead** — remove enum + build branch |
| `_OnboardingStep.follow` | **Already dead** — remove enum + build branch |
| `_OnboardingStep.permissions` | **Already dead** — remove old enum value |

---

## 3. Component & Layout Spec

### 3.1 OnboardingStepScaffold (Single Reusable Layout)

One widget used by ALL onboarding steps. Replaces the current per-step card approach.

```
┌─────────────────────────────────────────────────────┐
│  HEADER                                             │
│  ┌─────────────────────────────────────────────────┐│
│  │ [← Back]          [Logo]         [Skip ▸] / [X]││
│  └─────────────────────────────────────────────────┘│
│                                                     │
│  PROGRESS (optional — hidden during welcome wizard) │
│  ┌─────────────────────────────────────────────────┐│
│  │  ████████░░░░░░░░░░░░  Step 2 of 5             ││
│  └─────────────────────────────────────────────────┘│
│                                                     │
│  BODY (flexible, centered vertically)               │
│  ┌─────────────────────────────────────────────────┐│
│  │                                                 ││
│  │         [Illustration / Icon]                   ││
│  │                                                 ││
│  │         Title (multi-line safe)                  ││
│  │                                                 ││
│  │         Subtitle / description                  ││
│  │                                                 ││
│  │         [Step-specific content]                 ││
│  │           (form fields, toggles, etc.)          ││
│  │                                                 ││
│  └─────────────────────────────────────────────────┘│
│                                                     │
│  FOOTER (pinned to bottom, safe area aware)         │
│  ┌─────────────────────────────────────────────────┐│
│  │  [Primary Action Button]        (full width)    ││
│  │  [Secondary link]    (e.g., "Not now" / "Skip")││
│  └─────────────────────────────────────────────────┘│
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Properties:**

```dart
class OnboardingStepScaffold extends StatelessWidget {
  final Widget? leading;              // Back button or null
  final Widget? trailing;             // Skip/close or null
  final bool showProgress;            // Progress bar visibility
  final int currentStep;              // For progress indicator
  final int totalSteps;               // For progress indicator
  final Widget? illustration;         // Icon/image/animation
  final String title;                 // Always multi-line safe
  final String? subtitle;             // Optional description
  final Widget? body;                 // Step-specific content
  final String primaryLabel;          // Primary button text
  final VoidCallback? onPrimary;      // Primary button action
  final String? secondaryLabel;       // "Not now" / "Skip" text
  final VoidCallback? onSecondary;    // Secondary action
  final bool primaryLoading;          // Loading state for primary
}
```

### 3.2 Responsive Rules

#### Breakpoints (reuse existing `DesktopBreakpoints`)

| Breakpoint | Width | Layout |
|------------|-------|--------|
| **Compact** (phone) | < 600 | Single column, stacked vertically |
| **Medium** (tablet) | 600-899 | Single column, wider padding |
| **Expanded** (small desktop) | 900-1199 | Two-panel: side illustration + content |
| **Large** (desktop) | ≥ 1200 | Two-panel + step rail (desktop only) |

#### Mobile Layout (< 600px)

```
┌──────────────────────┐
│ [←]  [Logo]  [Skip▸] │  ← 48px header
│                      │
│   ┌──────────────┐   │
│   │  Icon 64x64  │   │  ← Centered, modest size
│   └──────────────┘   │
│                      │
│   Title              │  ← max 2 lines, 24sp
│   Subtitle           │  ← max 3 lines, 14sp
│                      │
│   [Content area]     │  ← Flexible, scrollable if needed
│                      │
│                      │
│   ┌──────────────┐   │
│   │  Continue    │   │  ← Full width, 52px height, 48px min tap
│   └──────────────┘   │
│   "Not now"          │  ← Text link, 44px tap target
│                      │
└──────────────────────┘
```

- Horizontal padding: 24px (increased from current 22px)
- No side panels, no illustrations larger than 80px
- Progress bar: thin line at top (4px), no step labels
- Titles: `KubusTextStyles.screenTitle` — never truncated (use `maxLines: 3, overflow: TextOverflow.visible`)
- Buttons: full width, minimum height 52px, min tap target 48x48

#### Desktop Layout (≥ 900px)

```
┌─────────────────────────────────────────────────────────┐
│  [Logo]                          [Skip ▸]  [Lang] [🌓]  │
│                                                         │
│  ┌──────────────────┐  ┌───────────────────────────────┐│
│  │                  │  │                               ││
│  │  Illustration    │  │   Title                       ││
│  │  or              │  │   Subtitle                    ││
│  │  Step Rail       │  │                               ││
│  │  (≥1200px)       │  │   [Content area]              ││
│  │                  │  │                               ││
│  │                  │  │   [Continue]  "Not now"        ││
│  │                  │  │                               ││
│  └──────────────────┘  └───────────────────────────────┘│
│                                                         │
│  ████████████░░░░░░░░░  Step 2 of 5                     │
└─────────────────────────────────────────────────────────┘
```

- Left panel (40% width): large illustration or step rail with completed/active indicators
- Right panel (60% width): step content
- Max content width: 1280px, centered
- Progress: segmented bar at bottom with step labels
- Buttons: max 320px width (not full width on desktop)

#### What Shows / Hides by Breakpoint

| Element | Mobile | Tablet | Desktop |
|---------|--------|--------|---------|
| Side illustration panel | Hidden | Hidden | Visible |
| Step rail | Hidden | Hidden | Visible (≥1200px) |
| Language picker in header | Hidden (use settings) | Visible | Visible |
| Theme picker in header | Hidden (use settings) | Visible | Visible |
| Progress bar | Thin line, no labels | Thin line + step count | Segmented + labels |
| Action buttons | Full width | Full width | Max 320px |
| Illustration in body | 64px icon | 80px icon | Hidden (in side panel) |

### 3.3 Accessibility Notes

| Requirement | Implementation |
|-------------|---------------|
| **Minimum tap target** | 48x48 dp for all interactive elements (buttons, toggles, back/skip) |
| **Color contrast** | All text meets WCAG AA (4.5:1 for body, 3:1 for large text). Use `KubusColorRoles` semantic colors. |
| **Focus order** | Logical tab order: back → content → primary → secondary → skip |
| **Screen reader** | `Semantics` labels on all icons, progress indicator announces "Step X of Y" |
| **Keyboard navigation** | All actions reachable via Tab + Enter. Carousel supports arrow keys. |
| **Reduced motion** | Respect `MediaQuery.disableAnimations`. Skip page transition animations if true. |
| **Text scaling** | Titles use `maxLines` + `overflow: visible`. Layout doesn't break at 200% text scale. |
| **Safe areas** | Use `SafeArea` / `MediaQuery.viewPaddingOf` for notches, home indicators, keyboard. |

### 3.4 Visual Language

- **Background**: `AnimatedGradientBackground` — reuse existing, change accent color per phase (welcome = primary, guest = teal, account = accent)
- **Cards**: `LiquidGlassCard` for content areas — reuse existing glass effect
- **Icons**: `GradientIconCard` — reuse existing, 64px on mobile / 120px in desktop side panel
- **Buttons**: `KubusButton` — reuse existing, enforce min height 52px
- **Progress**: Custom segmented bar using `KubusColorRoles.positiveAction` for fill
- **Typography**: `KubusTextStyles` — reuse existing tokens, no new styles needed

---

## 4. UX Copy & UI Structure Per Screen

### Phase 1: Welcome Wizard

#### Page 1 — "Discover art around you"

| Element | Mobile | Desktop |
|---------|--------|---------|
| **Illustration** | `map_outlined` icon, 64px | Large map illustration in side panel |
| **Title** | "Discover art around you" | Same |
| **Subtitle** | "Explore artworks, exhibitions, and creative spaces on an interactive map." | Same |
| **Primary button** | "Next" | "Next" |
| **Secondary** | — | — |
| **Skip** | "Skip" in header (jumps to page 3) | Same |
| **Progress** | Dot indicator (1 of 3) | Dot indicator |

#### Page 2 — "Create & collect"

| Element | Mobile | Desktop |
|---------|--------|---------|
| **Illustration** | `palette_outlined` icon, 64px | Large creator illustration in side panel |
| **Title** | "Create & collect" | Same |
| **Subtitle** | "Mint your art, build your portfolio, and collect pieces from artists worldwide." | Same |
| **Primary button** | "Next" | "Next" |
| **Secondary** | — | — |
| **Back** | "←" in header | Same |
| **Skip** | "Skip" in header | Same |

#### Page 3 — "Join the community" (BRANCH POINT)

| Element | Mobile | Desktop |
|---------|--------|---------|
| **Illustration** | `groups_outlined` icon, 64px | Large community illustration in side panel |
| **Title** | "Ready to begin?" | Same |
| **Subtitle** | "Start exploring or create your account." | Same |
| **Primary button** | "Create an account" | Same |
| **Secondary button** | "Discover art" (outlined/ghost style, equally prominent) | Same |
| **Back** | "←" in header | Same |
| **Skip** | Hidden (the two buttons ARE the choices) | Same |

> **Design note**: Both "Create an account" and "Discover art" should be visually prominent — not one primary and one text link. Use filled button for "Create an account" and outlined button for "Discover art", both full width on mobile, side-by-side on desktop.

### Branch A: Guest Path

#### Permissions (single screen)

| Element | Mobile | Desktop |
|---------|--------|---------|
| **Title** | "Allow permissions" | Same |
| **Subtitle** | "These help you get the most out of the app. You can change them later in Settings." | Same |
| **Content** | 2-3 toggle rows: Location, Camera (mobile only), Notifications. Each with icon + one-line benefit + toggle/button. | Same, side-by-side layout |
| **Primary button** | "Continue" | Same |
| **Secondary** | "Not now" (skips all, goes to /main) | Same |
| **Behavior** | Each permission can be individually granted or skipped. "Continue" proceeds regardless. | Same |

> After this screen → navigate to `/main` in guest mode. Mark onboarding complete.

### Branch B: Account Creation

#### Step 1 — Account

| Element | Mobile | Desktop |
|---------|--------|---------|
| **Progress** | Step 1 of 4 (or 5 if verify needed) | Segmented bar |
| **Title** | "Create your account" | Same |
| **Subtitle** | "Sign up with email, Google, or a Web3 wallet." | Same |
| **Content** | Embedded `AuthMethodsPanel` — reuse as-is | Same, wider layout via `DesktopAuthShell` |
| **Skip** | "Not now" → defer, go to /main as guest | Same |
| **Primary** | Handled by AuthMethodsPanel internally | Same |

#### Step 2 — Verify Email (conditional)

| Element | Mobile | Desktop |
|---------|--------|---------|
| **Progress** | Step 2 of 5 | Segmented bar |
| **Title** | "Verify your email" | Same |
| **Subtitle** | "We sent a verification link to {email}." | Same |
| **Content** | Status indicator, "Resend" button, "Open email app" button | Same |
| **Skip** | "I'll do this later" → mark deferred, continue to role | Same |
| **Auto-advance** | Poll verification status; auto-advance when confirmed | Same |

#### Step 3 — Choose Your Role

| Element | Mobile | Desktop |
|---------|--------|---------|
| **Progress** | Step 2/3 of 4/5 | Segmented bar |
| **Title** | "How will you use art.kubus?" | Same |
| **Subtitle** | "You can always change this later." | Same |
| **Content** | `UserPersonaPickerContent` — reuse existing. 3 cards: Artist, Collector, Institution. | Same, cards in row on desktop |
| **Primary** | "Continue" (enabled when a role is selected) | Same |
| **Skip** | "Not now" → skip role, default to collector | Same |
| **Note** | DAO application fields (portfolio URL, statement) are **removed from onboarding**. These move to Artist Studio first-launch. | Same |

#### Step 4 — Your Profile

| Element | Mobile | Desktop |
|---------|--------|---------|
| **Progress** | Step 3/4 of 4/5 | Segmented bar |
| **Title** | "Set up your profile" | Same |
| **Subtitle** | "Tell others about yourself." | Same |
| **Content** | Avatar picker + display name + username + bio. **Remove** twitter/instagram/website/fieldOfWork/yearsActive from onboarding (move to profile settings). | Same, two-column layout for fields |
| **Primary** | "Continue" | Same |
| **Skip** | "Not now" → skip profile | Same |
| **Validation** | Display name required if filled (min 2 chars). Username auto-generated if empty. | Same |

#### Step 5 — Permissions

Same as Guest permissions screen (reuse same step widget).

#### Step 6 — Done

| Element | Mobile | Desktop |
|---------|--------|---------|
| **Illustration** | `rocket_launch_outlined`, 64px | Large illustration |
| **Title** | "You're all set!" | Same |
| **Subtitle** | "Welcome to art.kubus. Start exploring." | Same |
| **Primary** | "Get started" | Same |
| **Secondary** | — | — |
| **Behavior** | Marks onboarding complete, submits any pending DAO draft, navigates to /main | Same |

---

## 5. Implementation Plan

### 5.1 File-Level Changes

#### Files to DELETE

| File | Reason |
|------|--------|
| `lib/screens/onboarding/onboarding_screen.dart` | Thin wrapper, zero value |
| `lib/screens/onboarding/onboarding_intro_screen.dart` | Merged into flow screen as welcome wizard pages |
| `lib/screens/desktop/onboarding/desktop_onboarding_screen.dart` | Thin wrapper, zero value |
| `lib/screens/desktop/onboarding/desktop_permissions_screen.dart` | Permissions consolidated into flow |
| `lib/screens/onboarding/permissions_screen.dart` | Permissions consolidated into flow |

#### Files to CREATE

| File | Purpose |
|------|---------|
| `lib/widgets/onboarding_step_scaffold.dart` | Single reusable scaffold layout (header + progress + body + footer) |

> **That's it.** Only ONE new file. Everything else is refactored in place.

#### Files to MODIFY (Major)

| File | Changes |
|------|---------|
| `lib/screens/onboarding/onboarding_flow_screen.dart` | **Major refactor** — see Section 5.2 below |
| `lib/core/app_initializer.dart` | Remove desktop/mobile branching for onboarding; always navigate to `OnboardingFlowScreen()` |
| `lib/main.dart` | Remove route registration for deleted screens if any exist |
| `lib/services/onboarding_state_service.dart` | Add `guestBranch` flag to flow progress |

#### Files to MODIFY (Minor)

| File | Changes |
|------|---------|
| `lib/l10n/app_en.arb` (and other locales) | Add new l10n keys for reworked copy; deprecate unused keys |
| `lib/config/config.dart` | No changes needed (existing flags sufficient) |
| `lib/widgets/auth_methods_panel.dart` | No changes needed (used as-is in embedded mode) |
| `test/onboarding/onboarding_flow_layout_test.dart` | Update tests for new step names, remove tests for deleted screens |

### 5.2 Refactoring `onboarding_flow_screen.dart`

This is the biggest change. Strategy: **refactor in place**, don't rewrite from scratch. The file is 4 500 lines — we reduce it to ~2 000-2 500 by:

#### A. Delete dead code

1. Remove `_OnboardingStep.permissions`, `.artwork`, `.follow` enum values
2. Remove `_buildStepCard` branches for those steps (~300 lines)
3. Remove `_PermissionsStep`, `_ArtworkInlineStep`, `_FollowStep`, `_AuthRequiredStep` widgets (~400 lines)
4. Remove inline permission prompts from `_InfoStep` / mapDiscovery / community / arScan (~200 lines)

#### B. Replace intro steps with welcome wizard

1. Replace `_OnboardingStep.welcome`, `.mapDiscovery`, `.community`, `.arScan` with `welcomeDiscover`, `welcomeCreate`, `welcomeJoin`
2. Welcome wizard pages use a `PageView` (swipeable, dot indicators) — no step progress bar during welcome phase
3. `welcomeJoin` renders two prominent buttons: "Discover art" + "Create an account"

#### C. Add branch logic

1. "Discover art" → set `_branch = OnboardingBranch.guest`, show `guestPermissions` → complete
2. "Create an account" → set `_branch = OnboardingBranch.account`, show account steps → complete
3. `_buildSteps()` returns different step lists based on `_branch`

#### D. Simplify remaining steps

1. `role` step: Remove DAO application fields (portfolio URL, medium, statement). Just persona picker.
2. `profile` step: Reduce to avatar + displayName + username + bio. Remove social links + fieldOfWork + yearsActive.
3. `account` step: Keep `AuthMethodsPanel` as-is.
4. `verifyEmail` step: Keep as-is.
5. `done` step: Keep as-is.

#### E. Use OnboardingStepScaffold

Replace inline card building with `OnboardingStepScaffold` widget for consistent layout across all steps.

#### F. Extract desktop layout

Move `_buildDesktopStepRail` and `_buildDesktopContent` from inline methods to use `OnboardingStepScaffold`'s responsive layout.

### 5.3 Commit Strategy (Risk-Managed)

Execute in this order. Each commit is independently safe and testable.

| # | Commit | Risk | What to verify |
|---|--------|------|----------------|
| 1 | **Delete dead code**: Remove unused enum values + their build branches + unreachable widget classes | None — dead code | App compiles, onboarding still works |
| 2 | **Delete wrapper screens**: Remove `OnboardingScreen`, `DesktopOnboardingScreen`. Update `AppInitializer` to navigate directly to `OnboardingFlowScreen` | Low — just removing indirection | First-time launch still shows onboarding on both mobile & desktop |
| 3 | **Delete standalone permissions**: Remove `PermissionsScreen`, `DesktopPermissionsScreen` | Low — unreachable screens | App compiles, no references remain |
| 4 | **Create OnboardingStepScaffold**: Add the reusable layout widget | None — new code, not yet used | Widget renders correctly in isolation |
| 5 | **Replace welcome + info steps with welcome wizard**: Swap out welcome/mapDiscovery/community/arScan for 3-page wizard. Add branch buttons on page 3. | Medium — changes user-facing flow | Welcome wizard renders, swipe works, both branch buttons navigate correctly |
| 6 | **Add guest branch**: Implement "Discover art" → permissions → /main path. Add `guestPermissions` step. | Medium — new flow path | Guest path works end-to-end, onboarding marked complete |
| 7 | **Simplify account branch steps**: Reduce role step (remove DAO fields), reduce profile step (remove socials/extras). Reorder: account → verifyEmail → role → profile → permissions → done. | Medium — changes step order | Account creation flow works, drafts persist, fields save |
| 8 | **Apply OnboardingStepScaffold to all steps**: Migrate each step's UI to use the scaffold. Update padding, button sizes, title wrapping. | Low-Medium — visual changes | No truncation, no cramped buttons, consistent layout |
| 9 | **Update desktop layout**: Enhance side panel, responsive breakpoints, wider illustrations. | Low — desktop-only visual | Desktop rail shows correctly, collapses on tablet |
| 10 | **Update tests + l10n**: Fix broken test references, add new l10n keys, remove deprecated keys. | Low | All tests pass |
| 11 | **Clean up**: Remove any remaining unused imports, legacy pref key code, etc. | None | App compiles clean |

### 5.4 Safe Backend/Logic Optimizations (Permitted)

These are small, safe improvements to existing logic — not rewrites:

| Optimization | Where | Risk |
|-------------|-------|------|
| **Persist email across steps** | `_handleEmbeddedEmailRegistrationAttempted` — ensure email is saved to draft immediately | None — additive |
| **Guard double-submit on "Get started"** | Add `_isSubmitting` flag to prevent multiple taps on done step | None — defensive |
| **Remove redundant `_refreshAuthDerivedSteps` calls** | Called 3x in succession in some handlers — deduplicate | Low — same outcome |
| **Clear legacy pref keys on migration** | After migrating `first_time` → `is_first_launch`, delete the old key | None — cleanup |
| **Ensure avatar upload doesn't block step advance** | `_flushPendingAvatarUploadIfPossible` should be fire-and-forget, not awaited in navigation | Low — UX improvement |

---

## 6. QA Acceptance Criteria

### 6.1 Testable Acceptance Checks

| # | Criterion | Pass Condition |
|---|-----------|----------------|
| 1 | **No duplicate welcome screens** | Only the 3-page welcome wizard exists. No separate intro carousel. |
| 2 | **Welcome is skippable** | "Skip" in header on pages 1-2 jumps to page 3. Page 3 has clear branch actions. |
| 3 | **Guest path works end-to-end** | Tap "Discover art" → permissions screen → "Continue" or "Not now" → lands on /main in guest mode. |
| 4 | **Account path works end-to-end** | Tap "Create an account" → account step → (verify email if needed) → role → profile → permissions → done → /main authenticated. |
| 5 | **Skip/Not now on every applicable step** | Account, role, profile, permissions steps all have "Not now" or "Skip" option. |
| 6 | **No truncated titles** | Test on 320px wide viewport: all titles fully visible (wrap to multiple lines). |
| 7 | **No cramped buttons** | All buttons ≥ 52px height, ≥ 48x48 tap target. No buttons overlapping or touching container edges. |
| 8 | **Desktop shows side panel** | At ≥ 900px width: side illustration panel visible. At ≥ 1200px: step rail visible. |
| 9 | **Mobile has no side panel** | At < 600px: no side panel, no step rail, just vertically stacked content. |
| 10 | **Progress indicator correct** | Shows "Step X of Y" during account branch. Hidden during welcome wizard. Dots visible during welcome wizard. |
| 11 | **Back navigation works** | Back button returns to previous step. On welcome page 1, no back button shown. |
| 12 | **State persists across app restart** | Kill app mid-onboarding, reopen → resumes at correct step. |
| 13 | **Returning user skips onboarding** | User who completed onboarding → goes directly to /main. |
| 14 | **Deep link cold start defers correctly** | Open via share link → see content → onboarding shows after. |
| 15 | **Email verification persists** | Start email registration → close app → reopen → verification step resumes with correct email. |
| 16 | **No dead imports/references** | No references to deleted screens (`OnboardingScreen`, `DesktopOnboardingScreen`, `PermissionsScreen`, `DesktopPermissionsScreen`, `OnboardingIntroScreen`). |
| 17 | **Existing auth logic unchanged** | Registration, sign-in, wallet connect, Google auth all work identically. |
| 18 | **Avatar upload non-blocking** | Slow avatar upload doesn't prevent advancing to next step. |
| 19 | **Double-submit prevention** | Tapping "Get started" twice doesn't trigger duplicate navigation or API calls. |
| 20 | **Theme consistency** | Glass effects, gradients, typography match rest of app. |

### 6.2 Manual QA Script (5-10 minutes)

#### Setup
- Reset onboarding: Use developer tool (`onboarding_reset_screen.dart`) or clear SharedPreferences.
- Test on: (a) phone viewport 360x640, (b) tablet 768x1024, (c) desktop 1440x900.

#### Test Path 1: Guest / Discover (2 min)
1. Launch app. Verify welcome wizard page 1 appears.
2. Swipe through pages 1 → 2 → 3. Verify dot indicator updates.
3. On page 3, verify both "Discover art" and "Create an account" are visible and tappable.
4. Tap "Discover art".
5. Verify permissions screen appears with location + camera + notifications.
6. Tap "Not now".
7. Verify you land on /main in guest/browse mode.
8. Kill and reopen app. Verify you go straight to /main (onboarding marked complete).

#### Test Path 2: Account Creation — Email (3 min)
1. Reset onboarding. Launch app.
2. On welcome page 1, tap "Skip" in header. Verify jump to page 3.
3. Tap "Create an account".
4. Verify account step shows with AuthMethodsPanel.
5. Register with email + password.
6. Verify "Verify email" step appears with the correct email.
7. Tap "I'll do this later" (skip verification).
8. Verify role picker appears. Select "Artist". Tap "Continue".
9. Verify profile step appears. Enter display name. Tap "Continue".
10. Verify permissions step appears. Grant location. Tap "Continue".
11. Verify done screen appears. Tap "Get started".
12. Verify you land on /main, authenticated, with profile visible.

#### Test Path 3: Account Creation — Google (1 min)
1. Reset onboarding. Navigate to account step.
2. Tap "Continue with Google".
3. After auth, verify flow advances past account step (verify step skipped for Google).
4. Complete remaining steps. Verify /main.

#### Test Path 4: Back Navigation (1 min)
1. Start any path. Advance to step 3.
2. Tap back. Verify step 2. Tap back. Verify step 1.
3. On welcome wizard: back from page 3 → page 2 → page 1. On page 1, no back button.

#### Test Path 5: Edge Cases (2 min)
1. **Orientation change**: Start onboarding in portrait, rotate to landscape mid-step. Verify no overflow.
2. **Very small phone**: Test on 320x568 (iPhone SE). Verify no truncation, no overflow.
3. **Slow network**: Enable network throttling. Start account creation. Verify loading state on auth, no double-submit.
4. **App resume on verify step**: Register with email, leave app, return. Verify verify step resumes and auto-checks status.

### 6.3 Proposed Widget/Integration Tests

| Test | File | What It Tests |
|------|------|---------------|
| `welcome wizard renders 3 pages with dot indicator` | `test/onboarding/onboarding_flow_layout_test.dart` | PageView with 3 pages, dots update |
| `welcome page 3 shows both branch buttons` | Same | "Discover art" + "Create an account" present |
| `guest branch: discover → permissions → main` | Same | Navigation flow for guest path |
| `account branch: account → role → profile → permissions → done → main` | Same | Navigation flow for account path |
| `skip on welcome jumps to page 3` | Same | Header skip behavior |
| `onboarding step scaffold renders title without truncation` | `test/widgets/onboarding_step_scaffold_test.dart` | Long titles wrap correctly |
| `onboarding step scaffold shows skip when provided` | Same | Skip button visibility |
| `permissions step allows "Not now"` | `test/onboarding/onboarding_flow_layout_test.dart` | "Not now" skips permissions |
| `double-tap prevention on done step` | Same | Second tap is no-op |
| `desktop layout shows side panel at 1200px` | Same | Responsive breakpoint test |
| `state persists after widget dispose and recreate` | Same | SharedPreferences round-trip |

---

## Appendix A: Deleted vs Kept Summary

```
DELETED (5 files):
  ✗ lib/screens/onboarding/onboarding_screen.dart
  ✗ lib/screens/onboarding/onboarding_intro_screen.dart
  ✗ lib/screens/onboarding/permissions_screen.dart
  ✗ lib/screens/desktop/onboarding/desktop_onboarding_screen.dart
  ✗ lib/screens/desktop/onboarding/desktop_permissions_screen.dart

CREATED (1 file):
  ✦ lib/widgets/onboarding_step_scaffold.dart

REFACTORED (major, 1 file):
  ✎ lib/screens/onboarding/onboarding_flow_screen.dart

MODIFIED (minor, 4 files):
  ✎ lib/core/app_initializer.dart
  ✎ lib/services/onboarding_state_service.dart
  ✎ lib/l10n/app_en.arb
  ✎ test/onboarding/onboarding_flow_layout_test.dart

UNTOUCHED (auth logic):
  ✓ lib/widgets/auth_methods_panel.dart
  ✓ lib/screens/auth/register_screen.dart
  ✓ lib/screens/auth/sign_in_screen.dart
  ✓ lib/screens/auth/verify_email_screen.dart
  ✓ lib/services/auth_gating_service.dart
  ✓ lib/providers/deferred_onboarding_provider.dart
```

## Appendix B: L10N Keys to Add

```json
{
  "onboardingWelcomeDiscoverTitle": "Discover art around you",
  "onboardingWelcomeDiscoverBody": "Explore artworks, exhibitions, and creative spaces on an interactive map.",
  "onboardingWelcomeCreateTitle": "Create & collect",
  "onboardingWelcomeCreateBody": "Mint your art, build your portfolio, and collect pieces from artists worldwide.",
  "onboardingWelcomeJoinTitle": "Ready to begin?",
  "onboardingWelcomeJoinBody": "Start exploring or create your account.",
  "onboardingDiscoverArtButton": "Discover art",
  "onboardingCreateAccountButton": "Create an account",
  "onboardingPermissionsTitle": "Allow permissions",
  "onboardingPermissionsBody": "These help you get the most out of the app. You can change them later in Settings.",
  "onboardingNotNowButton": "Not now",
  "onboardingSkipButton": "Skip",
  "onboardingIllDoThisLater": "I'll do this later",
  "onboardingRoleTitle": "How will you use art.kubus?",
  "onboardingRoleBody": "You can always change this later.",
  "onboardingProfileTitle": "Set up your profile",
  "onboardingProfileBody": "Tell others about yourself.",
  "onboardingDoneTitle": "You're all set!",
  "onboardingDoneBody": "Welcome to art.kubus. Start exploring."
}
```
