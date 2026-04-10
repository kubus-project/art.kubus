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
import 'package:art_kubus/models/user_profile.dart';
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
  profileProvider.setCurrentUser(
    UserProfile(
      id: 'profile_${derived.address.substring(0, 8)}',
      walletAddress: derived.address,
      username: 'tester',
      displayName: derived.address,
      bio: '',
      avatar: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );

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
      // Provide existing instances via `create` so Provider owns disposal.
      ChangeNotifierProvider(create: (_) => themeProvider),
      ChangeNotifierProvider(create: (_) => profileProvider),
      ChangeNotifierProvider(create: (_) => walletProvider),
      ChangeNotifierProvider(create: (_) => web3Provider),
      ChangeNotifierProvider(create: (_) => platformProvider),
      ChangeNotifierProvider(create: (_) => notificationProvider),
      ChangeNotifierProvider(create: (_) => navigationProvider),
      ChangeNotifierProvider(create: (_) => localeProvider),
      ChangeNotifierProvider(create: (_) => statsProvider),
      ChangeNotifierProvider(create: (_) => securityGateProvider),
      ChangeNotifierProvider(create: (_) => glassCapabilitiesProvider),
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
        '/connect-wallet': (_) => Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('connect-wallet')),
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

Future<void> _scrollUntilVisibleNoSettle(
  WidgetTester tester,
  Finder target, {
  Finder? scrollable,
  double delta = 420,
  int maxScrolls = 24,
}) async {
  if (target.evaluate().isNotEmpty) {
    return;
  }

  final scrollableFinder = scrollable ?? find.byType(Scrollable);
  if (scrollableFinder.evaluate().isEmpty) {
    expect(target, findsOneWidget);
    return;
  }

  final scrollableTarget = scrollableFinder.first;
  for (var i = 0; i < maxScrolls && target.evaluate().isEmpty; i += 1) {
    // Drag up to scroll down.
    await tester.drag(scrollableTarget, Offset(0, -delta));
    await tester.pump(const Duration(milliseconds: 16));
  }

  expect(target, findsOneWidget);
}

Future<void> _scrollToTopNoSettle(
  WidgetTester tester, {
  Finder? scrollable,
  double delta = 900,
  int maxScrolls = 12,
}) async {
  final scrollableFinder = scrollable ?? find.byType(Scrollable);
  if (scrollableFinder.evaluate().isEmpty) {
    return;
  }

  final scrollableTarget = scrollableFinder.first;
  for (var i = 0; i < maxScrolls; i += 1) {
    // Drag down to scroll up.
    await tester.drag(scrollableTarget, Offset(0, delta));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 8),
  Duration step = const Duration(milliseconds: 120),
}) async {
  final maxTicks = (timeout.inMilliseconds / step.inMilliseconds).ceil();
  for (var i = 0; i < maxTicks; i += 1) {
    if (predicate()) return;
    await tester.pump(step);
  }
  expect(predicate(), isTrue);
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
    await _scrollUntilVisibleNoSettle(tester, disconnectTile);
    await tester.tap(disconnectTile);
    await _pumpFrames(tester);
    await _pumpUntil(tester, () => providers.walletProvider.isReadOnlySession);

    final l10n = AppLocalizations.of(tester.element(disconnectTile))!;

    // The reconnect hint is rendered in the header section near the top of the
    // settings list. Because the list is lazily built, it may not be in the
    // widget tree when we're scrolled down to the wallet section.
    await _scrollToTopNoSettle(tester);
    await _pumpFrames(tester, count: 2);

    expect(providers.walletProvider.hasWalletIdentity, isTrue);
    expect(providers.walletProvider.isReadOnlySession, isTrue);
    expect(find.text(l10n.walletReconnectManualRequiredToast), findsOneWidget);
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
    await _scrollUntilVisibleNoSettle(tester, disconnectTile);
    await tester.tap(disconnectTile);
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Disconnect'));
    await _pumpFrames(tester);
    await _pumpUntil(tester, () => providers.walletProvider.isReadOnlySession);

    final l10n = AppLocalizations.of(tester.element(disconnectTile))!;

    expect(providers.walletProvider.hasWalletIdentity, isTrue);
    expect(providers.walletProvider.isReadOnlySession, isTrue);
    expect(find.text(l10n.commonReconnect), findsOneWidget);
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

    final l10n = AppLocalizations.of(tester.element(find.byType(WalletHome)))!;

    expect(find.text(l10n.walletReconnectManualRequiredToast), findsOneWidget);

    final sendButton = find.byKey(const Key('wallet_home_action_send'));
    final sendInkWell = find.descendant(
      of: sendButton,
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(sendButton);
    await tester.tap(sendInkWell, warnIfMissed: false);
    await _pumpUntil(tester, () => find.text('connect-wallet').evaluate().isNotEmpty);

    await tester.pageBack();
    await _pumpUntil(tester, () => find.text('connect-wallet').evaluate().isEmpty);
    await _pumpFrames(tester, count: 2);

    final swapButton = find.byKey(const Key('wallet_home_action_swap'));
    final swapInkWell = find.descendant(
      of: swapButton,
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(swapButton);
    await tester.tap(swapInkWell, warnIfMissed: false);
    await _pumpUntil(tester, () => find.text('connect-wallet').evaluate().isNotEmpty);
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
    // Allow loadAuthToken().timeout(...) and other one-shot timers to complete
    // so the widget test framework doesn't report pending timers.
    await tester.pump(const Duration(seconds: 9));

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

    final l10n = AppLocalizations.of(tester.element(find.byType(TokenSwap)))!;

    expect(find.text(l10n.settingsBackupStatusReadOnly), findsOneWidget);
    expect(find.text(l10n.walletReconnectManualRequiredToast), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, l10n.commonReconnect));
    await _pumpFrames(tester, count: 4);

    expect(find.text('connect-wallet'), findsOneWidget);
  });
}
