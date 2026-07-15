import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/config.dart';
import '../features/map/navigation/walking_navigation_models.dart';
import '../l10n/app_localizations.dart';
import '../screens/map_screen.dart';
import '../screens/desktop/desktop_map_screen.dart';
import '../screens/desktop/desktop_shell.dart';
import '../providers/walking_navigation_provider.dart';

class MapNavigation {
  static void open(
    BuildContext context, {
    required LatLng center,
    double? zoom,
    bool autoFollow = false,
    String? initialMarkerId,
    String? initialArtworkId,
    String? initialSubjectId,
    String? initialSubjectType,
    String? initialTargetLabel,
    bool preserveDesktopBackStack = false,
    WalkingNavigationIntent? walkingNavigationIntent,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final targetZoom = zoom ?? 16.0;

    if (isDesktop) {
      final shellScope = DesktopShellScope.of(context);
      if (shellScope != null) {
        final l10n = AppLocalizations.of(context);
        if (!preserveDesktopBackStack) {
          shellScope.navigateToRoute('/explore');
        }
        shellScope.pushScreen(
          DesktopSubScreen(
            title: l10n?.navigationScreenExploreMap ?? 'Explore Map',
            child: DesktopMapScreen(
              initialCenter: center,
              initialZoom: targetZoom,
              autoFollow: autoFollow,
              initialMarkerId: initialMarkerId,
              initialArtworkId: initialArtworkId,
              initialSubjectId: initialSubjectId,
              initialSubjectType: initialSubjectType,
              initialTargetLabel: initialTargetLabel,
              walkingNavigationIntent: walkingNavigationIntent,
            ),
          ),
        );
        return;
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isDesktop
            ? DesktopMapScreen(
                initialCenter: center,
                initialZoom: targetZoom,
                autoFollow: autoFollow,
                initialMarkerId: initialMarkerId,
                initialArtworkId: initialArtworkId,
                initialSubjectId: initialSubjectId,
                initialSubjectType: initialSubjectType,
                initialTargetLabel: initialTargetLabel,
                walkingNavigationIntent: walkingNavigationIntent,
              )
            : MapScreen(
                initialCenter: center,
                initialZoom: targetZoom,
                autoFollow: autoFollow,
                initialMarkerId: initialMarkerId,
                initialArtworkId: initialArtworkId,
                initialSubjectId: initialSubjectId,
                initialSubjectType: initialSubjectType,
                initialTargetLabel: initialTargetLabel,
                walkingNavigationIntent: walkingNavigationIntent,
              ),
      ),
    );
  }

  static void openWalking(
    BuildContext context, {
    required WalkingNavigationIntent intent,
  }) {
    if (!AppConfig.isFeatureEnabled('mapWalkingNavigation')) return;
    context.read<WalkingNavigationProvider>().start(intent);
    open(
      context,
      center: intent.destination,
      zoom: 17,
      autoFollow: true,
      initialArtworkId: intent.destinationId,
      initialTargetLabel: intent.destinationLabel,
      preserveDesktopBackStack: true,
      walkingNavigationIntent: intent,
    );
  }
}
