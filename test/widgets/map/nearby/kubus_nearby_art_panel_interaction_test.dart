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

  testWidgets('nearby panel radius button and artwork list item callbacks fire',
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
            travelModeEnabled: false,
            radiusKm: 2,
            onRadiusTap: () => radiusTapCount += 1,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.radar));
    await tester.pump();

    await tester.tap(find.text('Nearby Artwork'));
    await tester.pumpAndSettle();

    expect(radiusTapCount, 1);
    expect(mapDelegate.selectedMarker?.id, marker.id);
    expect(mapDelegate.animateCallCount, 1);
    expect(mapDelegate.lastAnimatedTarget, marker.position);
  });

  testWidgets('nearby panel desktop close button callback fires',
      (tester) async {
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
            travelModeEnabled: false,
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

  testWidgets('nearby panel mobile handle is decorative for semantics',
      (tester) async {
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
            travelModeEnabled: false,
            radiusKm: 2,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('nearby_art_handle'), findsNothing);
    expect(find.bySemanticsLabel('Nearby art and places'),
        findsAtLeastNWidgets(1));
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
    expect(
      tester.getSemantics(finder).flagsCollection.isLiveRegion,
      isTrue,
    );

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
    expect(
      tester.getSemantics(finder).flagsCollection.isLiveRegion,
      isTrue,
    );

    semantics.dispose();
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
