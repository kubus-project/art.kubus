import 'dart:async';
import 'dart:developer' as dev;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    ArtMarker marker,
    ThemeProvider themeProvider,
  );

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
  KubusMapMarkerSyncEngine(this.host,
      {KubusMarkerCoverLoader? coverLoader, int Function()? nowMs})
      : _coverLoader = coverLoader ?? KubusMarkerCoverLoader(),
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);
  final int Function() _nowMs;

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

  // Direct sync calls can overlap while sharing a controller and style epoch.
  // The source pipeline is latest-request-wins; long-lived icon/cover asset
  // work remains guarded only by controller/style freshness below.
  int _sourceSyncGeneration = 0;
  bool _disposed = false;
  int _topologyStyleEpoch = -1;

  // Cover icons registered per style epoch. MapLibre has no image removal (and
  // the web plugin ignores a re-added name), so the total is capped instead:
  // once the pool is spent, further markers simply keep their canonical badge
  // until the next style reload clears the images.
  int _coverImagesRegistered = 0;
  final Map<String, int> _coverRevealStarted = {};
  bool _coverAnimationActive = false;

  /// The markers the latest plan wants a cover for. A cover that finishes
  /// loading after the camera has moved on is dropped, never drawn offscreen.
  Set<String> _wantedCoverIds = const <String>{};
  int _coverEpoch = -1;
  final Set<String> _pendingCoverKeys = <String>{};
  final KubusCoverUrlCache _coverUrls = KubusCoverUrlCache();

  /// Cover images registered in the current style epoch (debug / evidence).
  int get coverImagesRegistered => _coverImagesRegistered;

  void dispose() {
    _disposed = true;
    _sourceSyncGeneration += 1;
    _topologyFrameTimer?.cancel();
    _clusterTransition.reset();
    _coverGate.dispose();
    _coverLoader.dispose();
  }

  final _clusterTransition = KubusClusterTopologyTransition(
    durationMs: MapMarkerCollisionConfig.entryRegroupDurationMs,
  );
  Timer? _topologyFrameTimer;

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
    if (_disposed) return;
    final controller = host.mapController;
    if (controller == null) return;
    final mapController = host.kubusMapController;
    if (!host.styleInitialized) return;
    if (!host.managedSourceIds.contains(host.markerSourceId)) return;
    if (!host.hostMounted) return;
    final styleEpoch = mapController.styleEpoch;
    if (_topologyStyleEpoch != styleEpoch) {
      _topologyStyleEpoch = styleEpoch;
      _clusterTransition.reset();
      _topologyFrameTimer?.cancel();
      _topologyFrameTimer = null;
    }
    final sourceGeneration = ++_sourceSyncGeneration;
    bool isFresh() =>
        !_disposed &&
        host.hostMounted &&
        host.styleInitialized &&
        identical(host.mapController, controller) &&
        identical(host.kubusMapController, mapController) &&
        mapController.styleEpoch == styleEpoch;
    bool isCurrentSource() =>
        isFresh() && sourceGeneration == _sourceSyncGeneration;

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
      _coverAnimationActive = false;
      final selectedId = host.kubusMapController.selectedMarkerId;
      final pinned = <String>{
        if (selectedId != null && selectedId.isNotEmpty) selectedId,
      };
      if (_coverEpoch != styleEpoch) {
        _coverEpoch = styleEpoch;
        _coverImagesRegistered = 0;
        _coverRevealStarted.clear();
        _pendingCoverKeys.clear();
      }

      // World and region zoom draw the server's exact aggregate nodes, not a
      // nearest-first slice of detailed markers, and do not cluster them again:
      // they already are the regional groups.
      // The overview is drawn for as long as the host holds one. That is the
      // live overview, and also the one kept while detailed markers load after
      // the camera crossed the exit zoom: switching on the zoom alone emptied
      // the source for the length of the fetch.
      final overview = host.markerOverview;
      if (overview != null) {
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
          controller: controller,
          shouldAbort: () => !isFresh(),
          isCurrentSource: isCurrentSource,
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
        controller: controller,
        shouldAbort: () => !isFresh(),
      );

      // A warm-up still rendering these icons finishes first, so the same icon
      // is never rasterised twice.
      final warmup = _iconWarmup;
      if (warmup != null) await warmup;
      if (!isCurrentSource()) return;

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
        controller: controller,
        shouldAbort: () => !isFresh(),
      );
      if (!isCurrentSource()) return;

      final blankIconId =
          host.kubusMapController.ids.layers.markerHitboxImageId;
      final features = await kubusBuildMarkerFeatureList(
        markers: geoMarkers,
        useClustering: useClustering,
        zoom: topologyZoom,
        clusterGridLevelForZoom: host.clusterGridLevelForZoom,
        sortClustersBySizeDesc: host.sortClustersBySizeDesc,
        shouldAbort: () => !isFresh(),
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
            controller: controller,
            shouldAbort: () => !isFresh(),
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
            controller: controller,
            shouldAbort: () => !isFresh(),
          );
        },
      );
      if (!isCurrentSource()) return;

      _applyClusterTopologyTransition(features, reduceMotion: reduceMotion);
      final collection = <String, dynamic>{
        'type': 'FeatureCollection',
        'features': features,
      };
      if (!isCurrentSource()) return;
      final layersManager = host.kubusMapController.layersManager;
      if (layersManager != null) {
        final didWrite = await layersManager.upsertMarkerData(collection);
        if (!isCurrentSource()) return;
        if (didWrite) host.onMarkerSourceWrite();
      } else if (kDebugMode) {
        AppConfig.debugPrint(
          '${host.debugLabel}: marker sync skipped without layers manager',
        );
      }

      if (!isCurrentSource()) return;
      await host.afterMarkerSync(themeProvider);
      if (!isCurrentSource()) return;

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
          controller: controller,
          shouldAbort: () => !isFresh(),
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
    required ml.MapLibreMapController controller,
    required bool Function() shouldAbort,
    required bool Function() isCurrentSource,
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
    final features = <Map<String, dynamic>>[];
    // Overview data can outlive the far LOD while detail is loading. Give its
    // exact aggregates canonical badges instead of invisible hitbox images.
    // Reuse the existing category/count cache and render one image at a time.
    for (final node in nodes) {
      String? artworkIconId;
      if (KubusMarkerLod.needsMarkerArtwork(zoom)) {
        final counts = <ArtMarkerType, int>{};
        final types = node.types.isEmpty
            ? <String, int>{node.dominantType: node.count}
            : node.types;
        for (final entry in types.entries) {
          final type = ArtMarker.parseMarkerType(entry.key, null);
          counts.update(type, (count) => count + entry.value,
              ifAbsent: () => entry.value);
        }
        final categories = counts.entries.toList()
          ..sort((a, b) {
            final count = b.value.compareTo(a.value);
            return count != 0 ? count : a.key.index.compareTo(b.key.index);
          });
        final breakdown = <KubusClusterCategory>[
          for (final entry in categories)
            KubusClusterCategory(type: entry.key, count: entry.value),
        ];
        final iconId = MapMarkerIconIds.cluster(
          categorySignature: kubusClusterCategorySignature(breakdown),
          label: node.count > 99 ? '99+' : '${node.count}',
          isDark: isDark,
        );
        if (!host.registeredMapImages.contains(iconId)) {
          final badges = <ClusterCategoryBadge>[
            for (final entry
                in categories.take(kKubusClusterMaxBadgeCategories))
              ClusterCategoryBadge(
                shape: ArtMapMarkerShape.forType(entry.key),
                color: AppColorUtils.markerSubjectColor(
                    markerType: entry.key.name, scheme: scheme, roles: roles),
                count: entry.value,
                icon: KubusMapMarkerHelpers.resolveArtMarkerIcon(entry.key),
              ),
          ];
          final bytes = await ArtMarkerCubeIconRenderer.renderClusterPng(
            count: node.count,
            baseColor: badges.first.color,
            categories: badges,
            scheme: scheme,
            isDark: isDark,
            pixelRatio: host.markerPixelRatio(),
          );
          if (shouldAbort() || !isCurrentSource()) return;
          await controller.addImage(iconId, bytes);
          if (shouldAbort() || !isCurrentSource()) return;
          host.registeredMapImages.add(iconId);
        }
        artworkIconId = iconId;
      }
      features.add(kubusOverviewNodeFeature(
        node: node,
        blankIconId: blankIconId,
        artworkIconId: artworkIconId,
        colorHex: MapLibreStyleUtils.hexRgb(
          AppColorUtils.markerSubjectColor(
            markerType: node.dominantType,
            scheme: scheme,
            roles: roles,
          ),
        ),
      ));
    }

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
        controller: controller,
        shouldAbort: shouldAbort,
      );
      if (shouldAbort() || !isCurrentSource()) return;
      for (final rendered in pinnedRendered) {
        final feature = await markerFeatureFor(
          marker: rendered.marker.copyWith(position: rendered.position),
          renderMarker: rendered,
          themeProvider: themeProvider,
          scheme: scheme,
          roles: roles,
          isDark: isDark,
          controller: controller,
          shouldAbort: shouldAbort,
        );
        if (shouldAbort() || !isCurrentSource()) return;
        if (feature.isNotEmpty) features.add(feature);
      }
    }
    if (shouldAbort() || !isCurrentSource()) return;

    _applyClusterTopologyTransition(features, reduceMotion: reduceMotion);
    if (!isCurrentSource()) return;
    final layersManager = host.kubusMapController.layersManager;
    if (layersManager != null) {
      final didWrite = await layersManager.upsertMarkerData(<String, dynamic>{
        'type': 'FeatureCollection',
        'features': features,
      });
      if (shouldAbort() || !isCurrentSource()) return;
      if (didWrite) host.onMarkerSourceWrite();
    }
    if (shouldAbort() || !isCurrentSource()) return;
    await host.afterMarkerSync(themeProvider);
    if (shouldAbort() || !isCurrentSource()) return;

    // The overview may have been dropped (detailed markers arrived) while this
    // pass ran: rebuild once for what is current.
    if (!shouldAbort() && host.markerOverview == null) {
      host.requestMarkerResync();
    }
  }

  void _applyClusterTopologyTransition(List<Map<String, dynamic>> features,
      {required bool reduceMotion}) {
    final topologyActive =
        _clusterTransition.apply(features, reduceMotion: reduceMotion);
    final active = topologyActive || _coverAnimationActive;
    if (!active) {
      _topologyFrameTimer?.cancel();
      _topologyFrameTimer = null;
      return;
    }
    if (_topologyFrameTimer != null) return;
    final epoch = _topologyStyleEpoch;
    _topologyFrameTimer = Timer(const Duration(milliseconds: 32), () {
      _topologyFrameTimer = null;
      if (!_disposed &&
          host.hostMounted &&
          host.styleInitialized &&
          host.kubusMapController.styleEpoch == epoch) {
        host.requestMarkerResync();
      }
    });
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
    ml.MapLibreMapController? controller,
    bool Function()? shouldAbort,
  }) async {
    final activeController = controller ?? host.mapController;
    if (activeController == null) return;
    final abort = shouldAbort ?? () => !host.hostMounted;
    if (abort()) return;

    await kubusPreregisterMarkerIcons(
      pinnedMarkerIds: pinnedMarkerIds,
      controller: activeController,
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
      shouldAbort: abort,
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
    ml.MapLibreMapController? controller,
    bool Function()? shouldAbort,
  }) async {
    final activeController = controller ?? host.mapController;
    if (activeController == null) return const <String, dynamic>{};
    final abort = shouldAbort ?? () => !host.hostMounted;
    if (abort()) return const <String, dynamic>{};

    final media = MediaQuery.maybeOf(host.hostContext);
    final reduceMotion =
        media?.disableAnimations == true || media?.accessibleNavigation == true;

    final feature = await kubusMarkerFeatureFor(
      controller: activeController,
      registeredMapImages: host.registeredMapImages,
      marker: marker,
      isDark: isDark,
      scheme: scheme,
      roles: roles,
      pixelRatio: host.markerPixelRatio(),
      shouldAbort: abort,
      resolveMarkerIcon: KubusMapMarkerHelpers.resolveArtMarkerIcon,
      resolveMarkerBaseColor: (m) =>
          host.resolveArtMarkerBaseColor(m, themeProvider),
      entryScale: renderMarker?.entryScale ?? 1.0,
      entryOpacity: renderMarker?.entryOpacity ?? 1.0,
      spiderfied: renderMarker?.isSpiderfied ?? false,
      coordinateKey: renderMarker?.sameCoordinateKey,
      entrySerial: renderMarker?.entrySerial ?? 0,
    );
    if (abort()) return const <String, dynamic>{};
    final properties = feature['properties'];
    if (cover != null && properties is Map<String, dynamic>) {
      // Fade a colocated cover over the canonical badge without restarting
      // entry, replacing its identity or changing its size/anchor/hitbox.
      properties['coverIcon'] = cover.base;
      properties['coverIconSelected'] = cover.selected ?? cover.base;
      final now = _nowMs();
      final started = _coverRevealStarted.putIfAbsent(cover.base, () => now);
      final progress = reduceMotion
          ? 1.0
          : ((now - started) / 220).clamp(0.0, 1.0).toDouble();
      properties['coverReveal'] = progress;
      _coverAnimationActive = _coverAnimationActive || progress < 1;
    }
    return feature;
  }

  Future<Map<String, dynamic>> clusterFeatureFor({
    required KubusClusterBucket cluster,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
    Map<String, KubusRenderedMarker>? renderById,
    ml.MapLibreMapController? controller,
    bool Function()? shouldAbort,
  }) async {
    final activeController = controller ?? host.mapController;
    if (activeController == null) return const <String, dynamic>{};
    final abort = shouldAbort ?? () => !host.hostMounted;
    if (abort()) return const <String, dynamic>{};

    final entry = kubusClusterEntryValues(cluster, renderById);
    final feature = await kubusClusterFeatureFor(
      controller: activeController,
      registeredMapImages: host.registeredMapImages,
      cluster: cluster,
      isDark: isDark,
      scheme: scheme,
      roles: roles,
      pixelRatio: host.markerPixelRatio(),
      shouldAbort: abort,
      resolveMarkerIcon: KubusMapMarkerHelpers.resolveArtMarkerIcon,
      entryScale: entry.scale,
      entryOpacity: entry.opacity,
    );
    if (abort()) return const <String, dynamic>{};
    return feature;
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
        : Provider.of<ArtworkProvider>(
            host.hostContext,
            listen: false,
          ).getArtworkById(artworkId);
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
    required ml.MapLibreMapController controller,
    required bool Function() shouldAbort,
  }) {
    if (!KubusMarkerLod.allowsSelectedCover(zoom)) {
      // No cover is wanted at this zoom: drop the demand, anything still
      // queued and the pins, so abandoned close-view work cannot keep running
      // (or keep the decoded cache enlarged) after the visitor zoomed out.
      _wantedCoverIds = const <String>{};
      _coverLoader.cancelPendingExcept(
        const <String>[],
        targetPx: _coverFetchWidthPx,
      );
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
    _coverLoader.cancelPendingExcept([
      for (final id in chosen)
        if (byId[id] != null)
          if (_coverUrlFor(byId[id]!) case final url?) url,
      ...warmUrls,
    ], targetPx: _coverFetchWidthPx);
    // Covers in the active viewport that are not drawn into the map yet keep
    // their decoded image until they are; everything else (offscreen, old
    // zoom, stale size) stays evictable. Registered covers need no decoded
    // copy any more.
    _coverLoader.setPinned([
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
    ], targetPx: _coverFetchWidthPx);
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
        controller: controller,
        shouldAbort: shouldAbort,
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
    required ml.MapLibreMapController controller,
    required bool Function() shouldAbort,
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
        if (shouldAbort()) return;
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
        if (shouldAbort()) return;
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
          if (shouldAbort()) return false;
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
          if (shouldAbort()) return false;
          final addWatch = Stopwatch()..start();
          await controller.addImage(id, bytes);
          recordKubusCoverPhase(KubusCoverPhase.addImage, addWatch.elapsed);
          if (shouldAbort()) return false;
          host.registeredMapImages.add(id);
          _coverImagesRegistered += 1;
          recordKubusCoverGauge(
            'registeredImages',
            _coverImagesRegistered.toDouble(),
          );
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
              !shouldAbort() && _wantedCoverIds.contains(marker.id),
        );
        if (rendered == true && !shouldAbort()) {
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
