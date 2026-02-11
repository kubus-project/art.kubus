import 'dart:async';

import 'package:flutter/material.dart';

import '../../../features/map/controller/kubus_map_controller.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/design_tokens.dart';
import '../../common/kubus_glass_icon_button.dart';
import '../../glass_components.dart';
import 'map_view_mode_controls.dart';

/// Layout variants for [KubusMapPrimaryControls].
///
/// - [mobileRightRail] matches the vertical control stack used in `MapScreen`.
/// - [desktopToolbar] matches the horizontal glass toolbar used in
///   `DesktopMapScreen`.
enum KubusMapPrimaryControlsLayout {
	mobileRightRail,
	desktopToolbar,
}

/// Unified primary map controls used by both mobile + desktop map screens.
///
/// This widget is deliberately UI-only:
/// - It does not read providers or perform any side effects in `build()`.
/// - It integrates with [KubusMapController] for camera actions (zoom and
///   reset bearing), while leaving screen-owned flows (create marker, travel
///   mode, center-on-me) as callbacks.
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
		this.showTravelModeToggle = false,
		this.travelModeActive = false,
		this.onToggleTravelMode,
		this.travelModeKey,
		this.travelModeTooltip,
		this.travelModeTooltipWhenActive,
		this.travelModeTooltipWhenInactive,
		this.showIsometricViewToggle = false,
		this.isometricViewActive = false,
		this.onToggleIsometricView,
		this.isometricViewTooltip,
		this.isometricViewTooltipWhenActive,
		this.isometricViewTooltipWhenInactive,
		this.zoomMin = 3.0,
		this.zoomMax = 18.0,
		this.zoomStep = 1.0,
		this.zoomInTooltip = 'Zoom in',
		this.zoomOutTooltip = 'Zoom out',
		this.resetBearingTooltip = 'Reset bearing',
		this.resetBearingSemanticLabel = 'map_reset_bearing',
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

	// --- Travel mode ---

	final bool showTravelModeToggle;
	final bool travelModeActive;
	final VoidCallback? onToggleTravelMode;
	final Key? travelModeKey;
	final String? travelModeTooltip;
	final String? travelModeTooltipWhenActive;
	final String? travelModeTooltipWhenInactive;

	// --- Isometric view ---

	final bool showIsometricViewToggle;
	final bool isometricViewActive;
	final VoidCallback? onToggleIsometricView;
	final String? isometricViewTooltip;
	final String? isometricViewTooltipWhenActive;
	final String? isometricViewTooltipWhenInactive;

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
    final resolvedGap = gap ?? 10.0;
    final resolvedButtonSize = buttonSize ?? 44.0;
    final hasModeControls = (showTravelModeToggle && onToggleTravelMode != null) ||
        (showIsometricViewToggle && onToggleIsometricView != null);

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
							SizedBox(height: resolvedGap),
						],
					);
				},
      ),
    );

    if (hasModeControls) {
      children.add(
        MapViewModeControls(
          density: MapViewModeControlsDensity.mobileRail,
          showTravelModeToggle: showTravelModeToggle,
          travelModeActive: travelModeActive,
          onToggleTravelMode: onToggleTravelMode,
          showIsometricViewToggle: showIsometricViewToggle,
          isometricViewActive: isometricViewActive,
          onToggleIsometricView: onToggleIsometricView,
          travelModeIcon: Icons.travel_explore,
          isometricViewIcon: Icons.filter_tilt_shift,
          travelModeKey: travelModeKey,
          travelModeTooltip: _resolveTooltip(
            active: travelModeActive,
            fallback: travelModeTooltip,
            whenActive: travelModeTooltipWhenActive,
            whenInactive: travelModeTooltipWhenInactive,
          ),
          isometricViewTooltip: _resolveTooltip(
            active: isometricViewActive,
            fallback: isometricViewTooltip,
            whenActive: isometricViewTooltipWhenActive,
            whenInactive: isometricViewTooltipWhenInactive,
          ),
          gap: resolvedGap,
          buttonBuilder: (context, spec) {
            final button = _KubusSquareControlButton.mobile(
              size: resolvedButtonSize,
              icon: spec.icon,
              tooltip: spec.tooltip,
              onTap: spec.onPressed,
              active: spec.active,
            );
            if (spec.controlKey == null) return button;
            return KeyedSubtree(
              key: spec.controlKey,
              child: button,
            );
          },
        ),
      );
      children.add(
        SizedBox(height: resolvedGap),
      );
    }

    children.add(
      Semantics(
        label: 'map_zoom_in',
        button: true,
        child: _KubusSquareControlButton.mobile(
          size: resolvedButtonSize,
          icon: Icons.add,
          tooltip: zoomInTooltip,
          onTap: () => unawaited(_zoomBy(delta: zoomStep)),
        ),
      ),
    );
    children.add(
      SizedBox(height: resolvedGap),
    );

    children.add(
      Semantics(
        label: 'map_zoom_out',
        button: true,
        child: _KubusSquareControlButton.mobile(
          size: resolvedButtonSize,
          icon: Icons.remove,
          tooltip: zoomOutTooltip,
          onTap: () => unawaited(_zoomBy(delta: -zoomStep)),
        ),
      ),
    );
    children.add(
      SizedBox(height: resolvedGap),
    );

    children.add(
      KeyedSubtree(
        key: centerOnMeKey,
        child: _KubusSquareControlButton.mobile(
          size: resolvedButtonSize,
          icon: Icons.my_location,
          tooltip: centerOnMeTooltip,
          onTap: onCenterOnMe,
          active: centerOnMeActive,
        ),
      ),
    );
    children.add(
      SizedBox(height: resolvedGap),
    );

    children.add(
      Semantics(
        label: 'map_create_marker',
        button: true,
        child: KeyedSubtree(
          key: createMarkerKey,
          child: _KubusSquareControlButton.mobile(
            size: resolvedButtonSize,
            icon: createMarkerIcon ?? Icons.add_location_alt,
            tooltip: createMarkerTooltip,
            onTap: onCreateMarker,
          ),
        ),
      ),
    );

    return Column(children: children);
  }

	Widget _buildDesktopToolbar(BuildContext context) {
		final theme = Theme.of(context);
		final scheme = theme.colorScheme;
		final isDark = theme.brightness == Brightness.dark;

		final resolvedButtonSize = buttonSize ?? 42.0;
		final resolvedPadding = desktopToolbarPadding ??
				const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
    final resolvedRadius = desktopToolbarRadius ?? 14.0;

    final accent = accentColor ?? scheme.primary;
    final hasModeControls = (showTravelModeToggle && onToggleTravelMode != null) ||
        (showIsometricViewToggle && onToggleIsometricView != null);

    Widget buildDivider() {
      return Container(
        width: 1,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: scheme.outline.withValues(alpha: 0.22),
      );
    }

    final rowChildren = <Widget>[];

    if (hasModeControls) {
      rowChildren.add(
        MapViewModeControls(
          density: MapViewModeControlsDensity.desktopToolbar,
          showTravelModeToggle: showTravelModeToggle,
          travelModeActive: travelModeActive,
          onToggleTravelMode: onToggleTravelMode,
          showIsometricViewToggle: showIsometricViewToggle,
          isometricViewActive: isometricViewActive,
          onToggleIsometricView: onToggleIsometricView,
          travelModeIcon: Icons.travel_explore,
          isometricViewIcon: Icons.filter_tilt_shift,
          travelModeKey: travelModeKey,
          travelModeTooltip: _resolveTooltip(
            active: travelModeActive,
            fallback: travelModeTooltip,
            whenActive: travelModeTooltipWhenActive,
            whenInactive: travelModeTooltipWhenInactive,
          ),
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
            if (spec.controlKey == null) return button;
            return KeyedSubtree(
              key: spec.controlKey,
              child: button,
            );
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
        KeyedSubtree(
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
      );
      rowChildren.add(buildDivider());
    }

		rowChildren.add(
			Semantics(
				label: 'map_zoom_out',
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
				label: 'map_zoom_in',
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
				label: 'map_create_marker',
				button: true,
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

		rowChildren.add(const SizedBox(width: 6));

		rowChildren.add(
			KeyedSubtree(
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
		);

		return MouseRegion(
			cursor: SystemMouseCursors.basic,
			child: LiquidGlassPanel(
				padding: resolvedPadding,
				margin: EdgeInsets.zero,
				borderRadius: BorderRadius.circular(resolvedRadius),
				blurSigma: KubusGlassEffects.blurSigmaLight,
				backgroundColor: scheme.surface.withValues(alpha: isDark ? 0.18 : 0.14),
				showBorder: true,
				child: Row(
					mainAxisSize: MainAxisSize.min,
					children: rowChildren,
				),
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
	})  : accent = null,
				activeTint = null,
				activeIconColor = null,
				_variant = _KubusSquareControlVariant.mobile;

	const _KubusSquareControlButton.desktop({
		required this.size,
		required this.accent,
		required this.icon,
		required this.tooltip,
		this.onTap,
		this.active = false,
		this.activeTint,
		this.activeIconColor,
	}) : _variant = _KubusSquareControlVariant.desktop;

	final _KubusSquareControlVariant _variant;

	final double size;
	final IconData icon;
	final String tooltip;
	final VoidCallback? onTap;
	final bool active;

	// Desktop styling.
	final Color? accent;
	final Color? activeTint;
	final Color? activeIconColor;

	@override
	Widget build(BuildContext context) {
		final animationTheme = context.animationTheme;
		final theme = Theme.of(context);
		final scheme = theme.colorScheme;
		final isDark = theme.brightness == Brightness.dark;

		final radius = BorderRadius.circular(KubusRadius.md);

		final resolvedOnTap = onTap;
		final bool enabled = resolvedOnTap != null;

		switch (_variant) {
			case _KubusSquareControlVariant.mobile:
				final mobileAccent = scheme.primary;
				final mobileActiveIconColor =
						ThemeData.estimateBrightnessForColor(mobileAccent) == Brightness.dark
								? KubusColors.textPrimaryDark
								: KubusColors.textPrimaryLight;
				return KubusGlassIconButton(
					icon: icon,
					onPressed: resolvedOnTap,
					tooltip: tooltip,
					size: size,
					active: active,
					accentColor: mobileAccent,
					iconColor: scheme.onSurface,
					activeIconColor: mobileActiveIconColor,
					activeTint: mobileAccent.withValues(alpha: 0.20),
				);

			case _KubusSquareControlVariant.desktop:
				final resolvedAccent = accent ?? scheme.primary;
				final idleTint = scheme.surface.withValues(alpha: isDark ? 0.16 : 0.12);
				final selectedTint = activeTint ??
						resolvedAccent.withValues(alpha: isDark ? 0.14 : 0.16);

				final iconCol = active
						? (activeIconColor ?? resolvedAccent)
						: scheme.onSurface;

				final child = SizedBox(
					width: size,
					height: size,
					child: Center(
						child: Icon(icon, size: 20, color: iconCol),
					),
				);

				final decoration = BoxDecoration(
					borderRadius: radius,
					border: Border.all(
						color: active
								? resolvedAccent.withValues(alpha: 0.85)
								: scheme.outline.withValues(alpha: 0.18),
						width: active ? 1.25 : 1,
					),
					boxShadow: active
							? [
									BoxShadow(
										color: resolvedAccent.withValues(alpha: 0.12),
										blurRadius: 12,
										offset: const Offset(0, 4),
									),
								]
							: null,
				);

				// Requirement: pointer cursor on desktop.
				return MouseRegion(
					cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
					child: AnimatedContainer(
						duration: animationTheme.short,
						curve: animationTheme.defaultCurve,
						decoration: decoration,
						child: LiquidGlassPanel(
							padding: EdgeInsets.zero,
							margin: EdgeInsets.zero,
							borderRadius: radius,
							blurSigma: KubusGlassEffects.blurSigmaLight,
							showBorder: false,
							backgroundColor: active ? selectedTint : idleTint,
							onTap: resolvedOnTap,
							child: tooltip.isEmpty
									? child
									: Tooltip(message: tooltip, child: child),
						),
					),
				);
		}
	}
}

enum _KubusSquareControlVariant { mobile, desktop }
