import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/email_preferences_provider.dart';
import 'package:art_kubus/providers/glass_capabilities_provider.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/navigation_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/platform_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/stats_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:art_kubus/screens/settings_screen.dart';
import 'package:art_kubus/screens/web3/wallet/token_swap.dart';
import 'package:art_kubus/screens/web3/wallet/wallet_home.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _buildWalletToken(String walletAddress) {
  final header =
      base64Url.encode(utf8.encode(jsonEncode(<String, String>{'alg': 'none'})));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, String>{'walletAddress': walletAddress}),
    ),
  );
  return '$header.$payload.signature';
}

Future<
    ({
      ThemeProvider themeProvider,
      ProfileProvider profileProvider,
      WalletProvider walletProvider,
      Web3Provider web3Provider,
      PlatformProvider platformProvider,
      NotificationProvider notificationProvider,
      NavigationProvider navigationProvider,
      LocaleProvider localeProvider,
      StatsProvider statsProvider,
      SecurityGateProvider securityGateProvider,
      GlassCapabilitiesProvider glassCapabilitiesProvider,
      String walletAddress,
    })> _createTestProviders({
  bool withSigner = true,
  bool withAuthenticatedSession = true,
  String? lastSignInMethod,
}) async {
  final solanaWalletService = SolanaWalletService();
  final mnemonic = solanaWalletService.generateMnemonic();
  final derived = await solanaWalletService.derivePreferredKeyPair(mnemonic);
  if (withSigner) {
    solanaWalletService.setActiveKeyPair(derived.hdKeyPair);
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('wallet_address', derived.address);
  await prefs.setString('walletAddress', derived.address);
  await prefs.setString('wallet', derived.address);
  await prefs.setBool('has_wallet', true);
  if ((lastSignInMethod ?? '').isNotEmpty) {
    await prefs.setString(
      PreferenceKeys.authLastSignInMethodV1,
      lastSignInMethod!,
    );
  }

  final themeProvider = ThemeProvider();
  final profileProvider = ProfileProvider();
  await profileProvider.initialize();

  final walletProvider = WalletProvider(
    solanaWalletService: solanaWalletService,
    deferInit: true,
  );
  walletProvider.setCurrentWalletAddressForTesting(derived.address);

  final web3Provider = Web3Provider(solanaWalletService: solanaWalletService)
    ..bindWalletProvider(walletProvider);
  final platformProvider = PlatformProvider();
  final notificationProvider = NotificationProvider();
  final navigationProvider = NavigationProvider();
  final localeProvider = LocaleProvider();
  final statsProvider = StatsProvider();
  final securityGateProvider = SecurityGateProvider()
    ..bindDependencies(
      profileProvider: profileProvider,
      walletProvider: walletProvider,
      notificationProvider: notificationProvider,
    );
  final glassCapabilitiesProvider = GlassCapabilitiesProvider();

  if (withAuthenticatedSession) {
    BackendApiService().setAuthTokenForTesting(_buildWalletToken(derived.address));
  }

  return (
    themeProvider: themeProvider,
    profileProvider: profileProvider,
    walletProvider: walletProvider,
    web3Provider: web3Provider,
    platformProvider: platformProvider,
    notificationProvider: notificationProvider,
    navigationProvider: navigationProvider,
    localeProvider: localeProvider,
    statsProvider: statsProvider,
    securityGateProvider: securityGateProvider,
    glassCapabilitiesProvider: glassCapabilitiesProvider,
    walletAddress: derived.address,
  );
}

Widget _wrapWithApp({
  required Widget home,
  required ThemeProvider themeProvider,
  required ProfileProvider profileProvider,
  required WalletProvider walletProvider,
  required Web3Provider web3Provider,
  required PlatformProvider platformProvider,
  required NotificationProvider notificationProvider,
  required NavigationProvider navigationProvider,
  required LocaleProvider localeProvider,
  required StatsProvider statsProvider,
  required SecurityGateProvider securityGateProvider,
  required GlassCapabilitiesProvider glassCapabilitiesProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: themeProvider),
      ChangeNotifierProvider.value(value: profileProvider),
      ChangeNotifierProvider.value(value: walletProvider),
      ChangeNotifierProvider.value(value: web3Provider),
      ChangeNotifierProvider.value(value: platformProvider),
      ChangeNotifierProvider.value(value: notificationProvider),
      ChangeNotifierProvider.value(value: navigationProvider),
      ChangeNotifierProvider.value(value: localeProvider),
      ChangeNotifierProvider.value(value: statsProvider),
      ChangeNotifierProvider.value(value: securityGateProvider),
      ChangeNotifierProvider.value(value: glassCapabilitiesProvider),
      ChangeNotifierProvider(
        create: (_) =>
            EmailPreferencesProvider(backendApi: BackendApiService()),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routes: {
        '/connect-wallet': (_) => const Scaffold(
              body: Center(child: Text('connect-wallet')),
            ),
      },
      home: home,
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 8}) async {
  for (var i = 0; i < count; i += 1) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setPreferredWalletAddress(null);
    BackendApiService().setHttpClient(
      MockClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true, 'data': <String, dynamic>{}}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );
  });

  tearDown(() {
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  testWidgets(
      'mobile settings disconnect keeps wallet identity in read-only mode',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = await _createTestProviders();

    await tester.pumpWidget(
      _wrapWithApp(
        home: const SettingsScreen(),
        themeProvider: providers.themeProvider,
        profileProvider: providers.profileProvider,
        walletProvider: providers.walletProvider,
        web3Provider: providers.web3Provider,
        platformProvider: providers.platformProvider,
        notificationProvider: providers.notificationProvider,
        navigationProvider: providers.navigationProvider,
        localeProvider: providers.localeProvider,
        statsProvider: providers.statsProvider,
        securityGateProvider: providers.securityGateProvider,
        glassCapabilitiesProvider: providers.glassCapabilitiesProvider,
      ),
    );
    await _pumpFrames(tester);

    final disconnectTile =
        find.byKey(const Key('settings_tile_wallet_connection'));
    await tester.scrollUntilVisible(disconnectTile, 500);
    await tester.tap(disconnectTile);
    await _pumpFrames(tester);

    expect(providers.walletProvider.hasWalletIdentity, isTrue);
    expect(providers.walletProvider.isReadOnlySession, isTrue);
    expect(find.text('Read-only wallet session'), findsOneWidget);
  });

  testWidgets(
      'desktop settings disconnect keeps wallet identity in read-only mode',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = await _createTestProviders();

    await tester.pumpWidget(
      _wrapWithApp(
        home: const DesktopSettingsScreen(),
        themeProvider: providers.themeProvider,
        profileProvider: providers.profileProvider,
        walletProvider: providers.walletProvider,
        web3Provider: providers.web3Provider,
        platformProvider: providers.platformProvider,
        notificationProvider: providers.notificationProvider,
        navigationProvider: providers.navigationProvider,
        localeProvider: providers.localeProvider,
        statsProvider: providers.statsProvider,
        securityGateProvider: providers.securityGateProvider,
        glassCapabilitiesProvider: providers.glassCapabilitiesProvider,
      ),
    );
    await _pumpFrames(tester, count: 10);

    final disconnectTile =
        find.byKey(const Key('desktop_settings_wallet_disconnect'));
    await tester.scrollUntilVisible(disconnectTile, 300);
    await tester.tap(disconnectTile);
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Disconnect'));
    await _pumpFrames(tester);

    expect(providers.walletProvider.hasWalletIdentity, isTrue);
    expect(providers.walletProvider.isReadOnlySession, isTrue);
    expect(find.text('Reconnect'), findsOneWidget);
  });

  testWidgets('read-only wallet home reroutes send and swap to reconnect',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = await _createTestProviders(withSigner: false);

    await tester.pumpWidget(
      _wrapWithApp(
        home: const WalletHome(),
        themeProvider: providers.themeProvider,
        profileProvider: providers.profileProvider,
        walletProvider: providers.walletProvider,
        web3Provider: providers.web3Provider,
        platformProvider: providers.platformProvider,
        notificationProvider: providers.notificationProvider,
        navigationProvider: providers.navigationProvider,
        localeProvider: providers.localeProvider,
        statsProvider: providers.statsProvider,
        securityGateProvider: providers.securityGateProvider,
        glassCapabilitiesProvider: providers.glassCapabilitiesProvider,
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('Reconnect to enable signing and transfers.'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('wallet_home_action_send')));
    await _pumpFrames(tester, count: 4);
    expect(find.text('connect-wallet'), findsOneWidget);

    await tester.pageBack();
    await _pumpFrames(tester, count: 4);

    await tester.tap(find.byKey(const Key('wallet_home_action_swap')));
    await _pumpFrames(tester, count: 4);
    expect(find.text('connect-wallet'), findsOneWidget);
  });

  testWidgets(
      'managed read-only wallet home reconnect stays in-app for email/google sessions',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = await _createTestProviders(
      withSigner: false,
      lastSignInMethod: 'email',
    );

    await tester.pumpWidget(
      _wrapWithApp(
        home: const WalletHome(),
        themeProvider: providers.themeProvider,
        profileProvider: providers.profileProvider,
        walletProvider: providers.walletProvider,
        web3Provider: providers.web3Provider,
        platformProvider: providers.platformProvider,
        notificationProvider: providers.notificationProvider,
        navigationProvider: providers.navigationProvider,
        localeProvider: providers.localeProvider,
        statsProvider: providers.statsProvider,
        securityGateProvider: providers.securityGateProvider,
        glassCapabilitiesProvider: providers.glassCapabilitiesProvider,
      ),
    );
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('wallet_home_action_send')));
    await _pumpFrames(tester, count: 4);

    expect(find.text('connect-wallet'), findsNothing);
  });

  testWidgets('token swap screen shows reconnect prompt in read-only mode',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = await _createTestProviders(withSigner: false);

    await tester.pumpWidget(
      _wrapWithApp(
        home: const TokenSwap(),
        themeProvider: providers.themeProvider,
        profileProvider: providers.profileProvider,
        walletProvider: providers.walletProvider,
        web3Provider: providers.web3Provider,
        platformProvider: providers.platformProvider,
        notificationProvider: providers.notificationProvider,
        navigationProvider: providers.navigationProvider,
        localeProvider: providers.localeProvider,
        statsProvider: providers.statsProvider,
        securityGateProvider: providers.securityGateProvider,
        glassCapabilitiesProvider: providers.glassCapabilitiesProvider,
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('Read-only wallet session'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Reconnect'));
    await _pumpFrames(tester, count: 4);

    expect(find.text('connect-wallet'), findsOneWidget);
  });
}
