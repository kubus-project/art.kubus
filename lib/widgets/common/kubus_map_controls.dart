import 'package:flutter/material.dart';

import '../../features/map/controller/kubus_map_controller.dart';
import '../map/controls/kubus_map_primary_controls.dart';

/// Thin shared wrapper around [KubusMapPrimaryControls].
///
/// Keeps map screens aligned on a single control entry point while preserving
/// all current behavior from the existing controls widget.
class KubusMapControls extends StatelessWidget {
  const KubusMapControls({
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
    this.isometricViewTooltipWhenActive,
    this.isometricViewTooltipWhenInactive,
    this.zoomInTooltip = 'Zoom in',
    this.zoomOutTooltip = 'Zoom out',
    this.resetBearingTooltip = 'Reset bearing',
    this.centerOnMeKey,
    this.centerOnMeTooltip = 'Center on me',
    this.createMarkerKey,
    this.createMarkerTooltip = 'Create marker here',
    this.createMarkerHighlighted = false,
  });

  final KubusMapController controller;
  final KubusMapPrimaryControlsLayout layout;
  final VoidCallback onCenterOnMe;
  final VoidCallback onCreateMarker;
  final bool centerOnMeActive;

  final Color? accentColor;

  final bool showNearbyToggle;
  final bool nearbyActive;
  final VoidCallback? onToggleNearby;
  final Key? nearbyKey;
  final String? nearbyTooltip;
  final String? nearbyTooltipWhenActive;
  final String? nearbyTooltipWhenInactive;

  final bool showTravelModeToggle;
  final bool travelModeActive;
  final VoidCallback? onToggleTravelMode;
  final Key? travelModeKey;
  final String? travelModeTooltip;
  final String? travelModeTooltipWhenActive;
  final String? travelModeTooltipWhenInactive;

  final bool showIsometricViewToggle;
  final bool isometricViewActive;
  final VoidCallback? onToggleIsometricView;
  final String? isometricViewTooltipWhenActive;
  final String? isometricViewTooltipWhenInactive;

  final String zoomInTooltip;
  final String zoomOutTooltip;
  final String resetBearingTooltip;

  final Key? centerOnMeKey;
  final String centerOnMeTooltip;

  final Key? createMarkerKey;
  final String createMarkerTooltip;
  final bool createMarkerHighlighted;

  @override
  Widget build(BuildContext context) {
    return KubusMapPrimaryControls(
      controller: controller,
      layout: layout,
      onCenterOnMe: onCenterOnMe,
      onCreateMarker: onCreateMarker,
      centerOnMeActive: centerOnMeActive,
      accentColor: accentColor,
      showNearbyToggle: showNearbyToggle,
      nearbyActive: nearbyActive,
      onToggleNearby: onToggleNearby,
      nearbyKey: nearbyKey,
      nearbyTooltip: nearbyTooltip,
      nearbyTooltipWhenActive: nearbyTooltipWhenActive,
      nearbyTooltipWhenInactive: nearbyTooltipWhenInactive,
      showTravelModeToggle: showTravelModeToggle,
      travelModeActive: travelModeActive,
      onToggleTravelMode: onToggleTravelMode,
      travelModeKey: travelModeKey,
      travelModeTooltip: travelModeTooltip,
      travelModeTooltipWhenActive: travelModeTooltipWhenActive,
      travelModeTooltipWhenInactive: travelModeTooltipWhenInactive,
      showIsometricViewToggle: showIsometricViewToggle,
      isometricViewActive: isometricViewActive,
      onToggleIsometricView: onToggleIsometricView,
      isometricViewTooltipWhenActive: isometricViewTooltipWhenActive,
      isometricViewTooltipWhenInactive: isometricViewTooltipWhenInactive,
      zoomInTooltip: zoomInTooltip,
      zoomOutTooltip: zoomOutTooltip,
      resetBearingTooltip: resetBearingTooltip,
      centerOnMeKey: centerOnMeKey,
      centerOnMeTooltip: centerOnMeTooltip,
      createMarkerKey: createMarkerKey,
      createMarkerTooltip: createMarkerTooltip,
      createMarkerHighlighted: createMarkerHighlighted,
    );
  }
}
