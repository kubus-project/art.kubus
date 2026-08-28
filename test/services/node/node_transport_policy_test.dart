import 'dart:io';

import 'package:art_kubus/services/node/kubus_node_transport.dart';
import 'package:art_kubus/services/node/node_transport_policy.dart';
import 'package:art_kubus/services/node/node_transport_resolver.dart';
import 'package:art_kubus/services/node/turn_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTransport implements KubusNodeTransport {
  _FakeTransport(this.kind);

  @override
  final KubusNodeTransportKind kind;

  int requests = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<KubusNodeResponse> request(KubusNodeRequest request) async {
    requests += 1;
    return KubusNodeResponse(
      statusCode: 200,
      body: '{"via":"${kind.name}"}',
      requestPath: request.path,
    );
  }

  @override
  Future<KubusNodeResponse> streamUpload(
    KubusNodeRequest req, {
    required File file,
    required String contentType,
  }) =>
      request(req);

  @override
  void close() {}
}

const _read = KubusNodeRequest(method: 'GET', path: '/local/v1/info');
final _now = DateTime.utc(2026, 1, 1, 12);

void main() {
  group('policy is pluggable, not hard-coded', () {
    test('a native client tries the local route first', () async {
      final lan = _FakeTransport(KubusNodeTransportKind.localDirect);
      final direct = _FakeTransport(KubusNodeTransportKind.webRtcDirect);
      final resolver = KubusNodeTransportResolver(
        transports: [direct, lan],
        policy: const NativeTransportPolicy(),
      );

      await resolver.request(_read);

      expect(lan.requests, 1);
      expect(direct.requests, 0);
    });

    test(
      'a browser client tries WebRTC first, because private-network HTTP from '
      'a public origin is frequently blocked',
      () async {
        final lan = _FakeTransport(KubusNodeTransportKind.localDirect);
        final direct = _FakeTransport(KubusNodeTransportKind.webRtcDirect);
        final resolver = KubusNodeTransportResolver(
          transports: [lan, direct],
          policy: const BrowserTransportPolicy(),
        );

        await resolver.request(_read);

        expect(direct.requests, 1);
        expect(lan.requests, 0);
      },
    );

    test('a route the policy omits is never attempted', () async {
      final relay = _FakeTransport(KubusNodeTransportKind.webRtcRelay);
      final resolver = KubusNodeTransportResolver(
        transports: [relay],
        policy: _NoRelayPolicy(),
      );

      await expectLater(
        resolver.request(_read),
        throwsA(isA<KubusNodeUnreachableException>()),
      );
      expect(relay.requests, 0);
    });
  });

  group('relay avoidance', () {
    test('a bulk spatial transfer avoids the relay when a direct route exists',
        () async {
      final relay = _FakeTransport(KubusNodeTransportKind.webRtcRelay);
      final https = _FakeTransport(KubusNodeTransportKind.remoteHttps);
      final resolver = KubusNodeTransportResolver(
        transports: [relay, https],
        policy: const NativeTransportPolicy(),
        contextForOperation: () => const TransportSelectionContext(
          operationClass: NodeOperationClass.bulkUpload,
          expectedUploadBytes: 400 * 1024 * 1024,
        ),
      );

      await resolver.request(_read);

      // Relay bandwidth is paid for by whoever runs the relay; a 400 MB
      // capture is exactly what must not go over it by default.
      expect(https.requests, 1);
      expect(relay.requests, 0);
    });

    test('the relay still carries a bulk transfer when it is the only route',
        () async {
      final relay = _FakeTransport(KubusNodeTransportKind.webRtcRelay);
      final resolver = KubusNodeTransportResolver(
        transports: [relay],
        policy: const NativeTransportPolicy(),
        contextForOperation: () => const TransportSelectionContext(
          operationClass: NodeOperationClass.bulkUpload,
          expectedUploadBytes: 400 * 1024 * 1024,
        ),
      );

      await resolver.request(_read);

      // Penalised, never removed: a slow upload beats no upload.
      expect(relay.requests, 1);
    });

    test('a metered network penalises the relay for ordinary requests', () {
      const policy = NativeTransportPolicy();
      const metered = TransportSelectionContext(network: NetworkClass.mobile);
      const unmetered = TransportSelectionContext(network: NetworkClass.wifi);

      expect(
        policy.penaltyFor(KubusNodeTransportKind.webRtcRelay, metered),
        greaterThan(
          policy.penaltyFor(KubusNodeTransportKind.webRtcRelay, unmetered),
        ),
      );
    });

    test('non-relay routes are never penalised for size or metering', () {
      const policy = NativeTransportPolicy();
      const heavy = TransportSelectionContext(
        expectedUploadBytes: 400 * 1024 * 1024,
        network: NetworkClass.mobile,
      );

      for (final kind in [
        KubusNodeTransportKind.localDirect,
        KubusNodeTransportKind.webRtcDirect,
        KubusNodeTransportKind.remoteHttps,
      ]) {
        expect(policy.penaltyFor(kind, heavy), 0, reason: '$kind');
      }
    });

    test(
        'the bulk threshold is what distinguishes a capture from a status call',
        () {
      const small = TransportSelectionContext(expectedUploadBytes: 1024);
      const large = TransportSelectionContext(
        expectedUploadBytes:
            TransportSelectionContext.defaultBulkTransferThresholdBytes,
      );

      expect(small.isBulkTransfer, isFalse);
      expect(large.isBulkTransfer, isTrue);
      expect(const TransportSelectionContext().isBulkTransfer, isFalse);
    });
  });

  group('TURN is optional and never permanent', () {
    test('an ICE configuration with no relay is entirely valid', () {
      const config = IceConfiguration(
        stun: [StunServer('stun:stun.example:3478')],
      );

      // Owning a Node must never require a relay.
      expect(config.relayAvailableAt(_now), isFalse);
      expect(config.toIceServers(_now), hasLength(1));
    });

    test('a valid short-lived credential is accepted', () {
      final credentials = TurnCredentials(
        urls: const ['turn:relay.example:3478?transport=udp'],
        username: '1767225600:device-1',
        credential: 'derived',
        expiresAt: _now.add(const Duration(minutes: 10)),
      );

      expect(
        () => credentials.validate(now: _now, issuedAt: _now),
        returnsNormally,
      );
    });

    test('a credential outliving the maximum is refused on receipt', () {
      final credentials = TurnCredentials(
        urls: const ['turn:relay.example:3478'],
        username: 'u',
        credential: 'c',
        expiresAt: _now.add(const Duration(days: 1)),
      );

      // Enforced client-side rather than trusted: a control plane that starts
      // issuing day-long credentials must fail loudly, not quietly widen the
      // window in which a leaked credential is useful.
      expect(
        () => credentials.validate(now: _now, issuedAt: _now),
        throwsA(isA<TurnCredentialException>()),
      );
    });

    test('an already-expired credential is refused', () {
      final credentials = TurnCredentials(
        urls: const ['turn:relay.example:3478'],
        username: 'u',
        credential: 'c',
        expiresAt: _now.subtract(const Duration(minutes: 1)),
      );

      expect(
        () => credentials.validate(now: _now, issuedAt: _now),
        throwsA(isA<TurnCredentialException>()),
      );
    });

    test('a non-relay URL is refused', () {
      final credentials = TurnCredentials(
        urls: const ['https://backend.example'],
        username: 'u',
        credential: 'c',
        expiresAt: _now.add(const Duration(minutes: 5)),
      );

      // The relay is a separate service; pointing relay config at the control
      // plane would collapse the separation this design depends on.
      expect(
        () => credentials.validate(now: _now, issuedAt: _now),
        throwsA(isA<TurnCredentialException>()),
      );
    });

    test('an incomplete credential is refused', () {
      for (final pair in [('', 'c'), ('u', ''), ('  ', '  ')]) {
        final credentials = TurnCredentials(
          urls: const ['turn:relay.example:3478'],
          username: pair.$1,
          credential: pair.$2,
          expiresAt: _now.add(const Duration(minutes: 5)),
        );
        expect(
          () => credentials.validate(now: _now, issuedAt: _now),
          throwsA(isA<TurnCredentialException>()),
        );
      }
    });

    test('an expired credential is dropped from ICE servers, not offered', () {
      final config = IceConfiguration(
        stun: const [StunServer('stun:stun.example:3478')],
        turn: TurnCredentials(
          urls: const ['turn:relay.example:3478'],
          username: 'u',
          credential: 'c',
          expiresAt: _now.add(const Duration(minutes: 5)),
        ),
      );

      expect(config.toIceServers(_now), hasLength(2));
      // Handing WebRTC a credential the relay will reject only wastes
      // negotiation time and hides why the connection really failed.
      expect(
        config.toIceServers(_now.add(const Duration(minutes: 6))),
        hasLength(1),
      );
    });

    test('the credential never appears in log output', () {
      final credentials = TurnCredentials(
        urls: const ['turn:relay.example:3478'],
        username: '1767225600:device-1',
        credential: 'super-secret-derived-value',
        expiresAt: _now.add(const Duration(minutes: 5)),
      );

      final logged = credentials.toLogSafeJson().toString();
      expect(logged, isNot(contains('super-secret-derived-value')));
      expect(logged, contains('relay.example'));
    });
  });
}

/// A deployment that declines to use a relay at all.
class _NoRelayPolicy extends NodeTransportPolicy {
  @override
  List<KubusNodeTransportKind> order(TransportSelectionContext context) =>
      const <KubusNodeTransportKind>[
        KubusNodeTransportKind.localDirect,
        KubusNodeTransportKind.webRtcDirect,
        KubusNodeTransportKind.remoteHttps,
      ];
}
