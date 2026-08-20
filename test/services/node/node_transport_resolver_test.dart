import 'dart:io';

import 'package:art_kubus/services/node/kubus_node_transport.dart';
import 'package:art_kubus/services/node/node_transport_health.dart';
import 'package:art_kubus/services/node/node_transport_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// A transport whose behaviour each test dictates outright.
class _FakeTransport implements KubusNodeTransport {
  _FakeTransport(
    this.kind, {
    this.available = true,
    this.failWith,
  });

  @override
  final KubusNodeTransportKind kind;

  bool available;

  /// Thrown instead of answering, when set.
  Object? failWith;

  int requests = 0;
  int uploads = 0;
  int closes = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<KubusNodeResponse> request(KubusNodeRequest request) async {
    requests += 1;
    final error = failWith;
    if (error != null) throw error;
    return KubusNodeResponse(
      statusCode: 200,
      body: '{"via":"${kind.name}"}',
      requestPath: request.path,
    );
  }

  @override
  Future<KubusNodeResponse> streamUpload(
    KubusNodeRequest request, {
    required File file,
    required String contentType,
  }) async {
    uploads += 1;
    final error = failWith;
    if (error != null) throw error;
    return KubusNodeResponse(
      statusCode: 200,
      body: '{"via":"${kind.name}"}',
      requestPath: request.path,
    );
  }

  @override
  void close() => closes += 1;
}

/// A clock the test advances by hand, so cooldowns are deterministic.
class _TestClock {
  DateTime now = DateTime.utc(2026, 1, 1);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

const _read = KubusNodeRequest(method: 'GET', path: '/local/v1/info');
const _write = KubusNodeRequest(method: 'POST', path: '/local/v1/jobs');
const _idempotentWrite = KubusNodeRequest(
  method: 'POST',
  path: '/local/v1/captures/drafts/d1/commit',
  idempotencyKey: 'draft-d1-commit',
);

void main() {
  group('route preference', () {
    test('prefers the local route when every rung is available', () async {
      final lan = _FakeTransport(KubusNodeTransportKind.localDirect);
      final direct = _FakeTransport(KubusNodeTransportKind.webRtcDirect);
      final relay = _FakeTransport(KubusNodeTransportKind.webRtcRelay);
      final resolver = KubusNodeTransportResolver(
        transports: [relay, direct, lan],
      );

      await resolver.request(_read);

      expect(lan.requests, 1);
      expect(direct.requests, 0);
      expect(relay.requests, 0);
      expect(resolver.activeKind, KubusNodeTransportKind.localDirect);
    });

    test('a relay never outranks a working direct route, even if faster',
        () async {
      final clock = _TestClock();
      final direct = _FakeTransport(KubusNodeTransportKind.webRtcDirect);
      final relay = _FakeTransport(KubusNodeTransportKind.webRtcRelay);
      final resolver = KubusNodeTransportResolver(
        transports: [direct, relay],
        clock: clock.call,
      );

      // Give the relay a long record of fast success.
      for (var i = 0; i < 5; i++) {
        resolver.health[KubusNodeTransportKind.webRtcRelay]!
            .recordSuccess(const Duration(milliseconds: 1), clock.now);
      }
      resolver.health[KubusNodeTransportKind.webRtcDirect]!
          .recordSuccess(const Duration(milliseconds: 400), clock.now);

      await resolver.request(_read);

      expect(direct.requests, 1);
      expect(relay.requests, 0);
    });

    test('skips transports that report themselves unavailable', () async {
      final lan = _FakeTransport(
        KubusNodeTransportKind.localDirect,
        available: false,
      );
      final https = _FakeTransport(KubusNodeTransportKind.remoteHttps);
      final resolver = KubusNodeTransportResolver(transports: [lan, https]);

      await resolver.request(_read);

      expect(lan.requests, 0);
      expect(https.requests, 1);
    });
  });

  group('failover', () {
    test('falls through to the next route when the first cannot connect',
        () async {
      final lan = _FakeTransport(
        KubusNodeTransportKind.localDirect,
        failWith: const SocketException('no route to host'),
      );
      final https = _FakeTransport(KubusNodeTransportKind.remoteHttps);
      final resolver = KubusNodeTransportResolver(transports: [lan, https]);

      final response = await resolver.request(_read);

      expect(lan.requests, 1);
      expect(https.requests, 1);
      expect(response.body, contains('remoteHttps'));
    });

    test(
      'never retries a non-idempotent write on another route — a duplicate '
      'capture is worse than a failed one',
      () async {
        final lan = _FakeTransport(
          KubusNodeTransportKind.localDirect,
          failWith: const SocketException('connection reset'),
        );
        final https = _FakeTransport(KubusNodeTransportKind.remoteHttps);
        final resolver = KubusNodeTransportResolver(transports: [lan, https]);

        await expectLater(
          resolver.request(_write),
          throwsA(isA<SocketException>()),
        );

        expect(lan.requests, 1);
        expect(https.requests, 0, reason: 'must not duplicate the job');
      },
    );

    test('retries an idempotent write, because the Node can deduplicate it',
        () async {
      final lan = _FakeTransport(
        KubusNodeTransportKind.localDirect,
        failWith: const SocketException('connection reset'),
      );
      final https = _FakeTransport(KubusNodeTransportKind.remoteHttps);
      final resolver = KubusNodeTransportResolver(transports: [lan, https]);

      final response = await resolver.request(_idempotentWrite);

      expect(lan.requests, 1);
      expect(https.requests, 1);
      expect(response.statusCode, 200);
    });

    test('throws unreachable when no route is usable', () async {
      final lan = _FakeTransport(
        KubusNodeTransportKind.localDirect,
        available: false,
      );
      final resolver = KubusNodeTransportResolver(transports: [lan]);

      await expectLater(
        resolver.request(_read),
        throwsA(isA<KubusNodeUnreachableException>()),
      );
    });
  });

  group('a Node error is not a transport failure', () {
    test('an application exception does not demote the route or try another',
        () async {
      final lan = _FakeTransport(
        KubusNodeTransportKind.localDirect,
        failWith: StateError('worker_unavailable'),
      );
      final https = _FakeTransport(KubusNodeTransportKind.remoteHttps);
      final resolver = KubusNodeTransportResolver(transports: [lan, https]);

      await expectLater(resolver.request(_read), throwsStateError);

      // The route delivered the request; asking a second route would only
      // fetch the same unhappy answer.
      expect(https.requests, 0);
      expect(
        resolver.health[KubusNodeTransportKind.localDirect]!.state,
        KubusTransportHealth.healthy,
      );
    });

    test('a non-2xx response is returned, not treated as a route failure',
        () async {
      final lan = _FakeTransport(KubusNodeTransportKind.localDirect);
      final resolver = KubusNodeTransportResolver(transports: [lan]);

      final response = await resolver.request(_read);

      expect(response.statusCode, 200);
      expect(
        resolver.health[KubusNodeTransportKind.localDirect]!.state,
        KubusTransportHealth.healthy,
      );
    });
  });

  group('health and cooldown', () {
    test('a failing route is suppressed, then retried once cooldown expires',
        () async {
      final clock = _TestClock();
      final lan = _FakeTransport(
        KubusNodeTransportKind.localDirect,
        failWith: const SocketException('down'),
      );
      final https = _FakeTransport(KubusNodeTransportKind.remoteHttps);
      final resolver = KubusNodeTransportResolver(
        transports: [lan, https],
        clock: clock.call,
      );

      await resolver.request(_read);
      expect(lan.requests, 1);

      // Immediately after failing, the LAN route is skipped entirely.
      await resolver.request(_read);
      expect(lan.requests, 1, reason: 'still in cooldown');

      clock.advance(const Duration(minutes: 5));
      lan.failWith = null;
      await resolver.request(_read);
      expect(lan.requests, 2, reason: 'cooldown expired, route re-tried');
      expect(resolver.activeKind, KubusNodeTransportKind.localDirect);
    });

    test('cooldown lengthens with consecutive failures and is capped', () {
      final record =
          TransportHealthRecord(kind: KubusNodeTransportKind.localDirect);
      final now = DateTime.utc(2026, 1, 1);

      record.recordFailure(now);
      final first = record.cooldownUntil!.difference(now);
      record.recordFailure(now);
      final second = record.cooldownUntil!.difference(now);

      expect(second, greaterThan(first));

      for (var i = 0; i < 20; i++) {
        record.recordFailure(now);
      }
      expect(
        record.cooldownUntil!.difference(now),
        lessThanOrEqualTo(TransportHealthRecord.maxCooldown),
      );
    });

    test('success clears the failure streak', () {
      final record =
          TransportHealthRecord(kind: KubusNodeTransportKind.localDirect);
      final now = DateTime.utc(2026, 1, 1);

      record.recordFailure(now);
      record.recordFailure(now);
      expect(record.consecutiveFailures, 2);
      expect(record.state, KubusTransportHealth.cooldown);

      record.recordSuccess(const Duration(milliseconds: 20), now);
      expect(record.consecutiveFailures, 0);
      expect(record.cooldownUntil, isNull);
      expect(record.state, KubusTransportHealth.healthy);
    });

    test('latency is smoothed, so one stall cannot redefine a route', () {
      final record =
          TransportHealthRecord(kind: KubusNodeTransportKind.localDirect);
      final now = DateTime.utc(2026, 1, 1);

      record.recordSuccess(const Duration(milliseconds: 20), now);
      expect(record.latencyEwmaMs, closeTo(20, 0.01));

      record.recordSuccess(const Duration(milliseconds: 1020), now);
      // Pulled upward, but nowhere near the outlier itself.
      expect(record.latencyEwmaMs, greaterThan(20));
      expect(record.latencyEwmaMs, lessThan(500));
    });
  });

  group('network change', () {
    test('clears stale verdicts so the LAN route is reconsidered at once',
        () async {
      final clock = _TestClock();
      final lan = _FakeTransport(
        KubusNodeTransportKind.localDirect,
        failWith: const SocketException('was away from home'),
      );
      final https = _FakeTransport(KubusNodeTransportKind.remoteHttps);
      final resolver = KubusNodeTransportResolver(
        transports: [lan, https],
        clock: clock.call,
      );

      await resolver.request(_read);
      expect(lan.requests, 1);

      // Walked back in the door: the LAN route must not stay suppressed for
      // the remainder of its cooldown.
      lan.failWith = null;
      resolver.onNetworkChanged();
      await resolver.request(_read);

      expect(lan.requests, 2);
      expect(resolver.activeKind, KubusNodeTransportKind.localDirect);
    });
  });

  group('composition', () {
    test('is itself a transport, so callers never change', () {
      final resolver = KubusNodeTransportResolver(
        transports: [_FakeTransport(KubusNodeTransportKind.localDirect)],
      );
      expect(resolver, isA<KubusNodeTransport>());
    });

    test('closing the resolver closes every route it owns', () {
      final lan = _FakeTransport(KubusNodeTransportKind.localDirect);
      final https = _FakeTransport(KubusNodeTransportKind.remoteHttps);
      KubusNodeTransportResolver(transports: [lan, https]).close();

      expect(lan.closes, 1);
      expect(https.closes, 1);
    });

    test('streamUpload follows the same routing and retry rules', () async {
      final file = File(
        '${Directory.systemTemp.createTempSync('kubus_resolver').path}'
        '${Platform.pathSeparator}c.bin',
      );
      addTearDown(() => file.parent.deleteSync(recursive: true));
      file.writeAsBytesSync(List<int>.filled(16, 7));

      final lan = _FakeTransport(
        KubusNodeTransportKind.localDirect,
        failWith: const SocketException('down'),
      );
      final https = _FakeTransport(KubusNodeTransportKind.remoteHttps);
      final resolver = KubusNodeTransportResolver(transports: [lan, https]);

      await resolver.streamUpload(
        const KubusNodeRequest(
          method: 'PUT',
          path: '/local/v1/captures/drafts/d1/files',
          idempotencyKey: 'd1-file-0',
        ),
        file: file,
        contentType: 'application/octet-stream',
      );

      expect(lan.uploads, 1);
      expect(https.uploads, 1);
    });
  });
}
