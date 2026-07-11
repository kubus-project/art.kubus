# UI Kit + Token Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One canonical component vocabulary with lint-enforced design tokens, proven by migrating the worst offender surfaces (onboarding, sign-in, connect-wallet).

**Architecture:** Fill the gaps in the existing kubus kit (border roles, accent gradients, badge, text field), declare canon via a barrel file, enforce with an in-repo `custom_lint` package + grandfathered ignore headers + a CI ratchet that only lets violation counts go down.

**Tech Stack:** Flutter 3.44.2 (at `C:\dev\flutter\bin\flutter.bat`), Dart ≥3.6, `custom_lint` 0.8.1 / `custom_lint_builder` (verified to resolve against this SDK), Node ≥18 for the ratchet script (repo already has root `package.json`).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md`. Amendment: contextual colors are allowed but must be **centrally defined** (tokens/roles/gradient sets) — never inline in widgets.
- `flutter`/`dart` are NOT on PATH. Always use `C:/dev/flutter/bin/flutter.bat` and `C:/dev/flutter/bin/dart.bat`.
- Work on branch `feat/ui-kit-token-enforcement` (already created). Commit after every task.
- Do NOT touch `lib/l10n/app_localizations.dart` (hand-patched generated file) or run `gen-l10n`.
- Do NOT change layouts/behavior in migrated screens — colors, borders, and glass sourcing only. Palette consolidation (mapping near-duplicate hues onto the curated gradient set) is explicitly approved.
- New widgets live in `lib/widgets/common/`, new token files in `lib/utils/`, following existing naming (`kubus_*.dart`).
- Tests: `C:/dev/flutter/bin/flutter.bat test <path> --reporter compact`. The full suite has known pre-existing flaky tests (documented in repo memory / `flutter-test-full.log`); compare failures against master before blaming your change.
- All new UI code must itself pass the new lint rules (no raw colors, no raw borders).

## File Structure

```
lib/utils/design_tokens.dart              # + KubusBorders (semantic border roles)
lib/utils/kubus_accent_gradients.dart     # NEW: curated contextual gradient set
lib/widgets/common/kubus_badge.dart       # NEW: status/count/label pill
lib/widgets/common/kubus_text_field.dart  # NEW: general above-label text field
lib/widgets/kubus_kit.dart                # NEW: canonical barrel + decision table doc
packages/kubus_lints/                     # NEW: custom_lint plugin package
  pubspec.yaml
  lib/kubus_lints.dart                    # plugin entrypoint (createPlugin)
  lib/src/allowlists.dart                 # shared path allowlists
  lib/src/no_raw_color.dart
  lib/src/no_raw_border.dart
  lib/src/no_raw_backdrop_filter.dart
  lib/src/no_inline_google_fonts.dart
  example/                                # fixture app using expect_lint
scripts/kubus-lint-ratchet.mjs            # NEW: --grandfather / --check modes
tool/kubus_lint_ratchet.json              # NEW: checked-in baseline counts
analysis_options.yaml                     # + custom_lint plugin
pubspec.yaml                              # + dev deps custom_lint, kubus_lints (path)
.github/workflows/ci.yml                  # + custom_lint + ratchet steps
test/widgets/common/kubus_badge_test.dart
test/widgets/common/kubus_text_field_test.dart
test/utils/kubus_borders_test.dart
test/utils/kubus_accent_gradients_test.dart
```

---

### Task 1: `KubusBorders` semantic border roles

**Files:**
- Modify: `lib/utils/design_tokens.dart` (append new class at end)
- Test: `test/utils/kubus_borders_test.dart` (create)

**Interfaces:**
- Produces: `KubusBorders.hairline(BuildContext)`, `.hairlineSide(BuildContext)`, `.glass(BuildContext)`, `.glassSide(BuildContext)`, `.focus(BuildContext, {Color? accent})`, `.focusSide(BuildContext, {Color? accent})`, `.active(BuildContext, {Color? accent})`, `.activeSide(BuildContext, {Color? accent})` — all return `Border` / `BorderSide`. Alpha/width values below are the canon; later tasks use these instead of ad-hoc `Border.all`.

- [ ] **Step 1: Write the failing test**

```dart
// test/utils/kubus_borders_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/utils/design_tokens.dart';

Widget _host(Brightness b, void Function(BuildContext) probe) {
  return MaterialApp(
    theme: ThemeData(
      brightness: b,
      colorScheme: b == Brightness.dark
          ? const ColorScheme.dark(outline: KubusColors.outlineDark)
          : const ColorScheme.light(outline: KubusColors.outlineLight),
    ),
    home: Builder(builder: (context) {
      probe(context);
      return const SizedBox.shrink();
    }),
  );
}

void main() {
  testWidgets('hairline uses scheme outline at hairline width', (tester) async {
    late BorderSide side;
    await tester.pumpWidget(_host(Brightness.dark, (c) {
      side = KubusBorders.hairlineSide(c);
    }));
    expect(side.width, KubusSizes.hairline);
    expect(side.color, KubusColors.outlineDark);
  });

  testWidgets('glass border matches glass token per brightness', (tester) async {
    late BorderSide dark;
    late BorderSide light;
    await tester.pumpWidget(_host(Brightness.dark, (c) {
      dark = KubusBorders.glassSide(c);
    }));
    await tester.pumpWidget(_host(Brightness.light, (c) {
      light = KubusBorders.glassSide(c);
    }));
    expect(dark.color, KubusColors.glassBorderDark);
    expect(light.color, KubusColors.glassBorderLight);
  });

  testWidgets('focus and active derive from accent', (tester) async {
    late BorderSide focus;
    late BorderSide active;
    const accent = KubusColors.accentBlue;
    await tester.pumpWidget(_host(Brightness.dark, (c) {
      focus = KubusBorders.focusSide(c, accent: accent);
      active = KubusBorders.activeSide(c, accent: accent);
    }));
    expect(focus.width, greaterThan(KubusSizes.hairline));
    expect(focus.color.toARGB32() & 0x00FFFFFF, accent.toARGB32() & 0x00FFFFFF);
    expect(active.color.a, closeTo(0.85, 0.01));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:/dev/flutter/bin/flutter.bat test test/utils/kubus_borders_test.dart --reporter compact`
Expected: FAIL — `KubusBorders` not defined.

- [ ] **Step 3: Implement** — append to `lib/utils/design_tokens.dart`:

```dart
/// Semantic border roles for the kubus design system.
///
/// The app previously had ~546 ad-hoc `Border.all`/`BorderSide` call sites
/// each choosing its own color/alpha. All container borders collapse onto
/// these four roles:
///
/// * [hairline] — default container/divider border (theme outline).
/// * [glass]    — border on glass surfaces (matches [GlassSurface] tokens).
/// * [focus]    — focused input / keyboard-focused interactive element.
/// * [active]   — selected/active state emphasis.
class KubusBorders {
  KubusBorders._();

  /// Width used by [focus] and [active] emphasis borders.
  static const double emphasisWidth = 1.25;

  static BorderSide hairlineSide(BuildContext context) => BorderSide(
        color: Theme.of(context).colorScheme.outline,
        width: KubusSizes.hairline,
      );

  static Border hairline(BuildContext context) =>
      Border.fromBorderSide(hairlineSide(context));

  static BorderSide glassSide(BuildContext context) => BorderSide(
        color: Theme.of(context).brightness == Brightness.dark
            ? KubusColors.glassBorderDark
            : KubusColors.glassBorderLight,
        width: KubusSizes.hairline,
      );

  static Border glass(BuildContext context) =>
      Border.fromBorderSide(glassSide(context));

  static BorderSide focusSide(BuildContext context, {Color? accent}) =>
      BorderSide(
        color: (accent ?? Theme.of(context).colorScheme.primary)
            .withValues(alpha: 0.70),
        width: emphasisWidth,
      );

  static Border focus(BuildContext context, {Color? accent}) =>
      Border.fromBorderSide(focusSide(context, accent: accent));

  static BorderSide activeSide(BuildContext context, {Color? accent}) =>
      BorderSide(
        color: (accent ?? Theme.of(context).colorScheme.primary)
            .withValues(alpha: 0.85),
        width: emphasisWidth,
      );

  static Border active(BuildContext context, {Color? accent}) =>
      Border.fromBorderSide(activeSide(context, accent: accent));

  /// Soft accent-tinted border for chips/cards that carry a contextual
  /// accent (e.g. wallet action cards). Replaces the widespread
  /// `Border.all(color: X.withValues(alpha: 0.2..0.35))` pattern.
  static BorderSide accentTintSide(Color accent) => BorderSide(
        color: accent.withValues(alpha: 0.30),
        width: KubusSizes.hairline,
      );

  static Border accentTint(Color accent) =>
      Border.fromBorderSide(accentTintSide(accent));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `C:/dev/flutter/bin/flutter.bat test test/utils/kubus_borders_test.dart --reporter compact`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/utils/design_tokens.dart test/utils/kubus_borders_test.dart
git commit -m "feat(design): KubusBorders semantic border roles"
```

---

### Task 2: `KubusAccentGradients` — centralized contextual gradients

**Files:**
- Create: `lib/utils/kubus_accent_gradients.dart`
- Test: `test/utils/kubus_accent_gradients_test.dart`

**Interfaces:**
- Produces: `KubusAccentGradient` (fields `start`, `end`, `accent`, getter `linear`, method `linearWith({Alignment begin, Alignment end})`) and `KubusAccentGradients` with static consts: `cyanBlue`, `skyCyan`, `emerald`, `sunset`, `indigo`, `tealBlue`, `violet`, `gold` and `static const List<KubusAccentGradient> all`. Migration tasks 8–9 reference these exact names.

- [ ] **Step 1: Write the failing test**

```dart
// test/utils/kubus_accent_gradients_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/utils/kubus_accent_gradients.dart';

void main() {
  test('curated set is stable and distinct', () {
    expect(KubusAccentGradients.all.length, 8);
    final starts = KubusAccentGradients.all.map((g) => g.start.toARGB32()).toSet();
    expect(starts.length, 8, reason: 'no duplicate gradient starts');
  });

  test('linear gradient exposes start and end', () {
    final g = KubusAccentGradients.cyanBlue;
    expect(g.linear.colors.first, g.start);
    expect(g.linear.colors.last, g.end);
  });

  test('accent is readable on dark backgrounds (lighter than start)', () {
    for (final g in KubusAccentGradients.all) {
      expect(
        g.accent.computeLuminance(),
        greaterThanOrEqualTo(g.start.computeLuminance()),
        reason: '${g.debugName} accent must not be darker than start',
      );
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:/dev/flutter/bin/flutter.bat test test/utils/kubus_accent_gradients_test.dart --reporter compact`
Expected: FAIL — file/classes don't exist.

- [ ] **Step 3: Implement `lib/utils/kubus_accent_gradients.dart`**

```dart
import 'package:flutter/material.dart';

/// A named, centrally defined contextual gradient.
///
/// Contextual color IS allowed in kubus (onboarding steps, wallet actions,
/// web3 hubs may each carry their own accent) — but every gradient must be
/// defined HERE, never inline in a widget. See the design spec
/// (docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md).
@immutable
class KubusAccentGradient {
  const KubusAccentGradient({
    required this.debugName,
    required this.start,
    required this.end,
    required this.accent,
  });

  final String debugName;
  final Color start;
  final Color end;

  /// Light companion tone for icons/labels rendered on top of the gradient
  /// or on dark surfaces next to it.
  final Color accent;

  LinearGradient get linear => linearWith();

  LinearGradient linearWith({
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return LinearGradient(begin: begin, end: end, colors: [start, this.end]);
  }
}

/// The curated contextual gradient set. Keep this list SHORT — a tight
/// palette is what makes the app read as professional. Add a new entry only
/// when no existing one fits, and never define gradient colors in widgets.
class KubusAccentGradients {
  KubusAccentGradients._();

  static const cyanBlue = KubusAccentGradient(
    debugName: 'cyanBlue',
    start: Color(0xFF06B6D4),
    end: Color(0xFF3B82F6),
    accent: Color(0xFF67E8F9),
  );

  static const skyCyan = KubusAccentGradient(
    debugName: 'skyCyan',
    start: Color(0xFF0EA5E9),
    end: Color(0xFF06B6D4),
    accent: Color(0xFF81D4FA),
  );

  static const emerald = KubusAccentGradient(
    debugName: 'emerald',
    start: Color(0xFF10B981),
    end: Color(0xFF059669),
    accent: Color(0xFFA7F3D0),
  );

  static const sunset = KubusAccentGradient(
    debugName: 'sunset',
    start: Color(0xFFF59E0B),
    end: Color(0xFFEF4444),
    accent: Color(0xFFFFE082),
  );

  static const indigo = KubusAccentGradient(
    debugName: 'indigo',
    start: Color(0xFF6366F1),
    end: Color(0xFF3B82F6),
    accent: Color(0xFFC7D2FE),
  );

  static const tealBlue = KubusAccentGradient(
    debugName: 'tealBlue',
    start: Color(0xFF0F766E),
    end: Color(0xFF2563EB),
    accent: Color(0xFF99F6E4),
  );

  static const violet = KubusAccentGradient(
    debugName: 'violet',
    start: Color(0xFF7C3AED),
    end: Color(0xFFA855F7),
    accent: Color(0xFFDDD6FE),
  );

  static const gold = KubusAccentGradient(
    debugName: 'gold',
    start: Color(0xFFF59E0B),
    end: Color(0xFFD97706),
    accent: Color(0xFFFDE68A),
  );

  static const List<KubusAccentGradient> all = [
    cyanBlue,
    skyCyan,
    emerald,
    sunset,
    indigo,
    tealBlue,
    violet,
    gold,
  ];
}
```

Note: `gold.start` duplicates `sunset.start` — adjust `gold.start` to `Color(0xFFFBBF24)` so the distinctness test passes.

- [ ] **Step 4: Run test to verify it passes**

Run: `C:/dev/flutter/bin/flutter.bat test test/utils/kubus_accent_gradients_test.dart --reporter compact`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/utils/kubus_accent_gradients.dart test/utils/kubus_accent_gradients_test.dart
git commit -m "feat(design): centralized KubusAccentGradients contextual gradient set"
```

---

### Task 3: `KubusBadge`

**Files:**
- Create: `lib/widgets/common/kubus_badge.dart`
- Test: `test/widgets/common/kubus_badge_test.dart`

**Interfaces:**
- Consumes: `KubusBorders.accentTint`, `KubusTextStyles.badgeCount`, `KubusRadius`, `KubusSpacing`.
- Produces: `KubusBadge({required String text, KubusBadgeVariant variant = .label, Color? accent, IconData? icon, bool compact = false})`; `enum KubusBadgeVariant { label, status, count }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/common/kubus_badge_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/widgets/common/kubus_badge.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('renders text', (tester) async {
    await tester.pumpWidget(_wrap(const KubusBadge(text: 'Draft')));
    expect(find.text('Draft'), findsOneWidget);
  });

  testWidgets('status variant tints with provided accent', (tester) async {
    const accent = Color(0xFF10B981);
    await tester.pumpWidget(_wrap(const KubusBadge(
      text: 'Live',
      variant: KubusBadgeVariant.status,
      accent: accent,
    )));
    final deco = tester.widget<Container>(
      find.ancestor(of: find.text('Live'), matching: find.byType(Container)).first,
    ).decoration! as BoxDecoration;
    expect((deco.color!.toARGB32() & 0x00FFFFFF), accent.toARGB32() & 0x00FFFFFF);
  });

  testWidgets('optional icon renders', (tester) async {
    await tester.pumpWidget(_wrap(const KubusBadge(
      text: '3',
      variant: KubusBadgeVariant.count,
      icon: Icons.notifications,
    )));
    expect(find.byIcon(Icons.notifications), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:/dev/flutter/bin/flutter.bat test test/widgets/common/kubus_badge_test.dart --reporter compact`
Expected: FAIL — widget doesn't exist.

- [ ] **Step 3: Implement `lib/widgets/common/kubus_badge.dart`**

```dart
import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';

enum KubusBadgeVariant {
  /// Neutral descriptive tag (category, metadata).
  label,

  /// Colored state pill (Draft/Live/Pending...). Pass [KubusBadge.accent].
  status,

  /// Compact numeric counter (unread counts).
  count,
}

/// Canonical pill badge. Replaces `CreatorStatusBadge` clones and ad-hoc
/// count/label pills. Colors must come from roles/scheme via [accent] —
/// this widget never invents hues.
class KubusBadge extends StatelessWidget {
  const KubusBadge({
    super.key,
    required this.text,
    this.variant = KubusBadgeVariant.label,
    this.accent,
    this.icon,
    this.compact = false,
  });

  final String text;
  final KubusBadgeVariant variant;

  /// Contextual accent (from KubusColorRoles / scheme). Defaults to
  /// scheme.primary for status/count and scheme.onSurface for label.
  final Color? accent;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLabel = variant == KubusBadgeVariant.label;
    final color =
        accent ?? (isLabel ? scheme.onSurface : scheme.primary);

    final background =
        color.withValues(alpha: isLabel ? 0.08 : 0.14);
    final foreground = isLabel
        ? scheme.onSurface.withValues(alpha: 0.85)
        : color;

    final style = (variant == KubusBadgeVariant.count
            ? KubusTextStyles.badgeCount
            : KubusTextStyles.navMetaLabel)
        .copyWith(color: foreground, fontWeight: FontWeight.w600);

    final horizontal = compact ? KubusSpacing.sm : KubusSpacing.sm + 2;
    final vertical = compact ? KubusSpacing.xxs : KubusSpacing.xs;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        border: KubusBorders.accentTint(color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: KubusSizes.trailingChevron, color: foreground),
            const SizedBox(width: KubusSpacing.xs),
          ],
          Text(text, style: style),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `C:/dev/flutter/bin/flutter.bat test test/widgets/common/kubus_badge_test.dart --reporter compact`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/common/kubus_badge.dart test/widgets/common/kubus_badge_test.dart
git commit -m "feat(kit): KubusBadge canonical pill badge"
```

---

### Task 4: `KubusTextField`

**Files:**
- Create: `lib/widgets/common/kubus_text_field.dart`
- Test: `test/widgets/common/kubus_text_field_test.dart`

**Interfaces:**
- Consumes: theme `inputDecorationTheme` (already tokenized), `KubusTextStyles.detailLabel`, `KubusSpacing`.
- Produces: `KubusTextField({String? label, TextEditingController? controller, String? hintText, bool obscureText = false, TextInputType? keyboardType, String? Function(String?)? validator, int maxLines = 1, Widget? prefixIcon, Widget? suffix, bool enabled = true, ValueChanged<String>? onChanged, FocusNode? focusNode, TextInputAction? textInputAction, Iterable<String>? autofillHints, String? errorText, String? helperText})`. Renders above-label + `TextFormField`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/common/kubus_text_field_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/widgets/common/kubus_text_field.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)));

void main() {
  testWidgets('renders above-label and forwards text input', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_wrap(KubusTextField(
      label: 'Email',
      controller: controller,
      hintText: 'you@kubus.site',
    )));
    expect(find.text('Email'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'rok@kubus.site');
    expect(controller.text, 'rok@kubus.site');
  });

  testWidgets('validator surfaces error text', (tester) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(_wrap(Form(
      key: key,
      child: KubusTextField(
        label: 'Name',
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
    )));
    key.currentState!.validate();
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('label is omitted when null', (tester) async {
    await tester.pumpWidget(_wrap(const KubusTextField(hintText: 'Search')));
    expect(find.byType(Text), findsNothing); // only hint inside the field
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:/dev/flutter/bin/flutter.bat test test/widgets/common/kubus_text_field_test.dart --reporter compact`
Expected: FAIL — widget doesn't exist.

- [ ] **Step 3: Implement `lib/widgets/common/kubus_text_field.dart`**

```dart
import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';

/// Canonical general-purpose text field: optional above-label + a
/// `TextFormField` styled entirely by the app-level `inputDecorationTheme`.
///
/// Use this instead of hand-rolling `InputDecoration` per screen. Creator
/// flows keep `CreatorTextField` (same visual family); consolidation of the
/// two is tracked for the glass-sweep slice.
class KubusTextField extends StatelessWidget {
  const KubusTextField({
    super.key,
    this.label,
    this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffix,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
    this.textInputAction,
    this.autofillHints,
    this.errorText,
    this.helperText,
  });

  final String? label;
  final TextEditingController? controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final Widget? prefixIcon;
  final Widget? suffix;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final field = TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      enabled: enabled,
      onChanged: onChanged,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffix,
        errorText: errorText,
        helperText: helperText,
      ),
    );

    if (label == null || label!.isEmpty) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label!,
          style: KubusTextStyles.detailLabel.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: KubusSpacing.xs + 2),
        field,
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `C:/dev/flutter/bin/flutter.bat test test/widgets/common/kubus_text_field_test.dart --reporter compact`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/common/kubus_text_field.dart test/widgets/common/kubus_text_field_test.dart
git commit -m "feat(kit): KubusTextField general above-label text field"
```

---

### Task 5: `kubus_kit.dart` barrel + AGENTS.md pointer

**Files:**
- Create: `lib/widgets/kubus_kit.dart`
- Modify: `lib/AGENTS.md` (add short kit section; read the file first and append in its style)

**Interfaces:**
- Produces: single import `package:art_kubus/widgets/kubus_kit.dart` exposing the canonical kit.

- [ ] **Step 1: Create the barrel**

```dart
/// # Kubus UI Kit — canonical component index
///
/// Import this file when building screens. If a component you need exists
/// here, you MUST use it instead of hand-rolling. Decision table:
///
/// | Need | Use |
/// |---|---|
/// | Screen background | `AnimatedGradientBackground` |
/// | Glass panel/card | `LiquidGlassPanel` / `LiquidGlassCard` / `KubusCard` |
/// | Small floating glass (chips/info) | `FrostedContainer` |
/// | Bottom sheet | `BackdropGlassSheet` (inside `showModalBottomSheet`) |
/// | Dialog | `KubusAlertDialog` via `showKubusDialog` |
/// | Primary/secondary button | `KubusButton` |
/// | Icon button on glass/map | `KubusGlassIconButton` |
/// | Filter/selection chip | `KubusGlassChip` |
/// | Status/count/label pill | `KubusBadge` |
/// | Text input | `KubusTextField` (creator flows: `CreatorTextField`) |
/// | Search input | `KubusSearchBar` |
/// | Screen/section header | `KubusScreenHeader` |
/// | Stat tile | `KubusStatCard` |
/// | Empty state | `EmptyStateCard` |
/// | Toast/snackbar | `KubusSnackbar` |
/// | Borders | `KubusBorders.*` (never raw `Border.all`) |
/// | Contextual gradients | `KubusAccentGradients.*` (never inline colors) |
///
/// Colors: `Theme.of(context).colorScheme`, `KubusColorRoles.of(context)`,
/// `KubusColors`. Spacing/radius/typography: `KubusSpacing`, `KubusRadius`,
/// `KubusTextStyles`. Enforced by `packages/kubus_lints`.
library;

export '../utils/design_tokens.dart';
export '../utils/kubus_accent_gradients.dart';
export '../utils/kubus_color_roles.dart';
export 'common/kubus_badge.dart';
export 'common/kubus_glass_chip.dart';
export 'common/kubus_glass_icon_button.dart';
export 'common/kubus_screen_header.dart';
export 'common/kubus_stat_card.dart';
export 'common/kubus_text_field.dart';
export 'empty_state_card.dart';
export 'glass_components.dart';
export 'kubus_button.dart';
export 'kubus_card.dart';
export 'kubus_snackbar.dart';
export 'search/kubus_search_bar.dart';
```

Check each export compiles (some files may have name collisions — if two exports collide, use `show`/`hide` to resolve, preferring the canonical symbol).

- [ ] **Step 2: Verify it compiles**

Run: `C:/dev/flutter/bin/flutter.bat analyze lib/widgets/kubus_kit.dart`
Expected: No issues found.

- [ ] **Step 3: Add AGENTS.md pointer** — append to `lib/AGENTS.md` (match existing tone):

```markdown
## UI kit & design tokens

- Import `package:art_kubus/widgets/kubus_kit.dart` for the canonical component set; its dartdoc has the decision table.
- Never inline `Color(0x...)`, raw `Border.all`, `BackdropFilter`, or `GoogleFonts.*` in widgets — enforced by `packages/kubus_lints` (see `// ignore_for_file` grandfather headers + `tool/kubus_lint_ratchet.json` ratchet).
- Contextual colors are fine but must be defined centrally (`KubusColorRoles`, `KubusAccentGradients`, `design_tokens.dart`).
```

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/kubus_kit.dart lib/AGENTS.md
git commit -m "feat(kit): kubus_kit barrel with component decision table"
```

---

### Task 6: `packages/kubus_lints` custom_lint plugin

**Files:**
- Create: `packages/kubus_lints/pubspec.yaml`, `lib/kubus_lints.dart`, `lib/src/allowlists.dart`, `lib/src/no_raw_color.dart`, `lib/src/no_raw_border.dart`, `lib/src/no_raw_backdrop_filter.dart`, `lib/src/no_inline_google_fonts.dart`
- Create: `packages/kubus_lints/example/` fixture package with `expect_lint` comments

**Interfaces:**
- Produces: plugin exposing rules `kubus_no_raw_color`, `kubus_no_raw_border`, `kubus_no_raw_backdropfilter`, `kubus_no_inline_google_fonts`. Task 7 wires it into the app.

- [ ] **Step 1: Package scaffold** — `packages/kubus_lints/pubspec.yaml`:

```yaml
name: kubus_lints
description: In-repo custom_lint rules enforcing the kubus design token system.
version: 0.1.0
publish_to: none

environment:
  sdk: ">=3.6.0 <4.0.0"

dependencies:
  analyzer: ">=6.0.0 <9.0.0"
  custom_lint_builder: ^0.8.0
```

(If `dart pub get` fails on the analyzer range, widen/narrow to whatever `custom_lint_builder 0.8.x` requires — check the resolver error message.)

- [ ] **Step 2: Shared allowlists** — `lib/src/allowlists.dart`:

```dart
/// Files (by path suffix, forward slashes) where raw colors are legitimate:
/// these ARE the central definitions.
const rawColorAllowedSuffixes = <String>[
  'lib/utils/design_tokens.dart',
  'lib/utils/kubus_color_roles.dart',
  'lib/utils/kubus_accent_gradients.dart',
  'lib/utils/app_color_utils.dart',
  'lib/utils/category_accent_color.dart',
  'lib/utils/rarity_ui.dart',
  'lib/widgets/map_marker_style_config.dart',
  'lib/providers/themeprovider.dart',
];

/// Files allowed to use BackdropFilter directly (the canonical glass stack).
const backdropFilterAllowedSuffixes = <String>[
  'lib/widgets/glass/glass_surface.dart',
  'lib/widgets/glass_components.dart',
];

/// Files allowed to call GoogleFonts directly.
const googleFontsAllowedSuffixes = <String>[
  'lib/utils/design_tokens.dart',
];

bool isAllowed(String path, List<String> suffixes) {
  final normalized = path.replaceAll('\\', '/');
  return suffixes.any(normalized.endsWith);
}
```

- [ ] **Step 3: Rules.** Plugin entrypoint `lib/kubus_lints.dart`:

```dart
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/no_inline_google_fonts.dart';
import 'src/no_raw_backdrop_filter.dart';
import 'src/no_raw_border.dart';
import 'src/no_raw_color.dart';

PluginBase createPlugin() => _KubusLintsPlugin();

class _KubusLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const KubusNoRawColor(),
        const KubusNoRawBorder(),
        const KubusNoRawBackdropFilter(),
        const KubusNoInlineGoogleFonts(),
      ];
}
```

`lib/src/no_raw_color.dart`:

```dart
import 'package:analyzer/error/error.dart' as analyzer;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'allowlists.dart';

class KubusNoRawColor extends DartLintRule {
  const KubusNoRawColor() : super(code: _code);

  static const _code = LintCode(
    name: 'kubus_no_raw_color',
    problemMessage:
        'Raw Color(0x...) literal. Define it centrally (KubusColors, '
        'KubusColorRoles, KubusAccentGradients) and reference the token.',
    errorSeverity: analyzer.ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName;
    if (isAllowed(path, rawColorAllowedSuffixes)) return;

    context.registry.addInstanceCreationExpression((node) {
      final type = node.staticType?.getDisplayString();
      if (type != 'Color') return;
      final ctor = node.constructorName;
      // Color(0x...), Color.fromARGB(...), Color.fromRGBO(...)
      reporter.atNode(node, _code);
    });
  }
}
```

`lib/src/no_raw_border.dart` — flag `Border.all(...)`/`BorderSide(...)` whose `color:` argument is a `Color` literal or `Colors.*` access:

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' as analyzer;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'allowlists.dart';

class KubusNoRawBorder extends DartLintRule {
  const KubusNoRawBorder() : super(code: _code);

  static const _code = LintCode(
    name: 'kubus_no_raw_border',
    problemMessage:
        'Ad-hoc border color. Use KubusBorders.hairline/glass/focus/active/'
        'accentTint (lib/utils/design_tokens.dart).',
    errorSeverity: analyzer.ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName;
    // KubusBorders itself lives in design_tokens.dart.
    if (isAllowed(path, rawColorAllowedSuffixes)) return;

    void check(AstNode node, ArgumentList args) {
      for (final arg in args.arguments) {
        if (arg is! NamedExpression) continue;
        if (arg.name.label.name != 'color') continue;
        final expr = arg.expression.unParenthesized;
        final src = expr.toSource();
        final isRaw = src.startsWith('Color(') ||
            src.startsWith('Color.from') ||
            src.startsWith('Colors.');
        if (isRaw) reporter.atNode(node, _code);
      }
    }

    context.registry.addInstanceCreationExpression((node) {
      final name = node.constructorName.toSource();
      if (name == 'BorderSide' || name == 'Border.all') {
        check(node, node.argumentList);
      }
    });
    context.registry.addMethodInvocation((node) {
      // Border.all is a factory; may parse as MethodInvocation.
      if (node.target?.toSource() == 'Border' &&
          node.methodName.name == 'all') {
        check(node, node.argumentList);
      }
    });
  }
}
```

`lib/src/no_raw_backdrop_filter.dart`:

```dart
import 'package:analyzer/error/error.dart' as analyzer;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'allowlists.dart';

class KubusNoRawBackdropFilter extends DartLintRule {
  const KubusNoRawBackdropFilter() : super(code: _code);

  static const _code = LintCode(
    name: 'kubus_no_raw_backdropfilter',
    problemMessage:
        'Raw BackdropFilter. Use GlassSurface / LiquidGlassPanel / '
        'showKubusDialog so blur fallback & tokens stay consistent.',
    errorSeverity: analyzer.ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName;
    if (isAllowed(path, backdropFilterAllowedSuffixes)) return;

    context.registry.addInstanceCreationExpression((node) {
      if (node.constructorName.type.name2.lexeme == 'BackdropFilter') {
        reporter.atNode(node, _code);
      }
    });
  }
}
```

`lib/src/no_inline_google_fonts.dart`:

```dart
import 'package:analyzer/error/error.dart' as analyzer;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'allowlists.dart';

class KubusNoInlineGoogleFonts extends DartLintRule {
  const KubusNoInlineGoogleFonts() : super(code: _code);

  static const _code = LintCode(
    name: 'kubus_no_inline_google_fonts',
    problemMessage:
        'Inline GoogleFonts call. Use KubusTextStyles / the theme textTheme '
        '(lib/utils/design_tokens.dart).',
    errorSeverity: analyzer.ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName;
    if (isAllowed(path, googleFontsAllowedSuffixes)) return;

    context.registry.addMethodInvocation((node) {
      if (node.target?.toSource() == 'GoogleFonts') {
        reporter.atNode(node, _code);
      }
    });
  }
}
```

NOTE for implementer: `custom_lint_builder` 0.8.x API — verify exact reporter method (`reporter.atNode(node, code)`) and `LintCode` import against the resolved package source in `%PUB_CACHE%`; adjust if the API differs. This is the most likely place you'll need to adapt.

- [ ] **Step 4: Fixture test via `expect_lint`** — `packages/kubus_lints/example/pubspec.yaml`:

```yaml
name: kubus_lints_example
publish_to: none
environment:
  sdk: ">=3.6.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  google_fonts: any
dev_dependencies:
  custom_lint: ^0.8.0
  kubus_lints:
    path: ../
```

`packages/kubus_lints/example/analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint
```

`packages/kubus_lints/example/lib/fixture.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// expect_lint: kubus_no_raw_color
const bad = Color(0xFF123456);

final okNamed = Colors.transparent;

// expect_lint: kubus_no_raw_border
final badBorder = Border.all(color: Colors.red);

// expect_lint: kubus_no_raw_border
const badSide = BorderSide(color: Color(0xFF000000));

// expect_lint: kubus_no_raw_backdropfilter
final badBlur = BackdropFilter(filter: ColorFilter.mode(bad, BlendMode.srcOver));

// expect_lint: kubus_no_inline_google_fonts
final badFont = GoogleFonts.inter(fontSize: 12);
```

- [ ] **Step 5: Run the fixture check**

```bash
cd packages/kubus_lints/example
C:/dev/flutter/bin/flutter.bat pub get
C:/dev/flutter/bin/dart.bat run custom_lint
```

Expected: exit 0 — every `expect_lint` matched, no unexpected diagnostics. Iterate on rule code until clean.

- [ ] **Step 6: Commit**

```bash
git add packages/kubus_lints
git commit -m "feat(lint): kubus_lints custom_lint package with 4 token-enforcement rules"
```

---

### Task 7: Wire into app + grandfather + ratchet + CI

**Files:**
- Modify: `pubspec.yaml` (app), `analysis_options.yaml`
- Create: `scripts/kubus-lint-ratchet.mjs`, `tool/kubus_lint_ratchet.json`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: rule names from Task 6.
- Produces: green `dart run custom_lint` at repo root; `node scripts/kubus-lint-ratchet.mjs --check` exits 0; both wired into CI.

- [ ] **Step 1: App wiring** — `pubspec.yaml` dev_dependencies:

```yaml
  custom_lint: ^0.8.1
  kubus_lints:
    path: packages/kubus_lints
```

`analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint
  exclude:
    - third_party/**
```

Run `C:/dev/flutter/bin/flutter.bat pub get`. If resolution conflicts with existing deps, record the conflict and fall back to the grep-gate (Step 5 alt) — the ratchet script already covers detection.

- [ ] **Step 2: Ratchet script** — `scripts/kubus-lint-ratchet.mjs`:

```js
#!/usr/bin/env node
/**
 * Kubus lint ratchet.
 *
 * --grandfather  Add `// ignore_for_file:` headers for kubus lint rules to
 *                every lib/ file that currently violates them (regex-based
 *                over-approximation of the custom_lint rules).
 * --check        Recount grandfathered files per rule and compare with
 *                tool/kubus_lint_ratchet.json. Fails (exit 1) if any count
 *                INCREASED. Prints per-rule deltas.
 * --write        With --check: update the baseline to current counts
 *                (use after intentionally migrating files).
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const RULES = {
  kubus_no_raw_color: /\bColor(\.fromARGB|\.fromRGBO)?\s*\(\s*0x/,
  kubus_no_raw_border: /\b(Border\.all|BorderSide)\s*\((?:[^()]|\([^()]*\))*color:\s*(Color(\.from)?\(|Colors\.)/s,
  kubus_no_raw_backdropfilter: /\bBackdropFilter\s*\(/,
  kubus_no_inline_google_fonts: /\bGoogleFonts\.\w+\s*\(/,
};

const ALLOW = {
  kubus_no_raw_color: [
    'lib/utils/design_tokens.dart',
    'lib/utils/kubus_color_roles.dart',
    'lib/utils/kubus_accent_gradients.dart',
    'lib/utils/app_color_utils.dart',
    'lib/utils/category_accent_color.dart',
    'lib/utils/rarity_ui.dart',
    'lib/widgets/map_marker_style_config.dart',
    'lib/providers/themeprovider.dart',
  ],
  kubus_no_raw_border: [
    'lib/utils/design_tokens.dart',
    'lib/utils/kubus_color_roles.dart',
    'lib/utils/kubus_accent_gradients.dart',
    'lib/utils/app_color_utils.dart',
    'lib/utils/category_accent_color.dart',
    'lib/utils/rarity_ui.dart',
    'lib/widgets/map_marker_style_config.dart',
    'lib/providers/themeprovider.dart',
  ],
  kubus_no_raw_backdropfilter: [
    'lib/widgets/glass/glass_surface.dart',
    'lib/widgets/glass_components.dart',
  ],
  kubus_no_inline_google_fonts: ['lib/utils/design_tokens.dart'],
};

const BASELINE_PATH = 'tool/kubus_lint_ratchet.json';

function* dartFiles(dir) {
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    const st = statSync(p);
    if (st.isDirectory()) yield* dartFiles(p);
    else if (p.endsWith('.dart')) yield p;
  }
}

const norm = (p) => p.replaceAll('\\', '/');

function violatedRules(path, text) {
  const rules = [];
  for (const [rule, re] of Object.entries(RULES)) {
    if (ALLOW[rule].some((suffix) => norm(path).endsWith(suffix))) continue;
    if (re.test(text)) rules.push(rule);
  }
  return rules;
}

function existingIgnores(text) {
  const m = text.match(/\/\/ ignore_for_file:\s*([^\n]*)/g) ?? [];
  return new Set(
    m.flatMap((line) =>
      line.replace('// ignore_for_file:', '').split(',').map((s) => s.trim()),
    ),
  );
}

const mode = process.argv[2];
const files = [...dartFiles('lib')];

if (mode === '--grandfather') {
  let touched = 0;
  for (const path of files) {
    const text = readFileSync(path, 'utf8');
    const rules = violatedRules(path, text).filter(
      (r) => !existingIgnores(text).has(r),
    );
    if (rules.length === 0) continue;
    const header =
      `// ignore_for_file: ${rules.join(', ')}\n` +
      `// Grandfathered kubus design-token violations. Remove this header\n` +
      `// when migrating this file to tokens (see docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md).\n`;
    writeFileSync(path, header + text);
    touched++;
  }
  console.log(`Grandfathered ${touched} files.`);
} else if (mode === '--check') {
  const counts = Object.fromEntries(Object.keys(RULES).map((r) => [r, 0]));
  for (const path of files) {
    const text = readFileSync(path, 'utf8');
    for (const rule of existingIgnores(text)) {
      if (rule in counts) counts[rule]++;
    }
  }
  if (process.argv.includes('--write')) {
    writeFileSync(BASELINE_PATH, JSON.stringify(counts, null, 2) + '\n');
    console.log('Baseline updated:', counts);
    process.exit(0);
  }
  const baseline = JSON.parse(readFileSync(BASELINE_PATH, 'utf8'));
  let failed = false;
  for (const [rule, count] of Object.entries(counts)) {
    const base = baseline[rule] ?? 0;
    const delta = count - base;
    console.log(`${rule}: ${count} (baseline ${base}, delta ${delta >= 0 ? '+' : ''}${delta})`);
    if (count > base) failed = true;
  }
  if (failed) {
    console.error('\nRatchet violation: grandfathered-file count increased.');
    console.error('New code must use kubus tokens — do not add ignore_for_file headers.');
    process.exit(1);
  }
  console.log('\nRatchet OK.');
} else {
  console.error('Usage: node scripts/kubus-lint-ratchet.mjs --grandfather | --check [--write]');
  process.exit(2);
}
```

- [ ] **Step 3: Grandfather + baseline**

```bash
node scripts/kubus-lint-ratchet.mjs --grandfather
node scripts/kubus-lint-ratchet.mjs --check --write   # creates tool/kubus_lint_ratchet.json
```

Then verify the analyzer is clean:

```bash
C:/dev/flutter/bin/dart.bat run custom_lint    # from repo root; expect 0 issues
C:/dev/flutter/bin/flutter.bat analyze          # expect No issues found
```

If `dart run custom_lint` reports violations the regex grandfathering missed, add those rule names to the affected files' headers manually and re-run `--check --write`.

- [ ] **Step 4: CI wiring** — in `.github/workflows/ci.yml`, after the `Flutter analyze` step add:

```yaml
      - name: Kubus lint (custom_lint)
        run: dart run custom_lint

      - name: Kubus lint ratchet
        run: node scripts/kubus-lint-ratchet.mjs --check
```

- [ ] **Step 5 (fallback only):** If custom_lint could not be wired (dependency conflict), skip the `custom_lint` CI step, keep the ratchet step, and extend `kubus-lint-ratchet.mjs --check` to ALSO fail when a non-grandfathered file matches a rule regex (full grep gate). Document the conflict in the spec's Risk section.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock analysis_options.yaml scripts/kubus-lint-ratchet.mjs tool/kubus_lint_ratchet.json .github/workflows/ci.yml lib
git commit -m "feat(lint): wire kubus_lints into app with grandfathered baseline + CI ratchet"
```

---

### Task 8: Migrate onboarding (`onboarding_data.dart`, `onboarding_flow_screen.dart`)

**Files:**
- Modify: `lib/screens/onboarding/web3/onboarding_data.dart` (29 raw colors: `gradientColors:` pairs at lines ~16–352)
- Modify: `lib/screens/onboarding/onboarding_flow_screen.dart` (38 raw colors: step palette table lines ~299–367; scattered `Color(0xFF81C784)` at ~4536–5885)

**Interfaces:**
- Consumes: `KubusAccentGradients.*` (Task 2), `KubusColorRoles.of(context).positiveAction`.

- [ ] **Step 1: Map every gradient pair onto the curated set.** Mapping table (apply exactly):

| Old pair | New token |
|---|---|
| `0xFF06B6D4 → 0xFF3B82F6` | `KubusAccentGradients.cyanBlue` |
| `0xFF0EA5E9 → 0xFF06B6D4` | `KubusAccentGradients.skyCyan` |
| `0xFF10B981 → 0xFF059669` | `KubusAccentGradients.emerald` |
| `0xFFF59E0B → 0xFFEF4444` | `KubusAccentGradients.sunset` |
| `0xFF6366F1 → 0xFF3B82F6` | `KubusAccentGradients.indigo` |
| `0xFF0F766E → 0xFF2563EB` / `0xFF072A40 → 0xFF0B6E4F` / ARGB(6,89,141) pair | `KubusAccentGradients.tealBlue` |
| `0xFFEC4899 → *` (pink pairs), `0xFF667eea → 0xFF764ba2`, `0xFF6A1B9A → 0xFF8E24AA` | `KubusAccentGradients.violet` |
| `0xFFFFD700 → 0xFFFF8C00`, gold/amber triples | `KubusAccentGradients.gold` |
| `0xFF4ECDC4 → 0xFF26A69A` and other teal/cyan Material tones | `KubusAccentGradients.tealBlue` or `skyCyan` (closest hue) |
| Blue Material tones (`0xFF1565C0→0xFF42A5F5`, `0xFF01579B→0xFF0288D1`, `0xFF0D47A1→0xFF1E88E5`, `0xFF3F51B5`) | `KubusAccentGradients.cyanBlue` or `indigo` (closest hue) |
| Green Material tones (`0xFF2E7D32`, `0xFF00695C→0xFF26A69A`, `0xFF00796B→0xFF4DB6AC`) | `KubusAccentGradients.emerald` |
| Red/orange (`0xFFFF6B6B→0xFFE91E63`, `0xFFFF9A8B→0xFFFF7043`, `0xFFE65100`) | `KubusAccentGradients.sunset` |

In `onboarding_data.dart`: `gradientColors: [g.start, g.end]` where `g` is the token. In `onboarding_flow_screen.dart`'s step table: `start: g.start, end: g.end, accent: g.accent`. Because tokens are `const`, tables remain `const`.

- [ ] **Step 2: Replace scattered greens.** Every `Color(0xFF81C784)` in `onboarding_flow_screen.dart` → `KubusColorRoles.of(context).positiveAction` (context is available at all 8 sites — they're inside build methods). Remove now-unneeded `const` on affected constructors.

- [ ] **Step 3: Remove grandfather headers** from both files (they're now clean), then verify:

```bash
C:/dev/flutter/bin/dart.bat run custom_lint   # 0 issues
C:/dev/flutter/bin/flutter.bat analyze         # No issues found
node scripts/kubus-lint-ratchet.mjs --check --write   # counts DECREASE
```

- [ ] **Step 4: Run onboarding tests**

```bash
C:/dev/flutter/bin/flutter.bat test test/ --plain-name onboarding --reporter compact
```

Expected: same pass/fail set as master (no new failures). Also run any test files matching `test/**/onboarding*`.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/onboarding tool/kubus_lint_ratchet.json
git commit -m "refactor(onboarding): centralize step gradients onto KubusAccentGradients"
```

---

### Task 9: Migrate `connectwallet_screen.dart`

**Files:**
- Modify: `lib/screens/web3/wallet/connectwallet_screen.dart` (24 raw colors + 23 border sites)

**Interfaces:**
- Consumes: `KubusAccentGradients` mapping table from Task 8, `KubusBorders.accentTint/hairline/focus`, `KubusColorRoles.of(context)` (`statBlue`, `positiveAction`, `warningAction`).

- [ ] **Step 1: Gradients.** Apply the Task 8 mapping table to the start/end pairs at lines ~118–132, ~1565, ~1700–1707, ~1825–1826, ~2147–2148, ~2362–2363, ~2777–2778. `0xFF099514 → 0xFF3B82F6` maps to `emerald`.
- [ ] **Step 2: Solid raw colors.** `Color(0xFF0EA5E9)`/`backgroundColor: Color(0xFF10B981)` etc. as solid fills → the mapped gradient's `.start` (e.g. `KubusAccentGradients.emerald.start`).
- [ ] **Step 3: Borders.**
  - `Border.all(color: Colors.orange.withValues(alpha: 0.3))` → `KubusBorders.accentTint(KubusColorRoles.of(context).warningAction)`
  - `Border.all(color: Colors.green.withValues(alpha: 0.3))` → `KubusBorders.accentTint(KubusColorRoles.of(context).positiveAction)`
  - `Border.all(color: Colors.blue.withValues(alpha: 0.3))` → `KubusBorders.accentTint(KubusColorRoles.of(context).statBlue)`
  - `BorderSide(color: Colors.blue, width: 2)` (focused input) → `KubusBorders.focusSide(context, accent: KubusColorRoles.of(context).statBlue)`
  - Input `OutlineInputBorder` triplets (lines ~945–957, ~1886–1896): if they replicate the theme's input decoration, delete the overrides and let `inputDecorationTheme` apply; otherwise use `KubusBorders.hairlineSide(context)` / `focusSide(context)`.
  - Remaining `Border.all(` sites with scheme/roles-derived colors and non-token alphas: normalize to `KubusBorders.accentTint(<that color>)` when alpha ≤0.35, `KubusBorders.hairline(context)` when it's a neutral outline.
- [ ] **Step 4: Remove the grandfather header; verify** — same commands as Task 8 Step 3 (custom_lint 0, analyze clean, ratchet `--check --write` decreases).
- [ ] **Step 5: Run wallet tests**

```bash
C:/dev/flutter/bin/flutter.bat test test/ --plain-name wallet --reporter compact
```

Expected: same pass/fail set as master. (Known: secure-storage fake-async tests hang — skip those per repo memory if they block.)

- [ ] **Step 6: Commit**

```bash
git add lib/screens/web3/wallet/connectwallet_screen.dart tool/kubus_lint_ratchet.json
git commit -m "refactor(wallet): tokenize connect-wallet colors and borders"
```

---

### Task 10: Migrate `sign_in_screen.dart` + stray `BackdropFilter`

**Files:**
- Modify: `lib/screens/auth/sign_in_screen.dart` (5 border sites)
- Modify: `lib/utils/user_profile_navigation.dart` (1 raw `BackdropFilter`)

- [ ] **Step 1: sign_in_screen borders** → `KubusBorders` roles by intent (container hairline vs focused input vs accent tint), same normalization rules as Task 9 Step 3.
- [ ] **Step 2: user_profile_navigation BackdropFilter.** Read the call site; it's dialog/overlay chrome — replace with `showKubusDialog` (which applies canonical blur) or wrap content in `GlassSurface`. Preserve exact behavior (barrier dismiss, result passing).
- [ ] **Step 3: Remove both grandfather headers; verify** — custom_lint 0 issues, analyze clean, `node scripts/kubus-lint-ratchet.mjs --check --write` decreases.
- [ ] **Step 4: Run auth tests**

```bash
C:/dev/flutter/bin/flutter.bat test test/ --plain-name "sign in" --reporter compact
C:/dev/flutter/bin/flutter.bat test test/ --plain-name auth --reporter compact
```

Expected: same pass/fail set as master.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/auth/sign_in_screen.dart lib/utils/user_profile_navigation.dart tool/kubus_lint_ratchet.json
git commit -m "refactor(auth): tokenize sign-in borders; route profile nav blur through glass stack"
```

---

### Task 11: Full verification + spec amendment

**Files:**
- Modify: `docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md` (note: map controls beachhead verified already-migrated pre-slice; beachhead executed = onboarding + connectwallet + sign-in + stray blur)

- [ ] **Step 1: Full analyzer + lint**

```bash
C:/dev/flutter/bin/flutter.bat analyze          # No issues found
C:/dev/flutter/bin/dart.bat run custom_lint     # 0 issues
node scripts/kubus-lint-ratchet.mjs --check     # Ratchet OK
```

- [ ] **Step 2: Full test suite**

```bash
C:/dev/flutter/bin/flutter.bat test --reporter compact > flutter-test-slice1.log 2>&1
```

Compare failures against master's baseline (`git stash` not needed — run on master in a worktree or consult `flutter-test-full.log`). Zero NEW failures allowed.

- [ ] **Step 3: Visual smoke pass** (use the `verify`/`run` skill): launch the app (web debug is fine), walk onboarding → sign-in → connect-wallet in light & dark; confirm gradients look intentional, borders consistent, no layout shifts.

- [ ] **Step 4: Amend spec + commit**

```bash
git add docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md
git commit -m "docs: record slice-1 beachhead outcome in design spec"
```

---

## Self-Review Notes

- Spec coverage: kit gaps (Tasks 1–4), barrel/canon (5), enforcement (6–7), beachhead (8–10 — adjusted: map controls found already migrated; recorded in Task 11), verification (11). Color-policy amendment implemented via `KubusAccentGradients` + allowlists.
- Types consistent: `KubusBorders.*Side`/`Border` names used identically in Tasks 3, 9, 10; gradient token names in Tasks 2, 8, 9.
- Known adaptation points called out explicitly: custom_lint_builder API surface (Task 6 note), dependency-conflict fallback (Task 7 Step 5).
