import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/encrypted_wallet_backup_service.dart';
import 'package:art_kubus/services/wallet_recovery_flow_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FlowWalletProvider extends WalletProvider {
  _FlowWalletProvider({
    required this.walletAddressValue,
    required this.hasSignerValue,
    this.backupDefinition,
    this.passkeyThrows = false,
  }) : super(deferInit: true);

  String? walletAddressValue;
  bool hasSignerValue;
  EncryptedWalletBackupDefinition? backupDefinition;
  bool passkeyThrows;
  int backupLookups = 0;
  int passkeyRestoreAttempts = 0;

  @override
  String? get currentWalletAddress => walletAddressValue;

  @override
  bool get hasSigner => hasSignerValue;

  @override
  Future<void> setReadOnlyWalletIdentity(
    String address, {
    bool persist = true,
    bool loadData = true,
    bool syncBackend = false,
  }) async {
    walletAddressValue = address;
    hasSignerValue = false;
  }

  @override
  Future<ManagedWalletReconnectOutcome> recoverManagedWalletSession({
    String? walletAddress,
    bool refreshBackendSession = true,
  }) async {
    return ManagedWalletReconnectOutcome.manualConnectRequired;
  }

  @override
  Future<EncryptedWalletBackupDefinition?> getEncryptedWalletBackup({
    String? walletAddress,
    bool refresh = false,
  }) async {
    backupLookups += 1;
    return backupDefinition;
  }

  @override
  Future<bool> restoreSignerFromEncryptedWalletBackupPasskey({
    String? walletAddress,
  }) async {
    passkeyRestoreAttempts += 1;
    if (passkeyThrows) {
      throw const EncryptedWalletBackupException('passkey failed');
    }
    return false;
  }
}

EncryptedWalletBackupDefinition _backupWithPasskey(String walletAddress) {
  return EncryptedWalletBackupDefinition(
    walletAddress: walletAddress,
    version: 1,
    kdfName: 'argon2id',
    kdfParams: const <String, dynamic>{},
    salt: 'salt',
    wrappedDekNonce: 'dekNonce',
    wrappedDekCiphertext: 'dekCiphertext',
    mnemonicNonce: 'mnemonicNonce',
    mnemonicCiphertext: 'mnemonicCiphertext',
    passkeys: const <WalletBackupPasskeyDefinition>[
      WalletBackupPasskeyDefinition(
        credentialId: 'credential',
        transports: <String>['internal'],
      ),
    ],
  );
}

Widget _testApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('local signer ready short-circuits recovery prompts',
      (tester) async {
    final walletProvider = _FlowWalletProvider(
      walletAddressValue: 'wallet-1',
      hasSignerValue: true,
    );
    final securityGateProvider = SecurityGateProvider();
    WalletRecoveryResult? result;

    await tester.pumpWidget(_testApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await const WalletRecoveryFlowService()
                .recoverSignerForAccountWallet(
              context: context,
              walletAddress: 'wallet-1',
              walletProvider: walletProvider,
              securityGateProvider: securityGateProvider,
              origin: WalletRecoveryOrigin.postAuth,
            );
          },
          child: const Text('recover'),
        ),
      ),
    ));

    await tester.tap(find.text('recover'));
    await tester.pumpAndSettle();

    expect(result?.kind, WalletRecoveryResultKind.restored);
    expect(result?.restoreMethod, WalletRecoveryRestoreMethod.localSigner);
    expect(walletProvider.backupLookups, 0);
    expect(walletProvider.passkeyRestoreAttempts, 0);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('passkey failure shows fallback choices before password prompt',
      (tester) async {
    final walletProvider = _FlowWalletProvider(
      walletAddressValue: 'wallet-2',
      hasSignerValue: false,
      backupDefinition: _backupWithPasskey('wallet-2'),
      passkeyThrows: true,
    );
    final securityGateProvider = SecurityGateProvider();

    await tester.pumpWidget(_testApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () {
            unawaited(
              const WalletRecoveryFlowService().recoverSignerForAccountWallet(
                context: context,
                walletAddress: 'wallet-2',
                walletProvider: walletProvider,
                securityGateProvider: securityGateProvider,
                origin: WalletRecoveryOrigin.postAuth,
              ),
            );
          },
          child: const Text('recover'),
        ),
      ),
    ));

    await tester.tap(find.text('recover'));
    await tester.pumpAndSettle();

    expect(walletProvider.passkeyRestoreAttempts, 1);
    expect(find.text('Passkey recovery failed'), findsOneWidget);
    expect(find.text('Use recovery password'), findsOneWidget);
    expect(find.text('Import recovery phrase'), findsOneWidget);
    expect(find.text('Continue without wallet'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
}
