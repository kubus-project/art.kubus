@TestOn('browser')
library;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
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
import 'package:art_kubus/screens/desktop/desktop_map_screen.dart';
import 'package:art_kubus/screens/map_screen.dart';
import 'package:art_kubus/widgets/map/kubus_map_chrome.dart';
import 'package:art_kubus/widgets/art_map_view.dart';
import 'package:art_kubus/widgets/map/nearby/kubus_nearby_art_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
