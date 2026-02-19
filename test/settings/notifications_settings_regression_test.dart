import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/email_preferences_provider.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/navigation_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/platform_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/stats_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/settings_service.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapWithApp({
  required Widget home,
  required ThemeProvider themeProvider,
  required ProfileProvider profileProvider,
  required Web3Provider web3Provider,
  required WalletProvider walletProvider,
  required PlatformProvider platformProvider,
  required NotificationProvider notificationProvider,
  required NavigationProvider navigationProvider,
  required LocaleProvider localeProvider,
  required StatsProvider statsProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: themeProvider),
      ChangeNotifierProvider.value(value: profileProvider),
      ChangeNotifierProvider.value(value: web3Provider),
      ChangeNotifierProvider.value(value: walletProvider),
      ChangeNotifierProvider.value(value: platformProvider),
      ChangeNotifierProvider.value(value: notificationProvider),
      ChangeNotifierProvider.value(value: navigationProvider),
      ChangeNotifierProvider.value(value: localeProvider),
      ChangeNotifierProvider.value(value: statsProvider),
      ChangeNotifierProvider(
        create: (_) =>
            EmailPreferencesProvider(backendApi: BackendApiService()),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFrames(WidgetTester tester, {int count = 6}) async {
    for (var i = 0; i < count; i += 1) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  test('settings service persists push notification state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final defaults = await SettingsService.loadSettings();
    await SettingsService.saveSettings(
      defaults.copyWith(pushNotifications: false),
    );
    final disabled = await SettingsService.loadSettings();
    expect(disabled.pushNotifications, isFalse);

    await SettingsService.saveSettings(
      disabled.copyWith(pushNotifications: true),
    );
    final enabled = await SettingsService.loadSettings();
    expect(enabled.pushNotifications, isTrue);
  });

  testWidgets('desktop settings still exposes notifications section',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    final themeProvider = ThemeProvider();
    final profileProvider = ProfileProvider();
    await profileProvider.initialize();

    final solana = SolanaWalletService();
    final web3Provider = Web3Provider(solanaWalletService: solana);
    final walletProvider = WalletProvider(
      solanaWalletService: solana,
      deferInit: true,
    );
    final platformProvider = PlatformProvider();
    final notificationProvider = NotificationProvider();
    final navigationProvider = NavigationProvider();
    final localeProvider = LocaleProvider();
    final statsProvider = StatsProvider();

    await tester.pumpWidget(
      _wrapWithApp(
        home: const DesktopSettingsScreen(),
        themeProvider: themeProvider,
        profileProvider: profileProvider,
        web3Provider: web3Provider,
        walletProvider: walletProvider,
        platformProvider: platformProvider,
        notificationProvider: notificationProvider,
        navigationProvider: navigationProvider,
        localeProvider: localeProvider,
        statsProvider: statsProvider,
      ),
    );
    await pumpFrames(tester, count: 8);

    final notificationsNav =
        find.byKey(const ValueKey('desktop_settings_sidebar_item_2'));
    expect(notificationsNav, findsOneWidget);
    await tester.tap(notificationsNav);
    await pumpFrames(tester, count: 6);

    expect(find.text('Push notifications'), findsWidgets);
  });
}
