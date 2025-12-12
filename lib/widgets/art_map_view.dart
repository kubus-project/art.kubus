import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../providers/tile_providers.dart';

/// Shared FlutterMap layer used by both mobile and desktop map screens.
class ArtMapView extends StatelessWidget {
  const ArtMapView({
    super.key,
    required this.mapController,
    required this.initialCenter,
    required this.initialZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.isDarkMode,
    required this.isRetina,
    required this.markers,
    this.tileProviders,
    this.onPositionChanged,
    this.onTap,
    this.onLongPress,
    this.onMapReady,
    this.interactionOptions,
  });

  final MapController mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;
  final bool isDarkMode;
  final bool isRetina;
  final TileProviders? tileProviders;
  final List<Marker> markers;
  final void Function(MapCamera, bool)? onPositionChanged;
  final void Function(TapPosition, LatLng)? onTap;
  final void Function(TapPosition, LatLng)? onLongPress;
  final VoidCallback? onMapReady;
  final InteractionOptions? interactionOptions;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      key: ValueKey('${isDarkMode ? 'dark' : 'light'}-${isRetina ? 'retina' : 'std'}'),
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: minZoom,
        maxZoom: maxZoom,
        onMapReady: onMapReady,
        onPositionChanged: onPositionChanged,
        onTap: onTap,
        onLongPress: onLongPress,
        interactionOptions: interactionOptions ?? const InteractionOptions(),
      ),
      children: [
        if (tileProviders != null)
          (isRetina
              ? tileProviders!.getTileLayer()
              : tileProviders!.getNonRetinaTileLayer())
        else
          TileLayer(
            urlTemplate: isDarkMode
                ? 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png'
                : 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.art.kubus',
          ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}
