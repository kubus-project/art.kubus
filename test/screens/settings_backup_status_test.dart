import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/l10n/app_localizations_sl.dart';
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
import 'package:art_kubus/utils/wallet_presentation_state.dart';
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

  /// Links [address] as the account's wallet, the way a finished account link
  /// does: identity, optional proven backup, and a settled session phase.
  void linkWallet({
    required String address,
    EncryptedWalletBackupDefinition? backup,
  }) {
    walletAddressValue = address;
    hasWalletIdentityValue = true;
    hasSignerValue = false;
    isReadOnlySessionValue = true;
    backupDefinition = backup;
    setCurrentWalletAddressForTesting(address);
  }

  /// Drops the wallet identity; the account session (if any) stays as seeded.
  void unlinkWallet() {
    walletAddressValue = null;
    hasWalletIdentityValue = false;
    hasSignerValue = false;
    isReadOnlySessionValue = false;
    backupDefinition = null;
    setCurrentWalletAddressForTesting(null);
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
  ProfileProvider? profileProvider,
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
        create: (_) =>
            profileProvider ??
            (ProfileProvider()
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
              )),
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

  group('backup copy for walletless, unsettled and restorable states', () {
    final sl = AppLocalizationsSl();

    WalletBackupStatusSnapshot snapshot({
      bool hasWalletIdentity = false,
      bool hasEncryptedServerBackup = false,
    }) {
      return WalletBackupStatusSnapshot(
        walletAddress: hasWalletIdentity ? 'wallet123' : null,
        hasAccountSession: true,
        hasWalletIdentity: hasWalletIdentity,
        hasSigner: false,
        isReadOnlySession: hasWalletIdentity,
        mnemonicBackupRequired: false,
        hasEncryptedServerBackup: hasEncryptedServerBackup,
        hasPasskeyProtection: false,
      );
    }

    void expectNoRestoreWording(String text) {
      expect(text.toLowerCase(), isNot(contains('restor')));
    }

    test('walletless account is neutral on both surfaces (EN)', () {
      final walletless = snapshot();

      expect(
        walletless.settingsSummary(l10n),
        'No wallet linked to this account',
      );
      expect(
        walletless.protectionHeadline(l10n),
        'No wallet is linked to this account.',
      );
      expect(
        walletless.protectionBody(l10n),
        'A wallet is optional. Connect one from the Wallet screen when you need wallet-based ownership or participation.',
      );
      expectNoRestoreWording(walletless.settingsSummary(l10n));
      expectNoRestoreWording(walletless.protectionHeadline(l10n));
      expectNoRestoreWording(walletless.protectionBody(l10n));
    });

    test('walletless account is neutral in Slovenian (SL)', () {
      final walletless = snapshot();

      expect(
        walletless.settingsSummary(sl),
        'Z računom ni povezana nobena denarnica',
      );
      expect(
        walletless.protectionHeadline(sl),
        'Z vašim računom ni povezana nobena denarnica.',
      );
      expect(walletless.protectionBody(sl), isNot(contains('obnov')));
    });

    test('unsettled linkage shows the neutral loading copy, not restore', () {
      final walletless = snapshot();

      expect(
        walletless.settingsSummary(l10n, linkagePending: true),
        'Checking wallet status…',
      );
      expect(
        walletless.protectionHeadline(l10n, linkagePending: true),
        'Checking wallet status…',
      );
      expectNoRestoreWording(
        walletless.protectionBody(l10n, linkagePending: true),
      );
      expect(
        walletless.settingsSummary(sl, linkagePending: true),
        'Preverjamo stanje denarnice…',
      );
    });

    test('an unresolved snapshot is loading, never restore or no-wallet', () {
      const pending = WalletBackupStatusSnapshot.pending();

      expect(pending.settingsSummary(l10n), 'Checking wallet status…');
      expect(pending.protectionHeadline(l10n), 'Checking wallet status…');
      expectNoRestoreWording(pending.protectionBody(l10n));
    });

    test('a proven backup without a local key keeps the restore copy', () {
      final restorable = snapshot(
        hasWalletIdentity: true,
        hasEncryptedServerBackup: true,
      );

      expect(
        restorable.settingsSummary(l10n),
        'Encrypted backup available to restore signing on this device',
      );
      expect(
        restorable.protectionHeadline(l10n),
        'Encrypted backup is available, but signing is not restored on this device.',
      );
      // A wallet already known on this account is not hidden by loading.
      expect(
        restorable.settingsSummary(l10n, linkagePending: true),
        'Encrypted backup available to restore signing on this device',
      );
    });

    test('a read-only wallet without a proven backup is not a restore state',
        () {
      final readOnly = snapshot(hasWalletIdentity: true);

      expect(
        readOnly.settingsSummary(l10n),
        'Read-only wallet session on this device',
      );
      expect(
        readOnly.protectionHeadline(l10n),
        'This device has read-only wallet access.',
      );
      expectNoRestoreWording(readOnly.settingsSummary(l10n));
      expectNoRestoreWording(readOnly.protectionBody(l10n));
    });

    test(
        'a read-only wallet whose backup lookup failed never implies no backup',
        () {
      const lookupFailed = WalletBackupStatusSnapshot(
        walletAddress: 'wallet123',
        hasAccountSession: true,
        hasWalletIdentity: true,
        hasSigner: false,
        isReadOnlySession: true,
        mnemonicBackupRequired: false,
        hasEncryptedServerBackup: false,
        hasPasskeyProtection: false,
        encryptedBackupStatusKnown: false,
      );

      expect(
        lookupFailed.settingsSummary(l10n),
        'Read-only wallet session on this device. '
        'Backup status is unavailable right now. Try again in a moment.',
      );
      expect(
        lookupFailed.protectionBody(l10n),
        contains('Backup status is unavailable right now.'),
      );
      expect(
        lookupFailed.settingsSummary(sl),
        'Na tej napravi je seja denarnice samo za branje. '
        'Stanje varnostne kopije trenutno ni na voljo. Poskusi znova čez trenutek.',
      );
      // A known "no backup" read-only state keeps the plain copy.
      expect(
        snapshot(hasWalletIdentity: true).settingsSummary(l10n),
        'Read-only wallet session on this device',
      );
    });

    test('a signed-in account without a wallet resolves as walletless',
        () async {
      final walletProvider = _FakeWalletProvider(
        walletAddressValue: null,
        hasWalletIdentityValue: false,
        hasSignerValue: false,
        isReadOnlySessionValue: false,
        mnemonicBackupRequiredValue: false,
      )
        ..seedAccountSessionForTesting(
          email: 'walletless@example.com',
          backendProfile: const <String, dynamic>{},
        )
        ..setCurrentWalletAddressForTesting(null);

      final resolved = await WalletBackupStatusResolver.resolve(
        walletProvider: walletProvider,
        refreshRemote: false,
      );

      expect(resolved.hasAccountSession, isTrue);
      expect(resolved.hasWalletIdentity, isFalse);
      expect(
        resolved.settingsSummary(l10n),
        'No wallet linked to this account',
      );
      expect(
        WalletPresentationStateResolver.linkagePendingFor(walletProvider),
        isFalse,
      );
    });

    test('an unsettled provider reports linkage pending and loads', () async {
      final walletProvider = _FakeWalletProvider(
        walletAddressValue: null,
        hasWalletIdentityValue: false,
        hasSignerValue: false,
        isReadOnlySessionValue: false,
        mnemonicBackupRequiredValue: false,
      );

      final resolved = await WalletBackupStatusResolver.resolve(
        walletProvider: walletProvider,
        refreshRemote: false,
      );
      final pending =
          WalletPresentationStateResolver.linkagePendingFor(walletProvider);

      expect(pending, isTrue);
      expect(
        resolved.settingsSummary(l10n, linkagePending: pending),
        'Checking wallet status…',
      );
    });

    testWidgets('walletless account row says no wallet is linked, not restore',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final walletProvider = _FakeWalletProvider(
        walletAddressValue: null,
        hasWalletIdentityValue: false,
        hasSignerValue: false,
        isReadOnlySessionValue: false,
        mnemonicBackupRequiredValue: false,
      )
        ..seedAccountSessionForTesting(
          email: 'walletless@example.com',
          backendProfile: const <String, dynamic>{},
        )
        ..setCurrentWalletAddressForTesting(null);

      await tester.pumpWidget(_buildSettingsApp(walletProvider));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.scrollUntilVisible(
        find.text('No wallet linked to this account'),
        250,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('No wallet linked to this account'), findsOneWidget);
      expect(find.text('Checking wallet status…'), findsNothing);
      expect(
        find.text('Account wallet has not been restored on this device yet'),
        findsNothing,
      );
    });

    testWidgets('unsettled linkage shows the loading row, not restore',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final walletProvider = _FakeWalletProvider(
        walletAddressValue: null,
        hasWalletIdentityValue: false,
        hasSignerValue: false,
        isReadOnlySessionValue: false,
        mnemonicBackupRequiredValue: false,
      );

      await tester.pumpWidget(_buildSettingsApp(walletProvider));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.scrollUntilVisible(
        find.text('Checking wallet status…'),
        250,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Checking wallet status…'), findsOneWidget);
      expect(find.text('No wallet linked to this account'), findsNothing);
    });

    testWidgets('proven backup without a local key keeps the restore row',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final walletProvider = _FakeWalletProvider(
        walletAddressValue: 'wallet123',
        hasWalletIdentityValue: true,
        hasSignerValue: false,
        isReadOnlySessionValue: true,
        mnemonicBackupRequiredValue: false,
        backupDefinition: _backup(),
      );

      await tester.pumpWidget(_buildSettingsApp(walletProvider));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      const restoreCopy =
          'Encrypted backup available to restore signing on this device';
      await tester.scrollUntilVisible(
        find.text(restoreCopy),
        250,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(restoreCopy), findsOneWidget);
    });

    testWidgets(
        'read-only wallet without a backup shows read-only, not restore',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final walletProvider = _FakeWalletProvider(
        walletAddressValue: 'wallet123',
        hasWalletIdentityValue: true,
        hasSignerValue: false,
        isReadOnlySessionValue: true,
        mnemonicBackupRequiredValue: false,
      );

      await tester.pumpWidget(_buildSettingsApp(walletProvider));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.scrollUntilVisible(
        find.text('Read-only wallet session on this device'),
        250,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
          find.text('Read-only wallet session on this device'), findsOneWidget);
      expect(
        find.text(
            'Encrypted backup available to restore signing on this device'),
        findsNothing,
      );
    });
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
  group('backup row follows live wallet inputs', () {
    const restoreCopy =
        'Encrypted backup available to restore signing on this device';
    const walletlessCopy = 'No wallet linked to this account';
    const checkingCopy = 'Checking wallet status…';

    _FakeWalletProvider unlinked() => _FakeWalletProvider(
          walletAddressValue: null,
          hasWalletIdentityValue: false,
          hasSignerValue: false,
          isReadOnlySessionValue: false,
          mnemonicBackupRequiredValue: false,
        );

    _FakeWalletProvider restorable() => _FakeWalletProvider(
          walletAddressValue: 'wallet123',
          hasWalletIdentityValue: true,
          hasSignerValue: false,
          isReadOnlySessionValue: true,
          mnemonicBackupRequiredValue: false,
          backupDefinition: _backup(),
        );

    testWidgets(
        'wallet linked after the first build shows the restore copy, never no-wallet',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final walletProvider = unlinked();

      await tester.pumpWidget(_buildSettingsApp(walletProvider));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.scrollUntilVisible(
        find.text(checkingCopy),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(checkingCopy), findsOneWidget);
      expect(find.text(walletlessCopy), findsNothing);

      walletProvider.linkWallet(address: 'wallet123', backup: _backup());
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.scrollUntilVisible(
        find.text(restoreCopy),
        250,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(restoreCopy), findsOneWidget);
      expect(find.text(walletlessCopy), findsNothing);
      expect(find.text('No wallet connected yet'), findsNothing);
    });

    testWidgets(
        'a walletless account is never shown as no-wallet while linkage is unsettled',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final walletProvider = unlinked();

      await tester.pumpWidget(_buildSettingsApp(walletProvider));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.scrollUntilVisible(
        find.text(checkingCopy),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(checkingCopy), findsOneWidget);
      expect(find.text(walletlessCopy), findsNothing);

      walletProvider.seedAccountSessionForTesting(
        email: 'walletless@example.com',
        backendProfile: const <String, dynamic>{},
      );
      walletProvider.unlinkWallet();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.scrollUntilVisible(
        find.text(walletlessCopy),
        250,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(walletlessCopy), findsOneWidget);
      expect(find.text(checkingCopy), findsNothing);
    });

    testWidgets(
        'switching from a restorable account to a walletless one shows only the new account',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final walletProvider = restorable();

      await tester.pumpWidget(_buildSettingsApp(walletProvider));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.scrollUntilVisible(
        find.text(restoreCopy),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(restoreCopy), findsOneWidget);

      walletProvider.seedAccountSessionForTesting(
        email: 'second@example.com',
        backendProfile: const <String, dynamic>{},
      );
      walletProvider.unlinkWallet();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.scrollUntilVisible(
        find.text(walletlessCopy),
        250,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(walletlessCopy), findsOneWidget);
      expect(find.text(restoreCopy), findsNothing);
    });

    testWidgets(
        'desktop settings row follows an account switch from restorable to walletless',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);

      final walletProvider = restorable();
      await tester.pumpWidget(
        _buildSettingsApp(
          walletProvider,
          home: const DesktopSettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(restoreCopy), findsOneWidget);

      walletProvider.seedAccountSessionForTesting(
        email: 'second@example.com',
        backendProfile: const <String, dynamic>{},
      );
      walletProvider.unlinkWallet();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // The desktop Security section (and its backup row) only exists while a
      // wallet is linked, so the walletless account shows no backup row and
      // none of the previous account's restore copy.
      expect(find.text(restoreCopy), findsNothing);
      expect(find.text(walletlessCopy), findsNothing);
    });

    testWidgets(
        'desktop backup row appears with live copy when a wallet is linked after the first build',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);

      final walletProvider = unlinked();
      await tester.pumpWidget(
        _buildSettingsApp(
          walletProvider,
          home: const DesktopSettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(walletlessCopy), findsNothing);
      expect(find.text('No wallet connected yet'), findsNothing);

      walletProvider.linkWallet(address: 'wallet123', backup: _backup());
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.text(restoreCopy), findsOneWidget);
      expect(find.text('No wallet connected yet'), findsNothing);
      expect(find.text(walletlessCopy), findsNothing);
    });

    testWidgets(
        'mobile row built signed-out re-resolves to the restorable wallet on sign-in',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final walletProvider = restorable()
        // Settled linkage, as for an account whose wallet is already linked.
        ..setCurrentWalletAddressForTesting('wallet123');
      final profileProvider = ProfileProvider();

      await tester.pumpWidget(
        _buildSettingsApp(walletProvider, profileProvider: profileProvider),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(profileProvider.isSignedIn, isFalse);
      expect(find.text(restoreCopy), findsNothing);

      profileProvider.setCurrentUser(
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
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // The mobile list is lazy: scroll to whichever wallet-row copy is shown.
      await tester.scrollUntilVisible(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == restoreCopy ||
                  widget.data == 'No wallet connected yet'),
        ),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No wallet connected yet'), findsNothing);
      expect(find.text(restoreCopy), findsOneWidget);
      expect(find.text(walletlessCopy), findsNothing);
    });
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
