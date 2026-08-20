import 'package:art_kubus/services/node/kubus_node_transport.dart';
import 'package:art_kubus/services/node/node_signaling.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 1, 1, 12);

SignalingEnvelope _envelope({
  SignalingMessageType type = SignalingMessageType.offer,
  String nodeId = 'node-1',
  String deviceId = 'device-1',
  String nonce = 'nonce-1',
  String? payload = 'v=0\r\no=- 0 0 IN IP4 0.0.0.0',
  Duration lifetime = const Duration(minutes: 1),
  DateTime? issuedAt,
}) {
  final issued = issuedAt ?? _now;
  return SignalingEnvelope(
    type: type,
    sessionId: 'session-1',
    nodeId: nodeId,
    deviceId: deviceId,
    nonce: nonce,
    issuedAt: issued,
    expiresAt: issued.add(lifetime),
    payload: payload,
  );
}

void _validate(
  SignalingEnvelope envelope, {
  DateTime? now,
  String nodeId = 'node-1',
  String deviceId = 'device-1',
  Set<String>? seen,
}) =>
    envelope.validate(
      now: now ?? _now,
      expectedNodeId: nodeId,
      expectedDeviceId: deviceId,
      seenNonces: seen ?? <String>{},
    );

void main() {
  group('signaling validation', () {
    test('a well-formed, current message validates', () {
      expect(() => _validate(_envelope()), returnsNormally);
    });

    test('a message for another Node is refused', () {
      // Transport success is not Node trust: a peer that reaches us must still
      // be the Node this device paired with.
      expect(
        () => _validate(_envelope(nodeId: 'someone-elses-node')),
        throwsA(isA<SignalingValidationException>()),
      );
    });

    test('a message for another device is refused', () {
      expect(
        () => _validate(_envelope(deviceId: 'another-device')),
        throwsA(isA<SignalingValidationException>()),
      );
    });

    test('an expired session is refused', () {
      expect(
        () => _validate(
          _envelope(lifetime: const Duration(seconds: 30)),
          now: _now.add(const Duration(minutes: 1)),
        ),
        throwsA(isA<SignalingValidationException>()),
      );
    });

    test('a peer cannot grant itself a longer window than the protocol allows',
        () {
      expect(
        () => _validate(_envelope(lifetime: const Duration(hours: 6))),
        throwsA(isA<SignalingValidationException>()),
      );
    });

    test('a replayed nonce is refused', () {
      expect(
        () => _validate(_envelope(nonce: 'used'), seen: {'used'}),
        throwsA(isA<SignalingValidationException>()),
      );
    });

    test('offer, answer and candidate all require a payload', () {
      for (final type in [
        SignalingMessageType.offer,
        SignalingMessageType.answer,
        SignalingMessageType.candidate,
      ]) {
        expect(
          () => _validate(_envelope(type: type, payload: '   ')),
          throwsA(isA<SignalingValidationException>()),
          reason: '$type',
        );
      }
    });

    test('control messages need no payload', () {
      for (final type in [
        SignalingMessageType.connectionAttempt,
        SignalingMessageType.close,
      ]) {
        expect(
          () => _validate(_envelope(type: type, payload: null)),
          returnsNormally,
          reason: '$type',
        );
      }
    });

    test('an empty session id is refused', () {
      final envelope = SignalingEnvelope(
        type: SignalingMessageType.offer,
        sessionId: '  ',
        nodeId: 'node-1',
        deviceId: 'device-1',
        nonce: 'n',
        issuedAt: _now,
        expiresAt: _now.add(const Duration(minutes: 1)),
        payload: 'sdp',
      );

      expect(
        () => _validate(envelope),
        throwsA(isA<SignalingValidationException>()),
      );
    });

    test('expiry is exclusive at the boundary', () {
      final envelope = _envelope(lifetime: const Duration(minutes: 1));
      expect(
          envelope.isExpired(_now.add(const Duration(seconds: 59))), isFalse);
      expect(envelope.isExpired(_now.add(const Duration(minutes: 1))), isTrue);
    });
  });

  group('log safety', () {
    test('SDP is never written to logs, only its length', () {
      const sdp = 'v=0\r\no=- 0 0 IN IP4 192.168.1.50\r\na=candidate:...';
      final logged = _envelope(payload: sdp).toLogSafeJson();

      final serialized = logged.toString();
      expect(serialized, isNot(contains('192.168.1.50')));
      expect(serialized, isNot(contains('candidate')));
      expect(logged['payloadLength'], sdp.length);
    });

    test('log form keeps the identifiers needed to correlate an attempt', () {
      final logged = _envelope().toLogSafeJson();
      expect(logged['sessionId'], 'session-1');
      expect(logged['nodeId'], 'node-1');
      expect(logged['type'], 'offer');
    });
  });

  group('node presence privacy', () {
    test('publishes only identity, capability and freshness', () {
      final json = NodePresence(
        nodeId: 'node-1',
        transports: {
          KubusNodeTransportKind.localDirect,
          KubusNodeTransportKind.webRtcDirect,
        },
        updatedAt: _now,
      ).toJson();

      expect(json.keys.toSet(), {
        'nodeId',
        'transports',
        'acceptsConnections',
        'updatedAt',
      });
    });

    test('never publishes a LAN address', () {
      final json = NodePresence(
        nodeId: 'node-1',
        transports: {KubusNodeTransportKind.localDirect},
        updatedAt: _now,
      ).toJson();

      // Private addresses belong in ICE exchange between two authenticated
      // peers, not in a record the control plane holds.
      expect(json.toString(), isNot(contains('192.168')));
      expect(json.containsKey('endpoint'), isFalse);
    });

    test('rejects any record carrying a forbidden field', () {
      for (final forbidden in NodePresence.forbiddenKeys) {
        expect(
          () => NodePresence.assertPublishable({
            'nodeId': 'node-1',
            forbidden: 'anything',
          }),
          throwsA(isA<SignalingValidationException>()),
          reason: forbidden,
        );
      }
    });

    test('forbidden field detection is case-insensitive', () {
      expect(
        () => NodePresence.assertPublishable({'PairingSecret': 'x'}),
        throwsA(isA<SignalingValidationException>()),
      );
    });

    test('a legitimate record passes the publishability check', () {
      final json = NodePresence(
        nodeId: 'node-1',
        transports: {KubusNodeTransportKind.webRtcDirect},
        updatedAt: _now,
      ).toJson();

      expect(() => NodePresence.assertPublishable(json), returnsNormally);
    });

    test('transport list is stable, so presence updates are comparable', () {
      final a = NodePresence(
        nodeId: 'n',
        transports: {
          KubusNodeTransportKind.webRtcRelay,
          KubusNodeTransportKind.localDirect,
        },
        updatedAt: _now,
      ).toJson();
      final b = NodePresence(
        nodeId: 'n',
        transports: {
          KubusNodeTransportKind.localDirect,
          KubusNodeTransportKind.webRtcRelay,
        },
        updatedAt: _now,
      ).toJson();

      expect(a['transports'], b['transports']);
    });
  });
}
