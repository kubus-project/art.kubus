import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/config.dart';
import '../features/map/navigation/walking_navigation_models.dart';
import '../l10n/app_localizations.dart';
import '../screens/map_screen.dart';
import '../screens/desktop/desktop_map_screen.dart';
import '../screens/desktop/desktop_shell.dart';

class MapNavigation {
  static Uri externalWalkingUri(WalkingNavigationIntent intent) => Uri.https(
        'www.google.com',
        '/maps/dir/',
        <String, String>{
          'api': '1',
          'destination':
              '${intent.destination.latitude},${intent.destination.longitude}',
          'travelmode': 'walking',
        },
      );

  static Future<bool> openExternalWalking(
    WalkingNavigationIntent intent, {
    Future<bool> Function(Uri uri)? launcher,
  }) {
    final uri = externalWalkingUri(intent);
    return (launcher ??
        (uri) => launchUrl(uri, mode: LaunchMode.externalApplication))(uri);
  }

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
    open(
      context,
      center: intent.destination,
      zoom: 17,
      autoFollow: true,
      preserveDesktopBackStack: true,
      walkingNavigationIntent: intent,
    );
  }
}
