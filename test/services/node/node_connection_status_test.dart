import 'dart:io';

import 'package:art_kubus/services/node/kubus_node_transport.dart';
import 'package:art_kubus/services/node/node_connection_status.dart';
import 'package:art_kubus/services/node/node_transport_health.dart';
import 'package:art_kubus/services/node/node_transport_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTransport implements KubusNodeTransport {
  _FakeTransport(this.kind, {this.failWith});

  @override
  final KubusNodeTransportKind kind;
  final Object? failWith;

  @override
  bool get isAvailable => true;

  @override
  Future<KubusNodeResponse> request(KubusNodeRequest request) async {
    final error = failWith;
    if (error != null) throw error;
    return const KubusNodeResponse(statusCode: 200, body: '{}');
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

const _presenter = NodeConnectionPresenter();
const _read = KubusNodeRequest(method: 'GET', path: '/local/v1/info');

void main() {
  group('headline status', () {
    test('an unpaired device reports unpaired, whatever the routes say', () {
      final resolver = KubusNodeTransportResolver(
        transports: [_FakeTransport(KubusNodeTransportKind.localDirect)],
      );

      expect(
        _presenter.statusFor(isPaired: false, resolver: resolver),
        NodeConnectionStatus.unpaired,
      );
    });

    test('a healthy local route reads as "nearby"', () async {
      final resolver = KubusNodeTransportResolver(
        transports: [_FakeTransport(KubusNodeTransportKind.localDirect)],
      );
      await resolver.request(_read);

      expect(
        _presenter.statusFor(isPaired: true, resolver: resolver),
        NodeConnectionStatus.connectedNearby,
      );
    });

    test('every non-local rung reads simply as "remotely"', () async {
      for (final kind in [
        KubusNodeTransportKind.webRtcDirect,
        KubusNodeTransportKind.webRtcRelay,
        KubusNodeTransportKind.remoteHttps,
      ]) {
        final resolver =
            KubusNodeTransportResolver(transports: [_FakeTransport(kind)]);
        await resolver.request(_read);

        expect(
          _presenter.statusFor(isPaired: true, resolver: resolver),
          NodeConnectionStatus.connectedRemotely,
          reason: '$kind must not surface its mechanism in the headline',
        );
      }
    });

    test('an untried ladder reads as connecting, not offline', () {
      final resolver = KubusNodeTransportResolver(
        transports: [_FakeTransport(KubusNodeTransportKind.localDirect)],
      );

      expect(
        _presenter.statusFor(isPaired: true, resolver: resolver),
        NodeConnectionStatus.connecting,
      );
    });

    test('offline once every route has failed', () async {
      final resolver = KubusNodeTransportResolver(
        transports: [
          _FakeTransport(
            KubusNodeTransportKind.localDirect,
            failWith: const SocketException('down'),
          ),
        ],
      );
      await expectLater(resolver.request(_read), throwsA(isA<Object>()));

      expect(
        _presenter.statusFor(isPaired: true, resolver: resolver),
        NodeConnectionStatus.offline,
      );
    });

    test('only connected states permit processing', () {
      expect(NodeConnectionStatus.connectedNearby.canProcess, isTrue);
      expect(NodeConnectionStatus.connectedRemotely.canProcess, isTrue);
      expect(NodeConnectionStatus.connecting.canProcess, isFalse);
      expect(NodeConnectionStatus.offline.canProcess, isFalse);
      expect(NodeConnectionStatus.unpaired.canProcess, isFalse);
    });
  });

  group('diagnostics stay secondary', () {
    test('the headline enum carries no transport vocabulary at all', () {
      // Guards the product rule: TURN/STUN/ICE/NAT must never reach primary
      // UI. If someone adds `connectedViaRelay` here, this fails.
      final names =
          NodeConnectionStatus.values.map((v) => v.name.toLowerCase());
      for (final name in names) {
        for (final banned in ['turn', 'stun', 'ice', 'nat', 'webrtc', 'sctp']) {
          expect(name.contains(banned), isFalse, reason: '$name leaks $banned');
        }
      }
    });

    test('relay use is visible in diagnostics, not in the headline', () async {
      final resolver = KubusNodeTransportResolver(
        transports: [_FakeTransport(KubusNodeTransportKind.webRtcRelay)],
      );
      await resolver.request(_read);

      expect(
        _presenter.statusFor(isPaired: true, resolver: resolver),
        NodeConnectionStatus.connectedRemotely,
      );
      final diagnostics = _presenter.diagnosticsFor(resolver);
      expect(diagnostics.usingRelay, isTrue);
      expect(diagnostics.activeKind, KubusNodeTransportKind.webRtcRelay);
    });

    test('diagnostics report measured latency and per-route health', () async {
      final resolver = KubusNodeTransportResolver(
        transports: [
          _FakeTransport(KubusNodeTransportKind.localDirect),
          _FakeTransport(KubusNodeTransportKind.remoteHttps),
        ],
      );
      await resolver.request(_read);

      final diagnostics = _presenter.diagnosticsFor(resolver);
      expect(diagnostics.latencyMs, isNotNull);
      expect(
        diagnostics.routeHealth[KubusNodeTransportKind.localDirect],
        KubusTransportHealth.healthy,
      );
      expect(
        diagnostics.routeHealth[KubusNodeTransportKind.remoteHttps],
        KubusTransportHealth.unknown,
      );
    });

    test('diagnostics are empty-but-valid before anything is attempted', () {
      final resolver = KubusNodeTransportResolver(
        transports: [_FakeTransport(KubusNodeTransportKind.localDirect)],
      );

      final diagnostics = _presenter.diagnosticsFor(resolver);
      expect(diagnostics.activeKind, isNull);
      expect(diagnostics.usingRelay, isFalse);
      expect(diagnostics.latencyMs, isNull);
    });
  });
}
