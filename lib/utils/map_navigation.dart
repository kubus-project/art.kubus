import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../screens/map_screen.dart';
import '../screens/desktop/desktop_map_screen.dart';

class MapNavigation {
  static void open(
    BuildContext context, {
    required LatLng center,
    double? zoom,
    bool autoFollow = false,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final targetZoom = zoom ?? 16.0;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isDesktop
            ? DesktopMapScreen(
                initialCenter: center,
                initialZoom: targetZoom,
                autoFollow: autoFollow,
              )
            : MapScreen(
                initialCenter: center,
                initialZoom: targetZoom,
                autoFollow: autoFollow,
              ),
      ),
    );
  }
}
