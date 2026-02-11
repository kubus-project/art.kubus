import 'package:flutter/material.dart';

enum MapViewModeControlsDensity {
  mobileRail,
  desktopToolbar,
}

@immutable
class MapViewModeControlSpec {
  const MapViewModeControlSpec({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
    this.controlKey,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback? onPressed;
  final Key? controlKey;
}

typedef MapViewModeControlButtonBuilder = Widget Function(
  BuildContext context,
  MapViewModeControlSpec spec,
);

typedef MapViewModeControlsSeparatorBuilder = Widget Function(
  BuildContext context,
);

/// Shared travel/isometric map mode controls used by mobile + desktop layouts.
///
/// This widget is UI-only; screens/controllers own side effects.
class MapViewModeControls extends StatelessWidget {
  const MapViewModeControls({
    super.key,
    required this.density,
    required this.showTravelModeToggle,
    required this.travelModeActive,
    required this.onToggleTravelMode,
    required this.showIsometricViewToggle,
    required this.isometricViewActive,
    required this.onToggleIsometricView,
    required this.travelModeIcon,
    required this.isometricViewIcon,
    required this.travelModeTooltip,
    required this.isometricViewTooltip,
    this.travelModeKey,
    this.buttonBuilder,
    this.separatorBuilder,
    this.gap = 10.0,
    this.appendTrailingSeparator = false,
  });

  final MapViewModeControlsDensity density;

  final bool showTravelModeToggle;
  final bool travelModeActive;
  final VoidCallback? onToggleTravelMode;
  final IconData travelModeIcon;
  final String travelModeTooltip;
  final Key? travelModeKey;

  final bool showIsometricViewToggle;
  final bool isometricViewActive;
  final VoidCallback? onToggleIsometricView;
  final IconData isometricViewIcon;
  final String isometricViewTooltip;

  final MapViewModeControlButtonBuilder? buttonBuilder;
  final MapViewModeControlsSeparatorBuilder? separatorBuilder;
  final double gap;
  final bool appendTrailingSeparator;

  @override
  Widget build(BuildContext context) {
    final specs = _buildSpecs();
    if (specs.isEmpty) return const SizedBox.shrink();

    switch (density) {
      case MapViewModeControlsDensity.mobileRail:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < specs.length; i++) ...[
              _buildButton(context, specs[i]),
              if (i < specs.length - 1) SizedBox(height: gap),
            ],
          ],
        );
      case MapViewModeControlsDensity.desktopToolbar:
        final separator = separatorBuilder;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < specs.length; i++) ...[
              _buildButton(context, specs[i]),
              if (separator != null &&
                  (i < specs.length - 1 ||
                      (appendTrailingSeparator && specs.isNotEmpty)))
                separator(context),
            ],
          ],
        );
    }
  }

  List<MapViewModeControlSpec> _buildSpecs() {
    final specs = <MapViewModeControlSpec>[];
    if (showTravelModeToggle && onToggleTravelMode != null) {
      specs.add(
        MapViewModeControlSpec(
          icon: travelModeIcon,
          tooltip: travelModeTooltip,
          active: travelModeActive,
          onPressed: onToggleTravelMode,
          controlKey: travelModeKey,
        ),
      );
    }
    if (showIsometricViewToggle && onToggleIsometricView != null) {
      specs.add(
        MapViewModeControlSpec(
          icon: isometricViewIcon,
          tooltip: isometricViewTooltip,
          active: isometricViewActive,
          onPressed: onToggleIsometricView,
        ),
      );
    }
    return specs;
  }

  Widget _buildButton(BuildContext context, MapViewModeControlSpec spec) {
    final builder = buttonBuilder;
    if (builder != null) {
      return builder(context, spec);
    }

    final child = IconButton(
      tooltip: spec.tooltip,
      onPressed: spec.onPressed,
      icon: Icon(spec.icon),
      color: spec.active ? Theme.of(context).colorScheme.primary : null,
    );
    if (spec.controlKey == null) return child;
    return KeyedSubtree(
      key: spec.controlKey,
      child: child,
    );
  }
}
