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
    final l10n = AppLocalizations.of(
      tester.element(find.byType(WalletCustodyStatusPanel)),
    )!;

    expect(find.text(l10n.walletSecurityStatusTitle), findsOneWidget);
    expect(
      find.text(l10n.walletSessionStateEncryptedBackupAvailable),
      findsOneWidget,
    );
    expect(find.text(l10n.walletSecuritySignInMethodLabel), findsOneWidget);
    expect(find.text('Email (artist@example.com)'), findsOneWidget);
    expect(find.text(l10n.walletSecuritySignerStatusLabel), findsOneWidget);
    expect(
      find.text(l10n.walletSecuritySignerRestoreAvailableValue),
      findsOneWidget,
    );
    expect(find.text(l10n.walletSecurityConfigured), findsOneWidget);
    expect(find.text(l10n.walletSecurityRestoreSignerAction), findsOneWidget);
    expect(find.text(l10n.walletSecurityConnectExternalAction), findsOneWidget);
    expect(
        find.text(l10n.walletSecurityBackendBackupClarifier), findsOneWidget);

    await tester.tap(find.text(l10n.walletSecurityRestoreSignerAction));
    await tester.tap(find.text(l10n.walletSecurityConnectExternalAction));

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
    final l10n = AppLocalizations.of(
      tester.element(find.byType(WalletCustodyStatusPanel)),
    )!;

    expect(find.text(l10n.walletSecurityStatusTitle), findsOneWidget);
    expect(find.text(l10n.walletSessionStateExternalWalletReady), findsWidgets);
    expect(find.text(l10n.walletSecuritySignInMethodLabel), findsOneWidget);
    expect(find.text('Google (artist@example.com)'), findsOneWidget);
    expect(find.text(l10n.walletSecuritySignerStatusLabel), findsOneWidget);
    expect(
      find.text(l10n.walletSecurityExternalWalletConnectedValue('Phantom')),
      findsOneWidget,
    );
    expect(
        find.text(l10n.walletSecurityRecoveryNotNeededValue), findsOneWidget);
  });
}
