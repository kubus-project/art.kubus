import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/services/node/webrtc_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('round trip', () {
    test('a request head survives encode/decode intact', () {
      const frame = KubusFrame(
        type: KubusFrameType.requestHead,
        requestId: 42,
        metadata: {
          'method': 'POST',
          'path': '/local/v1/jobs',
          'query': {'a': 'b'},
        },
      );

      final decoded = KubusFrameCodec.decode(KubusFrameCodec.encode(frame));

      expect(decoded.type, KubusFrameType.requestHead);
      expect(decoded.requestId, 42);
      expect(decoded.metadata!['method'], 'POST');
      expect(decoded.metadata!['path'], '/local/v1/jobs');
      expect((decoded.metadata!['query'] as Map)['a'], 'b');
      expect(decoded.payload, isNull);
    });

    test('binary payload is preserved byte for byte, not re-encoded', () {
      // The whole point of raw payload framing: a capture must not be
      // base64-inflated on the way through.
      final payload = Uint8List.fromList(
        List<int>.generate(4096, (i) => (i * 7) % 256),
      );
      final frame = KubusFrame(
        type: KubusFrameType.requestChunk,
        requestId: 7,
        payload: payload,
      );

      final encoded = KubusFrameCodec.encode(frame);
      final decoded = KubusFrameCodec.decode(encoded);

      expect(decoded.payload, equals(payload));
      expect(
        encoded.length,
        KubusFrameCodec.headerLength + payload.length,
        reason: 'no expansion beyond the fixed header',
      );
    });

    test('metadata and payload can travel in the same frame', () {
      final frame = KubusFrame(
        type: KubusFrameType.responseHead,
        requestId: 3,
        metadata: const {'status': 200},
        payload: Uint8List.fromList(utf8.encode('{"ok":true}')),
      );

      final decoded = KubusFrameCodec.decode(KubusFrameCodec.encode(frame));

      expect(decoded.metadata!['status'], 200);
      expect(utf8.decode(decoded.payload!), '{"ok":true}');
    });

    test('every frame type round-trips', () {
      for (final type in KubusFrameType.values) {
        final decoded = KubusFrameCodec.decode(
          KubusFrameCodec.encode(KubusFrame(type: type, requestId: 1)),
        );
        expect(decoded.type, type, reason: '$type');
      }
    });

    test('the final flag marks the end of a stream', () {
      const frame = KubusFrame(
        type: KubusFrameType.requestChunk,
        requestId: 9,
        flags: KubusFrame.flagFinal,
      );

      final decoded = KubusFrameCodec.decode(KubusFrameCodec.encode(frame));

      expect(decoded.isFinal, isTrue);
    });

    test('a large request id survives the full u32 range', () {
      const frame = KubusFrame(
        type: KubusFrameType.requestHead,
        requestId: 4294967295,
      );

      final decoded = KubusFrameCodec.decode(KubusFrameCodec.encode(frame));

      expect(decoded.requestId, 4294967295);
    });
  });

  group('rejects malformed input', () {
    test('a truncated frame is rejected, not read past its end', () {
      final encoded = KubusFrameCodec.encode(
        KubusFrame(
          type: KubusFrameType.requestChunk,
          requestId: 1,
          payload: Uint8List.fromList([1, 2, 3, 4]),
        ),
      );

      expect(
        () => KubusFrameCodec.decode(encoded.sublist(0, encoded.length - 2)),
        throwsA(isA<KubusFrameException>()),
      );
    });

    test('a frame shorter than the header is rejected', () {
      expect(
        () => KubusFrameCodec.decode(Uint8List(4)),
        throwsA(isA<KubusFrameException>()),
      );
    });

    test('a foreign message is rejected by magic byte', () {
      final foreign = Uint8List(KubusFrameCodec.headerLength);
      foreign[0] = 0x00;

      expect(
        () => KubusFrameCodec.decode(foreign),
        throwsA(isA<KubusFrameException>()),
      );
    });

    test('a mismatched version is typed, so it can be reported as such', () {
      final encoded = KubusFrameCodec.encode(
        const KubusFrame(type: KubusFrameType.requestHead, requestId: 1),
      );
      encoded[1] = 99;

      expect(
        () => KubusFrameCodec.decode(encoded),
        throwsA(isA<KubusFrameVersionException>()),
      );
    });

    test('an unknown frame type is rejected', () {
      final encoded = KubusFrameCodec.encode(
        const KubusFrame(type: KubusFrameType.requestHead, requestId: 1),
      );
      encoded[2] = 200;

      expect(
        () => KubusFrameCodec.decode(encoded),
        throwsA(isA<KubusFrameException>()),
      );
    });

    test(
      'a lying length header cannot make the decoder over-read — the cheapest '
      'possible DoS',
      () {
        final encoded = KubusFrameCodec.encode(
          KubusFrame(
            type: KubusFrameType.requestChunk,
            requestId: 1,
            payload: Uint8List.fromList([1, 2, 3, 4]),
          ),
        );
        // Claim a far larger payload than the frame actually carries.
        ByteData.view(encoded.buffer).setUint32(12, 100000);

        expect(
          () => KubusFrameCodec.decode(encoded),
          throwsA(isA<KubusFrameException>()),
        );
      },
    );

    test('metadata that is not valid JSON is rejected', () {
      final bad = Uint8List(KubusFrameCodec.headerLength + 3);
      final view = ByteData.view(bad.buffer);
      view.setUint8(0, KubusFrameCodec.magic);
      view.setUint8(1, KubusFrameCodec.protocolVersion);
      view.setUint8(2, KubusFrameType.requestHead.wireValue);
      view.setUint32(4, 1);
      view.setUint32(8, 3);
      view.setUint32(12, 0);
      bad.setRange(
          KubusFrameCodec.headerLength, bad.length, utf8.encode('{{{'));

      expect(
        () => KubusFrameCodec.decode(bad),
        throwsA(isA<KubusFrameException>()),
      );
    });

    test('metadata that is not an object is rejected', () {
      final payload = utf8.encode('[1,2,3]');
      final bad = Uint8List(KubusFrameCodec.headerLength + payload.length);
      final view = ByteData.view(bad.buffer);
      view.setUint8(0, KubusFrameCodec.magic);
      view.setUint8(1, KubusFrameCodec.protocolVersion);
      view.setUint8(2, KubusFrameType.requestHead.wireValue);
      view.setUint32(4, 1);
      view.setUint32(8, payload.length);
      view.setUint32(12, 0);
      bad.setRange(KubusFrameCodec.headerLength, bad.length, payload);

      expect(
        () => KubusFrameCodec.decode(bad),
        throwsA(isA<KubusFrameException>()),
      );
    });
  });

  group('bounds', () {
    test('an oversized payload is refused at encode time', () {
      expect(
        () => KubusFrameCodec.encode(
          KubusFrame(
            type: KubusFrameType.requestChunk,
            requestId: 1,
            payload: Uint8List(KubusFrameCodec.maxPayloadLength + 1),
          ),
        ),
        throwsA(isA<KubusFrameException>()),
      );
    });

    test('a payload exactly at the limit is accepted', () {
      final frame = KubusFrame(
        type: KubusFrameType.requestChunk,
        requestId: 1,
        payload: Uint8List(KubusFrameCodec.maxPayloadLength),
      );

      final decoded = KubusFrameCodec.decode(KubusFrameCodec.encode(frame));

      expect(decoded.payload!.length, KubusFrameCodec.maxPayloadLength);
    });

    test('oversized metadata is refused at encode time', () {
      expect(
        () => KubusFrameCodec.encode(
          KubusFrame(
            type: KubusFrameType.requestHead,
            requestId: 1,
            metadata: {'v': 'x' * (KubusFrameCodec.maxMetadataLength + 1)},
          ),
        ),
        throwsA(isA<KubusFrameException>()),
      );
    });

    test('the chunk limit keeps a large capture bounded per frame', () {
      // A 100 MB capture must become many bounded frames, never one giant
      // message that a peer has to hold whole.
      const captureBytes = 100 * 1024 * 1024;
      final frames = (captureBytes / KubusFrameCodec.maxPayloadLength).ceil();

      expect(frames, greaterThan(1000));
      expect(KubusFrameCodec.maxPayloadLength, lessThanOrEqualTo(64 * 1024));
    });
  });
}
