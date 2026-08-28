import 'package:flutter/material.dart';

import '../../utils/app_color_utils.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../widgets/inline_loading.dart';

/// The production AR chrome, as widgets rather than inline builders.
///
/// Extracted so the layout contract is exercised against the widgets the app
/// actually renders. The previous layout test mirrored the intended structure
/// in a private harness, which could — and did — stay green while the screen
/// itself still carried absolutely-positioned instruction cards the harness
/// never modelled.
///
/// Everything here is presentational: no providers, no platform channels, no
/// AR session. The camera surface arrives as a widget, so a test can inject a
/// coloured box where the device has a camera.

/// One entry in the mode dock.
@immutable
class ArModeOption {
  const ArModeOption({
    required this.id,
    required this.icon,
    required this.label,
  });

  final String id;
  final IconData icon;
  final String label;
}

/// The single contextual action for the current mode.
@immutable
class ArPrimaryAction {
  const ArPrimaryAction({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;

  /// Null disables the button. Callers pass null rather than hiding the action,
  /// so the control never jumps around as state changes.
  final VoidCallback? onPressed;
}

/// A supporting action shown beneath the primary one.
@immutable
class ArSecondaryAction {
  const ArSecondaryAction({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
}

/// Live capture readout shown inside the guidance surface.
@immutable
class ArCaptureReadout {
  const ArCaptureReadout({
    required this.coverage,
    required this.detail,
    this.animate = false,
  });

  /// Viewpoint-diversity progress in 0..1. Not a frame-count ratio.
  final double coverage;

  /// Localized "N tracked views · depth available" line.
  final String detail;
  final bool animate;
}

/// Measured transfer progress, shown while a capture is streaming to a node.
@immutable
class ArTransferReadout {
  const ArTransferReadout({required this.label, this.fraction});

  final String label;

  /// Null renders an indeterminate bar, for a phase with no honest fraction.
  final double? fraction;
}

/// Compact status header, floating over the edge-to-edge camera. Its
/// top-to-transparent gradient scrim exists for exactly that: legible text
/// over unpredictable live camera content, the same visual language as the
/// controls region below. It never sits on top of the controls — those are
/// bottom-anchored and the header is top-anchored, so the two can only meet
/// if the intervening guidance content overflows, which the layout tests
/// guard against.
///
/// The header carries exactly two things: what the session is doing, and one
/// overflow affordance. Flash appears only while it is genuinely actionable.
/// Library and AR settings live behind the overflow, because three permanent
/// icon buttons plus a status pill do not fit a 320dp row at accessible text
/// sizes — the previous layout clipped the status to unreadable stubs on real
/// hardware.
class ArStatusHeader extends StatelessWidget {
  const ArStatusHeader({
    super.key,
    required this.statusLabel,
    required this.statusAccent,
    required this.onOpenMore,
    required this.moreTooltip,
    this.isDark = true,
    this.onToggleFlash,
    this.flashTooltip,
    this.flashEnabled = false,
  });

  /// One or two words. Long-form guidance belongs in [ArContextualGuidance].
  final String statusLabel;

  /// Semantic status color, resolved by the caller from `KubusColorRoles`.
  final Color statusAccent;

  final VoidCallback onOpenMore;
  final String moreTooltip;
  final bool isDark;

  /// Null hides flash entirely. It is only offered while a torch-capable
  /// camera surface is actually mounted.
  final VoidCallback? onToggleFlash;
  final String? flashTooltip;
  final bool flashEnabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overlayColor = scheme.surface.withValues(alpha: isDark ? 0.8 : 0.95);
    final flashTint = KubusColorRoles.of(context).statAmber;

    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [overlayColor, overlayColor.withValues(alpha: 0.0)],
        ),
      ),
      child: Row(
        children: [
          // Flexible, not Expanded: the pill takes the width it needs and
          // yields the rest, so the actions can never be pushed off the row.
          Flexible(
            child: ArStatusPill(label: statusLabel, accent: statusAccent),
          ),
          const SizedBox(width: KubusSpacing.sm),
          if (onToggleFlash != null) ...[
            _HeaderAction(
              icon: flashEnabled ? Icons.flash_on : Icons.flash_off,
              tooltip: flashTooltip ?? '',
              tint: flashEnabled ? flashTint : null,
              onPressed: onToggleFlash!,
            ),
            const SizedBox(width: KubusSpacing.sm),
          ],
          _HeaderAction(
            icon: Icons.more_horiz_rounded,
            tooltip: moreTooltip,
            onPressed: onOpenMore,
          ),
        ],
      ),
    );
  }
}

/// The status pill itself, exposed so layout tests can measure it directly.
///
/// Two lines rather than one: at a 2.0 text scale on a 320dp screen a single
/// line cannot hold "Finding surface" beside a 44dp action, and truncating a
/// two-word status to "Findi…" tells the user nothing.
class ArStatusPill extends StatelessWidget {
  const ArStatusPill({super.key, required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = KubusTextStyles.navLabel.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Padding is the first thing the label can take back on a narrow row
        // at a large text scale, so it is given up only when the label
        // actually needs it — measured, not guessed from a width threshold
        // that would be wrong for some language or font.
        final comfortable = _labelFits(
          context,
          style: style,
          available: constraints.maxWidth -
              (KubusSpacing.md * 2) -
              KubusSizes.statusDot -
              KubusSpacing.sm,
        );
        final horizontal = comfortable ? KubusSpacing.md : KubusSpacing.xs;
        final gap = comfortable ? KubusSpacing.sm : KubusSpacing.xs;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontal,
            vertical: KubusSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(KubusRadius.xl),
            border: KubusBorders.accentTint(accent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A dot, not an icon: the mode already has its own dock entry,
              // and the colour is the signal.
              Container(
                width: KubusSizes.statusDot,
                height: KubusSizes.statusDot,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              SizedBox(width: gap),
              Flexible(
                child: Text(
                  label,
                  maxLines: _maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Two lines: a status is one or two words, and a word that will not fit on
  /// one line at an accessible text size still has to be readable.
  static const int _maxLines = 2;

  /// Whether [label] renders inside [_maxLines] in [available] logical pixels.
  bool _labelFits(
    BuildContext context, {
    required TextStyle style,
    required double available,
  }) {
    if (!available.isFinite) return true;
    if (available <= 0) return false;
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      maxLines: _maxLines,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: available);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return !exceeded;
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.tint,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: KubusHeaderMetrics.actionHitArea,
      height: KubusHeaderMetrics.actionHitArea,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tint == null
              ? scheme.surface.withValues(alpha: 0.92)
              : tint!.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(KubusRadius.xl),
          border: KubusBorders.accentTint(tint ?? scheme.outline),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          tooltip: tooltip.isEmpty ? null : tooltip,
          icon: Icon(
            icon,
            color: tint ?? scheme.onSurface,
            size: KubusHeaderMetrics.actionIcon,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// The one contextual guidance surface.
///
/// Replaces the stacked glass cards and `Positioned(top: 100)` instruction
/// panels that used to compete with each other and with the controls for the
/// same space. Guidance, capture readout and transfer progress are three parts
/// of one bounded card, never three overlapping ones.
class ArContextualGuidance extends StatelessWidget {
  const ArContextualGuidance({
    super.key,
    this.message,
    this.capture,
    this.transfer,
  });

  final String? message;
  final ArCaptureReadout? capture;
  final ArTransferReadout? transfer;

  bool get isEmpty => message == null && capture == null && transfer == null;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(KubusRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null)
            Text(
              message!,
              textAlign: TextAlign.center,
              // Session errors and capture guidance land here rather than in
              // the status pill, so this surface has to hold a sentence.
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: KubusTextStyles.navMetaLabel.copyWith(
                color: scheme.onSurface,
              ),
            ),
          if (capture != null) ...[
            const SizedBox(height: KubusSpacing.sm),
            InlineLoading(
              height: KubusSizes.meterThin,
              progress: capture!.coverage,
              color: scheme.primary,
              animate: capture!.animate,
            ),
            const SizedBox(height: KubusSpacing.xs),
            Text(
              capture!.detail,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (transfer != null) ...[
            const SizedBox(height: KubusSpacing.sm),
            InlineLoading(
              height: KubusSizes.meterThin,
              progress: transfer!.fraction,
              color: scheme.primary,
              animate: transfer!.fraction == null,
            ),
            const SizedBox(height: KubusSpacing.xs),
            Text(
              transfer!.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Restrained mode dock. A sibling of the primary action, never an overlay.
class ArModeDock extends StatelessWidget {
  const ArModeDock({
    super.key,
    required this.modes,
    required this.selectedModeId,
    required this.onSelect,
  });

  final List<ArModeOption> modes;
  final String selectedModeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The AR surface accent, resolved through the shared role table rather
    // than a hard-coded hue, so it tracks the theme like every other screen.
    final accent = KubusColorRoles.of(context).screenAccentForKey('ar', scheme);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm,
        vertical: KubusSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: KubusBorders.accentTint(accent),
      ),
      child: Row(
        children: modes.map((mode) {
          final isSelected = mode.id == selectedModeId;
          final tint =
              isSelected ? accent : scheme.onSurface.withValues(alpha: 0.6);
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: mode.label,
              child: GestureDetector(
                onTap: () => onSelect(mode.id),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: KubusSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                    border: isSelected
                        ? KubusBorders.active(context, accent: accent)
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mode.icon,
                        color: tint,
                        size: KubusHeaderMetrics.actionIcon,
                      ),
                      const SizedBox(height: KubusSpacing.xs),
                      // Labels shrink rather than overflow at large text
                      // scales.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          mode.label,
                          maxLines: 1,
                          style: KubusTextStyles.navMetaLabel.copyWith(
                            color: tint,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

/// Contextual actions above the mode dock.
///
/// Laid out in flow rather than stacked with absolute offsets, so the action
/// and the dock cannot overlap at any screen size or text scale.
class ArControlsRegion extends StatelessWidget {
  const ArControlsRegion({
    super.key,
    required this.modes,
    required this.selectedModeId,
    required this.onSelectMode,
    this.primaryAction,
    this.secondaryActions = const <ArSecondaryAction>[],
    this.isDark = true,
  });

  final List<ArModeOption> modes;
  final String selectedModeId;
  final ValueChanged<String> onSelectMode;
  final ArPrimaryAction? primaryAction;
  final List<ArSecondaryAction> secondaryActions;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = KubusColorRoles.of(context).screenAccentForKey('ar', scheme);
    // Contrast-resolved rather than assumed white: the AR accent is a light
    // teal, and white-on-teal is barely readable over a bright camera feed.
    final onAccent = AppColorUtils.onColor(accent);
    final action = primaryAction;

    return Container(
      padding: EdgeInsets.only(
        left: KubusSpacing.lg,
        right: KubusSpacing.lg,
        top: KubusSpacing.md,
        // Only the system/app navigation inset. The old
        // `bottom: 100 + navBarHeight` existed purely to dodge the mode dock,
        // which is a sibling here rather than a floating overlay.
        bottom: KubusSpacing.md + KubusLayout.mainBottomNavBarHeight,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            scheme.surface.withValues(alpha: isDark ? 0.92 : 0.97),
            scheme.surface.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (action != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: action.onPressed,
                icon: Icon(action.icon, color: onAccent),
                label: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTextStyles.detailButton.copyWith(
                    color: onAccent,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: onAccent,
                  disabledBackgroundColor: accent.withValues(alpha: 0.35),
                  disabledForegroundColor: onAccent.withValues(alpha: 0.7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.lg,
                    vertical: KubusSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                  ),
                  elevation: KubusElevation.raised,
                  shadowColor: accent.withValues(alpha: 0.4),
                ),
              ),
            ),
            if (secondaryActions.isNotEmpty) ...[
              const SizedBox(height: KubusSpacing.sm),
              // Wrap, not Row: at large text scales several icon buttons side
              // by side overflow the available width on a 360dp screen.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: KubusSpacing.md,
                runSpacing: KubusSpacing.xs,
                children: [
                  for (final secondary in secondaryActions)
                    TextButton.icon(
                      onPressed: secondary.onPressed,
                      icon: Icon(secondary.icon),
                      label: Text(secondary.label, maxLines: 1),
                    ),
                ],
              ),
            ],
            const SizedBox(height: KubusSpacing.md),
          ],
          ArModeDock(
            modes: modes,
            selectedModeId: selectedModeId,
            onSelect: onSelectMode,
          ),
        ],
      ),
    );
  }
}

/// The whole AR screen layout.
///
/// The camera surface is injected, so this composes identically in production
/// and under test — the structural guarantee the previous mirrored harness
/// could not give.
///
/// Edge-to-edge (Part 6): the camera is a full-bleed `Positioned.fill`
/// underneath everything, extending behind the status bar rather than being
/// confined to the space left over once the header/controls reserve their
/// own rows. Header, guidance and controls float over it inside their own
/// `SafeArea`, exactly as before — their relative layout to each other is
/// unchanged, only the camera's own bounds grew to the full screen.
class ArScreenChrome extends StatelessWidget {
  const ArScreenChrome({
    super.key,
    required this.cameraSurface,
    required this.controls,
    this.header,
    this.guidance,
    this.overlay,
  });

  final Widget cameraSurface;
  final Widget controls;
  final Widget? header;
  final ArContextualGuidance? guidance;

  /// Full-canvas overlay, used for the initialization state.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final guidanceCard = guidance;
    return Stack(
      children: [
        // The dominant surface, genuinely edge-to-edge: it is not inset by
        // SafeArea, so it renders behind the status bar and (via `bottom:
        // false` below) behind the system navigation area too.
        Positioned.fill(child: cameraSurface),
        if (overlay != null) Positioned.fill(child: overlay!),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (header != null) header!,

              // Contextual guidance is bounded inside this region and cannot
              // reach the controls below — unchanged from the pre-edge-to-edge
              // layout, just no longer double-hosting the camera as well.
              Expanded(
                child: Stack(
                  children: [
                    if (guidanceCard != null && !guidanceCard.isEmpty)
                      Positioned(
                        left: KubusSpacing.lg,
                        right: KubusSpacing.lg,
                        bottom: KubusSpacing.md,
                        child: guidanceCard,
                      ),
                  ],
                ),
              ),

              controls,
            ],
          ),
        ),
      ],
    );
  }
}
