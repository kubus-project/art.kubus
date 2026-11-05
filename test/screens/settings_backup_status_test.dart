import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/models/email_preferences.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/email_preferences_provider.dart';
import 'package:art_kubus/providers/glass_capabilities_provider.dart';
import 'package:art_kubus/providers/config_provider.dart';
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
import 'package:art_kubus/screens/support_center_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/encrypted_wallet_backup_service.dart';
import 'package:art_kubus/utils/wallet_backup_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWalletProvider extends WalletProvider {
  _FakeWalletProvider({
    required this.walletAddressValue,
    required this.hasWalletIdentityValue,
    required this.hasSignerValue,
    required this.isReadOnlySessionValue,
    required this.mnemonicBackupRequiredValue,
    this.backupDefinition,
  }) : super(deferInit: true);

  String? walletAddressValue;
  bool hasWalletIdentityValue;
  bool hasSignerValue;
  bool isReadOnlySessionValue;
  bool mnemonicBackupRequiredValue;
  EncryptedWalletBackupDefinition? backupDefinition;

  @override
  String? get currentWalletAddress => walletAddressValue;

  @override
  bool get hasWalletIdentity => hasWalletIdentityValue;

  @override
  bool get hasSigner => hasSignerValue;

  @override
  bool get isReadOnlySession => isReadOnlySessionValue;

  @override
  Future<bool> isMnemonicBackupRequired({String? walletAddress}) async {
    return mnemonicBackupRequiredValue;
  }

  @override
  Future<EncryptedWalletBackupDefinition?> getEncryptedWalletBackup({
    String? walletAddress,
    bool refresh = false,
  }) async {
    return backupDefinition;
  }

  @override
  EncryptedWalletBackupDefinition? get encryptedWalletBackupDefinition =>
      backupDefinition;

  @override
  bool get hasEncryptedWalletBackup => backupDefinition != null;

  @override
  Future<bool> hasPin() async => false;

  @override
  Future<bool> canUseBiometrics() async => false;

  void setBackupDefinition(
    EncryptedWalletBackupDefinition? nextDefinition,
  ) {
    backupDefinition = nextDefinition;
    notifyListeners();
  }
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

EncryptedWalletBackupDefinition _backup({
  List<WalletBackupPasskeyDefinition> passkeys =
      const <WalletBackupPasskeyDefinition>[],
}) {
  return EncryptedWalletBackupDefinition(
    walletAddress: 'wallet123',
    version: 1,
    kdfName: 'argon2id',
    kdfParams: const <String, dynamic>{'iterations': 1},
    salt: 'salt',
    wrappedDekNonce: 'wrappedNonce',
    wrappedDekCiphertext: 'wrappedCipher',
    mnemonicNonce: 'mnemonicNonce',
    mnemonicCiphertext: 'mnemonicCipher',
    passkeys: passkeys,
  );
}

class _AllowAllSecurityGateProvider extends SecurityGateProvider {
  @override
  Future<bool> requireSensitiveActionVerification() async => true;
}

Widget _buildSettingsApp(
  _FakeWalletProvider walletProvider, {
  Widget? home,
  Locale locale = const Locale('en'),
}) {
  final web3Provider = Web3Provider()..bindWalletProvider(walletProvider);
  final content = home ?? const SettingsScreen();
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
      ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
      ChangeNotifierProvider<Web3Provider>.value(value: web3Provider),
      ChangeNotifierProvider<PlatformProvider>.value(value: PlatformProvider()),
      ChangeNotifierProvider<ProfileProvider>(
        create: (_) => ProfileProvider()
          ..setCurrentUser(
            UserProfile(
              id: 'settings-backup-profile',
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
      ChangeNotifierProvider<SecurityGateProvider>(
        create: (_) => _AllowAllSecurityGateProvider(),
      ),
      ChangeNotifierProvider<EmailPreferencesProvider>(
        create: (_) => _FakeEmailPreferencesProvider(),
      ),
      ChangeNotifierProvider<SupportCenterProvider>(
        create: (_) => SupportCenterProvider(supportEnabled: true),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: content,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizationsEn();
  final requests = <http.Request>[];

  setUp(() {
    requests.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setHttpClient(
      MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(<String, dynamic>{'success': false}),
          404,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );
  });

  test('resolver reports no backup configured', () async {
    final walletProvider = _FakeWalletProvider(
      walletAddressValue: 'wallet123',
      hasWalletIdentityValue: true,
      hasSignerValue: true,
      isReadOnlySessionValue: false,
      mnemonicBackupRequiredValue: false,
    );

    final snapshot = await WalletBackupStatusResolver.resolve(
      walletProvider: walletProvider,
      refreshRemote: false,
    );

    expect(snapshot.hasEncryptedServerBackup, isFalse);
    expect(snapshot.mnemonicBackupRequired, isFalse);
  });

  test('resolver reports encrypted backup configured', () async {
    final walletProvider = _FakeWalletProvider(
      walletAddressValue: 'wallet123',
      hasWalletIdentityValue: true,
      hasSignerValue: true,
      isReadOnlySessionValue: false,
      mnemonicBackupRequiredValue: false,
      backupDefinition: _backup(),
    );

    final snapshot = await WalletBackupStatusResolver.resolve(
      walletProvider: walletProvider,
      refreshRemote: false,
    );

    expect(snapshot.hasEncryptedServerBackup, isTrue);
  });

  test('resolver reports recovery phrase still required', () async {
    final walletProvider = _FakeWalletProvider(
      walletAddressValue: 'wallet123',
      hasWalletIdentityValue: true,
      hasSignerValue: true,
      isReadOnlySessionValue: false,
      mnemonicBackupRequiredValue: true,
    );

    final snapshot = await WalletBackupStatusResolver.resolve(
      walletProvider: walletProvider,
      refreshRemote: false,
    );

    expect(snapshot.mnemonicBackupRequired, isTrue);
    expect(snapshot.hasEncryptedServerBackup, isFalse);
  });

  test('resolver reports read-only wallet state', () async {
    final walletProvider = _FakeWalletProvider(
      walletAddressValue: 'wallet123',
      hasWalletIdentityValue: true,
      hasSignerValue: false,
      isReadOnlySessionValue: true,
      mnemonicBackupRequiredValue: false,
    );

    final snapshot = await WalletBackupStatusResolver.resolve(
      walletProvider: walletProvider,
      refreshRemote: false,
    );

    expect(snapshot.needsSignerRestore, isTrue);
    expect(snapshot.isReadOnlySession, isTrue);
  });

  test('status summary prefers recovery phrase over encrypted backup', () {
    const snapshot = WalletBackupStatusSnapshot(
      walletAddress: 'wallet123',
      hasAccountSession: true,
      hasWalletIdentity: true,
      hasSigner: true,
      isReadOnlySession: false,
      mnemonicBackupRequired: true,
      hasEncryptedServerBackup: true,
      hasPasskeyProtection: false,
    );

    expect(
      snapshot.settingsSummary(l10n),
      'Recovery phrase backup still required',
    );
  });

  test('status headline prefers recovery phrase over passkey backup', () {
    const snapshot = WalletBackupStatusSnapshot(
      walletAddress: 'wallet123',
      hasAccountSession: true,
      hasWalletIdentity: true,
      hasSigner: true,
      isReadOnlySession: false,
      mnemonicBackupRequired: true,
      hasEncryptedServerBackup: true,
      hasPasskeyProtection: true,
    );

    expect(
      snapshot.protectionHeadline(l10n),
      'Recovery phrase backup is still required.',
    );
  });

  test('status summary prefers read-only over encrypted backup', () {
    const snapshot = WalletBackupStatusSnapshot(
      walletAddress: 'wallet123',
      hasAccountSession: true,
      hasWalletIdentity: true,
      hasSigner: false,
      isReadOnlySession: true,
      mnemonicBackupRequired: false,
      hasEncryptedServerBackup: true,
      hasPasskeyProtection: false,
    );

    expect(
      snapshot.settingsSummary(l10n),
      'Encrypted backup available to restore signing on this device',
    );
  });

  testWidgets(
      'settings screen shows real backup status instead of enabled default',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'autoBackup': true,
    });

    final walletProvider = _FakeWalletProvider(
      walletAddressValue: 'wallet123',
      hasWalletIdentityValue: true,
      hasSignerValue: true,
      isReadOnlySessionValue: false,
      mnemonicBackupRequiredValue: false,
    );

    await tester.pumpWidget(_buildSettingsApp(walletProvider));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.scrollUntilVisible(
      find.text('Backup protection'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Backup protection'), findsOneWidget);
    expect(find.text('No backup protection configured yet'), findsOneWidget);
    expect(find.text('Auto-backup: Enabled'), findsNothing);
  });

  testWidgets(
      'desktop settings screen reflects refreshed backup summary on reload',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'autoBackup': true,
    });
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    final walletProvider = _FakeWalletProvider(
      walletAddressValue: 'wallet123',
      hasWalletIdentityValue: true,
      hasSignerValue: true,
      isReadOnlySessionValue: false,
      mnemonicBackupRequiredValue: false,
    );
    await tester.pumpWidget(
      _buildSettingsApp(
        walletProvider,
        home: const DesktopSettingsScreen(
          key: ValueKey('desktop_settings_initial'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('No backup protection configured yet'), findsOneWidget);

    walletProvider.setBackupDefinition(_backup());
    await tester.pumpWidget(
      _buildSettingsApp(
        walletProvider,
        home: const DesktopSettingsScreen(
          key: ValueKey('desktop_settings_reloaded'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.text('Encrypted server backup configured'),
      findsOneWidget,
    );
  });
  for (final desktop in [false, true]) {
    for (final language in ['en', 'sl']) {
      testWidgets(
          'data copy request opens an unsent support form ($desktop, $language)',
          (tester) async {
        await tester.binding.setSurfaceSize(
            desktop ? const Size(1440, 1000) : const Size(420, 900));
        tester.view.physicalSize =
            desktop ? const Size(1440, 1000) : const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final wallet = _FakeWalletProvider(
            walletAddressValue: 'wallet123',
            hasWalletIdentityValue: true,
            hasSignerValue: true,
            isReadOnlySessionValue: false,
            mnemonicBackupRequiredValue: false);
        await tester.pumpWidget(_buildSettingsApp(wallet,
            home: desktop
                ? const DesktopSettingsScreen()
                : const SettingsScreen(),
            locale: Locale(language)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        final title = language == 'en'
            ? 'Request a copy of my data'
            : 'Zahtevaj kopijo svojih podatkov';
        if (desktop) {
          final section =
              find.text(language == 'en' ? 'Danger zone' : 'Nevarno območje');
          await tester.scrollUntilVisible(section, 200,
              scrollable: find.byType(Scrollable).first);
          await tester.ensureVisible(section);
          await tester.tap(section);
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.scrollUntilVisible(find.text(title), 300,
            scrollable: find.byType(Scrollable).last);
        await tester.ensureVisible(find.text(title).first);
        await tester.pump();
        await tester.tap(find.text(title).first);
        await tester.pump(const Duration(seconds: 1));
        expect(find.textContaining('support@kubus.site'), findsOneWidget);
        expect(
            find.text(language == 'en'
                ? 'Open request form'
                : 'Odpri obrazec za zahtevo'),
            findsOneWidget);
        await tester.tap(find.text(language == 'en'
            ? 'Open request form'
            : 'Odpri obrazec za zahtevo'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        final destination = tester
            .widget<SupportCenterScreen>(find.byType(SupportCenterScreen));
        expect(destination.initialSection, SupportSection.contact);
        expect(find.byType(TextFormField), findsWidgets);
        expect(find.textContaining('Data exported:'), findsNothing);
        expect(
            requests.where((request) =>
                request.method == 'POST' &&
                request.url.path.contains('support')),
            isEmpty);
      });
    }
  }
}
