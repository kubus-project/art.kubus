@TestOn('browser')
library;

import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/providers/activation_prompt_provider.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/events_provider.dart';
import 'package:art_kubus/providers/exhibitions_provider.dart';
import 'package:art_kubus/providers/main_tab_provider.dart';
import 'package:art_kubus/providers/map_deep_link_provider.dart';
import 'package:art_kubus/providers/marker_management_provider.dart';
import 'package:art_kubus/providers/navigation_provider.dart';
import 'package:art_kubus/providers/presence_provider.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/tile_providers.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/public_fallback_service.dart';
import 'package:art_kubus/utils/geo_bounds.dart';
import 'package:art_kubus/screens/desktop/desktop_map_screen.dart';
import 'package:art_kubus/screens/map_screen.dart';
import 'package:art_kubus/widgets/map/kubus_map_chrome.dart';
import 'package:art_kubus/widgets/art_map_view.dart';
import 'package:art_kubus/widgets/map/nearby/kubus_nearby_art_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

Widget _wrapWithProviders({
  required Widget child,
  required Size size,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => ArtworkProvider()),
      ChangeNotifierProvider(create: (_) => TaskProvider()),
      ChangeNotifierProvider(create: (_) => WalletProvider()),
      ChangeNotifierProvider(create: (_) => MainTabProvider()),
      ChangeNotifierProvider(create: (_) => MapDeepLinkProvider()),
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(create: (_) => ExhibitionsProvider()),
      ChangeNotifierProvider(create: (_) => EventsProvider()),
      ChangeNotifierProvider(
        create: (_) => ActivationPromptProvider(hasAuthSession: () => false),
      ),
      ChangeNotifierProvider(create: (_) => MarkerManagementProvider()),
      ChangeNotifierProvider(create: (_) => PresenceProvider()),
      Provider<TileProviders>(
        create: (context) => TileProviders(context.read<ThemeProvider>()),
        dispose: (_, value) => value.dispose(),
      ),
    ],
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
}

void main() {
  group('mounted map fallback revocation', () {
    setUp(() async {
      await PublicFallbackService().resetForTesting();
      BackendApiService().setAuthTokenForTesting(null);
      BackendApiService().setHttpClient(
        MockClient((_) async {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'version': 1,
              'zoom': 4,
              'level': 8,
              'total': 401,
              'count': 1,
              'data': <Object?>[
                <String, Object?>{
                  'id': 'ov8:130:75',
                  'lat': 48.2,
                  'lng': 16.37,
                  'count': 401,
                  'dominantType': 'artwork',
                  'types': <String, int>{'artwork': 401},
                },
              ],
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }),
      );
    });

    tearDown(() async {
      await PublicFallbackService().resetForTesting();
      BackendApiService().setHttpClient(http.Client());
    });

    Future<void> verifyCleared(
      WidgetTester tester, {
      required Widget mapScreen,
      required Type screenType,
      required Size size,
      required bool keepOverviewForHandoff,
    }) async {
      await tester.pumpWidget(
        _wrapWithProviders(child: mapScreen, size: size),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      final dynamic state = tester.state(find.byType(screenType));
      final marker = ArtMarker(
        id: 'synthetic-fallback-live-marker',
        name: 'Synthetic live marker',
        description: 'Fallback revocation test fixture',
        position: const ll.LatLng(46.0569, 14.5058),
        type: ArtMarkerType.artwork,
        artworkId: 'synthetic-artwork',
        createdAt: DateTime.utc(2026, 10, 23),
        createdBy: 'synthetic-test',
      );
      state.debugSetLoadedMarkersForTest(<ArtMarker>[marker]);
      expect(
        state.debugMarkerSourceInputIdsForTest,
        <String>['synthetic-fallback-live-marker'],
      );

      const bounds = GeoBounds(
        south: 33.3,
        west: -38.6,
        north: 68.4,
        east: 66.6,
      );
      await state.debugLoadOverviewForTest(
        bounds: bounds,
        zoom: 4.0,
        keepForHandoff: keepOverviewForHandoff,
      );
      expect(state.debugHasDrawableOverviewForTest, isTrue);

      for (var i = 0; i < AppConfig.backendOutageFailureThreshold; i++) {
        PublicFallbackService().recordDualBackendFailure();
      }
      expect(PublicFallbackService().isIpfsFallbackMode, isTrue);
      await tester.pump();

      expect(state.debugMarkerSourceInputIdsForTest, isEmpty);
      expect(state.debugHasDrawableOverviewForTest, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    }

    testWidgets('mobile clears loaded marker source and active overview',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(420, 820);
      addTearDown(tester.view.resetPhysicalSize);
      await verifyCleared(
        tester,
        mapScreen: const MapScreen(
          initialCenter: ll.LatLng(46.05, 14.51),
          initialZoom: 12,
          autoFollow: false,
        ),
        screenType: MapScreen,
        size: const Size(420, 820),
        keepOverviewForHandoff: false,
      );
    });

    testWidgets('desktop clears loaded marker source and overview handoff',
        (tester) async {
      await verifyCleared(
        tester,
        mapScreen: const DesktopMapScreen(
          initialCenter: ll.LatLng(46.05, 14.51),
          initialZoom: 12,
          autoFollow: false,
        ),
        screenType: DesktopMapScreen,
        size: const Size(1280, 900),
        keepOverviewForHandoff: true,
      );
    });
  });

  testWidgets('MapScreen mounts on web without exceptions', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 820);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      _wrapWithProviders(
        size: const Size(420, 820),
        child: const MapScreen(
          initialCenter: ll.LatLng(46.05, 14.51),
          initialZoom: 12,
          autoFollow: false,
        ),
      ),
    );

    // Allow a couple of frames for post-frame callbacks; MapScreen is guarded
    // to avoid starting platform services in widget tests.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(MapScreen), findsOneWidget);
    final renderedMap = tester.widget<ArtMapView>(find.byType(ArtMapView));
    expect(renderedMap.initialCenter, const ll.LatLng(46.05, 14.51));
    expect(renderedMap.initialZoom, 12);
    final credit = tester.getRect(find.byType(KubusMapAttributionControl));
    final nearbyPanel = tester.getRect(find.byType(KubusNearbyArtPanel));
    expect(
      nearbyPanel.top - credit.bottom,
      closeTo(14, 1),
      reason: 'the rendered info target stays 14px above the Nearby sheet',
    );
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('DesktopMapScreen mounts on web without exceptions',
      (tester) async {
    await tester.pumpWidget(
      _wrapWithProviders(
        size: const Size(1280, 900),
        child: const DesktopMapScreen(
          initialCenter: ll.LatLng(46.05, 14.51),
          initialZoom: 12,
          autoFollow: false,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(DesktopMapScreen), findsOneWidget);
    final renderedMap = tester.widget<ArtMapView>(find.byType(ArtMapView));
    expect(renderedMap.initialCenter, const ll.LatLng(46.05, 14.51));
    expect(renderedMap.initialZoom, 12);
  });

  testWidgets('a mounted mobile map applies the updated route camera', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 820);
    addTearDown(tester.view.resetPhysicalSize);
    var center = const ll.LatLng(46.05, 14.51);
    var zoom = 12.0;
    late StateSetter updateCamera;

    await tester.pumpWidget(
      _wrapWithProviders(
        size: const Size(420, 820),
        child: StatefulBuilder(
          builder: (context, setState) {
            updateCamera = setState;
            return MapScreen(
              initialCenter: center,
              initialZoom: zoom,
              autoFollow: false,
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    updateCamera(() {
      center = const ll.LatLng(47.12, 15.04);
      zoom = 9;
    });
    await tester.pump();

    final renderedMap = tester.widget<ArtMapView>(find.byType(ArtMapView));
    expect(renderedMap.initialCenter, center);
    expect(renderedMap.initialZoom, zoom);
  });

  testWidgets('a mounted desktop map applies the updated route camera', (
    tester,
  ) async {
    var center = const ll.LatLng(46.05, 14.51);
    var zoom = 12.0;
    late StateSetter updateCamera;

    await tester.pumpWidget(
      _wrapWithProviders(
        size: const Size(1280, 900),
        child: StatefulBuilder(
          builder: (context, setState) {
            updateCamera = setState;
            return DesktopMapScreen(
              initialCenter: center,
              initialZoom: zoom,
              autoFollow: false,
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    updateCamera(() {
      center = const ll.LatLng(47.12, 15.04);
      zoom = 9;
    });
    await tester.pump();

    final renderedMap = tester.widget<ArtMapView>(find.byType(ArtMapView));
    expect(renderedMap.initialCenter, center);
    expect(renderedMap.initialZoom, zoom);
  });
}
