import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/models/email_preferences.dart';
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
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/screens/settings_screen.dart';
import 'package:art_kubus/screens/web3/wallet/wallet_backup_protection_screen.dart';
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
    EncryptedWalletBackupDefinition? backupDefinition,
  })  : backupDefinition = backupDefinition,
        super(deferInit: true);

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

class _ShellHarness extends StatefulWidget {
  const _ShellHarness({
    required this.child,
    required this.pushedScreen,
  });

  final Widget child;
  final ValueNotifier<Widget?> pushedScreen;

  @override
  State<_ShellHarness> createState() => _ShellHarnessState();
}

class _ShellHarnessState extends State<_ShellHarness> {
  Widget? _currentScreen;

  @override
  Widget build(BuildContext context) {
    return DesktopShellScope(
      pushScreen: (screen) {
        widget.pushedScreen.value = screen;
        setState(() {
          _currentScreen = screen;
        });
      },
      popScreen: () {
        widget.pushedScreen.value = null;
        setState(() {
          _currentScreen = null;
        });
      },
      navigateToRoute: (_) {},
      openNotifications: () {},
      openFunctionsPanel: (_, {Widget? content}) {},
      setFunctionsPanelContent: (_) {},
      closeFunctionsPanel: () {},
      canPop: _currentScreen != null,
      child: Stack(
        children: [
          widget.child,
          if (_currentScreen != null)
            Positioned.fill(child: Material(child: _currentScreen!)),
        ],
      ),
    );
  }
}

Widget _buildSettingsApp(
  _FakeWalletProvider walletProvider, {
  Widget? home,
  ValueNotifier<Widget?>? pushedScreen,
}) {
  final web3Provider = Web3Provider()..bindWalletProvider(walletProvider);
  final content = home ?? const SettingsScreen();
  return MultiProvider(
    providers: [
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
      ChangeNotifierProvider<PlatformProvider>(
        create: (_) => PlatformProvider(),
      ),
      ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
      ChangeNotifierProvider<NavigationProvider>(
        create: (_) => NavigationProvider(),
      ),
      ChangeNotifierProvider<SecurityGateProvider>(
        create: (_) => _AllowAllSecurityGateProvider(),
      ),
      ChangeNotifierProvider<EmailPreferencesProvider>(
        create: (_) => _FakeEmailPreferencesProvider(),
      ),
    ],
    child: MaterialApp(
      locale: Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: pushedScreen == null
          ? content
          : _ShellHarness(
              pushedScreen: pushedScreen,
              child: content,
            ),
    ),
  );
}

void main() {
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
      hasWalletIdentity: true,
      hasSigner: false,
      isReadOnlySession: true,
      mnemonicBackupRequired: false,
      hasEncryptedServerBackup: true,
      hasPasskeyProtection: false,
    );

    expect(
      snapshot.settingsSummary(l10n),
      'Read-only wallet session on this device',
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
      'desktop shell refresh callback updates backup summary without rebuild',
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
    final pushedScreen = ValueNotifier<Widget?>(null);

    await tester.pumpWidget(
      _buildSettingsApp(
        walletProvider,
        home: const DesktopSettingsScreen(),
        pushedScreen: pushedScreen,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('No backup protection configured yet'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Backup protection'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Backup protection'));
    await tester.pump();

    final backupScreen =
        pushedScreen.value as WalletBackupProtectionScreen?;
    expect(backupScreen, isNotNull);

    walletProvider.setBackupDefinition(_backup());
    await backupScreen!.onBackupStateChanged!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Encrypted server backup configured'),
      findsOneWidget,
    );
  });
}
