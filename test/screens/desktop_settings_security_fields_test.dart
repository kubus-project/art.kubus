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
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:art_kubus/widgets/detail/shared_settings_widgets.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Wallet extends WalletProvider {
  _Wallet() : super(deferInit: true);

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

/// Local verification is refused, so a gated change must leave storage alone.
class _RefusingGate extends SecurityGateProvider {
  @override
  Future<bool> requireSensitiveActionVerification() async => false;
}

class _AllowingGate extends SecurityGateProvider {
  @override
  Future<bool> requireSensitiveActionVerification() async => true;
}

Widget _app(SecurityGateProvider gate) {
  final wallet = _Wallet();
  final web3Provider = Web3Provider()..bindWalletProvider(wallet);
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
      ChangeNotifierProvider<PlatformProvider>(
        create: (_) => PlatformProvider(),
      ),
      ChangeNotifierProvider<ProfileProvider>(
        create: (_) => ProfileProvider()
          ..setCurrentUser(
            UserProfile(
              id: 'settings-security-profile',
              walletAddress: 'wallet123',
              username: 'tester',
              displayName: 'Tester',
              bio: '',
              avatar: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
      ),
      ChangeNotifierProvider<NavigationProvider>(
        create: (_) => NavigationProvider(),
      ),
      ChangeNotifierProvider<SecurityGateProvider>.value(value: gate),
      ChangeNotifierProvider<EmailPreferencesProvider>(
        create: (_) => _FakeEmailPreferencesProvider(),
      ),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: DesktopSettingsScreen(),
    ),
  );
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

Future<void> _openSecurity(WidgetTester tester) async {
  await tester
      .tap(find.byKey(const ValueKey('desktop_settings_sidebar_item_3')));
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _switchFor(String title) => find.descendant(
      of: find.ancestor(
        of: find.text(title),
        matching: find.byType(SharedSettingsToggleRow),
      ),
      matching: find.byType(Switch),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizationsEn();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'requirePin': true,
      'biometricAuth': true,
      'autoLockTime': '5 minutes',
      'autoLockSeconds': 300,
    });
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

  Future<void> pumpSettings(
      WidgetTester tester, SecurityGateProvider gate) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(gate));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await _openSecurity(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets(
      'unrelated toggle does not write back a PIN change made elsewhere',
      (tester) async {
    await pumpSettings(tester, _AllowingGate());

    // The Security Hub turns the PIN requirement off while Settings is alive.
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('requirePin', false);
    });

    await tester.tap(_switchFor(l10n.settingsTwoFactorTitle));
    await tester.pump(const Duration(milliseconds: 300));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('requirePin'), isFalse,
        reason: 'the stale screen must not restore its own requirePin');
    expect(prefs.getBool('biometricAuth'), isTrue);
  });

  testWidgets('auto-lock to Never is refused and leaves storage unchanged',
      (tester) async {
    await pumpSettings(tester, _RefusingGate());

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(l10n.settingsAutoLockNever).last);
    await tester.pump(const Duration(milliseconds: 400));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('autoLockSeconds'), 300);
    expect(prefs.getString('autoLockTime'), '5 minutes');
  });

  testWidgets('biometric off is refused and leaves storage unchanged',
      (tester) async {
    await pumpSettings(tester, _RefusingGate());

    await tester.tap(_switchFor(l10n.settingsBiometricTileTitle));
    await tester.pump(const Duration(milliseconds: 300));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('biometricAuth'), isTrue);
  });

  testWidgets('biometric off is written once local verification passes',
      (tester) async {
    await pumpSettings(tester, _AllowingGate());

    await tester.tap(_switchFor(l10n.settingsBiometricTileTitle));
    await tester.pump(const Duration(milliseconds: 300));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('biometricAuth'), isFalse);
  });
}
