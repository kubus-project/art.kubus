import 'dart:async';

import 'package:flutter/material.dart';

import '../../../features/map/controller/kubus_map_controller.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/design_tokens.dart';
import '../kubus_map_chrome.dart';
import 'map_view_mode_controls.dart';

/// Layout variants for [KubusMapPrimaryControls].
///
/// - [mobileRightRail] matches the vertical control stack used in `MapScreen`.
/// - [desktopToolbar] matches the horizontal glass toolbar used in
///   `DesktopMapScreen`.
enum KubusMapPrimaryControlsLayout { mobileRightRail, desktopToolbar }

/// Unified primary map controls used by both mobile + desktop map screens.
///
/// This widget is deliberately UI-only:
/// - It does not read providers or perform any side effects in `build()`.
/// - It integrates with [KubusMapController] for camera actions (zoom and
///   reset bearing), while leaving screen-owned flows (create marker and
///   center-on-me) as callbacks.
///
/// Screens remain responsible for:
/// - feature flags (`AppConfig.isFeatureEnabled(...)`)
/// - gating actions based on permissions / location availability
/// - positioning via `Positioned` + `MapOverlayBlocker` where appropriate
class KubusMapPrimaryControls extends StatelessWidget {
  const KubusMapPrimaryControls({
    super.key,
    required this.controller,
    required this.layout,
    required this.onCenterOnMe,
    required this.onCreateMarker,
    required this.centerOnMeActive,
    this.accentColor,
    this.showNearbyToggle = false,
    this.nearbyActive = false,
    this.onToggleNearby,
    this.nearbyKey,
    this.nearbyTooltip,
    this.nearbyTooltipWhenActive,
    this.nearbyTooltipWhenInactive,
    this.nearbyIcon = Icons.view_list,
    this.showIsometricViewToggle = false,
    this.isometricViewActive = false,
    this.onToggleIsometricView,
    this.isometricViewTooltip,
    this.isometricViewTooltipWhenActive,
    this.isometricViewTooltipWhenInactive,
    this.showZoomControls = true,
    this.showSecondaryTools = false,
    this.onOpenSecondaryTools,
    this.secondaryToolsKey,
    this.secondaryToolsTooltip = 'Map tools',
    this.zoomMin = 3.0,
    this.zoomMax = 18.0,
    this.zoomStep = 1.0,
    this.zoomInTooltip = 'Zoom in',
    this.zoomOutTooltip = 'Zoom out',
    this.resetBearingTooltip = 'Reset bearing',
    this.resetBearingSemanticLabel = 'Reset bearing',
    this.bearingVisibleThresholdDegrees = 1.0,
    this.centerOnMeKey,
    this.centerOnMeTooltip = 'Center on me',
    this.createMarkerKey,
    this.createMarkerTooltip = 'Create marker here',
    this.createMarkerHighlighted = false,
    this.createMarkerIcon,
    this.createMarkerActiveTint,
    this.createMarkerActiveIconColor,
    this.gap,
    this.buttonSize,
    this.desktopToolbarPadding,
    this.desktopToolbarRadius,
  });

  final KubusMapController controller;
  final KubusMapPrimaryControlsLayout layout;

  /// Called when the user taps the center-on-me button.
  ///
  /// Screen should decide whether to enable auto-follow and whether to animate
  /// to the user's current location.
  final VoidCallback onCenterOnMe;

  /// Called when the user taps the create-marker button.
  ///
  /// Screen owns the full creation flow (dialogs, permissions, AR upload, etc.).
  final VoidCallback onCreateMarker;

  /// Whether the center-on-me button should show an "active" state.
  ///
  /// (Maps to `_autoFollow` on mobile/desktop screens.)
  final bool centerOnMeActive;

  /// Accent used for active states on desktop (defaults to theme primary).
  ///
  /// Desktop map uses `ThemeProvider.accentColor` to match the selected accent.
  final Color? accentColor;

  // --- Nearby list (desktop only today) ---

  /// Whether to show the "nearby" toggle button.
  ///
  /// Desktop map uses this to open/close the functions sidebar panel.
  final bool showNearbyToggle;
  final bool nearbyActive;
  final VoidCallback? onToggleNearby;
  final Key? nearbyKey;
  final String? nearbyTooltip;
  final String? nearbyTooltipWhenActive;
  final String? nearbyTooltipWhenInactive;
  final IconData nearbyIcon;

  // --- Isometric view ---

  final bool showIsometricViewToggle;
  final bool isometricViewActive;
  final VoidCallback? onToggleIsometricView;
  final String? isometricViewTooltip;
  final String? isometricViewTooltipWhenActive;
  final String? isometricViewTooltipWhenInactive;

  /// Touch layouts can hide dedicated zoom controls in favour of pinch zoom
  /// while retaining them inside a progressively disclosed tools surface.
  final bool showZoomControls;

  /// Compact entry point for secondary controls on touch layouts.
  final bool showSecondaryTools;
  final VoidCallback? onOpenSecondaryTools;
  final Key? secondaryToolsKey;
  final String secondaryToolsTooltip;

  // --- Zoom ---

  final double zoomMin;
  final double zoomMax;
  final double zoomStep;
  final String zoomInTooltip;
  final String zoomOutTooltip;

  // --- Compass / bearing reset ---

  final String resetBearingTooltip;
  final String resetBearingSemanticLabel;
  final double bearingVisibleThresholdDegrees;

  // --- Center on me ---

  final Key? centerOnMeKey;
  final String centerOnMeTooltip;

  // --- Create marker ---

  final Key? createMarkerKey;
  final String createMarkerTooltip;
  final bool createMarkerHighlighted;
  final IconData? createMarkerIcon;
  final Color? createMarkerActiveTint;
  final Color? createMarkerActiveIconColor;

  // --- Layout tokens ---

  /// Gap between buttons (mobile) or between groups (desktop).
  ///
  /// If null, uses the screen-matching defaults.
  final double? gap;

  /// Square button size.
  ///
  /// If null, uses 44 (mobile) and 42 (desktop) to match existing visuals.
  final double? buttonSize;

  /// Outer padding used by [KubusMapPrimaryControlsLayout.desktopToolbar] around the control row.
  final EdgeInsets? desktopToolbarPadding;

  /// Outer radius used by [KubusMapPrimaryControlsLayout.desktopToolbar].
  final double? desktopToolbarRadius;

  @override
  Widget build(BuildContext context) {
    switch (layout) {
      case KubusMapPrimaryControlsLayout.mobileRightRail:
        return _buildMobileRightRail(context);
      case KubusMapPrimaryControlsLayout.desktopToolbar:
        return _buildDesktopToolbar(context);
    }
  }

  Widget _buildMobileRightRail(BuildContext context) {
    final resolvedButtonSize = buttonSize ?? KubusHeaderMetrics.actionHitArea;
    final hasModeControls =
        showIsometricViewToggle && onToggleIsometricView != null;
    // One flat cluster: buttons are separated by hairlines, not by gaps.
    Widget rule() => KubusMapChromeRule(
          axis: Axis.horizontal,
          length: resolvedButtonSize - KubusSpacing.sm,
        );

    final children = <Widget>[];

    children.add(
      ValueListenableBuilder<double>(
        valueListenable: controller.bearingDegrees,
        builder: (context, bearing, _) {
          if (bearing.abs() <= bearingVisibleThresholdDegrees) {
            return const SizedBox.shrink();
          }
          return Column(
            children: [
              Semantics(
                label: resetBearingSemanticLabel,
                button: true,
                child: _KubusSquareControlButton.mobile(
                  size: resolvedButtonSize,
                  icon: Icons.explore,
                  tooltip: resetBearingTooltip,
                  onTap: () => unawaited(controller.resetBearing()),
                ),
              ),
              rule(),
            ],
          );
        },
      ),
    );

    if (hasModeControls) {
      children.add(
        MapViewModeControls(
          density: MapViewModeControlsDensity.mobileRail,
          showIsometricViewToggle: showIsometricViewToggle,
          isometricViewActive: isometricViewActive,
          onToggleIsometricView: onToggleIsometricView,
          isometricViewIcon: Icons.filter_tilt_shift,
          isometricViewTooltip: _resolveTooltip(
            active: isometricViewActive,
            fallback: isometricViewTooltip,
            whenActive: isometricViewTooltipWhenActive,
            whenInactive: isometricViewTooltipWhenInactive,
          ),
          gap: 0,
          buttonBuilder: (context, spec) {
            final button = _KubusSquareControlButton.mobile(
              size: resolvedButtonSize,
              icon: spec.icon,
              tooltip: spec.tooltip,
              onTap: spec.onPressed,
              active: spec.active,
            );
            final semanticButton = Semantics(
              label: spec.tooltip,
              button: true,
              selected: spec.active,
              child: button,
            );
            if (spec.controlKey == null) return semanticButton;
            return KeyedSubtree(key: spec.controlKey, child: semanticButton);
          },
        ),
      );
      children.add(rule());
    }

    if (showZoomControls) {
      children.add(
        Semantics(
          label: zoomInTooltip,
          button: true,
          child: _KubusSquareControlButton.mobile(
            size: resolvedButtonSize,
            icon: Icons.add,
            tooltip: zoomInTooltip,
            onTap: () => unawaited(_zoomBy(delta: zoomStep)),
          ),
        ),
      );
      children.add(rule());

      children.add(
        Semantics(
          label: zoomOutTooltip,
          button: true,
          child: _KubusSquareControlButton.mobile(
            size: resolvedButtonSize,
            icon: Icons.remove,
            tooltip: zoomOutTooltip,
            onTap: () => unawaited(_zoomBy(delta: -zoomStep)),
          ),
        ),
      );
      children.add(rule());
    }

    if (showSecondaryTools && onOpenSecondaryTools != null) {
      children.add(
        Semantics(
          label: secondaryToolsTooltip,
          button: true,
          child: KeyedSubtree(
            key: secondaryToolsKey,
            child: _KubusSquareControlButton.mobile(
              size: resolvedButtonSize,
              icon: Icons.tune,
              tooltip: secondaryToolsTooltip,
              onTap: onOpenSecondaryTools,
            ),
          ),
        ),
      );
      children.add(rule());
    }

    children.add(
      Semantics(
        label: centerOnMeTooltip,
        button: true,
        selected: centerOnMeActive,
        child: KeyedSubtree(
          key: centerOnMeKey,
          child: _KubusSquareControlButton.mobile(
            size: resolvedButtonSize,
            icon: Icons.my_location,
            tooltip: centerOnMeTooltip,
            onTap: onCenterOnMe,
            active: centerOnMeActive,
          ),
        ),
      ),
    );
    children.add(rule());

    children.add(
      Semantics(
        label: createMarkerTooltip,
        button: true,
        selected: createMarkerHighlighted,
        child: KeyedSubtree(
          key: createMarkerKey,
          child: _KubusSquareControlButton.mobile(
            size: resolvedButtonSize,
            icon: createMarkerIcon ?? Icons.add_location_alt,
            tooltip: createMarkerTooltip,
            onTap: onCreateMarker,
            // Visual parity with the desktop toolbar's
            // `createMarkerHighlighted` state.
            active: createMarkerHighlighted,
            activeTint: createMarkerActiveTint,
            activeIconColor: createMarkerActiveIconColor,
          ),
        ),
      ),
    );

    return buildKubusMapChromeSurface(
      context: context,
      borderRadius: BorderRadius.circular(KubusRadius.surface),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildDesktopToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final resolvedButtonSize = buttonSize ?? KubusHeaderMetrics.actionHitArea;
    final resolvedPadding = desktopToolbarPadding ??
        const EdgeInsets.symmetric(
          horizontal: KubusSpacing.sm,
          vertical: KubusSpacing.xs + KubusSpacing.xxs,
        );
    final resolvedRadius = desktopToolbarRadius ?? KubusRadius.md;

    final accent = accentColor ?? scheme.primary;
    final hasModeControls =
        showIsometricViewToggle && onToggleIsometricView != null;

    Widget buildDivider() {
      return KubusMapChromeRule(length: KubusSpacing.lg + KubusSpacing.xxs);
    }

    final rowChildren = <Widget>[];

    if (hasModeControls) {
      rowChildren.add(
        MapViewModeControls(
          density: MapViewModeControlsDensity.desktopToolbar,
          showIsometricViewToggle: showIsometricViewToggle,
          isometricViewActive: isometricViewActive,
          onToggleIsometricView: onToggleIsometricView,
          isometricViewIcon: Icons.filter_tilt_shift,
          isometricViewTooltip: _resolveTooltip(
            active: isometricViewActive,
            fallback: isometricViewTooltip,
            whenActive: isometricViewTooltipWhenActive,
            whenInactive: isometricViewTooltipWhenInactive,
          ),
          appendTrailingSeparator: true,
          separatorBuilder: (context) => buildDivider(),
          buttonBuilder: (context, spec) {
            final button = _KubusSquareControlButton.desktop(
              size: resolvedButtonSize,
              accent: accent,
              icon: spec.icon,
              tooltip: spec.tooltip,
              onTap: spec.onPressed,
              active: spec.active,
            );
            final semanticButton = Semantics(
              label: spec.tooltip,
              button: true,
              selected: spec.active,
              child: button,
            );
            if (spec.controlKey == null) return semanticButton;
            return KeyedSubtree(key: spec.controlKey, child: semanticButton);
          },
        ),
      );
    }

    if (showNearbyToggle && onToggleNearby != null) {
      final tooltip = _resolveTooltip(
        active: nearbyActive,
        fallback: nearbyTooltip,
        whenActive: nearbyTooltipWhenActive,
        whenInactive: nearbyTooltipWhenInactive,
      );

      final idleTint = scheme.surface.withValues(alpha: isDark ? 0.16 : 0.12);

      rowChildren.add(
        Semantics(
          label: tooltip,
          button: true,
          selected: nearbyActive,
          child: KeyedSubtree(
            key: nearbyKey,
            child: _KubusSquareControlButton.desktop(
              size: resolvedButtonSize,
              accent: accent,
              icon: nearbyIcon,
              tooltip: tooltip,
              onTap: onToggleNearby,
              active: nearbyActive,
              // Keep the button background visually stable; the active state is
              // primarily communicated via the icon accent.
              activeTint: idleTint,
              activeIconColor: accent,
            ),
          ),
        ),
      );
      rowChildren.add(buildDivider());
    }

    rowChildren.add(
      Semantics(
        label: zoomOutTooltip,
        button: true,
        child: _KubusSquareControlButton.desktop(
          size: resolvedButtonSize,
          accent: accent,
          icon: Icons.remove,
          tooltip: zoomOutTooltip,
          onTap: () => unawaited(_zoomBy(delta: -zoomStep)),
        ),
      ),
    );

    rowChildren.add(
      Semantics(
        label: zoomInTooltip,
        button: true,
        child: _KubusSquareControlButton.desktop(
          size: resolvedButtonSize,
          accent: accent,
          icon: Icons.add,
          tooltip: zoomInTooltip,
          onTap: () => unawaited(_zoomBy(delta: zoomStep)),
        ),
      ),
    );

    rowChildren.add(
      ValueListenableBuilder<double>(
        valueListenable: controller.bearingDegrees,
        builder: (context, bearing, _) {
          if (bearing.abs() <= bearingVisibleThresholdDegrees) {
            return const SizedBox.shrink();
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildDivider(),
              Semantics(
                label: resetBearingSemanticLabel,
                button: true,
                child: _KubusSquareControlButton.desktop(
                  size: resolvedButtonSize,
                  accent: accent,
                  icon: Icons.explore,
                  tooltip: resetBearingTooltip,
                  onTap: () => unawaited(controller.resetBearing()),
                ),
              ),
            ],
          );
        },
      ),
    );

    rowChildren.add(buildDivider());

    rowChildren.add(
      Semantics(
        label: createMarkerTooltip,
        button: true,
        selected: createMarkerHighlighted,
        child: KeyedSubtree(
          key: createMarkerKey,
          child: _KubusSquareControlButton.desktop(
            size: resolvedButtonSize,
            accent: accent,
            icon: createMarkerIcon ?? Icons.add_location_alt_outlined,
            tooltip: createMarkerTooltip,
            onTap: onCreateMarker,
            active: createMarkerHighlighted,
            activeTint: createMarkerActiveTint ??
                accent.withValues(alpha: isDark ? 0.24 : 0.20),
            activeIconColor: createMarkerActiveIconColor ??
                AppColorUtils.contrastText(accent),
          ),
        ),
      ),
    );

    rowChildren.add(buildDivider());

    rowChildren.add(
      Semantics(
        label: centerOnMeTooltip,
        button: true,
        selected: centerOnMeActive,
        child: KeyedSubtree(
          key: centerOnMeKey,
          child: _KubusSquareControlButton.desktop(
            size: resolvedButtonSize,
            accent: accent,
            icon: Icons.my_location,
            tooltip: centerOnMeTooltip,
            onTap: onCenterOnMe,
            active: centerOnMeActive,
            activeIconColor: AppColorUtils.contrastText(accent),
          ),
        ),
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: buildKubusMapChromeSurface(
        context: context,
        borderRadius: BorderRadius.circular(resolvedRadius),
        padding: resolvedPadding,
        child: Row(mainAxisSize: MainAxisSize.min, children: rowChildren),
      ),
    );
  }

  Future<void> _zoomBy({required double delta}) async {
    final camera = controller.camera;
    final nextZoom = (camera.zoom + delta).clamp(zoomMin, zoomMax).toDouble();
    await controller.animateTo(camera.center, zoom: nextZoom);
  }

  String _resolveTooltip({
    required bool active,
    required String? fallback,
    required String? whenActive,
    required String? whenInactive,
  }) {
    final resolved = active ? whenActive : whenInactive;
    return resolved ?? fallback ?? '';
  }
}

class _KubusSquareControlButton extends StatelessWidget {
  const _KubusSquareControlButton.mobile({
    required this.size,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
    this.activeTint,
    this.activeIconColor,
  }) : accent = null;

  const _KubusSquareControlButton.desktop({
    required this.size,
    required this.accent,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
    this.activeTint,
    this.activeIconColor,
  });

  final double size;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  final Color? accent;

  /// Kept for call-site compatibility. The chrome selected state always uses
  /// the accent at one low strength, so a custom fill is not drawn.
  final Color? activeTint;
  final Color? activeIconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedAccent = accent ?? scheme.primary;
    // Flat chrome button: no border, shadow or glass of its own. The selected
    // state is the only accent use; hover and focus stay neutral.
    return KubusMapChromeIconButton(
      icon: icon,
      onPressed: onTap,
      tooltip: tooltip,
      size: size,
      active: active,
      accentColor: resolvedAccent,
      iconColor: scheme.onSurface,
      activeIconColor: activeIconColor,
    );
  }
}
