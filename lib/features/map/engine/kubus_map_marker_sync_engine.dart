import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:provider/provider.dart';

import '../../../config/config.dart';
import '../../../models/art_marker.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/artwork_media_resolver.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/map_marker_icon_ids.dart';
import '../../../utils/map_performance_debug.dart';
import '../../../utils/maplibre_style_utils.dart';
import '../../../widgets/art_marker_cube.dart';
import '../shared/map_screen_shared_helpers.dart';
import '../../../widgets/map/kubus_map_marker_features.dart';
import '../../../widgets/map/kubus_map_marker_geojson_builder.dart';
import '../../../widgets/map/kubus_map_marker_rendering.dart';
import '../controller/kubus_map_controller.dart';
import '../shared/map_cluster_transition.dart';
import '../shared/map_marker_collision_config.dart';
import '../shared/map_marker_lod.dart';
import 'kubus_cover_work_gate.dart';
import 'kubus_marker_cover_loader.dart';

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
  Color resolveArtMarkerBaseColor(
      ArtMarker marker, ThemeProvider themeProvider);

  /// Called after each successful GeoJSON source write (debug counters).
  void onMarkerSourceWrite();

  /// A cover image finished loading and was registered: the marker source
  /// should be rebuilt so the cover appears.
  void requestMarkerResync();

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
  KubusMapMarkerSyncEngine(this.host, {KubusMarkerCoverLoader? coverLoader})
      : _coverLoader = coverLoader ?? KubusMarkerCoverLoader();

  final KubusMapMarkerSyncHost host;
  final KubusMarkerCoverLoader _coverLoader;
  final KubusCoverWorkGate _coverGate = KubusCoverWorkGate();

  // Cover icons registered per style epoch. MapLibre has no image removal (and
  // the web plugin ignores a re-added name), so the total is capped instead:
  // once the pool is spent, further markers simply keep their canonical badge
  // until the next style reload clears the images.
  int _coverImagesRegistered = 0;
  int _coverEpoch = -1;
  final Set<String> _pendingCoverKeys = <String>{};
  final Map<String, String> _coverUrlByMarker = <String, String>{};

  /// Cover images registered in the current style epoch (debug / evidence).
  int get coverImagesRegistered => _coverImagesRegistered;

  void dispose() {
    _coverGate.dispose();
    _coverLoader.dispose();
  }

  List<KubusClusterTransitionNode> _lastRenderedTopology =
      const <KubusClusterTransitionNode>[];
  String _stableTopologySignature = '';
  String? _transitionTargetSignature;
  List<KubusClusterTransitionNode> _transitionOriginTopology =
      const <KubusClusterTransitionNode>[];

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
      final media = MediaQuery.maybeOf(host.hostContext);
      final reduceMotion = media?.disableAnimations == true ||
          media?.accessibleNavigation == true;
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

      // Level of detail. Far: data-coloured dots only, no marker artwork for
      // anything but the selected marker. Mid/close: the canonical marker.
      // Close: a bounded set of markers carry their artwork cover inside the
      // canonical geometry. The selected marker is pinned out of clusters at
      // every level so it can never be absorbed into a count badge.
      final needsArtwork = KubusMarkerLod.needsMarkerArtwork(zoom);
      final selectedId = host.kubusMapController.selectedMarkerId;
      final pinned = <String>{
        if (selectedId != null && selectedId.isNotEmpty) selectedId,
      };
      final styleEpoch = host.kubusMapController.styleEpoch;
      if (_coverEpoch != styleEpoch) {
        _coverEpoch = styleEpoch;
        _coverImagesRegistered = 0;
        _pendingCoverKeys.clear();
      }

      final coverPlan = _planCovers(
        zoom: zoom,
        rendered: renderedMarkers,
        selectedId: selectedId,
        isDark: isDark,
        scheme: scheme,
        roles: roles,
        themeProvider: themeProvider,
        styleEpoch: styleEpoch,
      );

      // Pre-register all needed icons in parallel to avoid waterfall.
      await preregisterIcons(
        markers: needsArtwork
            ? visibleMarkers
            : visibleMarkers
                .where((marker) => pinned.contains(marker.id))
                .toList(growable: false),
        themeProvider: themeProvider,
        scheme: scheme,
        roles: roles,
        isDark: isDark,
        useClustering: needsArtwork && useClustering,
        zoom: zoom,
        pinnedMarkerIds: pinned,
      );
      if (!host.hostMounted) return;

      final blankIconId =
          host.kubusMapController.ids.layers.markerHitboxImageId;
      final features = await kubusBuildMarkerFeatureList(
        markers: geoMarkers,
        useClustering: useClustering,
        zoom: zoom,
        clusterGridLevelForZoom: host.clusterGridLevelForZoom,
        sortClustersBySizeDesc: host.sortClustersBySizeDesc,
        shouldAbort: () => !host.hostMounted,
        pinnedMarkerIds: pinned,
        buildMarkerFeature: (marker) {
          if (!needsArtwork && !pinned.contains(marker.id)) {
            return Future<Map<String, dynamic>>.value(
              kubusFarMarkerFeature(
                marker: marker,
                colorHex: MapLibreStyleUtils.hexRgb(
                  host.resolveArtMarkerBaseColor(marker, themeProvider),
                ),
                blankIconId: blankIconId,
                entryScale: renderById[marker.id]?.entryScale ?? 1.0,
                entryOpacity: renderById[marker.id]?.entryOpacity ?? 1.0,
                spiderfied: renderById[marker.id]?.isSpiderfied ?? false,
                coordinateKey: renderById[marker.id]?.sameCoordinateKey,
                entrySerial: renderById[marker.id]?.entrySerial ?? 0,
              ),
            );
          }
          return markerFeatureFor(
            marker: marker,
            renderMarker: renderById[marker.id],
            themeProvider: themeProvider,
            scheme: scheme,
            roles: roles,
            isDark: isDark,
            cover: coverPlan[marker.id],
          );
        },
        buildClusterFeature: (cluster) {
          if (!needsArtwork) {
            final entry = kubusClusterEntryValues(cluster, renderById);
            return kubusFarClusterFeature(
              cluster: cluster,
              isDark: isDark,
              scheme: scheme,
              roles: roles,
              resolveMarkerIcon: KubusMapMarkerHelpers.resolveArtMarkerIcon,
              blankIconId: blankIconId,
              entryScale: entry.scale,
              entryOpacity: entry.opacity,
            );
          }
          return clusterFeatureFor(
            cluster: cluster,
            scheme: scheme,
            roles: roles,
            isDark: isDark,
            renderById: renderById,
          );
        },
      );
      if (!host.hostMounted) return;

      _applyClusterTopologyTransition(
        features,
        reduceMotion: reduceMotion,
      );
      final collection = <String, dynamic>{
        'type': 'FeatureCollection',
        'features': features,
      };
      if (!host.hostMounted) return;
      final layersManager = host.kubusMapController.layersManager;
      if (layersManager != null) {
        final didWrite = await layersManager.upsertMarkerData(collection);
        if (didWrite) host.onMarkerSourceWrite();
      } else if (kDebugMode) {
        AppConfig.debugPrint(
          '${host.debugLabel}: marker sync skipped without layers manager',
        );
      }

      await host.afterMarkerSync(themeProvider);

      // Marker artwork depends on the zoom this pass was built for. If the
      // camera moved across a level-of-detail boundary meanwhile, the source
      // now holds the wrong artwork, so rebuild once for the current zoom.
      final settledZoom = host.syncZoom;
      if (KubusMarkerLod.needsMarkerArtwork(settledZoom) != needsArtwork ||
          KubusMarkerLod.allowsCovers(settledZoom) !=
              KubusMarkerLod.allowsCovers(zoom)) {
        host.requestMarkerResync();
      }
    } finally {
      timeline?.finish();
    }
  }

  void _applyClusterTopologyTransition(
    List<Map<String, dynamic>> features, {
    required bool reduceMotion,
  }) {
    final targetNodes = _topologyNodesFromFeatures(features);
    final targetSignature = kubusClusterTopologySignature(targetNodes);
    if (reduceMotion) {
      _lastRenderedTopology = targetNodes;
      _stableTopologySignature = targetSignature;
      _transitionTargetSignature = null;
      _transitionOriginTopology = const <KubusClusterTransitionNode>[];
      return;
    }
    if (_lastRenderedTopology.isEmpty || _stableTopologySignature.isEmpty) {
      _lastRenderedTopology = targetNodes;
      _stableTopologySignature = targetSignature;
      _transitionTargetSignature = null;
      return;
    }
    if (targetSignature == _stableTopologySignature) {
      _lastRenderedTopology = targetNodes;
      _transitionTargetSignature = null;
      _transitionOriginTopology = const <KubusClusterTransitionNode>[];
      return;
    }

    if (_transitionTargetSignature != targetSignature) {
      _transitionTargetSignature = targetSignature;
      _transitionOriginTopology = _lastRenderedTopology;
    }
    final progress = Curves.easeOutCubic.transform(
      kubusClusterRegroupProgress(
        entryOpacities: features.map((feature) {
          final properties = feature['properties'];
          if (properties is! Map) return 1.0;
          return (properties['entryOpacity'] as num?)?.toDouble() ?? 1.0;
        }),
        startOpacity: MapMarkerCollisionConfig.entryRegroupStartOpacity,
      ),
    );

    final renderedNodes = <KubusClusterTransitionNode>[];
    for (var index = 0; index < features.length; index++) {
      final target = targetNodes[index];
      final origin = resolveKubusClusterTransitionOrigin(
        target: target,
        previous: _transitionOriginTopology,
      );
      final position = origin == null
          ? target.position
          : interpolateKubusClusterPosition(origin, target.position, progress);
      final geometry = features[index]['geometry'];
      if (geometry is Map<String, dynamic>) {
        geometry['coordinates'] = <double>[
          position.longitude,
          position.latitude,
        ];
      }
      renderedNodes.add(
        KubusClusterTransitionNode(
          id: target.id,
          memberIds: target.memberIds,
          position: position,
        ),
      );
    }
    _lastRenderedTopology = List<KubusClusterTransitionNode>.unmodifiable(
      renderedNodes,
    );
    if (progress >= 0.999) {
      _stableTopologySignature = targetSignature;
      _transitionTargetSignature = null;
      _transitionOriginTopology = const <KubusClusterTransitionNode>[];
      _lastRenderedTopology = targetNodes;
    }
  }

  List<KubusClusterTransitionNode> _topologyNodesFromFeatures(
    List<Map<String, dynamic>> features,
  ) {
    return List<KubusClusterTransitionNode>.unmodifiable(
      features.map((feature) {
        final properties = feature['properties'] as Map;
        final geometry = feature['geometry'] as Map;
        final coordinates = geometry['coordinates'] as List;
        final id = (properties['id'] ?? feature['id']).toString();
        final rawMembers = properties['clusterMemberIds'];
        final memberIds = rawMembers is List
            ? rawMembers.map((value) => value.toString()).toSet()
            : <String>{(properties['markerId'] ?? id).toString()};
        return KubusClusterTransitionNode(
          id: id,
          memberIds: Set<String>.unmodifiable(memberIds),
          position: LatLng(
            (coordinates[1] as num).toDouble(),
            (coordinates[0] as num).toDouble(),
          ),
        );
      }),
    );
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
    Set<String> pinnedMarkerIds = const <String>{},
  }) async {
    final controller = host.mapController;
    if (controller == null) return;

    await kubusPreregisterMarkerIcons(
      pinnedMarkerIds: pinnedMarkerIds,
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
    KubusMarkerCoverIcons? cover,
  }) async {
    final controller = host.mapController;
    if (controller == null) return const <String, dynamic>{};

    final feature = await kubusMarkerFeatureFor(
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
    final properties = feature['properties'];
    if (cover != null && properties is Map<String, dynamic>) {
      // The cover lives inside the canonical badge geometry: only the image
      // changes, never the layer, size, anchor or hitbox.
      properties['icon'] = cover.base;
      if (cover.selected != null) properties['iconSelected'] = cover.selected;
    }
    return feature;
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

  // -------------------------------------------------------------------------
  // Close-level artwork covers
  // -------------------------------------------------------------------------

  /// Cover width requested from the media resolver and decoded, in logical px.
  /// The badge face is 44 logical px, so a 2x decode is already generous; the
  /// resolver clamps the download to this width, never archival media.
  static const int _coverFetchWidthLogicalPx = 160;

  String? _coverUrlFor(ArtMarker marker) {
    final cached = _coverUrlByMarker[marker.id];
    if (cached != null) return cached.isEmpty ? null : cached;
    final artworkId = marker.artworkId;
    final artwork = artworkId == null || artworkId.isEmpty
        ? null
        : Provider.of<ArtworkProvider>(host.hostContext, listen: false)
            .getArtworkById(artworkId);
    final url = ArtworkMediaResolver.resolveCover(
      artwork: artwork,
      metadata: marker.metadata,
      maxWidth: _coverFetchWidthLogicalPx,
    );
    // An empty marker is remembered too: a marker with no cover is not
    // re-resolved on every sync.
    _coverUrlByMarker[marker.id] = url ?? '';
    return url;
  }

  /// Chooses the bounded set of markers that should show a cover now and
  /// returns the cover icon ids that are *already registered* for them.
  ///
  /// Covers that still need loading are started in the background and the host
  /// is asked to resync when each one lands, so a slow image never delays the
  /// canonical marker. Nothing here can remove a marker: no cover, a failed
  /// cover, an exhausted image pool or an unmounted host all leave the
  /// canonical badge in place.
  Map<String, KubusMarkerCoverIcons> _planCovers({
    required double zoom,
    required List<KubusRenderedMarker> rendered,
    required String? selectedId,
    required bool isDark,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required ThemeProvider themeProvider,
    required int styleEpoch,
  }) {
    if (!KubusMarkerLod.allowsCovers(zoom)) {
      return const <String, KubusMarkerCoverIcons>{};
    }
    final visible = host.kubusMapController.visibleMarkerIds;
    final countAt = <String, int>{};
    for (final item in rendered) {
      countAt.update(item.sameCoordinateKey, (v) => v + 1, ifAbsent: () => 1);
    }
    final candidates = <ArtMarker>[
      for (final item in rendered)
        if ((visible.contains(item.marker.id) ||
                item.marker.id == selectedId) &&
            // A same-coordinate stack is one cluster feature, not a marker.
            ((countAt[item.sameCoordinateKey] ?? 1) == 1 || item.isSpiderfied))
          item.marker,
    ];
    final failed = <String>{};
    for (final marker in candidates) {
      final url = _coverUrlFor(marker);
      if (url != null && _coverLoader.hasFailed(url)) failed.add(marker.id);
    }
    final viewport = MediaQuery.maybeOf(host.hostContext)?.size ?? Size.zero;
    final chosen = KubusMarkerLod.selectCoverMarkerIds(
      candidates: candidates,
      selectedId: selectedId,
      center: host.kubusMapController.camera.center,
      budget: KubusMarkerLod.coverBudget(viewport),
      hasCover: (marker) => _coverUrlFor(marker) != null,
      failedIds: failed,
    );

    final plan = <String, KubusMarkerCoverIcons>{};
    final byId = <String, ArtMarker>{
      for (final marker in candidates) marker.id: marker,
    };
    for (final id in chosen) {
      final marker = byId[id];
      final url = marker == null ? null : _coverUrlFor(marker);
      if (marker == null || url == null) continue;
      final hash = url.hashCode;
      final base = MapMarkerIconIds.markerCover(
        markerId: id,
        coverHash: hash,
        isDark: isDark,
        selected: false,
      );
      final selected = MapMarkerIconIds.markerCover(
        markerId: id,
        coverHash: hash,
        isDark: isDark,
        selected: true,
      );
      final isSelected = id == selectedId;
      final hasBase = host.registeredMapImages.contains(base);
      final hasSelected = host.registeredMapImages.contains(selected);
      if (hasBase && (!isSelected || hasSelected)) {
        plan[id] = KubusMarkerCoverIcons(
          base: base,
          selected: hasSelected ? selected : null,
        );
        continue;
      }
      // Rasterising a cover is a GPU readback: never start one mid-gesture. The
      // screens re-plan covers when the camera idles at street scale.
      if (host.kubusMapController.cameraIsMoving) continue;
      _prepareCover(
        marker: marker,
        url: url,
        isDark: isDark,
        scheme: scheme,
        roles: roles,
        themeProvider: themeProvider,
        styleEpoch: styleEpoch,
        needSelectedVariant: isSelected,
      );
    }
    return plan;
  }

  void _prepareCover({
    required ArtMarker marker,
    required String url,
    required bool isDark,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required ThemeProvider themeProvider,
    required int styleEpoch,
    required bool needSelectedVariant,
  }) {
    final key = '$styleEpoch|${marker.id}|${url.hashCode}|$isDark|'
        '$needSelectedVariant';
    if (!_pendingCoverKeys.add(key)) return;
    final pixelRatio = host.markerPixelRatio();
    final targetWidth = (_coverFetchWidthLogicalPx * pixelRatio).round();
    unawaited(() async {
      try {
        final image = await _coverLoader.load(url, targetWidthPx: targetWidth);
        if (image == null) {
          // A failed cover leaves the canonical marker; resync so the failed
          // marker frees its budget slot for the next candidate.
          if (host.hostMounted)
            _coverGate.scheduleResync(host.requestMarkerResync);
          return;
        }
        final controller = host.mapController;
        if (controller == null ||
            !host.hostMounted ||
            host.kubusMapController.styleEpoch != styleEpoch) {
          return;
        }
        final baseColor = host.resolveArtMarkerBaseColor(marker, themeProvider);
        final shape = ArtMapMarkerShape.forType(marker.type);
        final hash = url.hashCode;

        Future<void> register(bool selected) async {
          final id = MapMarkerIconIds.markerCover(
            markerId: marker.id,
            coverHash: hash,
            isDark: isDark,
            selected: selected,
          );
          if (host.registeredMapImages.contains(id)) return;
          if (_coverImagesRegistered >=
              KubusMarkerLod.maxRegisteredCoverImages) {
            return;
          }
          final bytes = await ArtMarkerCubeIconRenderer.renderCoverMarkerPng(
            cover: image,
            baseColor: baseColor,
            tier: marker.signalTier,
            shape: shape,
            scheme: scheme,
            roles: roles,
            isDark: isDark,
            forceGlow: selected,
            showPromotionStar: marker.isPromoted,
            pixelRatio: pixelRatio,
          );
          if (!host.hostMounted ||
              host.kubusMapController.styleEpoch != styleEpoch) {
            return;
          }
          await controller.addImage(id, bytes);
          host.registeredMapImages.add(id);
          _coverImagesRegistered += 1;
        }

        // One cover at a time, only while the camera is still: the readback
        // behind each icon must not land on a frame the camera needs. A skipped
        // cover is re-planned at the next camera idle.
        final rendered = await _coverGate.runSerial<bool>(
          () async {
            await register(false);
            if (needSelectedVariant) await register(true);
            return true;
          },
          shouldRun: () =>
              host.hostMounted &&
              !host.kubusMapController.cameraIsMoving &&
              host.kubusMapController.styleEpoch == styleEpoch,
        );
        if (rendered == true && host.hostMounted) {
          _coverGate.scheduleResync(host.requestMarkerResync);
        }
      } catch (e) {
        if (kDebugMode) {
          AppConfig.debugPrint(
            '${host.debugLabel}: cover registration failed (${marker.id}): $e',
          );
        }
      } finally {
        _pendingCoverKeys.remove(key);
      }
    }());
  }
}

/// Icon ids of a marker whose artwork cover is registered with the map.
@immutable
class KubusMarkerCoverIcons {
  const KubusMarkerCoverIcons({required this.base, this.selected});

  final String base;

  /// Present only for the selected marker (the glow variant).
  final String? selected;
}
