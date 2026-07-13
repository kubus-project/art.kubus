import 'package:art_kubus/services/browser_solana_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const phantom = BrowserSolanaWalletDefinition(
    id: 'phantom',
    name: 'Phantom',
    source: BrowserSolanaWalletSource.phantomInjected,
    isPhantom: true,
  );
  const solflare = BrowserSolanaWalletDefinition(
    id: 'solflare',
    name: 'Solflare',
    source: BrowserSolanaWalletSource.walletStandard,
  );

  test('single injected wallet on web prefers direct browser connect', () {
    final plan = buildExternalWalletConnectPlan(
      isWeb: true,
      browserWallets: const <BrowserSolanaWalletDefinition>[phantom],
      reownAvailable: true,
    );

    expect(plan.route, ExternalWalletConnectRoute.directBrowserWallet);
    expect(plan.preferredBrowserWallet?.id, phantom.id);
  });

  test('multiple injected wallets on web require chooser', () {
    final plan = buildExternalWalletConnectPlan(
      isWeb: true,
      browserWallets: const <BrowserSolanaWalletDefinition>[
        phantom,
        solflare,
      ],
      reownAvailable: true,
    );

    expect(plan.route, ExternalWalletConnectRoute.browserWalletChooser);
    expect(plan.preferredBrowserWallet, isNull);
    expect(plan.browserWallets, hasLength(2));
  });

  test('no injected wallet on web falls back to Reown modal', () {
    final plan = buildExternalWalletConnectPlan(
      isWeb: true,
      browserWallets: const <BrowserSolanaWalletDefinition>[],
      reownAvailable: true,
    );

    expect(plan.route, ExternalWalletConnectRoute.reownModal);
    expect(plan.browserWallets, isEmpty);
  });

  test('non-web ignores browser wallets and uses Reown modal', () {
    final plan = buildExternalWalletConnectPlan(
      isWeb: false,
      browserWallets: const <BrowserSolanaWalletDefinition>[phantom],
      reownAvailable: true,
    );

    expect(plan.route, ExternalWalletConnectRoute.reownModal);
    expect(plan.browserWallets, isEmpty);
  });

  test('MetaMask Wallet Standard works without a Reown project ID', () {
    const metamask = BrowserSolanaWalletDefinition(
      id: 'wallet-standard-metamask',
      name: 'MetaMask',
      source: BrowserSolanaWalletSource.walletStandard,
    );
    final plan = buildExternalWalletConnectPlan(
      isWeb: true,
      browserWallets: const <BrowserSolanaWalletDefinition>[metamask],
      reownAvailable: false,
    );

    expect(plan.route, ExternalWalletConnectRoute.directBrowserWallet);
    expect(plan.preferredBrowserWallet?.name, 'MetaMask');
    expect(plan.reownAvailable, isFalse);
  });

  test('missing browser wallet and Reown configuration is unavailable', () {
    final plan = buildExternalWalletConnectPlan(
      isWeb: true,
      browserWallets: const <BrowserSolanaWalletDefinition>[],
      reownAvailable: false,
    );

    expect(plan.route, ExternalWalletConnectRoute.unavailable);
    expect(plan.browserWallets, isEmpty);
  });

  test('non-web requires Reown configuration', () {
    final plan = buildExternalWalletConnectPlan(
      isWeb: false,
      browserWallets: const <BrowserSolanaWalletDefinition>[phantom],
      reownAvailable: false,
    );

    expect(plan.route, ExternalWalletConnectRoute.unavailable);
    expect(plan.browserWallets, isEmpty);
  });
}
