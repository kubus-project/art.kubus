import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/wallet/kubus_wallet_shell.dart';
import 'package:art_kubus/widgets/wallet/wallet_action_controller.dart';
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

List<WalletActionConfig> _actions(
  WalletAuthoritySnapshot authority, {
  bool includeSetup = true,
}) {
  return WalletActionController.buildPrimaryActions(
    l10n: AppLocalizationsEn(),
    roles: KubusColorRoles.light,
    authority: authority,
    onSend: () {},
    onReceive: () {},
    onSwap: () {},
    onSecureWallet: () {},
    onRestoreSigner: () {},
    onCreateLocalWallet: includeSetup ? () {} : null,
    onImportWallet: includeSetup ? () {} : null,
    onConnectExternalWallet: includeSetup ? () {} : null,
  );
}

void _expectNoDuplicateTypes(List<WalletActionConfig> actions) {
  final types = actions.map((action) => action.type).toList();
  expect(types.toSet(), hasLength(types.length));
}

void main() {
  test('signed out action set is disabled and deduped', () {
    final actions = _actions(
      _snapshot(
        state: WalletAuthorityState.signedOut,
        signerSource: WalletSignerSource.none,
        accountSignedIn: false,
        walletAddress: null,
      ),
    );

    _expectNoDuplicateTypes(actions);
    expect(
        actions.map((action) => action.type),
        containsAll(<WalletActionType>[
          WalletActionType.createLocalWallet,
          WalletActionType.importWallet,
          WalletActionType.connectExternalWallet,
          WalletActionType.send,
          WalletActionType.receive,
          WalletActionType.secureWallet,
        ]));
    expect(
      actions
          .firstWhere((action) => action.type == WalletActionType.send)
          .enabled,
      isFalse,
    );
  });

  test('account shell exposes wallet setup actions once', () {
    final actions = _actions(
      _snapshot(
        state: WalletAuthorityState.accountShellOnly,
        signerSource: WalletSignerSource.none,
        walletAddress: null,
      ),
    );

    _expectNoDuplicateTypes(actions);
    expect(
      actions
          .where((action) => action.type == WalletActionType.createLocalWallet),
      hasLength(1),
    );
    expect(
      actions.where((action) => action.type == WalletActionType.importWallet),
      hasLength(1),
    );
    expect(
      actions
          .firstWhere(
              (action) => action.type == WalletActionType.createLocalWallet)
          .enabled,
      isTrue,
    );
  });

  test('signer missing with encrypted backup exposes one restore action', () {
    final actions = _actions(
      _snapshot(
        state: WalletAuthorityState.encryptedBackupAvailableSignerMissing,
        signerSource: WalletSignerSource.none,
        hasEncryptedBackup: true,
      ),
    );

    _expectNoDuplicateTypes(actions);
    expect(
      actions.where((action) => action.type == WalletActionType.restoreSigner),
      hasLength(1),
    );
    expect(
      actions
          .firstWhere((action) => action.type == WalletActionType.send)
          .enabled,
      isFalse,
    );
  });

  test('local signer ready enables transaction actions without restore', () {
    final actions = _actions(
      _snapshot(
        state: WalletAuthorityState.localSignerReady,
        signerSource: WalletSignerSource.local,
        hasLocalSigner: true,
        hasEncryptedBackup: true,
      ),
    );

    _expectNoDuplicateTypes(actions);
    expect(
        actions.any((action) => action.type == WalletActionType.restoreSigner),
        isFalse);
    expect(
      actions
          .firstWhere((action) => action.type == WalletActionType.send)
          .enabled,
      isTrue,
    );
    expect(
      actions
          .firstWhere((action) => action.type == WalletActionType.secureWallet)
          .enabled,
      isTrue,
    );
  });

  test(
      'external wallet ready enables transaction actions without connect duplicate',
      () {
    final actions = _actions(
      _snapshot(
        state: WalletAuthorityState.externalWalletReady,
        signerSource: WalletSignerSource.external,
        hasExternalSigner: true,
        externalWalletConnected: true,
        externalWalletName: 'Phantom',
      ),
    );

    _expectNoDuplicateTypes(actions);
    expect(
      actions.any(
          (action) => action.type == WalletActionType.connectExternalWallet),
      isFalse,
    );
    expect(
      actions
          .firstWhere((action) => action.type == WalletActionType.send)
          .enabled,
      isTrue,
    );
  });
}
