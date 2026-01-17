# Interactive Tutorials Blueprint (Coach Marks)

This document is the single reference for building **interactive, fluent, “attached to real UI” tutorials** in the Flutter app.

It is designed to keep tutorials consistent with the app’s **glass-first** UI system and avoid one-off overlays per screen.

---

## Goals

A good tutorial should:

- Highlight **real UI controls** (not screenshots or fake replicas).
- Be **step-based** and short, with clear “why” and “what to do next”.
- Be **skippable** at any time.
- Be shown **once per screen/version**, persisted via `SharedPreferences`.
- Respect **feature flags** (don’t teach a feature that’s disabled).
- Be **safe** (no crashes if a target widget isn’t laid out yet).

---

## Building blocks (single source of truth)

- Overlay widget: `lib/widgets/tutorial/interactive_tutorial_overlay.dart`
  - Uses `GlobalKey` targets.
  - Draws a dim layer with a highlighted “hole”.
  - Renders a liquid-glass tooltip card.
  - Provides a top-right **Skip** chip.

- Preference keys: `lib/config/config.dart` → `PreferenceKeys.*`
  - Use a **versioned** key per screen, e.g. `mapOnboardingMobileSeenV2`.
  - When tutorial content changes materially (steps/order/meaning), bump the version.

---

## Integration checklist (per screen)

### 1) Define anchor keys

In your `State` class:

- Create `GlobalKey` fields for each UI element you want to highlight.
- Keep naming consistent:
  - `_tutorialMapKey`, `_tutorialFiltersButtonKey`, `_tutorialSearchKey`, …

### 2) Attach keys to real widgets

Attach anchors using `KeyedSubtree(key: ..., child: ...)` when the target widget does not accept a `Key`, or pass the key directly when it does.

Good targets:

- Primary action buttons (filters, travel mode, add marker)
- Panels/titles that the user can visually associate with a feature
- Search field
- Type filter chips

Avoid targets:

- Dynamic list items that are frequently rebuilt
- Widgets that can be off-screen while the tutorial runs

### 3) Tutorial state + show-once logic

Maintain:

- `_showXxxTutorial` (bool)
- `_xxxTutorialIndex` (int)

Show-once pattern:

- On first meaningful render (usually after `initState` via a post-frame callback), check the versioned preference key.
- Only enable the tutorial if the screen is mounted and visible.

### 4) Build steps

Build a `List<TutorialStepDefinition>` with localized `title` + `body`.

Guidelines for steps:

- Start with **orientation** (“This is the map” / “This is the screen”).
- Explain **markers & types**.
- Teach **nearby/results list**.
- Teach **filters**.
- Teach optional power features last (e.g. **Travel mode**).

If the step should open a panel or toggle a state, use `onTargetTap` (or trigger it programmatically when the step becomes active).

Important: actions must be **idempotent**. Tapping the highlight twice should not break state.

### 5) Render the overlay

Render the overlay inside the page’s top-level `Stack`, near the end so it sits above everything.

Pass labels from `AppLocalizations`:

- `skipLabel: l10n.commonSkip`
- `backLabel: l10n.commonBack`
- `nextLabel: l10n.commonNext`
- `doneLabel: l10n.commonDone`

### 6) Mark tutorial as seen

When the user taps:

- **Skip** → immediately mark as seen (versioned preference key)
- **Done** (last step next) → mark as seen

---

## Localization rules

All step titles/bodies must be localized.

- Add keys to:
  - `lib/l10n/app_en.arb`
  - `lib/l10n/app_sl.arb`

Prefer screen-specific keys only when needed. Reuse shared keys when the meaning matches.

---

## Feature flags

If a step references a gated feature:

- Only include the step when `AppConfig.isFeatureEnabled('flag')` is true.

Example: Travel mode step only when `mapTravelMode` is enabled.

---

## Failure/edge-case safety

Targets may be null temporarily (first frame, layout changes, desktop resize).

The overlay must:

- Handle `targetKey.currentContext == null` gracefully.
- Still render the tooltip even if a target isn’t available.

For actions in `onTargetTap`:

- Avoid using `BuildContext` after `await`.
- Guard with `if (!mounted) return;` in stateful widgets.

---

## Design consistency (non-negotiable)

Tutorial UI must follow the app’s **glassmorphism + tokens** system:

- Use existing glass components (`LiquidGlassPanel` / `FrostedModal` styles).
- Avoid hardcoded color palettes; use `Theme.of(context).colorScheme.*` and token helpers.

---

## Suggested step templates

### Map screen (mobile)

1. Map (pan/zoom)
2. Markers & types
3. Create marker
4. Nearby art list
5. Filters
6. Travel mode (optional)
7. Recenter

### Map screen (desktop)

1. Map (pan/zoom)
2. Markers & types
3. Nearby panel
4. Type chips
5. Filters panel
6. Travel mode (optional)
7. Search

---

## When to bump the tutorial version

Bump `...SeenV#` when:

- Step order changes in a meaningful way
- Copy changes significantly (new concepts)
- Targets move to different UI places
- A new key feature is introduced

Do **not** bump for minor typo fixes.
