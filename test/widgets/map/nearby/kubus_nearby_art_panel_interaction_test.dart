import 'package:art_kubus/features/map/controller/kubus_map_controller.dart';
import 'package:art_kubus/features/map/nearby/nearby_art_controller.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/widgets/map/nearby/kubus_nearby_art_panel.dart';
import 'package:art_kubus/widgets/map/nearby/kubus_nearby_art_panel_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('nearby sheet snaps stay unique when the measured minimum reaches max',
      () {
    final bounds = KubusNearbyArtSheetExtentBounds(
      availableHeight: 100,
      headerHeight: 95,
    );

    expect(bounds.minExtent, 0.85);
    expect(bounds.snapSizes, <double>[0.85]);
  });

  testWidgets(
    'nearby panel radius button and artwork list item callbacks fire',
    (tester) async {
      final mapDelegate = _FakeNearbyMapDelegate();
      final controller = NearbyArtController(map: mapDelegate);
      var radiusTapCount = 0;

      final artwork = _artwork();
      final marker = _marker(artworkId: artwork.id);

      await tester.pumpWidget(
        _buildApp(
          SizedBox(
            width: 420,
            height: 640,
            child: KubusNearbyArtPanel(
              controller: controller,
              layout: KubusNearbyArtPanelLayout.mobileBottomSheet,
              artworks: <Artwork>[artwork],
              markers: <ArtMarker>[marker],
              basePosition: const LatLng(46.0569, 14.5058),
              isLoading: false,
              viewportScope: false,
              radiusKm: 2,
              onRadiusTap: () => radiusTapCount += 1,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('KUB8'), findsNothing);

      // Mobile header controls are flat 48px map-chrome targets.
      final radarTarget = tester.getSize(
        find
            .ancestor(
              of: find.byIcon(Icons.radar),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(radarTarget.width, greaterThanOrEqualTo(48));
      expect(radarTarget.height, greaterThanOrEqualTo(48));

      await tester.tap(find.byIcon(Icons.radar));
      await tester.pump();

      await tester.tap(find.text('Nearby Artwork'));
      await tester.pumpAndSettle();

      expect(radiusTapCount, 1);
      expect(mapDelegate.selectedMarker?.id, marker.id);
      expect(mapDelegate.animateCallCount, 1);
      expect(mapDelegate.lastAnimatedTarget, marker.position);
    },
  );

  testWidgets(
    'measured mobile header stays above navigation across compact resizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      final controller = NearbyArtController(map: _FakeNearbyMapDelegate());
      final headerKey = GlobalKey();
      final hostKey = GlobalKey<_MeasuredNearbySheetHostState>();

      Future<void> showViewport(Size size, double textScale) async {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          _buildApp(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(textScale),
              ),
              child: _MeasuredNearbySheetHost(
                key: hostKey,
                controller: controller,
                headerKey: headerKey,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await showViewport(const Size(320, 700), 1);
      final state = hostKey.currentState!;
      final firstController = state.sheetController;
      _expectHeaderFits(tester, headerKey, const Size(320, 700), 64);
      expect(state.sheetController.isAttached, isTrue);

      await tester.tap(find.byKey(const ValueKey<String>('unrelated-state')));
      await tester.pumpAndSettle();
      expect(state.sheetController, same(firstController));
      expect(state.sheetController.isAttached, isTrue);

      final expand = state.sheetController.animateTo(
        0.50,
        duration: const Duration(milliseconds: 1),
        curve: Curves.linear,
      );
      await tester.pumpAndSettle();
      await expand;
      expect(state.sheetController.size, closeTo(0.50, 0.001));

      await showViewport(const Size(852, 393), 1.5);
      _expectHeaderFits(tester, headerKey, const Size(852, 393), 64);
      expect(state.sheetController, same(firstController));
      expect(state.sheetController.isAttached, isTrue);
      if (state.minExtent <= 0.50) {
        expect(state.sheetController.size, closeTo(0.50, 0.001));
      } else {
        expect(
          state.sheetController.size,
          greaterThanOrEqualTo(state.minExtent),
        );
      }

      final collapse = state.sheetController.animateTo(
        state.minExtent,
        duration: const Duration(milliseconds: 1),
        curve: Curves.linear,
      );
      await tester.pumpAndSettle();
      await collapse;
      await showViewport(const Size(320, 700), 1);
      _expectHeaderFits(tester, headerKey, const Size(320, 700), 64);
      expect(state.sheetController.size, closeTo(state.minExtent, 0.001));
      expect(state.snapSizes, orderedEquals(state.snapSizes.toSet().toList()));
      expect(state.snapSizes.first, state.minExtent);
      expect(state.snapSizes, everyElement(inInclusiveRange(0.12, 0.85)));
      expect(state.sheetController.isAttached, isTrue);

      await showViewport(const Size(320, 700), 2);
      _expectHeaderFits(tester, headerKey, const Size(320, 700), 64);
      expect(state.sheetController, same(firstController));
      expect(state.sheetController.isAttached, isTrue);
      expect(
        state.sheetController.size,
        greaterThanOrEqualTo(state.minExtent),
      );
    },
  );

  testWidgets('nearby panel desktop close button callback fires', (
    tester,
  ) async {
    final mapDelegate = _FakeNearbyMapDelegate();
    final controller = NearbyArtController(map: mapDelegate);
    var closeTapCount = 0;

    await tester.pumpWidget(
      _buildApp(
        SizedBox(
          width: 420,
          height: 640,
          child: KubusNearbyArtPanel(
            controller: controller,
            layout: KubusNearbyArtPanelLayout.desktopSidePanel,
            artworks: <Artwork>[_artwork()],
            markers: const <ArtMarker>[],
            basePosition: const LatLng(46.0569, 14.5058),
            isLoading: false,
            viewportScope: false,
            radiusKm: 2,
            onClose: () => closeTapCount += 1,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(closeTapCount, 1);
  });

  testWidgets(
    'nearby artwork with a spatial archive shows the subtle 3D badge',
    (tester) async {
      final controller = NearbyArtController(map: _FakeNearbyMapDelegate());
      final artwork = _artwork().copyWith(spatialCaptureCount: 2);
      await tester.pumpWidget(
        _buildApp(
          SizedBox(
            width: 420,
            height: 640,
            child: KubusNearbyArtPanel(
              controller: controller,
              layout: KubusNearbyArtPanelLayout.mobileBottomSheet,
              artworks: <Artwork>[artwork],
              markers: <ArtMarker>[_marker(artworkId: artwork.id)],
              basePosition: const LatLng(46.0569, 14.5058),
              isLoading: false,
              viewportScope: false,
              radiusKm: 2,
              onRadiusTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.threed_rotation_rounded), findsOneWidget);
    },
  );

  testWidgets('nearby panel mobile handle is decorative for semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final mapDelegate = _FakeNearbyMapDelegate();
    final controller = NearbyArtController(map: mapDelegate);

    await tester.pumpWidget(
      _buildApp(
        SizedBox(
          width: 420,
          height: 640,
          child: KubusNearbyArtPanel(
            controller: controller,
            layout: KubusNearbyArtPanelLayout.mobileBottomSheet,
            artworks: <Artwork>[_artwork()],
            markers: const <ArtMarker>[],
            basePosition: const LatLng(46.0569, 14.5058),
            isLoading: false,
            viewportScope: false,
            radiusKm: 2,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('nearby_art_handle'), findsNothing);
    expect(
      find.bySemanticsLabel('Nearby art and places'),
      findsAtLeastNWidgets(1),
    );
    semantics.dispose();
  });

  testWidgets('nearby loading state announces a live region', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _buildApp(
        const SizedBox(
          width: 420,
          height: 320,
          child: KubusNearbyArtLoadingState(),
        ),
      ),
    );

    final finder = find.bySemanticsLabel('Loading: Nearby art and places');
    expect(finder, findsOneWidget);
    expect(tester.getSemantics(finder).flagsCollection.isLiveRegion, isTrue);

    semantics.dispose();
  });

  testWidgets('nearby empty state announces a live region', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _buildApp(
        const SizedBox(
          width: 420,
          height: 320,
          child: KubusNearbyArtEmptyState(),
        ),
      ),
    );

    final finder = find.bySemanticsLabel(
      'No nearby cultural markers. '
      'Explore different areas or adjust your filters to discover art around you.',
    );
    expect(finder, findsOneWidget);
    expect(tester.getSemantics(finder).flagsCollection.isLiveRegion, isTrue);

    semantics.dispose();
  });

  testWidgets('a reload keeps the rows on screen, and the same row element',
      (tester) async {
    final mapDelegate = _FakeNearbyMapDelegate();
    final controller = NearbyArtController(map: mapDelegate);
    final artwork = _artwork();
    final marker = _marker(artworkId: artwork.id);

    Widget panel({required bool isLoading}) => _buildApp(
          SizedBox(
            width: 420,
            height: 640,
            child: KubusNearbyArtPanel(
              controller: controller,
              layout: KubusNearbyArtPanelLayout.mobileBottomSheet,
              artworks: <Artwork>[artwork],
              markers: <ArtMarker>[marker],
              basePosition: const LatLng(46.0569, 14.5058),
              isLoading: isLoading,
              viewportScope: false,
              radiusKm: 2,
            ),
          ),
        );

    await tester.pumpWidget(panel(isLoading: false));
    await tester.pumpAndSettle();
    final row = tester.element(find.text('Nearby Artwork'));

    await tester.pumpWidget(panel(isLoading: true));
    await tester.pump();

    expect(find.text('Nearby Artwork'), findsOneWidget);
    expect(find.byType(KubusNearbyArtLoadingState), findsNothing);
    expect(tester.element(find.text('Nearby Artwork')), same(row));
  });
}

Widget _buildApp(Widget child) {
  return ChangeNotifierProvider<ThemeProvider>(
    create: (_) => ThemeProvider(),
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    ),
  );
}

class _MeasuredNearbySheetHost extends StatefulWidget {
  const _MeasuredNearbySheetHost({
    super.key,
    required this.controller,
    required this.headerKey,
  });

  final NearbyArtController controller;
  final GlobalKey headerKey;

  @override
  State<_MeasuredNearbySheetHost> createState() =>
      _MeasuredNearbySheetHostState();
}

class _MeasuredNearbySheetHostState extends State<_MeasuredNearbySheetHost> {
  static const double _reservedBottom = 64;
  final DraggableScrollableController sheetController =
      DraggableScrollableController();
  double minExtent = KubusNearbyArtSheetExtentBounds.baselineMinExtent;
  List<double> snapSizes = const <double>[0.12, 0.24, 0.50];
  bool _measurementScheduled = false;
  Size? _pendingViewport;
  int _unrelatedRevision = 0;

  @override
  void dispose() {
    sheetController.dispose();
    super.dispose();
  }

  void _scheduleMeasurement(Size viewport) {
    _pendingViewport = viewport;
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      final renderObject = widget.headerKey.currentContext?.findRenderObject();
      final latestViewport = _pendingViewport;
      if (renderObject is! RenderBox ||
          !renderObject.hasSize ||
          latestViewport == null) {
        return;
      }
      final bounds = KubusNearbyArtSheetExtentBounds(
        availableHeight: latestViewport.height - _reservedBottom,
        headerHeight: renderObject.size.height,
      );
      if ((bounds.minExtent - minExtent).abs() < 0.0001) return;
      final previousMinimum = minExtent;
      final previousExtent =
          sheetController.isAttached ? sheetController.size : minExtent;
      final wasCollapsed = previousExtent <= previousMinimum + 0.0001;
      setState(() {
        minExtent = bounds.minExtent;
        snapSizes = bounds.snapSizes;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !sheetController.isAttached) return;
        if (wasCollapsed &&
            bounds.minExtent < previousMinimum &&
            sheetController.size > bounds.minExtent + 0.0001) {
          sheetController.jumpTo(bounds.minExtent);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleMeasurement(Size(constraints.maxWidth, constraints.maxHeight));
        return Stack(
          children: [
            Positioned.fill(
              bottom: _reservedBottom,
              child: DraggableScrollableSheet(
                key: const ValueKey<String>('stable-nearby-sheet'),
                controller: sheetController,
                initialChildSize: minExtent,
                minChildSize: minExtent,
                maxChildSize: KubusNearbyArtSheetExtentBounds.maxExtent,
                snap: true,
                snapSizes: snapSizes,
                builder: (context, scrollController) => KubusNearbyArtPanel(
                  controller: widget.controller,
                  layout: KubusNearbyArtPanelLayout.mobileBottomSheet,
                  artworks: <Artwork>[_artwork()],
                  markers: const <ArtMarker>[],
                  basePosition: const LatLng(46.0569, 14.5058),
                  isLoading: false,
                  viewportScope: false,
                  radiusKm: 2,
                  headerMeasurementKey: widget.headerKey,
                  onRadiusTap: () {},
                  scrollController: scrollController,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: TextButton(
                key: const ValueKey<String>('unrelated-state'),
                onPressed: () => setState(() => _unrelatedRevision++),
                child: Text('Refresh $_unrelatedRevision'),
              ),
            ),
          ],
        );
      },
    );
  }
}

void _expectHeaderFits(
  WidgetTester tester,
  GlobalKey headerKey,
  Size viewport,
  double reservedBottom,
) {
  final headerRect = tester.getRect(find.byKey(headerKey));
  expect(headerRect.top, greaterThanOrEqualTo(0));
  expect(headerRect.bottom,
      lessThanOrEqualTo(viewport.height - reservedBottom + 0.5));
}

Artwork _artwork() {
  return Artwork(
    id: 'art-1',
    title: 'Nearby Artwork',
    artist: 'Artist',
    description: 'Description',
    position: const LatLng(46.0569, 14.5058),
    rewards: 8,
    createdAt: DateTime(2024, 1, 1),
    category: 'Painting',
  );
}

ArtMarker _marker({required String artworkId}) {
  return ArtMarker(
    id: 'marker-1',
    name: 'Nearby Marker',
    description: 'Marker description',
    position: const LatLng(46.0570, 14.5059),
    artworkId: artworkId,
    type: ArtMarkerType.artwork,
    createdAt: DateTime(2024, 1, 1),
    createdBy: 'tester',
  );
}

class _FakeNearbyMapDelegate implements NearbyArtMapDelegate {
  @override
  void selectMarkerWhenLoaded(
    ArtMarker? Function(List<ArtMarker> markers) resolve,
  ) {}

  ArtMarker? selectedMarker;
  int animateCallCount = 0;
  LatLng? lastAnimatedTarget;

  @override
  KubusMapCameraState get camera => const KubusMapCameraState(
        center: LatLng(46.0569, 14.5058),
        zoom: 14,
        bearing: 0,
        pitch: 0,
      );

  @override
  Future<void> animateTo(
    LatLng target, {
    double? zoom,
    double? rotation,
    double? tilt,
    Duration duration = const Duration(milliseconds: 360),
    double? compositionYOffsetPx,
  }) async {
    animateCallCount += 1;
    lastAnimatedTarget = target;
  }

  @override
  void selectMarker(
    ArtMarker marker, {
    List<ArtMarker>? stackedMarkers,
    int? stackIndex,
  }) {
    selectedMarker = marker;
  }
}
