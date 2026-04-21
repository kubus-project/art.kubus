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
    );

    expect(plan.route, ExternalWalletConnectRoute.browserWalletChooser);
    expect(plan.preferredBrowserWallet, isNull);
    expect(plan.browserWallets, hasLength(2));
  });

  test('no injected wallet on web falls back to Reown modal', () {
    final plan = buildExternalWalletConnectPlan(
      isWeb: true,
      browserWallets: const <BrowserSolanaWalletDefinition>[],
    );

    expect(plan.route, ExternalWalletConnectRoute.reownModal);
    expect(plan.browserWallets, isEmpty);
  });

  test('non-web ignores browser wallets and uses Reown modal', () {
    final plan = buildExternalWalletConnectPlan(
      isWeb: false,
      browserWallets: const <BrowserSolanaWalletDefinition>[phantom],
    );

    expect(plan.route, ExternalWalletConnectRoute.reownModal);
    expect(plan.browserWallets, isEmpty);
  });
}
