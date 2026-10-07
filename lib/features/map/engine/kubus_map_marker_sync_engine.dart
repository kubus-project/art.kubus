import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:provider/provider.dart';

import '../../../config/config.dart';
import '../../../models/art_marker.dart';
import '../../../models/map_marker_overview.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/app_color_utils.dart';
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
import '../controller/map_overview_controller.dart';
import '../shared/map_cluster_transition.dart';
import '../shared/map_marker_collision_config.dart';
import '../shared/map_marker_lod.dart';
import 'kubus_cover_perf_probe.dart';
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

  /// Camera zoom the sync pipeline builds level of detail for (screens track
  /// this in different fields: `_lastZoom` on mobile, `_cameraZoom` on
  /// desktop).
  double get syncZoom;

  /// Zoom marker grouping is evaluated at: [syncZoom] with the shared regroup
  /// gate's hysteresis applied, so grouping does not flip back and forth while
  /// the camera jitters around a boundary (see `KubusMarkerRegroupGate`).
  double get clusterTopologyZoom;

  /// The low-zoom overview to draw instead of detailed markers, or null when
  /// detailed markers are showing. See `KubusMapOverviewController`.
  MapMarkerOverview? get markerOverview;

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
  late final KubusCoverWorkGate _coverGate = KubusCoverWorkGate(
    isPaced: () => host.kubusMapController.cameraIsMoving,
  );

  /// How far below the cluster threshold individual-marker artwork is warmed
  /// (see [syncMarkers]): one zoom level, i.e. the city-scale approach.
  static const double markerIconWarmBand = 1.0;

  /// The icon warm-up in flight, if any (see [syncMarkers]). Icon
  /// pre-registration checks the registered set only before each asynchronous
  /// render, so two overlapping runs would rasterise and add the same icons.
  Future<void>? _iconWarmup;

  // Cover icons registered per style epoch. MapLibre has no image removal (and
  // the web plugin ignores a re-added name), so the total is capped instead:
  // once the pool is spent, further markers simply keep their canonical badge
  // until the next style reload clears the images.
  int _coverImagesRegistered = 0;

  /// The markers the latest plan wants a cover for. A cover that finishes
  /// loading after the camera has moved on is dropped, never drawn offscreen.
  Set<String> _wantedCoverIds = const <String>{};
  int _coverEpoch = -1;
  final Set<String> _pendingCoverKeys = <String>{};
  final KubusCoverUrlCache _coverUrls = KubusCoverUrlCache();

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
  // Per-feature regroup progress of the transition in flight. Monotonic: a
  // feature that has started moving towards its target never slides back.
  final Map<String, double> _transitionProgressById = <String, double>{};

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
      final topologyZoom = host.clusterTopologyZoom;
      final useClustering = topologyZoom < host.clusterMaxZoom &&
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

      // World and region zoom draw the server's exact aggregate nodes, not a
      // nearest-first slice of detailed markers, and do not cluster them again:
      // they already are the regional groups.
      final overview = host.markerOverview;
      if (overview != null && zoom < KubusMapOverviewController.exitZoom) {
        await _syncOverview(
          overview: overview,
          themeProvider: themeProvider,
          scheme: scheme,
          roles: roles,
          isDark: isDark,
          zoom: zoom,
          pinned: pinned,
          renderedMarkers: renderedMarkers,
          reduceMotion: reduceMotion,
        );
        return;
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

      // A warm-up still rendering these icons finishes first, so the same icon
      // is never rasterised twice.
      final warmup = _iconWarmup;
      if (warmup != null) await warmup;
      if (!host.hostMounted) return;

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
        zoom: topologyZoom,
        pinnedMarkerIds: pinned,
      );
      if (!host.hostMounted) return;

      final blankIconId =
          host.kubusMapController.ids.layers.markerHitboxImageId;
      final features = await kubusBuildMarkerFeatureList(
        markers: geoMarkers,
        useClustering: useClustering,
        zoom: topologyZoom,
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

      // Close to the street threshold the next zoom-in dissolves the clusters
      // into individual markers. Their artwork (one icon per category, tier
      // and theme, plus the same-coordinate stacks) is rasterised now, while
      // the camera rests, so the crossing itself only rewrites the source:
      // rasterising it there was the longest task of the whole transition.
      // One warm-up at a time, for the style it was started in.
      if (needsArtwork &&
          useClustering &&
          _iconWarmup == null &&
          topologyZoom >= host.clusterMaxZoom - markerIconWarmBand &&
          !host.kubusMapController.cameraIsMoving &&
          host.kubusMapController.styleEpoch == styleEpoch) {
        late final Future<void> run;
        run = preregisterIcons(
          markers: visibleMarkers,
          themeProvider: themeProvider,
          scheme: scheme,
          roles: roles,
          isDark: isDark,
          useClustering: false,
          zoom: topologyZoom,
          pinnedMarkerIds: pinned,
        ).catchError((Object _) {}).whenComplete(() {
          if (identical(_iconWarmup, run)) _iconWarmup = null;
        });
        _iconWarmup = run;
      }

      // Marker artwork depends on the zoom this pass was built for. If the
      // camera moved across a level-of-detail boundary meanwhile, the source
      // now holds the wrong artwork, so rebuild once for the current zoom.
      final settledZoom = host.syncZoom;
      if (KubusMarkerLod.needsMarkerArtwork(settledZoom) != needsArtwork ||
          KubusMarkerLod.coverStageForZoom(settledZoom) !=
              KubusMarkerLod.coverStageForZoom(zoom)) {
        host.requestMarkerResync();
      }
    } finally {
      timeline?.finish();
    }
  }

  /// Draws the low-zoom overview: one far dot per node, plus the selected marker
  /// pinned out of every node so it is never swallowed into an aggregate.
  Future<void> _syncOverview({
    required MapMarkerOverview overview,
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
    required double zoom,
    required Set<String> pinned,
    required List<KubusRenderedMarker> renderedMarkers,
    required bool reduceMotion,
  }) async {
    final blankIconId = host.kubusMapController.ids.layers.markerHitboxImageId;
    // The map's content-layer toggles apply to the overview through each node's
    // type breakdown: a node shows only the markers of the visible types, and
    // disappears when none remain.
    bool typeIsVisible(String type) => host.kubusMapController
        .isMarkerTypeVisible(ArtMarker.parseMarkerType(type, null));
    final nodes = <MapMarkerOverviewNode>[
      for (final node in overview.nodes)
        if (node.restrictedTo(typeIsVisible) case final visible?) visible,
    ];
    final features = <Map<String, dynamic>>[
      for (final node in nodes)
        kubusOverviewNodeFeature(
          node: node,
          blankIconId: blankIconId,
          colorHex: MapLibreStyleUtils.hexRgb(
            AppColorUtils.markerSubjectColor(
              markerType: node.dominantType,
              scheme: scheme,
              roles: roles,
            ),
          ),
        ),
    ];

    final pinnedRendered = renderedMarkers
        .where((rendered) => pinned.contains(rendered.marker.id))
        .toList(growable: false);
    if (pinnedRendered.isNotEmpty) {
      await preregisterIcons(
        markers: <ArtMarker>[for (final item in pinnedRendered) item.marker],
        themeProvider: themeProvider,
        scheme: scheme,
        roles: roles,
        isDark: isDark,
        useClustering: false,
        zoom: zoom,
        pinnedMarkerIds: pinned,
      );
      if (!host.hostMounted) return;
      for (final rendered in pinnedRendered) {
        final feature = await markerFeatureFor(
          marker: rendered.marker.copyWith(position: rendered.position),
          renderMarker: rendered,
          themeProvider: themeProvider,
          scheme: scheme,
          roles: roles,
          isDark: isDark,
        );
        if (feature.isNotEmpty) features.add(feature);
      }
    }
    if (!host.hostMounted) return;

    _applyClusterTopologyTransition(features, reduceMotion: reduceMotion);
    final layersManager = host.kubusMapController.layersManager;
    if (layersManager != null) {
      final didWrite = await layersManager.upsertMarkerData(
        <String, dynamic>{'type': 'FeatureCollection', 'features': features},
      );
      if (didWrite) host.onMarkerSourceWrite();
    }
    await host.afterMarkerSync(themeProvider);

    // The camera may have left the overview band (or the overview was dropped)
    // while this pass ran: rebuild once for what is current.
    if (host.markerOverview == null ||
        host.syncZoom >= KubusMapOverviewController.exitZoom) {
      host.requestMarkerResync();
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
      _transitionProgressById.clear();
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
      _transitionProgressById.clear();
      return;
    }

    if (_transitionTargetSignature != targetSignature) {
      _transitionTargetSignature = targetSignature;
      _transitionOriginTopology = _lastRenderedTopology;
      _transitionProgressById.clear();
    }

    // Each feature travels from its origin in the previous arrangement as its
    // own (centre-out staggered) regroup entrance runs, so a dissolving cluster
    // fans out progressively instead of every marker leaving at once.
    var minProgress = 1.0;
    final renderedNodes = <KubusClusterTransitionNode>[];
    for (var index = 0; index < features.length; index++) {
      final target = targetNodes[index];
      final properties = features[index]['properties'];
      final entryOpacity = properties is Map
          ? (properties['entryOpacity'] as num?)?.toDouble() ?? 1.0
          : 1.0;
      final raw = kubusClusterRegroupFeatureProgress(
        entryOpacity: entryOpacity,
        startOpacity: MapMarkerCollisionConfig.entryRegroupStartOpacity,
      );
      final previousProgress = _transitionProgressById[target.id] ?? 0.0;
      final featureProgress = math.max(previousProgress, raw);
      _transitionProgressById[target.id] = featureProgress;
      if (featureProgress < minProgress) minProgress = featureProgress;
      final progress = Curves.easeOutCubic.transform(featureProgress);
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
    if (minProgress >= 0.999) {
      _stableTopologySignature = targetSignature;
      _transitionTargetSignature = null;
      _transitionOriginTopology = const <KubusClusterTransitionNode>[];
      _transitionProgressById.clear();
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

  /// Physical width the cover is requested at and decoded to. The badge face
  /// is 44 logical px, so this is the face at the device pixel ratio plus a
  /// modest oversample (see [KubusMarkerLod.coverFetchWidthPx]); the resolver
  /// clamps the download near it (with long-edge headroom, see
  /// [_coverDownloadWidthPx]), never archival media, and the decode targets the
  /// short side instead of upscaling.
  int get _coverFetchWidthPx =>
      KubusMarkerLod.coverFetchWidthPx(host.markerPixelRatio());

  /// Long-edge width the cover URL is clamped to. Wider than the decode target
  /// so a landscape source keeps its short side (see
  /// [KubusMarkerLod.coverDownloadWidthPx]).
  int get _coverDownloadWidthPx =>
      KubusMarkerLod.coverDownloadWidthPx(host.markerPixelRatio());

  String? _coverUrlFor(ArtMarker marker) {
    final width = _coverDownloadWidthPx;
    final artworkId = marker.artworkId;
    final artwork = artworkId == null || artworkId.isEmpty
        ? null
        : Provider.of<ArtworkProvider>(host.hostContext, listen: false)
            .getArtworkById(artworkId);
    // The cached answer is only valid for the data it was resolved from.
    // Artwork hydration is asynchronous (a marker can be planned before its
    // artwork has arrived) and refreshed records carry new data, so the entry
    // is keyed by what the resolver reads, not by marker id alone. A marker
    // without a cover is remembered too, but only until that data changes.
    final signature = '${artwork?.id}|${artwork?.imageUrl}|'
        '${identityHashCode(artwork?.metadata)}|'
        '${identityHashCode(marker.metadata)}|$width';
    return _coverUrls.lookup(
      markerId: marker.id,
      signature: signature,
      resolve: () => ArtworkMediaResolver.resolveCover(
        artwork: artwork,
        metadata: marker.metadata,
        maxWidth: width,
      ),
    );
  }

  /// Plans a cover for every eligible individual marker in view (the selected
  /// one first) and returns the cover icon ids that are *already registered*
  /// for them.
  ///
  /// There is no cap on how many in-view markers get a cover: the number of
  /// concurrent downloads, decoded pixels, the decoded-image cache and the
  /// work done per idle are what stay bounded. Covers that still need loading
  /// are queued in the background (selected, promoted, then the rest spread
  /// across the viewport) and the host is asked to resync as each one lands,
  /// so a slow image never delays the canonical marker. Nothing here can remove a marker: no cover, a failed
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
    if (!KubusMarkerLod.allowsSelectedCover(zoom)) {
      // No cover is wanted at this zoom: drop the demand, anything still
      // queued and the pins, so abandoned close-view work cannot keep running
      // (or keep the decoded cache enlarged) after the visitor zoomed out.
      _wantedCoverIds = const <String>{};
      _coverLoader
          .cancelPendingExcept(const <String>[], targetPx: _coverFetchWidthPx);
      _coverLoader.setPinned(const <String>[], targetPx: _coverFetchWidthPx);
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
    bool hasCover(ArtMarker marker) => _coverUrlFor(marker) != null;
    // Below the display zoom only the selected marker (pinned out of
    // clustering) may show its cover; nearby covers are at most prefetched.
    final chosen = KubusMarkerLod.planCoverIds(
      candidates: candidates,
      selectedId: selectedId,
      zoom: zoom,
      hasCover: hasCover,
      failedIds: failed,
    );
    final warmUrls = _prefetchCovers(
      zoom: zoom,
      candidates: candidates,
      selectedId: selectedId,
      hasCover: hasCover,
      failed: failed,
    );

    final plan = <String, KubusMarkerCoverIcons>{};
    final byId = <String, ArtMarker>{
      for (final marker in candidates) marker.id: marker,
    };
    _wantedCoverIds = chosen.toSet();
    // A viewport change cancels queued loads for covers no longer wanted, so
    // the new view's covers are never queued behind the old one's.
    // The warm-up set of the prefetch stage is wanted too: at zoom 11.5-12.5
    // the display plan holds only the selection, and pruning to it would drop
    // the very prefetches that were just queued.
    _coverLoader.cancelPendingExcept(
      [
        for (final id in chosen)
          if (byId[id] != null)
            if (_coverUrlFor(byId[id]!) case final url?) url,
        ...warmUrls,
      ],
      targetPx: _coverFetchWidthPx,
    );
    // Covers in the active viewport that are not drawn into the map yet keep
    // their decoded image until they are; everything else (offscreen, old
    // zoom, stale size) stays evictable. Registered covers need no decoded
    // copy any more.
    _coverLoader.setPinned(
      [
        for (final id in chosen)
          if (byId[id] != null &&
              !host.registeredMapImages.contains(
                MapMarkerIconIds.markerCover(
                  markerId: id,
                  coverHash: (_coverUrlFor(byId[id]!) ?? '').hashCode,
                  isDark: isDark,
                  selected: false,
                ),
              ))
            if (_coverUrlFor(byId[id]!) case final url?) url,
      ],
      targetPx: _coverFetchWidthPx,
    );
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
      // A spent image pool cannot take another cover: planning it again would
      // only fetch, render and discard it on every idle.
      if (_coverImagesRegistered >= KubusMarkerLod.maxRegisteredCoverImages) {
        continue;
      }
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

  /// Warms (downloads + decodes, never rasterises) the first
  /// [KubusMarkerLod.coverPrefetchLimit] covers the display stage will show, so
  /// they are ready when the visitor zooms in. Bounded by that limit, the
  /// loader's concurrency and cache, and only while the camera is idle: a
  /// settled camera means a stable candidate set.
  ///
  /// Returns the cover URLs the warm-up set wants (queued or already cached),
  /// so the caller can keep them when it prunes queued loads.
  List<String> _prefetchCovers({
    required double zoom,
    required List<ArtMarker> candidates,
    required String? selectedId,
    required bool Function(ArtMarker marker) hasCover,
    required Set<String> failed,
  }) {
    if (!KubusMarkerLod.allowsCoverPrefetch(zoom)) return const <String>[];
    if (KubusMarkerLod.allowsCovers(zoom)) return const <String>[];
    if (host.kubusMapController.cameraIsMoving) return const <String>[];
    final ids = KubusMarkerLod.selectCoverMarkerIds(
      candidates: candidates,
      selectedId: selectedId,
      hasCover: hasCover,
      failedIds: failed,
      limit: KubusMarkerLod.coverPrefetchLimit,
    );
    final byId = <String, ArtMarker>{
      for (final marker in candidates) marker.id: marker,
    };
    final width = _coverFetchWidthPx;
    // A settled camera replaces the warm-up set: prefetches planned for an
    // earlier view that have not started yet must not delay this one.
    _coverLoader.cancelPendingPrefetches();
    final warm = <String>[];
    for (final id in ids) {
      final marker = byId[id];
      final url = marker == null ? null : _coverUrlFor(marker);
      if (url == null) continue;
      warm.add(url);
      if (_coverLoader.cached(url, targetPx: width) != null) continue;
      unawaited(
        _coverLoader
            .load(url, targetPx: width, prefetch: true)
            .then((image) => image?.dispose()),
      );
    }
    return warm;
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
    final targetWidth = _coverFetchWidthPx;
    unawaited(() async {
      ui.Image? image;
      try {
        image = await _coverLoader.load(url, targetPx: targetWidth);
        if (image != null && !_wantedCoverIds.contains(marker.id)) {
          // The camera moved on while this loaded: not drawn offscreen.
          return;
        }
        if (image == null) {
          // A failed cover leaves the canonical marker; resync so the failed
          // marker frees its budget slot for the next candidate.
          if (host.hostMounted) {
            _coverGate.scheduleResync(host.requestMarkerResync);
          }
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

        // Whether an image was actually added: a resync is only worth its cost
        // when the source can now show something new.
        Future<bool> register(bool selected) async {
          final id = MapMarkerIconIds.markerCover(
            markerId: marker.id,
            coverHash: hash,
            isDark: isDark,
            selected: selected,
          );
          if (host.registeredMapImages.contains(id)) return false;
          if (_coverImagesRegistered >=
              KubusMarkerLod.maxRegisteredCoverImages) {
            return false;
          }
          final renderWatch = Stopwatch()..start();
          final bytes = await ArtMarkerCubeIconRenderer.renderCoverMarkerPng(
            cover: image!,
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
          recordKubusCoverPhase(KubusCoverPhase.renderPng, renderWatch.elapsed);
          if (!host.hostMounted ||
              host.kubusMapController.styleEpoch != styleEpoch) {
            return false;
          }
          final addWatch = Stopwatch()..start();
          await controller.addImage(id, bytes);
          recordKubusCoverPhase(KubusCoverPhase.addImage, addWatch.elapsed);
          host.registeredMapImages.add(id);
          _coverImagesRegistered += 1;
          recordKubusCoverGauge(
              'registeredImages', _coverImagesRegistered.toDouble());
          return true;
        }

        // One cover at a time, with a breather that widens while the camera
        // moves (see KubusCoverWorkGate.motionSpacing): the readback behind
        // each icon never lands on consecutive frames, yet covers keep
        // arriving during a pan or zoom instead of all at once when it stops.
        // A skipped cover is re-planned at the next sync or camera idle.
        final rendered = await _coverGate.runSerial<bool>(
          () async {
            final base = await register(false);
            final glow = needSelectedVariant && await register(true);
            return base || glow;
          },
          // Demand is checked again here, not only after decoding: the job may
          // have waited behind other rasterisations while the camera moved on,
          // and an abandoned cover must not spend the append-only image pool.
          shouldRun: () =>
              host.hostMounted &&
              host.kubusMapController.styleEpoch == styleEpoch &&
              _wantedCoverIds.contains(marker.id),
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
        image?.dispose();
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
