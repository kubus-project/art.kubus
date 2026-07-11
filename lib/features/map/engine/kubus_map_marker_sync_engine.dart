import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../../config/config.dart';
import '../../../models/art_marker.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/map_performance_debug.dart';
import '../shared/map_screen_shared_helpers.dart';
import '../../../widgets/map/kubus_map_marker_features.dart';
import '../../../widgets/map/kubus_map_marker_geojson_builder.dart';
import '../../../widgets/map/kubus_map_marker_rendering.dart';
import '../controller/kubus_map_controller.dart';

/// What the marker sync engine needs from its hosting map screen `State`.
///
/// Both `MapScreen` and `DesktopMapScreen` implement this; the engine owns
/// the (previously duplicated) marker sync orchestration. Behavioral
/// divergences between the two screens are deliberate host choices —
/// notably [sortClustersBySizeDesc] (mobile `true`, desktop `false`).
abstract class KubusMapMarkerSyncHost {
  ml.MapLibreMapController? get mapController;
  bool get styleInitialized;

  /// Whether the hosting `State` is still mounted.
  bool get hostMounted;

  /// Context used to resolve theme/scheme/roles at sync time.
  BuildContext get hostContext;

  Set<String> get managedSourceIds;
  String get markerSourceId;
  KubusMapController get kubusMapController;
  Set<String> get registeredMapImages;

  /// Zoom the sync pipeline should cluster against (screens track this in
  /// different fields: `_lastZoom` on mobile, `_cameraZoom` on desktop).
  double get syncZoom;

  double get clusterMaxZoom;
  bool get sortClustersBySizeDesc;

  /// Label used in debug logging / perf timelines ('MapScreen', ...).
  String get debugLabel;

  int clusterGridLevelForZoom(double zoom);
  double markerPixelRatio();
  Color resolveArtMarkerBaseColor(ArtMarker marker, ThemeProvider themeProvider);

  /// Called after each successful GeoJSON source write (debug counters).
  void onMarkerSourceWrite();

  /// Called after the 2D marker sync completes (3D cube sync, pending
  /// marker refresh, ...). May be a no-op.
  Future<void> afterMarkerSync(ThemeProvider themeProvider);
}

/// Shared marker sync orchestration for the mobile and desktop map screens.
///
/// Ported behavior-preserving from the duplicated `_syncMapMarkers*` /
/// `_preregisterMarkerIcons` / `_markerFeatureFor` / `_clusterFeatureFor`
/// method families (see docs/superpowers/specs/2026-07-11-map-marker-engine-design.md).
class KubusMapMarkerSyncEngine {
  KubusMapMarkerSyncEngine(this.host);

  final KubusMapMarkerSyncHost host;

  Future<void> syncMarkersSafe({required ThemeProvider themeProvider}) async {
    try {
      await syncMarkers(themeProvider: themeProvider);
    } catch (e) {
      if (kDebugMode) {
        AppConfig.debugPrint('${host.debugLabel}: syncMarkers failed: $e');
      }
    }
  }

  Future<void> syncMarkers({required ThemeProvider themeProvider}) async {
    final controller = host.mapController;
    if (controller == null) return;
    if (!host.styleInitialized) return;
    if (!host.managedSourceIds.contains(host.markerSourceId)) return;
    if (!host.hostMounted) return;

    final dev.TimelineTask? timeline = MapPerformanceDebug.isEnabled
        ? (dev.TimelineTask()..start('${host.debugLabel}.syncMapMarkers'))
        : null;

    try {
      final scheme = Theme.of(host.hostContext).colorScheme;
      final roles = KubusColorRoles.of(host.hostContext);
      final isDark = themeProvider.isDarkMode;

      final zoom = host.syncZoom;
      final useClustering = zoom < host.clusterMaxZoom &&
          !host.kubusMapController.hasExpandedSameLocation;
      final renderedMarkers = host.kubusMapController.buildRenderedMarkers();
      final visibleMarkers =
          renderedMarkers.map((m) => m.marker).toList(growable: false);
      final renderById = <String, KubusRenderedMarker>{
        for (final marker in renderedMarkers) marker.marker.id: marker,
      };
      final geoMarkers = renderedMarkers
          .map((m) => m.marker.copyWith(position: m.position))
          .toList(growable: false);

      // Pre-register all needed icons in parallel to avoid waterfall.
      await preregisterIcons(
        markers: visibleMarkers,
        themeProvider: themeProvider,
        scheme: scheme,
        roles: roles,
        isDark: isDark,
        useClustering: useClustering,
        zoom: zoom,
      );
      if (!host.hostMounted) return;

      final features = await kubusBuildMarkerFeatureList(
        markers: geoMarkers,
        useClustering: useClustering,
        zoom: zoom,
        clusterGridLevelForZoom: host.clusterGridLevelForZoom,
        sortClustersBySizeDesc: host.sortClustersBySizeDesc,
        shouldAbort: () => !host.hostMounted,
        buildMarkerFeature: (marker) => markerFeatureFor(
          marker: marker,
          renderMarker: renderById[marker.id],
          themeProvider: themeProvider,
          scheme: scheme,
          roles: roles,
          isDark: isDark,
        ),
        buildClusterFeature: (cluster) => clusterFeatureFor(
          cluster: cluster,
          scheme: scheme,
          roles: roles,
          isDark: isDark,
          renderById: renderById,
        ),
      );
      if (!host.hostMounted) return;

      final collection = <String, dynamic>{
        'type': 'FeatureCollection',
        'features': features,
      };
      if (!host.hostMounted) return;
      try {
        await controller.setGeoJsonSource(host.markerSourceId, collection);
        host.onMarkerSourceWrite();
      } catch (_) {
        // Best-effort: style swaps can temporarily invalidate sources.
      }

      await host.afterMarkerSync(themeProvider);
    } finally {
      timeline?.finish();
    }
  }

  /// Pre-registers marker icons in batched parallel to avoid waterfall.
  /// This renders icons concurrently (up to a batch limit) before the main
  /// feature loop, so [markerFeatureFor] finds them already cached.
  Future<void> preregisterIcons({
    required List<ArtMarker> markers,
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
    required bool useClustering,
    required double zoom,
  }) async {
    final controller = host.mapController;
    if (controller == null) return;

    await kubusPreregisterMarkerIcons(
      controller: controller,
      registeredMapImages: host.registeredMapImages,
      markers: markers,
      isDark: isDark,
      useClustering: useClustering,
      zoom: zoom,
      clusterGridLevelForZoom: host.clusterGridLevelForZoom,
      sortClustersBySizeDesc: host.sortClustersBySizeDesc,
      scheme: scheme,
      roles: roles,
      pixelRatio: host.markerPixelRatio(),
      resolveMarkerIcon: KubusMapMarkerHelpers.resolveArtMarkerIcon,
      resolveMarkerBaseColor: (marker) =>
          host.resolveArtMarkerBaseColor(marker, themeProvider),
    );
  }

  Future<Map<String, dynamic>> markerFeatureFor({
    required ArtMarker marker,
    required KubusRenderedMarker? renderMarker,
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
  }) async {
    final controller = host.mapController;
    if (controller == null) return const <String, dynamic>{};

    return kubusMarkerFeatureFor(
      controller: controller,
      registeredMapImages: host.registeredMapImages,
      marker: marker,
      isDark: isDark,
      scheme: scheme,
      roles: roles,
      pixelRatio: host.markerPixelRatio(),
      shouldAbort: () => !host.hostMounted,
      resolveMarkerIcon: KubusMapMarkerHelpers.resolveArtMarkerIcon,
      resolveMarkerBaseColor: (m) =>
          host.resolveArtMarkerBaseColor(m, themeProvider),
      entryScale: renderMarker?.entryScale ?? 1.0,
      entryOpacity: renderMarker?.entryOpacity ?? 1.0,
      spiderfied: renderMarker?.isSpiderfied ?? false,
      coordinateKey: renderMarker?.sameCoordinateKey,
      entrySerial: renderMarker?.entrySerial ?? 0,
    );
  }

  Future<Map<String, dynamic>> clusterFeatureFor({
    required KubusClusterBucket cluster,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
    Map<String, KubusRenderedMarker>? renderById,
  }) async {
    final controller = host.mapController;
    if (controller == null) return const <String, dynamic>{};

    final entry = kubusClusterEntryValues(cluster, renderById);
    return kubusClusterFeatureFor(
      controller: controller,
      registeredMapImages: host.registeredMapImages,
      cluster: cluster,
      isDark: isDark,
      scheme: scheme,
      roles: roles,
      pixelRatio: host.markerPixelRatio(),
      shouldAbort: () => !host.hostMounted,
      resolveMarkerIcon: KubusMapMarkerHelpers.resolveArtMarkerIcon,
      entryScale: entry.scale,
      entryOpacity: entry.opacity,
    );
  }
}
