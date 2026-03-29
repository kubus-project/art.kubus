import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/public_action_outbox_service.dart';
import 'package:art_kubus/services/public_fallback_service.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWalletService extends SolanaWalletService {
  _FakeWalletService(this.walletAddress);

  final String walletAddress;

  @override
  bool get hasActiveKeyPair => true;

  @override
  String? get activePublicKey => walletAddress;

  @override
  Future<String> signMessageBase64(String messageBase64) async {
    return base64Encode(utf8.encode('sig:$messageBase64'));
  }
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var index = 0; index < 20; index += 1) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for expected condition.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PublicFallbackService fallbackService;
  late PublicActionOutboxService outboxService;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    fallbackService = PublicFallbackService();
    await fallbackService.resetForTesting();
    outboxService = PublicActionOutboxService();
    await outboxService.resetForTesting();
    outboxService.bindSigner(
      walletService:
          _FakeWalletService('WalletTest111111111111111111111111111111'),
      walletAddressResolver: () => 'WalletTest111111111111111111111111111111',
    );
    await outboxService.initialize();
  });

  test('enqueueSignedAction persists a wallet-scoped signed queue entry',
      () async {
    final record = await outboxService.enqueueSignedAction(
      const PublicActionDraftPayload(
        actionType: 'like',
        entityType: 'artwork',
        entityId: 'art-1',
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().singleWhere(
          (entry) => entry.startsWith('public_action_outbox_v1_'),
        );
    final stored = prefs.getStringList(key);
    final decoded = jsonDecode(stored!.single) as Map<String, dynamic>;

    expect(outboxService.queuedActionCount, 1);
    expect(record.entityId, 'art-1');
    expect(decoded['clientActionId'], record.clientActionId);
    expect(decoded['walletAddress'], record.walletAddress);
    expect(decoded['signature'], isNotEmpty);
  });

  test('flush removes applied-like statuses and keeps retryable errors',
      () async {
    for (final entityId in const <String>['art-1', 'art-2', 'art-3', 'art-4']) {
      await outboxService.enqueueSignedAction(
        PublicActionDraftPayload(
          actionType: 'like',
          entityType: 'artwork',
          entityId: entityId,
        ),
      );
    }

    outboxService.bindHttpClient(
      MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final actions = body['actions'] as List<dynamic>;
        final results = actions.map((rawAction) {
          final action = rawAction as Map<String, dynamic>;
          final entityId = action['entityId'];
          final status = switch (entityId) {
            'art-1' => 'applied',
            'art-2' => 'duplicate',
            'art-3' => 'rejected',
            _ => 'retryable_error',
          };
          return <String, dynamic>{
            'clientActionId': action['clientActionId'],
            'status': status,
          };
        }).toList(growable: false);
        return http.Response(
            jsonEncode(<String, dynamic>{'results': results}), 200);
      }),
    );

    final result = await outboxService.flush();
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().singleWhere(
          (entry) => entry.startsWith('public_action_outbox_v1_'),
        );
    final stored = prefs.getStringList(key);
    final remaining = jsonDecode(stored!.single) as Map<String, dynamic>;

    expect(result.sentCount, 5);
    expect(result.removedCount, 3);
    expect(result.remainingCount, 1);
    expect(outboxService.queuedActionCount, 1);
    expect(remaining['entityId'], 'art-4');
  });

  test('recovery from IPFS fallback triggers an automatic flush', () async {
    for (var index = 0;
        index < AppConfig.backendOutageFailureThreshold;
        index += 1) {
      fallbackService.recordDualBackendFailure();
    }
    expect(fallbackService.mode, AppRuntimeMode.ipfsFallback);

    await outboxService.enqueueSignedAction(
      const PublicActionDraftPayload(
        actionType: 'follow',
        entityType: 'profile',
        entityId: 'WalletTarget11111111111111111111111111111',
      ),
    );

    outboxService.bindHttpClient(
      MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final actions = body['actions'] as List<dynamic>;
        final results = actions.map((rawAction) {
          final action = rawAction as Map<String, dynamic>;
          return <String, dynamic>{
            'clientActionId': action['clientActionId'],
            'status': 'applied',
          };
        }).toList(growable: false);
        return http.Response(
            jsonEncode(<String, dynamic>{'results': results}), 200);
      }),
    );

    fallbackService.recordBackendSuccess(baseUrl: AppConfig.baseApiUrl);
    expect(outboxService.queuedActionCount, 1);

    fallbackService.recordBackendSuccess(baseUrl: AppConfig.baseApiUrl);
    await _waitUntil(() => outboxService.queuedActionCount == 0);

    expect(fallbackService.mode, AppRuntimeMode.live);
    expect(outboxService.queuedActionCount, 0);
  });

  test('initialize flushes queued actions when runtime mode is already live',
      () async {
    await outboxService.enqueueSignedAction(
      const PublicActionDraftPayload(
        actionType: 'bookmark',
        entityType: 'post',
        entityId: 'post-1',
      ),
    );

    await outboxService.resetForTesting();
    outboxService.bindHttpClient(
      MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final actions = body['actions'] as List<dynamic>;
        final results = actions.map((rawAction) {
          final action = rawAction as Map<String, dynamic>;
          return <String, dynamic>{
            'clientActionId': action['clientActionId'],
            'status': 'applied',
          };
        }).toList(growable: false);
        return http.Response(
          jsonEncode(<String, dynamic>{'results': results}),
          200,
        );
      }),
    );

    await outboxService.initialize();
    await _waitUntil(() => outboxService.queuedActionCount == 0);

    expect(outboxService.queuedActionCount, 0);
  });
}
