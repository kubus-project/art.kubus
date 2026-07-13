import 'dart:convert';

import 'browser_solana_wallet_service_stub.dart'
    if (dart.library.js_interop) 'browser_solana_wallet_service_web.dart'
    as impl;

enum BrowserSolanaWalletSource {
  phantomInjected,
  walletStandard,
}

class BrowserSolanaWalletDefinition {
  const BrowserSolanaWalletDefinition({
    required this.id,
    required this.name,
    required this.source,
    this.isPhantom = false,
  });

  final String id;
  final String name;
  final BrowserSolanaWalletSource source;
  final bool isPhantom;
}

class BrowserSolanaWalletConnectionResult {
  const BrowserSolanaWalletConnectionResult({
    required this.address,
    required this.walletName,
  });

  final String address;
  final String walletName;
}

abstract class BrowserSolanaWalletService {
  Future<List<BrowserSolanaWalletDefinition>> discoverCompatibleWallets();

  Future<BrowserSolanaWalletConnectionResult> connect({
    required String walletId,
    required String chainId,
  });

  Future<void> disconnect();

  Future<String> signMessageBase64(String messageBase64);

  Future<String> signTransactionBase64({
    required String transactionBase64,
    required String chainId,
  });

  Future<String> signAndSendTransactionBase64({
    required String transactionBase64,
    required String chainId,
  });
}

enum ExternalWalletConnectRoute {
  directBrowserWallet,
  browserWalletChooser,
  reownModal,
  unavailable,
}

class ExternalWalletConnectPlan {
  const ExternalWalletConnectPlan({
    required this.route,
    required this.browserWallets,
    required this.reownAvailable,
  });

  final ExternalWalletConnectRoute route;
  final List<BrowserSolanaWalletDefinition> browserWallets;
  final bool reownAvailable;

  BrowserSolanaWalletDefinition? get preferredBrowserWallet =>
      route == ExternalWalletConnectRoute.directBrowserWallet &&
              browserWallets.isNotEmpty
          ? browserWallets.first
          : null;
}

ExternalWalletConnectPlan buildExternalWalletConnectPlan({
  required bool isWeb,
  required List<BrowserSolanaWalletDefinition> browserWallets,
  required bool reownAvailable,
}) {
  if (!isWeb) {
    return ExternalWalletConnectPlan(
      route: reownAvailable
          ? ExternalWalletConnectRoute.reownModal
          : ExternalWalletConnectRoute.unavailable,
      browserWallets: <BrowserSolanaWalletDefinition>[],
      reownAvailable: reownAvailable,
    );
  }

  if (browserWallets.isEmpty) {
    return ExternalWalletConnectPlan(
      route: reownAvailable
          ? ExternalWalletConnectRoute.reownModal
          : ExternalWalletConnectRoute.unavailable,
      browserWallets: const <BrowserSolanaWalletDefinition>[],
      reownAvailable: reownAvailable,
    );
  }

  if (browserWallets.length == 1) {
    return ExternalWalletConnectPlan(
      route: ExternalWalletConnectRoute.directBrowserWallet,
      browserWallets: List<BrowserSolanaWalletDefinition>.unmodifiable(
        browserWallets,
      ),
      reownAvailable: reownAvailable,
    );
  }

  return ExternalWalletConnectPlan(
    route: ExternalWalletConnectRoute.browserWalletChooser,
    browserWallets: List<BrowserSolanaWalletDefinition>.unmodifiable(
      browserWallets,
    ),
    reownAvailable: reownAvailable,
  );
}

String encodeBase64FromJson(Map<String, Object?> payload) {
  return base64Encode(utf8.encode(jsonEncode(payload)));
}

BrowserSolanaWalletService createBrowserSolanaWalletService() =>
    impl.createBrowserSolanaWalletService();
