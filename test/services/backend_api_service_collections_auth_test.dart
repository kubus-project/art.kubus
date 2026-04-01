import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/backend_api_service.dart';
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

class _InactiveWalletService extends SolanaWalletService {
  @override
  bool get hasActiveKeyPair => false;

  @override
  String? get activePublicKey => null;

  @override
  Future<String> signMessageBase64(String messageBase64) async {
    throw UnsupportedError('No signing key available');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await PublicFallbackService().resetForTesting();
    final outbox = PublicActionOutboxService();
    await outbox.resetForTesting();
    outbox.bindSigner(
      walletService:
          _FakeWalletService('WalletTest111111111111111111111111111111'),
      walletAddressResolver: () => 'WalletTest111111111111111111111111111111',
    );
    await outbox.initialize();
    final api = BackendApiService();
    api.setPreferredWalletAddress(null);
    api.setAuthTokenForTesting(null);
  });

  test('getCollections for another wallet does not auto-issue auth', () async {
    final requests = <http.Request>[];

    final api = BackendApiService();
    api.setHttpClient(MockClient((request) async {
      requests.add(request);

      // The only expected call is an unauthenticated GET to /api/collections.
      if (request.method.toUpperCase() == 'GET' &&
          request.url.path.endsWith('/api/collections')) {
        return http.Response(
          jsonEncode(<String, Object?>{'data': <Object?>[]}),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      // Anything else would indicate auth issuance or unexpected side-effects.
      return http.Response(
        jsonEncode(<String, Object?>{
          'error': 'unexpected request',
          'path': request.url.path,
          'method': request.method
        }),
        500,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }));

    await api.getCollections(walletAddress: 'someone_else_wallet', limit: 6);

    expect(requests, isNotEmpty);
    expect(requests.every((r) => r.method.toUpperCase() == 'GET'), isTrue);
    expect(
      requests.every((r) => r.url.path.endsWith('/api/collections')),
      isTrue,
      reason:
          'Expected only collections fetch requests when viewing another user\'s collections.',
    );

    // Critical security behavior: no auth header should be attached for other users.
    expect(
      requests.every((r) =>
          !r.headers.keys.any((k) => k.toLowerCase() == 'authorization')),
      isTrue,
      reason:
          'Viewing another user\'s collections must not include Authorization nor trigger token issuance.',
    );
  });

  test('getCollections keeps implicit self requests scoped in snapshot mode',
      () async {
    const selfWallet = 'WalletSelf11111111111111111111111111111111';
    const selfCid =
        'bafybeigdyrzt5bq2dp2i5m2h3x2p6g7c6f3s4n5m6p7q8r9s0t1u2v3w4';
    const placeholderCid =
        'bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku';

    final registry = <String, dynamic>{
      'version': '2026-03-29',
      'generatedAt': '2026-03-29T12:00:00Z',
      'datasets': <String, dynamic>{
        for (final key in PublicFallbackService.requiredDatasetKeys)
          key: <String, dynamic>{
            'cid': key == 'collections' ? selfCid : placeholderCid,
            'generatedAt': '2026-03-29T12:00:00Z',
          },
      },
    };
    final collections = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'self-collection',
        'name': 'My Collection',
        'walletAddress': selfWallet,
      },
      <String, dynamic>{
        'id': 'other-collection',
        'name': 'Other Collection',
        'walletAddress': 'WalletOther11111111111111111111111111111',
      },
    ];

    SharedPreferences.setMockInitialValues(<String, Object>{
      'public_snapshot_registry_cache_v1': jsonEncode(registry),
      'public_snapshot_registry_raw_cache_v1': jsonEncode(registry),
      'public_snapshot_dataset_raw_cache_v1_collections':
          jsonEncode(collections),
      'public_snapshot_dataset_cid_cache_v1_collections': selfCid,
    });

    final fallbackService = PublicFallbackService();
    await fallbackService.resetForTesting();
    for (var i = 0; i < AppConfig.backendOutageFailureThreshold; i += 1) {
      fallbackService.recordDualBackendFailure();
    }

    final api = BackendApiService();
    api.setPreferredWalletAddress(selfWallet);

    final result = await api.getCollections(limit: 10);

    expect(fallbackService.mode, AppRuntimeMode.ipfsFallback);
    expect(result, hasLength(1));
    expect(result.single['id'], 'self-collection');
  });

  test('queueable mutation failures do not increment dual-backend outages',
      () async {
    final fallbackService = PublicFallbackService();
    final outboxService = PublicActionOutboxService();
    final api = BackendApiService();

    api.setHttpClient(MockClient((request) async {
      if (request.url.path.contains('/api/artworks/') &&
          request.url.path.endsWith('/like')) {
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'error': 'temporary outage',
          }),
          503,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      return http.Response(
        jsonEncode(<String, Object?>{'success': false, 'error': 'unexpected'}),
        500,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }));

    final likes = await api.likeArtwork('art-queue-1');
    expect(likes, isNull);

    expect(fallbackService.consecutiveDualFailures, 0);
    expect(fallbackService.mode, AppRuntimeMode.live);
    expect(outboxService.queuedActionCount, 1);
  });

  test('queueable writes preserve primary 4xx instead of queuing via standby',
      () async {
    final requests = <http.Request>[];
    final outboxService = PublicActionOutboxService();
    final api = BackendApiService();

    api.setHttpClient(MockClient((request) async {
      requests.add(request);
      if (request.url.host == Uri.parse(AppConfig.baseApiUrl).host) {
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'error': 'artwork not found',
          }),
          404,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      return http.Response(
        jsonEncode(<String, Object?>{
          'success': false,
          'error': 'standby unavailable',
        }),
        503,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }));

    await expectLater(
      api.likeArtwork('missing-artwork'),
      throwsA(
        isA<BackendApiRequestException>().having(
          (error) => error.statusCode,
          'statusCode',
          404,
        ),
      ),
    );

    expect(requests, hasLength(1));
    expect(requests.single.url.host, Uri.parse(AppConfig.baseApiUrl).host);
    expect(outboxService.queuedActionCount, 0);
  });

  test('ipfs fallback write path does not queue when session cannot sign',
      () async {
    final fallbackService = PublicFallbackService();
    final outboxService = PublicActionOutboxService();
    final api = BackendApiService();

    await outboxService.resetForTesting();
    outboxService.bindSigner(
      walletService: _InactiveWalletService(),
      walletAddressResolver: () => 'WalletTest111111111111111111111111111111',
    );
    await outboxService.initialize();

    for (var i = 0; i < AppConfig.backendOutageFailureThreshold; i += 1) {
      fallbackService.recordDualBackendFailure();
    }

    await expectLater(
      api.likeArtwork('art-ipfs-no-signer'),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('public snapshot fallback'),
        ),
      ),
    );

    expect(fallbackService.mode, AppRuntimeMode.ipfsFallback);
    expect(outboxService.queuedActionCount, 0);
  });

  test('street art claims are blocked while snapshot fallback is active',
      () async {
    final fallbackService = PublicFallbackService();
    final api = BackendApiService();
    var requestCount = 0;

    api.setHttpClient(MockClient((request) async {
      requestCount += 1;
      return http.Response(
        jsonEncode(<String, Object?>{'success': true, 'data': <Object?>[]}),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }));

    for (var i = 0; i < AppConfig.backendOutageFailureThreshold; i += 1) {
      fallbackService.recordDualBackendFailure();
    }

    await expectLater(
      api.getStreetArtClaims('marker-ipfs'),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Street art claims is unavailable'),
        ),
      ),
    );

    expect(fallbackService.mode, AppRuntimeMode.ipfsFallback);
    expect(requestCount, 0);
  });
}
