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
import 'package:art_kubus/screens/community/profile_edit_screen.dart' as mobile_profile_edit;
import 'package:art_kubus/screens/desktop/community/desktop_profile_edit_screen.dart' as desktop_profile_edit;
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:art_kubus/screens/settings_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
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
      ChangeNotifierProvider(create: (_) => EmailPreferencesProvider(backendApi: BackendApiService())),
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

  testWidgets('Mobile privacy toggles persist via ProfileProvider and reflect in Edit Profile', (tester) async {
    SharedPreferences.setMockInitialValues({});
    BackendApiService().setAuthTokenForTesting(null);
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    final themeProvider = ThemeProvider();
    final profileProvider = ProfileProvider();
    await profileProvider.initialize();
    await profileProvider.updatePreferences(showActivityStatus: true, shareLastVisitedLocation: true);

    final solana = SolanaWalletService();
    final web3Provider = Web3Provider(solanaWalletService: solana);
    final walletProvider = WalletProvider(solanaWalletService: solana, deferInit: true);
    final platformProvider = PlatformProvider();
    final notificationProvider = NotificationProvider();
    final navigationProvider = NavigationProvider();
    final localeProvider = LocaleProvider();
    final statsProvider = StatsProvider();

    await tester.pumpWidget(
      _wrapWithApp(
        home: const SettingsScreen(),
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

    // Open Settings -> Privacy settings dialog
    final privacyTile = find.byKey(const Key('settings_tile_privacy_settings'));
    await tester.scrollUntilVisible(privacyTile, 500);
    await tester.tap(privacyTile);
    await tester.pump(const Duration(milliseconds: 100));

    // Toggle "Show activity status" off; it should disable and clear "Share last visited location".
    await tester.tap(find.byKey(const Key('settings_privacy_show_activity_status')));
    await tester.pump();

    final shareTile = tester.widget<SwitchListTile>(
      find.byKey(const Key('settings_privacy_share_last_visited_location')),
    );
    expect(shareTile.value, false);
    expect(shareTile.onChanged, isNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(profileProvider.preferences.showActivityStatus, false);
    expect(profileProvider.preferences.shareLastVisitedLocation, false);

    // Rebuild the Edit Profile screen and ensure it reflects the same canonical prefs.
    await tester.pumpWidget(
      _wrapWithApp(
        home: const mobile_profile_edit.ProfileEditScreen(),
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
    await tester.pump();

    final activitySwitch = tester.widget<Switch>(
      find.byKey(const Key('profile_edit_privacy_show_activity_status')),
    );
    final shareSwitch = tester.widget<Switch>(
      find.byKey(const Key('profile_edit_privacy_share_last_visited_location')),
    );
    expect(activitySwitch.value, false);
    expect(shareSwitch.value, false);
    expect(shareSwitch.onChanged, isNull);
  });

  testWidgets('Desktop privacy toggles persist via ProfileProvider and reflect in Desktop Edit Profile', (tester) async {
    SharedPreferences.setMockInitialValues({});
    BackendApiService().setAuthTokenForTesting(null);
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    final themeProvider = ThemeProvider();
    final profileProvider = ProfileProvider();
    await profileProvider.initialize();
    await profileProvider.updatePreferences(showActivityStatus: true, shareLastVisitedLocation: true);

    final solana = SolanaWalletService();
    final web3Provider = Web3Provider(solanaWalletService: solana);
    final walletProvider = WalletProvider(solanaWalletService: solana, deferInit: true);
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
    await tester.pump(const Duration(milliseconds: 200));

    // Select "Privacy settings" on the left navigation.
    final privacyNav = find.byKey(const ValueKey('desktop_settings_sidebar_item_4'));
    await tester.tap(privacyNav.first);
    await tester.pump();

    // Toggle "Show activity status" off.
    await tester.tap(find.byKey(const Key('desktop_settings_privacy_show_activity_status')));
    await tester.pump();

    expect(profileProvider.preferences.showActivityStatus, false);
    expect(profileProvider.preferences.shareLastVisitedLocation, false);

    // Rebuild the Desktop Edit Profile screen and ensure it reflects the same canonical prefs.
    await tester.pumpWidget(
      _wrapWithApp(
        home: const desktop_profile_edit.ProfileEditScreen(),
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
    await tester.pump();

    final activitySwitch = tester.widget<Switch>(
      find.byKey(const Key('desktop_profile_edit_privacy_show_activity_status')),
    );
    final shareSwitch = tester.widget<Switch>(
      find.byKey(const Key('desktop_profile_edit_privacy_share_last_visited_location')),
    );
    expect(activitySwitch.value, false);
    expect(shareSwitch.value, false);
    expect(shareSwitch.onChanged, isNull);
  });
}
