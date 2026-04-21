import 'dart:convert';

import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/encrypted_wallet_backup_service.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _buildWalletToken(String walletAddress) {
  return _buildAuthToken(<String, Object?>{'walletAddress': walletAddress});
}

String _buildAuthToken(Map<String, Object?> claims) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode(<String, String>{'alg': 'none'})));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(claims),
    ),
  );
  return '$header.$payload.signature';
}

EncryptedWalletBackupDefinition _backupDefinition(String walletAddress) {
  return EncryptedWalletBackupDefinition(
    walletAddress: walletAddress,
    version: 1,
    kdfName: 'pbkdf2',
    kdfParams: const <String, dynamic>{'iterations': 1},
    salt: 'salt',
    wrappedDekNonce: 'wrappedDekNonce',
    wrappedDekCiphertext: 'wrappedDekCiphertext',
    mnemonicNonce: 'mnemonicNonce',
    mnemonicCiphertext: 'mnemonicCiphertext',
    passkeys: const <WalletBackupPasskeyDefinition>[
      WalletBackupPasskeyDefinition(
        credentialId: 'credential',
        transports: <String>['internal'],
        nickname: 'This device',
      ),
    ],
  );
}

Future<
    ({
      String walletAddress,
      DerivedKeyPairResult derived,
      SolanaWalletService solanaWalletService,
      WalletProvider walletProvider,
      Web3Provider web3Provider,
    })> _createBoundWalletProviders({
  bool withSigner = true,
  bool persistWalletIdentity = true,
}) async {
  final solanaWalletService = SolanaWalletService();
  final mnemonic = solanaWalletService.generateMnemonic();
  final derived = await solanaWalletService.derivePreferredKeyPair(mnemonic);

  if (withSigner) {
    solanaWalletService.setActiveKeyPair(derived.hdKeyPair);
  }

  if (persistWalletIdentity) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wallet_address', derived.address);
    await prefs.setString('walletAddress', derived.address);
    await prefs.setString('wallet', derived.address);
    await prefs.setBool('has_wallet', true);
  }

  final walletProvider = WalletProvider(
    solanaWalletService: solanaWalletService,
    deferInit: true,
  );
  walletProvider.setCurrentWalletAddressForTesting(derived.address);

  final web3Provider = Web3Provider(solanaWalletService: solanaWalletService)
    ..bindWalletProvider(walletProvider);

  return (
    walletAddress: derived.address,
    derived: derived,
    solanaWalletService: solanaWalletService,
    walletProvider: walletProvider,
    web3Provider: web3Provider,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setPreferredWalletAddress(null);
  });

  test('canonical authority state starts signed out', () {
    final walletProvider = WalletProvider(deferInit: true);

    expect(walletProvider.authority.state, WalletAuthorityState.signedOut);
    expect(walletProvider.authority.hasAccountSession, isFalse);
    expect(walletProvider.authority.canReadWallet, isFalse);
    expect(walletProvider.authority.canTransact, isFalse);
  });

  test('canonical authority state exposes account shell only', () {
    BackendApiService().setAuthTokenForTesting(
      _buildAuthToken(<String, Object?>{'email': 'artist@example.com'}),
    );
    final walletProvider = WalletProvider(deferInit: true);

    expect(
      walletProvider.authority.state,
      WalletAuthorityState.accountShellOnly,
    );
    expect(walletProvider.authority.accountSignedIn, isTrue);
    expect(walletProvider.authority.hasWalletIdentity, isFalse);
    expect(walletProvider.authority.canTransact, isFalse);
  });

  test('canonical authority state exposes read-only wallet identity', () async {
    final walletProvider = WalletProvider(deferInit: true);

    await walletProvider.setReadOnlyWalletIdentity(
      'readonly-wallet-123',
      loadData: false,
      syncBackend: false,
    );

    expect(walletProvider.authority.state, WalletAuthorityState.walletReadOnly);
    expect(walletProvider.authority.canReadWallet, isTrue);
    expect(walletProvider.authority.hasLocalSigner, isFalse);
    expect(walletProvider.authority.hasExternalSigner, isFalse);
    expect(walletProvider.authority.canTransact, isFalse);
  });

  test('canonical authority state exposes local signer readiness', () async {
    final providers = await _createBoundWalletProviders();

    expect(
      providers.walletProvider.authority.state,
      WalletAuthorityState.localSignerReady,
    );
    expect(
      providers.walletProvider.authority.signerSource,
      WalletSignerSource.local,
    );
    expect(providers.walletProvider.authority.canTransact, isTrue);
  });

  test('canonical authority state exposes external wallet readiness', () async {
    final walletProvider = WalletProvider(deferInit: true);

    await walletProvider.bindExternalSigner(
      address: 'external-wallet-123',
      walletName: 'Phantom',
      allowReplacingWalletIdentity: true,
    );

    expect(
      walletProvider.authority.state,
      WalletAuthorityState.externalWalletReady,
    );
    expect(walletProvider.authority.signerSource, WalletSignerSource.external);
    expect(walletProvider.authority.externalWalletName, 'Phantom');
    expect(walletProvider.authority.canTransact, isTrue);

    await walletProvider.clearExternalSigner();
    expect(walletProvider.authority.canTransact, isFalse);
  });

  test('external signer binding rejects address mismatches', () async {
    final walletProvider = WalletProvider(deferInit: true);
    await walletProvider.setReadOnlyWalletIdentity(
      'account-wallet',
      loadData: false,
      syncBackend: false,
    );

    expect(
      () => walletProvider.bindExternalSigner(
        address: 'other-wallet',
        walletName: 'Phantom',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('canonical authority state exposes encrypted backup restore path',
      () async {
    final walletProvider = WalletProvider(deferInit: true);
    await walletProvider.setReadOnlyWalletIdentity(
      'backup-wallet',
      loadData: false,
      syncBackend: false,
    );
    walletProvider.setEncryptedWalletBackupDefinitionForTesting(
      _backupDefinition('backup-wallet'),
    );

    expect(
      walletProvider.authority.state,
      WalletAuthorityState.encryptedBackupAvailableSignerMissing,
    );
    expect(walletProvider.authority.canRestoreFromEncryptedBackup, isTrue);
    expect(walletProvider.authority.hasPasskeyProtection, isTrue);
    expect(walletProvider.authority.canTransact, isFalse);
  });

  test('canonical authority state exposes recovery needed', () async {
    final walletProvider = WalletProvider(deferInit: true);
    await walletProvider.setReadOnlyWalletIdentity(
      'missing-backup-wallet',
      loadData: false,
      syncBackend: false,
    );
    walletProvider.setEncryptedWalletBackupStatusKnownForTesting(true);

    expect(walletProvider.authority.state, WalletAuthorityState.recoveryNeeded);
    expect(walletProvider.authority.recoveryNeeded, isTrue);
    expect(walletProvider.authority.canRestoreFromEncryptedBackup, isFalse);
  });

  test('backend account restoration with wallet claim never restores signer',
      () async {
    BackendApiService()
        .setAuthTokenForTesting(_buildWalletToken('claimed-wallet'));
    final walletProvider = WalletProvider(deferInit: true);

    final restored = await walletProvider.restoreAccountShellFromBackend(
      allowRefresh: false,
      loadWalletData: false,
    );

    expect(restored, isTrue);
    expect(walletProvider.authority.accountSignedIn, isTrue);
    expect(walletProvider.currentWalletAddress, 'claimed-wallet');
    expect(walletProvider.authority.state, WalletAuthorityState.walletReadOnly);
    expect(walletProvider.authority.hasLocalSigner, isFalse);
    expect(walletProvider.authority.hasExternalSigner, isFalse);
    expect(walletProvider.authority.canTransact, isFalse);
  });

  test('disconnect preserves authenticated wallet identity as read-only',
      () async {
    final providers = await _createBoundWalletProviders();
    final walletProvider = providers.walletProvider;
    BackendApiService()
        .setAuthTokenForTesting(_buildWalletToken(providers.walletAddress));

    expect(walletProvider.hasWalletIdentity, isTrue);
    expect(walletProvider.canTransact, isTrue);

    await walletProvider.disconnectWallet();

    expect(walletProvider.hasWalletIdentity, isTrue);
    expect(walletProvider.currentWalletAddress, providers.walletAddress);
    expect(walletProvider.canTransact, isFalse);
    expect(walletProvider.isReadOnlySession, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('walletAddress'), providers.walletAddress);
  });

  test('disconnect clears a local-only wallet session by default', () async {
    final providers = await _createBoundWalletProviders();
    final walletProvider = providers.walletProvider;

    await walletProvider.disconnectWallet();

    expect(walletProvider.hasWalletIdentity, isFalse);
    expect(walletProvider.currentWalletAddress, isNull);
    expect(walletProvider.canTransact, isFalse);
    expect(walletProvider.isReadOnlySession, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('walletAddress'), isNull);
    expect(prefs.getString('wallet_address'), isNull);
    expect(prefs.getString('wallet'), isNull);
  });

  test(
      'disconnect with preserveAuthenticatedWallet false clears the wallet session',
      () async {
    final providers = await _createBoundWalletProviders();
    final walletProvider = providers.walletProvider;

    await walletProvider.disconnectWallet(preserveAuthenticatedWallet: false);

    expect(walletProvider.hasWalletIdentity, isFalse);
    expect(walletProvider.currentWalletAddress, isNull);
    expect(walletProvider.canTransact, isFalse);
    expect(walletProvider.isReadOnlySession, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('walletAddress'), isNull);
    expect(prefs.getString('wallet_address'), isNull);
    expect(prefs.getString('wallet'), isNull);
  });

  test('logout disconnect clears restored account shell authority', () async {
    BackendApiService()
        .setAuthTokenForTesting(_buildWalletToken('claimed-wallet'));
    final walletProvider = WalletProvider(deferInit: true);

    await walletProvider.restoreAccountShellFromBackend(
      allowRefresh: false,
      loadWalletData: false,
    );
    expect(walletProvider.authority.accountSignedIn, isTrue);

    BackendApiService().setAuthTokenForTesting(null);
    await walletProvider.disconnectWallet(preserveAuthenticatedWallet: false);

    expect(walletProvider.authority.accountSignedIn, isFalse);
    expect(walletProvider.authority.state, WalletAuthorityState.signedOut);
  });

  test('web3 facade mirrors wallet read-only state and network updates',
      () async {
    final providers = await _createBoundWalletProviders(withSigner: false);
    final walletProvider = providers.walletProvider;
    final web3Provider = providers.web3Provider;

    expect(web3Provider.hasWalletIdentity, isTrue);
    expect(web3Provider.walletAddress, providers.walletAddress);
    expect(web3Provider.isReadOnlySession, isTrue);
    expect(web3Provider.isConnected, isFalse);

    providers.solanaWalletService.setActiveKeyPair(providers.derived.hdKeyPair);
    walletProvider.setCurrentWalletAddressForTesting(providers.walletAddress);

    expect(web3Provider.isConnected, isTrue);
    expect(web3Provider.canTransact, isTrue);

    walletProvider.switchSolanaNetwork('Devnet');
    expect(walletProvider.currentSolanaNetwork.toLowerCase(), 'devnet');
    expect(web3Provider.currentNetwork.toLowerCase(), 'devnet');
  });

  test('web3 signing actions require canonical transaction capability',
      () async {
    final walletProvider = WalletProvider(deferInit: true);
    await walletProvider.setReadOnlyWalletIdentity(
      'readonly-wallet-123',
      loadData: false,
      syncBackend: false,
    );
    final web3Provider = Web3Provider()..bindWalletProvider(walletProvider);

    expect(walletProvider.authority.canTransact, isFalse);
    await expectLater(
      web3Provider.swapSolToKub8(0.1),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      web3Provider.mintArtworkNFT(const <String, dynamic>{
        'name': 'Read-only mint',
      }),
      throwsA(isA<Exception>()),
    );
  });

  test('read-only wallet sessions can still require mnemonic backup', () async {
    final providers = await _createBoundWalletProviders(withSigner: false);
    final walletProvider = providers.walletProvider;

    expect(walletProvider.isReadOnlySession, isTrue);

    await walletProvider.setMnemonicBackupRequired(
      required: true,
      walletAddress: providers.walletAddress,
    );

    final required = await walletProvider.isMnemonicBackupRequired(
      walletAddress: providers.walletAddress,
    );
    expect(required, isTrue);

    await walletProvider.markMnemonicBackedUp(
      walletAddress: providers.walletAddress,
    );

    final requiredAfterBackup = await walletProvider.isMnemonicBackupRequired(
      walletAddress: providers.walletAddress,
    );
    expect(requiredAfterBackup, isFalse);
  });

  test('switching to a different wallet address clears the stale signer',
      () async {
    final providers = await _createBoundWalletProviders();
    final walletProvider = providers.walletProvider;

    expect(walletProvider.canTransact, isTrue);

    await walletProvider.connectWalletWithAddress('readonly-wallet-123');

    expect(walletProvider.currentWalletAddress, 'readonly-wallet-123');
    expect(walletProvider.hasSigner, isFalse);
    expect(walletProvider.canTransact, isFalse);
    expect(walletProvider.isReadOnlySession, isTrue);
  });
}
