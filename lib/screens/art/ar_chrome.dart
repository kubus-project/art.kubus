import 'package:flutter/material.dart';

import '../../utils/app_color_utils.dart';
import '../../utils/design_tokens.dart';
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

/// Compact status header. Part of the layout, never an overlay, so it cannot
/// sit on top of the camera content or the controls.
class ArStatusHeader extends StatelessWidget {
  const ArStatusHeader({
    super.key,
    required this.modeLabel,
    required this.modeIcon,
    required this.onOpenSettings,
    this.isDark = true,
    this.onToggleFlash,
    this.flashEnabled = false,
    this.onOpenLibrary,
  });

  final String modeLabel;
  final IconData modeIcon;
  final VoidCallback onOpenSettings;
  final bool isDark;
  final VoidCallback? onToggleFlash;
  final bool flashEnabled;
  final VoidCallback? onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overlayColor = scheme.surface.withValues(alpha: isDark ? 0.8 : 0.95);

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
          // Flexible, not Expanded: at large text scales the label must be
          // allowed to shrink rather than force the actions off the row.
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.md,
                vertical: KubusSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(KubusRadius.xl),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(modeIcon, color: AppColorUtils.cyanAccent, size: 20),
                  const SizedBox(width: KubusSpacing.sm),
                  Flexible(
                    child: Text(
                      modeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTypography.inter(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (onToggleFlash != null) ...[
            _HeaderAction(
              icon: flashEnabled ? Icons.flash_on : Icons.flash_off,
              tint: flashEnabled ? AppColorUtils.amberAccent : null,
              onPressed: onToggleFlash!,
            ),
            const SizedBox(width: KubusSpacing.sm),
          ],
          if (onOpenLibrary != null) ...[
            _HeaderAction(
              icon: Icons.video_library_outlined,
              onPressed: onOpenLibrary!,
            ),
            const SizedBox(width: KubusSpacing.sm),
          ],
          _HeaderAction(icon: Icons.settings, onPressed: onOpenSettings),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.onPressed, this.tint});

  final IconData icon;
  final VoidCallback onPressed;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tint == null
            ? scheme.primaryContainer
            : tint!.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        border: tint == null ? null : Border.all(color: tint!, width: 1.5),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          color: tint ?? scheme.onSurface,
          size: KubusHeaderMetrics.actionIcon,
        ),
        onPressed: onPressed,
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: KubusTypography.inter(
                color: scheme.onSurface,
                fontSize: KubusChromeMetrics.navMetaLabel,
              ),
            ),
          if (capture != null) ...[
            const SizedBox(height: KubusSpacing.sm),
            InlineLoading(
              height: 6,
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
              height: 6,
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm,
        vertical: KubusSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(
          color: AppColorUtils.cyanAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: modes.map((mode) {
          final isSelected = mode.id == selectedModeId;
          final tint = isSelected
              ? AppColorUtils.cyanAccent
              : scheme.onSurface.withValues(alpha: 0.6);
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
                        ? AppColorUtils.cyanAccent.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                    border: Border.all(
                      color: isSelected
                          ? AppColorUtils.cyanAccent
                          : Colors.transparent,
                      width: 2,
                    ),
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
                          style: KubusTypography.inter(
                            color: tint,
                            fontSize: KubusChromeMetrics.navMetaLabel,
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
                icon: Icon(action.icon, color: Colors.white),
                label: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTypography.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColorUtils.cyanAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColorUtils.cyanAccent.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.lg,
                    vertical: KubusSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                  ),
                  elevation: 8,
                  shadowColor: AppColorUtils.cyanAccent.withValues(alpha: 0.4),
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
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (header != null) header!,

          // The camera is the dominant surface. Contextual guidance is bounded
          // inside this region and cannot reach the controls below.
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: cameraSurface),
                if (overlay != null) Positioned.fill(child: overlay!),
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
    );
  }
}
