@TestOn('browser')
library;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/web3/wallet/connectwallet_screen.dart';
import 'package:art_kubus/services/browser_solana_wallet_service.dart';
import 'package:art_kubus/services/external_wallet_signer_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeBrowserSolanaWalletService implements BrowserSolanaWalletService {
  _FakeBrowserSolanaWalletService(this.wallets);

  final List<BrowserSolanaWalletDefinition> wallets;

  @override
  Future<List<BrowserSolanaWalletDefinition>>
      discoverCompatibleWallets() async {
    return wallets;
  }

  @override
  Future<BrowserSolanaWalletConnectionResult> connect({
    required String walletId,
    required String chainId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<String> signAndSendTransactionBase64({
    required String transactionBase64,
    required String chainId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> signMessageBase64(String messageBase64) async {
    throw UnimplementedError();
  }

  @override
  Future<String> signTransactionBase64({
    required String transactionBase64,
    required String chainId,
  }) async {
    throw UnimplementedError();
  }
}

Widget _buildHarness() {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: ChangeNotifierProvider<WalletProvider>.value(
      value: WalletProvider(deferInit: true),
      child: const Scaffold(
        body: ConnectWallet(
          initialStep: 3,
          embedded: true,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ExternalWalletSignerService.instance.resetBrowserWalletService();
  });

  testWidgets('web chooser hides dead WalletConnect URI and QR controls',
      (tester) async {
    ExternalWalletSignerService.instance.replaceBrowserWalletService(
      _FakeBrowserSolanaWalletService(
        const <BrowserSolanaWalletDefinition>[
          BrowserSolanaWalletDefinition(
            id: 'phantom',
            name: 'Phantom',
            source: BrowserSolanaWalletSource.phantomInjected,
            isPhantom: true,
          ),
          BrowserSolanaWalletDefinition(
            id: 'solflare',
            name: 'Solflare',
            source: BrowserSolanaWalletSource.walletStandard,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Choose a browser wallet'), findsOneWidget);
    expect(find.text('Phantom'), findsOneWidget);
    expect(find.text('Solflare'), findsOneWidget);
    expect(find.text('Open all wallets'), findsOneWidget);
    expect(find.text('Scan QR code'), findsNothing);
    expect(find.text('External wallet session'), findsNothing);
  });

  testWidgets('web fallback view appears when no browser wallet is detected',
      (tester) async {
    ExternalWalletSignerService.instance.replaceBrowserWalletService(
      _FakeBrowserSolanaWalletService(
        const <BrowserSolanaWalletDefinition>[],
      ),
    );

    await tester.pumpWidget(_buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('No compatible browser wallet detected'), findsOneWidget);
    expect(find.text('Open all wallets'), findsOneWidget);
    expect(find.text('Rescan browser wallets'), findsOneWidget);
    expect(find.text('Scan QR code'), findsNothing);
    expect(find.text('External wallet session'), findsNothing);
  });
}
