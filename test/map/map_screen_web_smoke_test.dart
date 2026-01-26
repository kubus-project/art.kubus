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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await tester.pumpWidget(
      _wrapWithProviders(
        size: const Size(420, 820),
        child: const MapScreen(),
      ),
    );

    // Allow a couple of frames for post-frame callbacks; MapScreen is guarded
    // to avoid starting platform services in widget tests.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(MapScreen), findsOneWidget);
  });

  testWidgets('DesktopMapScreen mounts on web without exceptions', (tester) async {
    await tester.pumpWidget(
      _wrapWithProviders(
        size: const Size(1280, 900),
        child: const DesktopMapScreen(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(DesktopMapScreen), findsOneWidget);
  });
}

