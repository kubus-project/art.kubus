import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/glass_capabilities_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/auth/security_setup_screen.dart';
import 'package:art_kubus/screens/security/security_hub_screen.dart';
import 'package:art_kubus/screens/web3/wallet/wallet_backup_protection_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/encrypted_wallet_backup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SecuritySetupWalletProvider extends WalletProvider {
  _SecuritySetupWalletProvider({
    required this.hasPinValue,
    required this.canUseBiometricsValue,
    required this.hasEncryptedWalletBackupValue,
    required this.mnemonicBackupRequiredValue,
    this.walletAddress = '7YgP1dXwz9exampleWallet111111111111111111',
    this.passkeys = const <WalletBackupPasskeyDefinition>[],
  }) : super(deferInit: true);

  bool hasPinValue;
  bool canUseBiometricsValue;
  bool hasEncryptedWalletBackupValue;
  bool mnemonicBackupRequiredValue;
  String walletAddress;
  List<WalletBackupPasskeyDefinition> passkeys;

  @override
  String? get currentWalletAddress => walletAddress;

  @override
  bool get hasLocalSigner => true;

  @override
  bool get hasExternalSigner => false;

  @override
  bool get hasSigner => true;

  @override
  WalletAuthoritySnapshot get authority => WalletAuthoritySnapshot(
        state: WalletAuthorityState.localSignerReady,
        signerSource: WalletSignerSource.local,
        accountSignedIn: true,
        signInMethod: AuthSignInMethod.email,
        accountEmail: 'tester@example.com',
        walletAddress: walletAddress,
        hasLocalSigner: true,
        hasExternalSigner: false,
        externalWalletConnected: false,
        externalWalletName: null,
        hasEncryptedBackup: hasEncryptedWalletBackupValue,
        encryptedBackupStatusKnown: true,
        hasPasskeyProtection: passkeys.isNotEmpty,
        mnemonicBackupRequired: mnemonicBackupRequiredValue,
        recoveryNeeded: false,
      );

  @override
  Future<bool> hasPin() async => hasPinValue;

  @override
  Future<bool> canUseBiometrics() async => canUseBiometricsValue;

  @override
  bool get hasEncryptedWalletBackup => hasEncryptedWalletBackupValue;

  @override
  DateTime? get encryptedWalletBackupLastVerifiedAt =>
      hasEncryptedWalletBackupValue ? DateTime(2026, 1, 2) : null;

  @override
  List<WalletBackupPasskeyDefinition> get encryptedWalletBackupPasskeys =>
      passkeys;

  @override
  Future<bool> isMnemonicBackupRequired({String? walletAddress}) async {
    return mnemonicBackupRequiredValue;
  }

  @override
  Future<EncryptedWalletBackupDefinition?> refreshEncryptedWalletBackupStatus({
    String? walletAddress,
    bool notify = true,
  }) async {
    if (!hasEncryptedWalletBackupValue) return null;
    return EncryptedWalletBackupDefinition(
      walletAddress: this.walletAddress,
      version: 1,
      kdfName: 'argon2id',
      kdfParams: const <String, dynamic>{},
      salt: 'salt',
      wrappedDekNonce: 'nonce',
      wrappedDekCiphertext: 'cipher',
      mnemonicNonce: 'mnemonicNonce',
      mnemonicCiphertext: 'mnemonicCipher',
      lastVerifiedAt: DateTime(2026, 1, 2),
      passkeys: passkeys,
    );
  }
}

Widget _buildSecurityApp({
  required Widget home,
  required _SecuritySetupWalletProvider walletProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<GlassCapabilitiesProvider>(
        create: (_) => GlassCapabilitiesProvider(),
      ),
      ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
      ChangeNotifierProvider<SecurityGateProvider>(
        create: (_) => SecurityGateProvider(),
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

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders compact mobile canonical security setup hub',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildSecurityApp(
        home: const SecuritySetupScreen(),
        walletProvider: _SecuritySetupWalletProvider(
          hasPinValue: false,
          canUseBiometricsValue: true,
          hasEncryptedWalletBackupValue: false,
          mnemonicBackupRequiredValue: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SecurityHubScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('security-hub-mobile-layout')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('security-setup-mobile-layout')),
        findsOneWidget);
    expect(find.text('PIN / local lock'), findsOneWidget);
    expect(find.text('Account sign-in passkey'), findsOneWidget);
    expect(find.text('Wallet recovery / unlock passkey'), findsOneWidget);
    expect(find.text('Secure this device'), findsOneWidget);
  });

  testWidgets('renders compact desktop canonical security setup hub',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildSecurityApp(
        home: const SecuritySetupScreen(),
        walletProvider: _SecuritySetupWalletProvider(
          hasPinValue: true,
          canUseBiometricsValue: false,
          hasEncryptedWalletBackupValue: true,
          mnemonicBackupRequiredValue: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('security-hub-desktop-layout')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('security-setup-desktop-layout')),
        findsOneWidget);
    expect(find.text('Wallet access state'), findsOneWidget);
    expect(find.text('Encrypted server backup'), findsOneWidget);
    expect(find.text('Security hub'), findsNothing);
  });

  testWidgets('wallet security route renders canonical hub without old cards',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildSecurityApp(
        home: const WalletBackupProtectionScreen(),
        walletProvider: _SecuritySetupWalletProvider(
          hasPinValue: true,
          canUseBiometricsValue: false,
          hasEncryptedWalletBackupValue: true,
          mnemonicBackupRequiredValue: false,
          passkeys: [
            WalletBackupPasskeyDefinition(
              id: 'wallet-passkey-1',
              credentialId: 'credential-1',
              transports: const ['internal'],
              nickname: 'Laptop',
              prfSupported: true,
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SecurityHubScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('security-hub-desktop-layout')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('security-methods-list')), findsOneWidget);
    expect(find.text('Wallet recovery / unlock passkey'), findsOneWidget);
    expect(find.text('Laptop'), findsOneWidget);
    expect(find.text('Wallet security status'), findsNothing);
    expect(find.text('Protect your web3 wallet'), findsNothing);
  });
}
