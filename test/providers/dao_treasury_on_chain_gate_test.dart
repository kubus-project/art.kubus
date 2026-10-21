import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts on-chain treasury reads; [gate] holds one read open.
class _CountingSolanaService extends SolanaWalletService {
  int treasuryCalls = 0;
  Completer<void>? gate;

  @override
  Future<double> getSplTokenBalance({
    required String owner,
    required String mint,
    int? expectedDecimals,
  }) async {
    treasuryCalls++;
    final pending = gate;
    if (pending != null) await pending.future;
    return 42.5;
  }
}

const _wallet = 'Wa11etAddressForDaoTreasuryGateTest1111111111';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingSolanaService solana;
  late int backendCalls;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    solana = _CountingSolanaService();
    backendCalls = 0;
    // The shared DAO load reaches the treasury step only after the backend
    // DAO reads succeed, so answer every DAO endpoint with an empty payload.
    BackendApiService().setHttpClient(
      MockClient((request) async {
        backendCalls++;
        return http.Response(jsonEncode(<dynamic>[]), 200,
            headers: {'content-type': 'application/json'});
      }),
    );
  });

  tearDown(() {
    BackendApiService().setHttpClient(http.Client());
  });

  test('guest desktop map prefetch makes no treasury RPC', () async {
    final dao = DAOProvider(solanaWalletService: solana);

    await dao.refreshData(force: true);

    expect(backendCalls, greaterThan(0), reason: 'the DAO load really ran');
    expect(dao.loadError, isNull, reason: 'the load completed');
    expect(solana.treasuryCalls, 0);
    expect(dao.treasuryOnChainBalance, isNull);
  });

  test('authenticated account without a wallet makes no treasury RPC',
      () async {
    final dao = DAOProvider(solanaWalletService: solana);
    final wallet = WalletProvider(solanaWalletService: solana, deferInit: true);
    dao.bindWalletProvider(wallet);

    await dao.refreshData(force: true);

    expect(backendCalls, greaterThan(0));
    expect(solana.treasuryCalls, 0);
  });

  test('wallet user: shared DAO load still makes no treasury RPC', () async {
    final dao = DAOProvider(solanaWalletService: solana);
    final wallet = WalletProvider(solanaWalletService: solana, deferInit: true);
    wallet.setCurrentWalletAddressForTesting(_wallet);
    dao.bindWalletProvider(wallet);

    await dao.refreshData(force: true);

    expect(solana.treasuryCalls, 0, reason: 'treasury is a governance read');
  });

  test('governance open makes exactly one treasury RPC', () async {
    final dao = DAOProvider(solanaWalletService: solana);

    await dao.ensureTreasuryOnChainBalance();

    expect(solana.treasuryCalls, 1);
    expect(dao.treasuryOnChainBalance, 42.5);
  });

  test('concurrent treasury requests share one in-flight read', () async {
    final dao = DAOProvider(solanaWalletService: solana);
    solana.gate = Completer<void>();

    final first = dao.ensureTreasuryOnChainBalance();
    final second = dao.ensureTreasuryOnChainBalance();
    await pumpEventQueue();
    expect(solana.treasuryCalls, 1);

    solana.gate!.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(solana.treasuryCalls, 1);
  });

  test('a fresh treasury balance is reused for five minutes', () async {
    final dao = DAOProvider(solanaWalletService: solana);

    await dao.ensureTreasuryOnChainBalance();
    await dao.ensureTreasuryOnChainBalance();
    await dao.ensureTreasuryOnChainBalance();

    expect(solana.treasuryCalls, 1);
  });
}
