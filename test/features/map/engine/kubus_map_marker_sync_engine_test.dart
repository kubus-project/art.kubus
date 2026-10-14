import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:art_kubus/features/map/controller/kubus_map_controller.dart';
import 'package:art_kubus/features/map/engine/kubus_map_marker_sync_engine.dart';
import 'package:art_kubus/features/map/engine/kubus_marker_cover_loader.dart';
import 'package:art_kubus/features/map/map_layers_manager.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/map_marker_overview.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/map_marker_icon_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:provider/provider.dart';

const _layerIds = MapLayersIds(
  markerSourceId: 'kubus_markers',
  markerLayerId: 'kubus_marker_layer',
  markerHitboxLayerId: 'kubus_marker_hitbox_layer',
  markerHitboxImageId: 'kubus_hitbox_square_transparent',
  markerDotLayerId: 'kubus_marker_dot_layer',
  markerPulseLayerId: 'kubus_marker_pulse_layer',
  cubeLayerId: 'kubus_marker_cubes_layer',
  cubeIconLayerId: 'kubus_marker_cubes_icon_layer',
  locationSourceId: 'kubus_user_location',
  locationLayerId: 'kubus_user_location_layer',
);

const _controllerIds = KubusMapControllerIds(layers: _layerIds);

ArtMarker _marker({Map<String, dynamic>? metadata, String id = 'marker-1'}) =>
    ArtMarker(
      id: id,
      name: id,
      description: 'Test marker',
      position: const LatLng(46.056946, 14.505751),
      type: ArtMarkerType.artwork,
      artworkId: 'artwork-$id',
      metadata: metadata,
      createdAt: DateTime.utc(2026, 10, 13),
      createdBy: 'wallet-1',
    );

List<KubusRenderedMarker> _rendered({
  Map<String, dynamic>? metadata,
  String id = 'marker-1',
}) {
  final marker = _marker(metadata: metadata, id: id);
  return <KubusRenderedMarker>[
    KubusRenderedMarker(
      marker: marker,
      position: marker.position,
      entryScale: 1,
      entryOpacity: 1,
      entrySerial: 0,
      sameCoordinateKey: '46.056946,14.505751',
      isSpiderfied: false,
    ),
  ];
}

class _FakeMapController implements ml.MapLibreMapController {
  _FakeMapController({this.holdImage});

  final bool Function(String imageId)? holdImage;
  final Completer<String> imageEntered = Completer<String>();
  final Completer<void> releaseImage = Completer<void>();
  final Completer<void> imageReturned = Completer<void>();
  final List<String> addedImageIds = <String>[];

  @override
  Future<void> addImage(String imageId, Uint8List bytes,
      [bool sdf = false]) async {
    addedImageIds.add(imageId);
    if (holdImage?.call(imageId) == true) {
      if (!imageEntered.isCompleted) imageEntered.complete(imageId);
      await releaseImage.future;
      if (!imageReturned.isCompleted) imageReturned.complete();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLayersManager implements MapLayersManager {
  final List<Map<String, dynamic>> markerCollections = <Map<String, dynamic>>[];

  @override
  Future<bool> upsertMarkerData(Map<String, dynamic> collection) async {
    markerCollections.add(collection);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMapState implements KubusMapController {
  _FakeMapState({
    required this.registeredMapImages,
    required this.manager,
  }) : rendered = _rendered();

  @override
  final Set<String> registeredMapImages;
  final _FakeLayersManager manager;
  final List<KubusRenderedMarker> rendered;
  MapMarkerOverview? overview;
  int epoch = 7;

  @override
  KubusMapControllerIds get ids => _controllerIds;
  @override
  MapLayersManager? get layersManager => manager;
  @override
  int get styleEpoch => epoch;
  @override
  bool get cameraIsMoving => false;
  @override
  bool get hasExpandedSameLocation => false;
  @override
  String? get selectedMarkerId => overview == null ? null : 'marker-1';
  @override
  Set<String> get visibleMarkerIds =>
      rendered.map((item) => item.marker.id).toSet();
  @override
  List<KubusRenderedMarker> buildRenderedMarkers() => rendered;
  @override
  bool isMarkerTypeVisible(ArtMarkerType type) => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHost implements KubusMapMarkerSyncHost {
  _FakeHost({
    required ml.MapLibreMapController? mapController,
    required this.mapState,
  })  : _mapController = mapController,
        registeredMapImages = mapState.registeredMapImages;

  ml.MapLibreMapController? _mapController;
  final _FakeMapState mapState;
  @override
  final Set<String> registeredMapImages;
  BuildContext? context;
  MapMarkerOverview? overview;
  int sourceWrites = 0;
  int afterSyncs = 0;
  int resyncRequests = 0;
  bool mounted = true;

  @override
  ml.MapLibreMapController? get mapController => _mapController;
  @override
  bool get styleInitialized => mounted;
  @override
  bool get hostMounted => mounted;
  @override
  BuildContext get hostContext => context!;
  @override
  Set<String> get managedSourceIds => const <String>{'kubus_markers'};
  @override
  String get markerSourceId => 'kubus_markers';
  @override
  KubusMapController get kubusMapController => mapState;
  @override
  double get syncZoom => 13;
  @override
  double get clusterTopologyZoom => 13;
  @override
  MapMarkerOverview? get markerOverview => overview;
  @override
  double get clusterMaxZoom => 12;
  @override
  bool get sortClustersBySizeDesc => true;
  @override
  String get debugLabel => 'EngineTest';
  @override
  int clusterGridLevelForZoom(double zoom) => 8;
  @override
  double markerPixelRatio() => 1;
  @override
  Color resolveArtMarkerBaseColor(ArtMarker marker, ThemeProvider provider) =>
      Colors.blue;
  @override
  void onMarkerSourceWrite() => sourceWrites += 1;
  @override
  void requestMarkerResync() => resyncRequests += 1;
  @override
  Future<void> afterMarkerSync(ThemeProvider provider) async {
    afterSyncs += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BlockingFeatureEngine extends KubusMapMarkerSyncEngine {
  _BlockingFeatureEngine(super.host);

  final Completer<void> featureEntered = Completer<void>();
  final Completer<void> releaseFeature = Completer<void>();
  int _featureCalls = 0;

  @override
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
  }) async {}

  @override
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
    _featureCalls += 1;
    if (!featureEntered.isCompleted) featureEntered.complete();
    if (_featureCalls == 1) await releaseFeature.future;
    return <String, dynamic>{
      'type': 'Feature',
      'id': marker.id,
      'geometry': <String, dynamic>{
        'type': 'Point',
        'coordinates': <double>[
          marker.position.longitude,
          marker.position.latitude,
        ],
      },
      'properties': <String, dynamic>{
        'id': marker.id,
        'markerId': marker.id,
        'clusterMemberIds': <String>[marker.id],
      },
    };
  }
}

void _addCanonicalIcons(Set<String> images) {
  for (final isDark in <bool>[false, true]) {
    images.add(MapMarkerIconIds.cluster(
        categorySignature: 'artwork', label: '3', isDark: isDark));
    images
      ..add(
        MapMarkerIconIds.markerBase(
          typeName: 'artwork',
          tierName: 'subtle',
          isDark: isDark,
        ),
      )
      ..add(
        MapMarkerIconIds.markerSelected(
          typeName: 'artwork',
          tierName: 'subtle',
          isDark: isDark,
        ),
      );
  }
}

Future<ui.Image> _coverImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 8, 8),
    ui.Paint()..color = const ui.Color(0xFF336699),
  );
  return recorder.endRecording().toImage(8, 8);
}

Widget _testApp(ThemeProvider theme, ValueChanged<BuildContext> onBuild) =>
    ChangeNotifierProvider<ArtworkProvider>(
      create: (_) => ArtworkProvider(),
      child: MaterialApp(
        theme: theme.lightTheme,
        home: Builder(
          builder: (context) {
            onBuild(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cover reveal preserves identity, entry and canonical fallback',
      (tester) async {
    final images = <String>{};
    _addCanonicalIcons(images);
    final state = _FakeMapState(
        registeredMapImages: images, manager: _FakeLayersManager());
    final host =
        _FakeHost(mapController: _FakeMapController(), mapState: state);
    final theme = ThemeProvider();
    await tester
        .pumpWidget(_testApp(theme, (context) => host.context = context));
    var now = 1000;
    final engine = KubusMapMarkerSyncEngine(host, nowMs: () => now);
    addTearDown(engine.dispose);
    Future<Map<String, dynamic>> feature({bool covered = true}) =>
        engine.markerFeatureFor(
          marker: state.rendered.single.marker,
          renderMarker: state.rendered.single,
          themeProvider: theme,
          scheme: Theme.of(host.hostContext).colorScheme,
          roles: KubusColorRoles.of(host.hostContext),
          isDark: false,
          cover: covered
              ? const KubusMarkerCoverIcons(
                  base: 'cover', selected: 'cover-selected')
              : null,
        );
    final canonical = await feature(covered: false);
    for (final elapsed in <int>[0, 110, 220, 440]) {
      now = 1000 + elapsed;
      final revealed = await feature();
      expect(revealed['id'], canonical['id']);
      expect(revealed['geometry'], canonical['geometry']);
      final properties = revealed['properties'] as Map;
      final original = canonical['properties'] as Map;
      expect(properties['icon'], original['icon']);
      expect(properties['iconSelected'], original['iconSelected']);
      expect(properties['entryOpacity'], 1);
      expect(properties['entryScale'], 1);
      expect(properties['coverReveal'], (elapsed / 220).clamp(0, 1));
      expect(properties['coverIconSelected'], 'cover-selected');
    }
    final fallback = await feature(covered: false);
    expect((fallback['properties'] as Map)['icon'],
        (canonical['properties'] as Map)['icon']);
    expect((fallback['properties'] as Map).containsKey('coverReveal'), isFalse);
  });

  testWidgets('disposal invalidates pending marker work while host is mounted',
      (tester) async {
    final images = <String>{};
    _addCanonicalIcons(images);
    final manager = _FakeLayersManager();
    final state = _FakeMapState(registeredMapImages: images, manager: manager);
    final host =
        _FakeHost(mapController: _FakeMapController(), mapState: state);
    final theme = ThemeProvider();
    await tester
        .pumpWidget(_testApp(theme, (context) => host.context = context));
    final engine = _BlockingFeatureEngine(host);
    final pending = engine.syncMarkers(themeProvider: theme);
    await tester.runAsync(() =>
        engine.featureEntered.future.timeout(const Duration(seconds: 10)));
    engine.dispose();
    engine.releaseFeature.complete();
    await pending;
    expect(manager.markerCollections, isEmpty);
    expect(host.sourceWrites, 0);
    expect(host.afterSyncs, 0);
    await engine.syncMarkers(themeProvider: theme);
    expect(manager.markerCollections, isEmpty);
  });

  testWidgets(
    'detailed and overview feature work aborts after a style/controller swap',
    (tester) async {
      final images = <String>{};
      _addCanonicalIcons(images);
      final firstController = _FakeMapController();
      final manager = _FakeLayersManager();
      final state = _FakeMapState(
        registeredMapImages: images,
        manager: manager,
      );
      final host = _FakeHost(mapController: firstController, mapState: state);
      await tester.pumpWidget(_testApp(ThemeProvider(), (context) {
        host.context = context;
      }));
      final theme = ThemeProvider();

      for (final useOverview in <bool>[false, true]) {
        for (final (invalidateEpoch, replaceController) in <(bool, bool)>[
          (true, false),
          (false, true)
        ]) {
          host.overview = useOverview
              ? const MapMarkerOverview(
                  zoom: 4,
                  level: 3,
                  total: 1,
                  nodes: <MapMarkerOverviewNode>[
                    MapMarkerOverviewNode(
                      id: 'ov3:0:0',
                      position: LatLng(46.05, 14.5),
                      count: 3,
                      dominantType: 'artwork',
                    ),
                  ],
                )
              : null;
          state.overview = host.overview;
          _addCanonicalIcons(images);
          host.sourceWrites = 0;
          host.afterSyncs = 0;
          final engine = _BlockingFeatureEngine(host);
          final sync = engine.syncMarkers(themeProvider: theme);
          await tester.runAsync(
            () => engine.featureEntered.future
                .timeout(const Duration(seconds: 10)),
          );

          if (invalidateEpoch) state.epoch += 1;
          if (replaceController) host._mapController = _FakeMapController();
          images.clear(); // Mirrors style initialization clearing its registry.
          engine.releaseFeature.complete();
          await sync;

          final scenario = 'overview=$useOverview, epoch=$invalidateEpoch, '
              'controller=$replaceController';
          expect(host.sourceWrites, 0, reason: scenario);
          expect(manager.markerCollections, isEmpty, reason: scenario);
          expect(host.afterSyncs, 0, reason: scenario);
          engine.dispose();
        }
      }

      host._mapController = _FakeMapController();
      _addCanonicalIcons(images);
      final healthyEngine = _BlockingFeatureEngine(host)
        ..releaseFeature.complete();
      await healthyEngine.syncMarkers(themeProvider: theme);
      expect(healthyEngine.featureEntered.isCompleted, isTrue);
      expect(manager.markerCollections, hasLength(1));
      healthyEngine.dispose();
    },
  );

  testWidgets('cover image completion cannot poison a replacement style', (
    tester,
  ) async {
    final images = <String>{};
    _addCanonicalIcons(images);
    final controller = _FakeMapController(holdImage: MapMarkerIconIds.isCover);
    final manager = _FakeLayersManager();
    final state = _FakeMapState(
      registeredMapImages: images,
      manager: manager,
    )
      ..rendered.clear()
      ..rendered.addAll(
        _rendered(
          metadata: const <String, dynamic>{
            'imageUrl': 'https://images.example.test/cover.png',
          },
        ),
      );
    final host = _FakeHost(mapController: controller, mapState: state);
    await tester.pumpWidget(_testApp(ThemeProvider(), (context) {
      host.context = context;
    }));
    final image = await tester.runAsync(_coverImage);
    var fetchCalls = 0;
    final loader = KubusMarkerCoverLoader(
      fetch: (url, width) async {
        fetchCalls += 1;
        return image;
      },
    );
    final engine = KubusMapMarkerSyncEngine(host, coverLoader: loader);
    await engine.syncMarkers(themeProvider: ThemeProvider());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(fetchCalls, 1,
        reason: 'the visible close marker must request its cover');
    final coverId = await tester.runAsync(
      () => controller.imageEntered.future.timeout(const Duration(seconds: 10)),
    );

    state.epoch += 1;
    host._mapController = _FakeMapController();
    images.clear();
    controller.releaseImage.complete();
    await tester.runAsync(() => controller.imageReturned.future);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 30));

    expect(coverId, startsWith('mc_'));
    expect(images, isEmpty);
    expect(engine.coverImagesRegistered, 0);
    engine.dispose();
  });

  testWidgets('a later same-style sync supersedes an older feature build', (
    tester,
  ) async {
    final manager = _FakeLayersManager();
    final state = _FakeMapState(
      registeredMapImages: <String>{},
      manager: manager,
    );
    final host =
        _FakeHost(mapController: _FakeMapController(), mapState: state);
    await tester.pumpWidget(_testApp(ThemeProvider(), (context) {
      host.context = context;
    }));

    final engine = _BlockingFeatureEngine(host);
    final olderSync = engine.syncMarkers(themeProvider: ThemeProvider());
    await tester.runAsync(
      () => engine.featureEntered.future.timeout(const Duration(seconds: 10)),
    );

    state.rendered
      ..clear()
      ..addAll(_rendered(id: 'marker-b'));
    final newerSync = engine.syncMarkers(themeProvider: ThemeProvider());
    await newerSync;
    expect(
      (manager.markerCollections.last['features']! as List)
          .cast<Map<String, dynamic>>()
          .single['properties']['markerId'],
      'marker-b',
    );

    engine.releaseFeature.complete();
    await olderSync;
    expect(manager.markerCollections, hasLength(1));
    expect(
      (manager.markerCollections.last['features']! as List)
          .cast<Map<String, dynamic>>()
          .single['properties']['markerId'],
      'marker-b',
      reason: 'the old same-epoch feature build must not overwrite newer data',
    );
    engine.dispose();
  });
}
