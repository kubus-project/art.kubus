import 'dart:async';

import 'package:art_kubus/models/wallet.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts the three RPC reads of a wallet sync; [gate] holds a sync open.
class _CountingWalletService extends SolanaWalletService {
  int balanceCalls = 0;
  Completer<void>? gate;
  bool failBalance = false;

  @override
  Future<double> getBalance(String publicKey) async {
    balanceCalls++;
    final pending = gate;
    if (pending != null) await pending.future;
    if (failBalance) throw StateError('rpc unavailable');
    return 1.5;
  }

  @override
  Future<List<TokenBalance>> getTokenBalances(String publicKey) async =>
      const <TokenBalance>[];

  @override
  Future<List<WalletTransaction>> getTransactionHistory(
    String publicKey, {
    int limit = 25,
    String? beforeSignature,
  }) async =>
      const <WalletTransaction>[];
}

const _wallet = 'Wa11etAddressForEnsureWalletDataTest11111111';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingWalletService service;
  late WalletProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    service = _CountingWalletService();
    provider = WalletProvider(solanaWalletService: service, deferInit: true);
  });

  test('does nothing without a wallet', () async {
    await provider.ensureWalletData();
    expect(service.balanceCalls, 0);
  });

  test('joins one in-flight sync and reuses a fresh result', () async {
    provider.setCurrentWalletAddressForTesting(_wallet);
    service.gate = Completer<void>();

    final first = provider.ensureWalletData();
    final second = provider.ensureWalletData();
    final explicit = provider.refreshData();
    await pumpEventQueue();
    expect(service.balanceCalls, 1);

    service.gate!.complete();
    await Future.wait(<Future<void>>[first, second, explicit]);
    expect(service.balanceCalls, 1);
    expect(provider.wallet, isNotNull);

    await provider.ensureWalletData();
    expect(service.balanceCalls, 1, reason: 'fresh data is reused');

    await provider.ensureWalletData(maxAge: Duration.zero);
    expect(service.balanceCalls, 2, reason: 'stale data is reloaded');
  });

  test('a network change makes the cached result stale', () async {
    provider.setCurrentWalletAddressForTesting(_wallet);
    await provider.ensureWalletData();
    expect(service.balanceCalls, 1);

    service.switchNetwork(
      service.currentNetwork == 'devnet' ? 'mainnet' : 'devnet',
    );
    await provider.ensureWalletData();
    expect(service.balanceCalls, 2);
  });

  test('a failed sync is not treated as fresh', () async {
    provider.setCurrentWalletAddressForTesting(_wallet);
    service.failBalance = true;
    await provider.ensureWalletData();
    expect(service.balanceCalls, 1);
    expect(provider.wallet, isNull);

    service.failBalance = false;
    await provider.ensureWalletData();
    expect(service.balanceCalls, 2);
    expect(provider.wallet, isNotNull);
  });
}
