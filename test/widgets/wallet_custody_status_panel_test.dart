import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/wallet_custody_status_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WalletAuthoritySnapshot _snapshot({
  required WalletAuthorityState state,
  required WalletSignerSource signerSource,
  bool accountSignedIn = true,
  AuthSignInMethod signInMethod = AuthSignInMethod.email,
  String? accountEmail = 'artist@example.com',
  String? walletAddress = 'wallet-address-123',
  bool hasLocalSigner = false,
  bool hasExternalSigner = false,
  bool externalWalletConnected = false,
  String? externalWalletName,
  bool hasEncryptedBackup = false,
  bool encryptedBackupStatusKnown = true,
  bool hasPasskeyProtection = false,
  bool mnemonicBackupRequired = false,
  bool recoveryNeeded = false,
}) {
  return WalletAuthoritySnapshot(
    state: state,
    signerSource: signerSource,
    accountSignedIn: accountSignedIn,
    signInMethod: signInMethod,
    accountEmail: accountEmail,
    walletAddress: walletAddress,
    hasLocalSigner: hasLocalSigner,
    hasExternalSigner: hasExternalSigner,
    externalWalletConnected: externalWalletConnected,
    externalWalletName: externalWalletName,
    hasEncryptedBackup: hasEncryptedBackup,
    encryptedBackupStatusKnown: encryptedBackupStatusKnown,
    hasPasskeyProtection: hasPasskeyProtection,
    mnemonicBackupRequired: mnemonicBackupRequired,
    recoveryNeeded: recoveryNeeded,
  );
}

Widget _wrap(
  Widget child, {
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  testWidgets('renders encrypted-backup signer-missing state in English',
      (tester) async {
    var restoreTapped = false;
    var connectTapped = false;

    await tester.pumpWidget(
      _wrap(
        WalletCustodyStatusPanel(
          authority: _snapshot(
            state: WalletAuthorityState.encryptedBackupAvailableSignerMissing,
            signerSource: WalletSignerSource.none,
            hasEncryptedBackup: true,
            hasPasskeyProtection: true,
          ),
          onRestoreSigner: () => restoreTapped = true,
          onConnectExternalWallet: () => connectTapped = true,
        ),
      ),
    );

    expect(find.text('Wallet security status'), findsOneWidget);
    expect(find.text('Encrypted backup available'), findsOneWidget);
    expect(find.text('Account sign-in'), findsOneWidget);
    expect(find.text('Email (artist@example.com)'), findsOneWidget);
    expect(find.text('Signer status'), findsOneWidget);
    expect(
      find.text('Restore available from encrypted backup'),
      findsOneWidget,
    );
    expect(find.text('Configured'), findsOneWidget);
    expect(find.text('Restore signer'), findsOneWidget);
    expect(find.text('Connect external wallet'), findsOneWidget);
    expect(
      find.textContaining('Encrypted backend backup is optional convenience'),
      findsOneWidget,
    );

    await tester.tap(find.text('Restore signer'));
    await tester.tap(find.text('Connect external wallet'));

    expect(restoreTapped, isTrue);
    expect(connectTapped, isTrue);
  });

  testWidgets('renders external wallet ready state in Slovenian',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        WalletCustodyStatusPanel(
          compact: true,
          authority: _snapshot(
            state: WalletAuthorityState.externalWalletReady,
            signerSource: WalletSignerSource.external,
            signInMethod: AuthSignInMethod.google,
            accountEmail: 'artist@example.com',
            hasExternalSigner: true,
            externalWalletConnected: true,
            externalWalletName: 'Phantom',
          ),
        ),
        locale: const Locale('sl'),
      ),
    );

    expect(find.text('Varnostno stanje denarnice'), findsOneWidget);
    expect(find.text('Zunanja denarnica je pripravljena'), findsWidgets);
    expect(find.text('Prijava v račun'), findsOneWidget);
    expect(find.text('Google (artist@example.com)'), findsOneWidget);
    expect(find.text('Stanje podpisnika'), findsOneWidget);
    expect(find.text('Povezano: Phantom'), findsOneWidget);
    expect(find.text('Ni potrebna'), findsOneWidget);
  });
}
