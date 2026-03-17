import 'dart:convert';

import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _buildWalletToken(String walletAddress) {
  final header =
      base64Url.encode(utf8.encode(jsonEncode(<String, String>{'alg': 'none'})));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, String>{'walletAddress': walletAddress}),
    ),
  );
  return '$header.$payload.signature';
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
}
