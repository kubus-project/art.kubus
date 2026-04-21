import 'browser_solana_wallet_service.dart';

BrowserSolanaWalletService createBrowserSolanaWalletService() =>
    _BrowserSolanaWalletServiceStub();

class _BrowserSolanaWalletServiceStub implements BrowserSolanaWalletService {
  @override
  Future<List<BrowserSolanaWalletDefinition>>
      discoverCompatibleWallets() async {
    return const <BrowserSolanaWalletDefinition>[];
  }

  @override
  Future<BrowserSolanaWalletConnectionResult> connect({
    required String walletId,
    required String chainId,
  }) async {
    throw StateError('Browser-injected Solana wallets are unavailable.');
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<String> signAndSendTransactionBase64({
    required String transactionBase64,
    required String chainId,
  }) async {
    throw StateError('Browser-injected Solana wallets are unavailable.');
  }

  @override
  Future<String> signMessageBase64(String messageBase64) async {
    throw StateError('Browser-injected Solana wallets are unavailable.');
  }

  @override
  Future<String> signTransactionBase64({
    required String transactionBase64,
    required String chainId,
  }) async {
    throw StateError('Browser-injected Solana wallets are unavailable.');
  }
}
