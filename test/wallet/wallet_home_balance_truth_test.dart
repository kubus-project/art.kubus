import 'package:art_kubus/config/api_keys.dart';
import 'package:art_kubus/models/wallet.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/web3/wallet/wallet_home.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/product_surface_harness.dart';

const _address = 'A8FtJ7fvJHZfsmMLfT85rTE6itNCf4qu26A4nU9LeCZ2';

Token _token(String mint, String symbol, String name, double balance) {
  return Token(
    id: 'spl_$mint',
    name: name,
    symbol: symbol,
    type: TokenType.erc20,
    balance: balance,
    value: 0,
    changePercentage: 0,
    contractAddress: mint,
    decimals: 6,
    network: 'Solana',
  );
}

class _FakeWallet extends WalletProvider {
  _FakeWallet(this._tokens) : super(deferInit: true) {
    setCurrentWalletAddressForTesting(_address);
  }

  final List<Token> _tokens;

  @override
  List<Token> get tokens => List<Token>.unmodifiable(_tokens);

  @override
  String? get currentWalletAddress => _address;

  @override
  bool get hasFiatValuation => false;
}

void main() {
  testWidgets(
      'wallet shows the real KUB8 balance by canonical mint; an impostor '
      'token named KUB8 is listed under its own name, never counted',
      (tester) async {
    final provider = _FakeWallet(<Token>[
      _token(ApiKeys.kub8MintAddress, 'KUB8', 'kubus', 1234.5),
      _token('ImpostorMint1111111111111111111111111111111', 'KUB8',
          'Free KUB8 airdrop', 999999),
      _token(
          'So11111111111111111111111111111111111111112', 'SOL', 'Solana', 0.75),
    ]);

    final handle = tester.ensureSemantics();
    final priorOnError = FlutterError.onError;
    final renderErrors = await pumpProductSurface(
      tester,
      child: const WalletHome(),
      extraProviders: [
        ChangeNotifierProvider<WalletProvider>.value(value: provider),
      ],
    );
    // Restore before expect(): the harness collects errors until teardown.
    FlutterError.onError = priorOnError;
    expect(renderErrors, isEmpty);

    expect(find.text('1234.50'), findsOneWidget,
        reason: 'KUB8 balance from the canonical mint');
    expect(find.text('999999.00'), findsNothing,
        reason: 'impostor never counted as KUB8');
    expect(find.bySemanticsLabel('KUB8 balance: 1234.50 KUB8'), findsOneWidget,
        reason: 'economic numbers carry an accessible unit label');
    expect(find.text('Free KUB8 airdrop'), findsOneWidget);
    expect(find.text('0.750'), findsOneWidget);
    // No fiat total without a real price source; no glass hero.
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.byType(LiquidGlassCard), findsNothing);
    // Full address is spoken, the visible value is truncated machine text.
    expect(find.bySemanticsLabel('Wallet address $_address'), findsOneWidget);
    expect(find.byTooltip('Copy address'), findsOneWidget);
    handle.dispose();
  });
}
