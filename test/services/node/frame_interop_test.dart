import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:art_kubus/services/node/webrtc_frame.dart';
import 'package:art_kubus/services/node/webrtc_frame_stream.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cross-language conformance for the DataChannel wire format.
///
/// The client is Dart and the Node is TypeScript, so "both sides implement the
/// spec" is two independent implementations of a byte layout that must agree
/// exactly. Nothing in either codebase would notice them diverging — a
/// mismatched field width or endianness produces a frame that decodes to
/// plausible nonsense, and the first symptom would be a corrupted capture.
///
/// These vectors are produced by the Node's encoder
/// (`kubus-node/src/webrtc/frameCodec.ts`) and checked into BOTH repositories
/// unchanged. Each side asserts it can decode the other's bytes and re-encode
/// them identically, so a change to either implementation that breaks the
/// other fails in CI rather than in the field.
///
/// Regenerating them is deliberate: it means the wire format changed, which is
/// a protocol version bump, not a test fix.
void main() {
  final fixture = File(
    'test/services/node/fixtures/kubus_frame_vectors.json',
  );
  final vectors =
      jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;

  Uint8List fromHex(String hex) {
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  String toHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  group('frame interoperability with the Node encoder', () {
    final frames =
        (vectors['frames'] as List<dynamic>).cast<Map<String, dynamic>>();

    test('every vector decodes and re-encodes to the same bytes', () {
      expect(frames, isNotEmpty);
      for (final vector in frames) {
        final name = vector['name'] as String;
        final expected = fromHex(vector['encoded'] as String);

        final decoded = KubusFrameCodec.decode(expected);
        final reencoded = KubusFrameCodec.encode(decoded);

        expect(
          toHex(reencoded),
          equals(toHex(expected)),
          reason: 'round-trip differs for "$name"',
        );
      }
    });

    test('the header fields land where the Node put them', () {
      // Decoding the whole vector could pass while, say, requestId and the
      // metadata length were swapped in both directions. Assert the parsed
      // fields against what the vector is named for.
      final head = frames.firstWhere(
        (vector) => vector['name'] == 'request head with inline json body',
      );
      final frame = KubusFrameCodec.decode(fromHex(head['encoded'] as String));

      expect(frame.type, KubusFrameType.requestHead);
      expect(frame.requestId, 2);
      expect(frame.isFinal, isTrue);
      expect(frame.metadata!['method'], 'POST');
      expect(frame.metadata!['path'], '/local/v1/jobs');
      expect(frame.metadata!['idempotencyKey'], 'job.create.c1');
      expect(
        (frame.metadata!['json'] as Map<String, dynamic>)['type'],
        'spatial.reconstruct',
      );
      expect(frame.payload, isNull);
    });

    test('a chunk payload survives with byte order intact', () {
      final chunk = frames.firstWhere(
        (vector) => vector['name'] == 'request chunk, not final',
      );
      final frame = KubusFrameCodec.decode(fromHex(chunk['encoded'] as String));

      expect(frame.type, KubusFrameType.requestChunk);
      expect(frame.isFinal, isFalse);
      // Deliberately includes 0x00 and 0xFF at both ends: a sign-extension or
      // truncation bug shows up here and nowhere else.
      expect(
          frame.payload, equals(Uint8List.fromList([0, 1, 2, 253, 254, 255])));
    });

    test('the final chunk carries the length and checksum the Node computed',
        () {
      final finalChunk = frames.firstWhere(
        (vector) => vector['name'] == 'final request chunk with length and crc',
      );
      final frame =
          KubusFrameCodec.decode(fromHex(finalChunk['encoded'] as String));

      expect(frame.isFinal, isTrue);
      expect(frame.metadata!['length'], 6);

      // Recompute it here rather than trusting the number: this is the check
      // that the two CRC implementations agree, which is what makes the
      // integrity metadata worth sending at all.
      final crc = Crc32()..add(const [0, 1, 2, 253, 254, 255]);
      expect(frame.metadata!['crc32'], crc.value);
    });

    test('a response head decodes with the status the Node set', () {
      final response = frames.firstWhere(
        (vector) => vector['name'] == 'response head, final, json payload',
      );
      final frame =
          KubusFrameCodec.decode(fromHex(response['encoded'] as String));

      expect(frame.type, KubusFrameType.responseHead);
      expect(frame.requestId, 2);
      expect(frame.metadata!['status'], 201);
      final body =
          jsonDecode(utf8.decode(frame.payload!)) as Map<String, dynamic>;
      expect(body['success'], isTrue);
      expect((body['data'] as Map<String, dynamic>)['id'], 'job-1');
    });

    test('a full-size payload is accepted at exactly the declared maximum', () {
      // The boundary is where an off-by-one between the two implementations
      // would hide: one side rejecting what the other considers legal is a
      // transfer that stalls only on large files.
      final maxFrame = frames.firstWhere(
        (vector) => vector['name'] == 'max size payload',
      );
      final frame =
          KubusFrameCodec.decode(fromHex(maxFrame['encoded'] as String));

      expect(frame.payload, hasLength(KubusFrameCodec.maxPayloadLength));
      expect(frame.payload!.every((byte) => byte == 0xAB), isTrue);
    });

    test('control frames carry no payload and decode cleanly', () {
      final error = KubusFrameCodec.decode(
        fromHex(
          frames.firstWhere(
              (vector) => vector['name'] == 'error frame')['encoded'] as String,
        ),
      );
      expect(error.type, KubusFrameType.error);
      expect(error.metadata!['message'], 'internal_error');

      final cancel = KubusFrameCodec.decode(
        fromHex(
          frames.firstWhere(
                  (vector) => vector['name'] == 'cancel frame')['encoded']
              as String,
        ),
      );
      expect(cancel.type, KubusFrameType.cancel);
      expect(cancel.requestId, 4);
      expect(cancel.payload, isNull);
    });
  });

  group('CRC-32 conformance', () {
    test('matches the Node implementation on every vector', () {
      final cases =
          (vectors['crc32'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(cases, isNotEmpty);
      for (final entry in cases) {
        final input = fromHex(entry['inputHex'] as String);
        final crc = Crc32()..add(input);
        expect(
          crc.value,
          entry['crc32'],
          reason: 'CRC differs for input ${entry['inputHex']}',
        );
      }
    });

    test('is incremental in the same way on both sides', () {
      // The splitter feeds the CRC one chunk at a time while the receiver feeds
      // it whatever arrives, so a difference between "all at once" and "in
      // pieces" would only surface on multi-frame bodies.
      final data = List<int>.generate(5000, (i) => (i * 31) % 256);
      final wholeCrc = Crc32()..add(data);
      final pieceCrc = Crc32();
      for (var offset = 0; offset < data.length; offset += 97) {
        pieceCrc.add(
          data.sublist(offset, (offset + 97).clamp(0, data.length)),
        );
      }
      expect(pieceCrc.value, wholeCrc.value);
    });
  });
}
