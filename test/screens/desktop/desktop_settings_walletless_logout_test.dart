import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/models/email_preferences.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/config_provider.dart';
import 'package:art_kubus/providers/email_preferences_provider.dart';
import 'package:art_kubus/providers/glass_capabilities_provider.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/navigation_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/platform_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/support_center_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:art_kubus/screens/settings_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/account_session_fixture.dart';

/// A wallet account: the wallet identity is on this device.
class _WalletAccountWallet extends WalletProvider {
  _WalletAccountWallet() : super(deferInit: true);

  @override
  String? get currentWalletAddress => 'wallet123';

  @override
  bool get hasWalletIdentity => true;

  @override
  Future<bool> hasPin() async => true;

  @override
  Future<bool> hasPinOrThrow() async => true;

  @override
  Future<bool> canUseBiometrics() async => true;
}

/// A walletless account (#437): no wallet identity on this device.
class _WalletlessWallet extends WalletProvider {
  _WalletlessWallet() : super(deferInit: true);

  @override
  String? get currentWalletAddress => null;

  @override
  bool get hasWalletIdentity => false;

  @override
  Future<bool> hasPin() async => true;

  @override
  Future<bool> hasPinOrThrow() async => true;

  @override
  Future<bool> canUseBiometrics() async => true;
}

class _FakeEmailPreferencesProvider extends EmailPreferencesProvider {
  _FakeEmailPreferencesProvider() : super();

  @override
  bool get initialized => true;

  @override
  bool get isLoading => false;

  @override
  EmailPreferences get preferences => EmailPreferences.defaults();
}

Widget _app({required bool walletless, required bool mobile}) {
  final wallet = walletless ? _WalletlessWallet() : _WalletAccountWallet();
  final web3Provider = Web3Provider()..bindWalletProvider(wallet);
  // The held account is the one behind the live session.
  AccountSessionFixture.start(
    accountId: 'settings-logout-profile',
    wallet: walletless ? null : 'wallet123',
  );
  final profile = ProfileProvider()
    ..setCurrentUser(
      UserProfile(
        id: 'settings-logout-profile',
        walletAddress: walletless ? '' : 'wallet123',
        username: 'tester',
        displayName: 'Tester',
        bio: '',
        avatar: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ConfigProvider>(create: (_) => ConfigProvider()),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<GlassCapabilitiesProvider>(
        create: (_) => GlassCapabilitiesProvider(),
      ),
      ChangeNotifierProvider<NotificationProvider>(
        create: (_) => NotificationProvider(),
      ),
      ChangeNotifierProvider<WalletProvider>.value(value: wallet),
      ChangeNotifierProvider<Web3Provider>.value(value: web3Provider),
      ChangeNotifierProvider<PlatformProvider>.value(
        value: PlatformProvider(),
      ),
      ChangeNotifierProvider<ProfileProvider>.value(value: profile),
      ChangeNotifierProvider<NavigationProvider>(
        create: (_) => NavigationProvider(),
      ),
      ChangeNotifierProvider<SecurityGateProvider>(
        create: (_) => SecurityGateProvider(),
      ),
      ChangeNotifierProvider<EmailPreferencesProvider>(
        create: (_) => _FakeEmailPreferencesProvider(),
      ),
      ChangeNotifierProvider<SupportCenterProvider>(
        create: (_) => SupportCenterProvider(supportEnabled: true),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: mobile ? const SettingsScreen() : const DesktopSettingsScreen(),
    ),
  );
}

void main() {
  // A signed-in surface has a live session behind its held profile.
  setUp(() => AccountSessionFixture.start(accountId: 'test-account'));
  tearDown(AccountSessionFixture.end);

  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizationsEn();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setHttpClient(
      MockClient((request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'success': false}),
          404,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );
  });

  Future<void> openDesktopLogoutDialog(
    WidgetTester tester, {
    required bool walletless,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(walletless: walletless, mobile: false));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text(l10n.settingsLogoutButton).first);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openMobileLogoutDialog(
    WidgetTester tester, {
    required bool walletless,
  }) async {
    // The default test surface, as the mobile settings harness uses: a 390 px
    // surface overflows a settings row unrelated to the logout copy.
    await tester.pumpWidget(_app(walletless: walletless, mobile: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    final tile = find.text(l10n.settingsLogoutTileTitle);
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // scrollUntilVisible can leave a fling running; a tap during it is lost.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('desktop walletless logout dialog does not mention a wallet',
      (tester) async {
    await openDesktopLogoutDialog(tester, walletless: true);

    expect(find.text(l10n.settingsLogoutDialogBody), findsNothing);
    expect(
      find.text(l10n.settingsLogoutDialogBodyAccountOnly),
      findsOneWidget,
    );
  });

  testWidgets('desktop wallet account logout dialog still discloses the wallet',
      (tester) async {
    await openDesktopLogoutDialog(tester, walletless: false);

    expect(find.text(l10n.settingsLogoutDialogBody), findsOneWidget);
    expect(
      find.text(l10n.settingsLogoutDialogBodyAccountOnly),
      findsNothing,
    );
  });

  testWidgets('mobile walletless logout dialog does not mention a wallet',
      (tester) async {
    await openMobileLogoutDialog(tester, walletless: true);

    expect(find.text(l10n.settingsLogoutDialogBody), findsNothing);
    expect(
      find.text(l10n.settingsLogoutDialogBodyAccountOnly),
      findsOneWidget,
    );
  });

  testWidgets('mobile wallet account logout dialog still discloses the wallet',
      (tester) async {
    await openMobileLogoutDialog(tester, walletless: false);

    expect(find.text(l10n.settingsLogoutDialogBody), findsOneWidget);
    expect(
      find.text(l10n.settingsLogoutDialogBodyAccountOnly),
      findsNothing,
    );
  });
}
