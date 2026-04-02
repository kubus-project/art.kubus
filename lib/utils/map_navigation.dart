import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
import '../screens/map_screen.dart';
import '../screens/desktop/desktop_map_screen.dart';
import '../screens/desktop/desktop_shell.dart';

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
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final targetZoom = zoom ?? 16.0;

    if (isDesktop) {
      final shellScope = DesktopShellScope.of(context);
      if (shellScope != null) {
        final l10n = AppLocalizations.of(context);
        shellScope.navigateToRoute('/explore');
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
              ),
      ),
    );
  }
}
