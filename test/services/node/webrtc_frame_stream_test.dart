import 'dart:typed_data';

import 'package:art_kubus/services/node/webrtc_frame.dart';
import 'package:art_kubus/services/node/webrtc_frame_stream.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(int length, {int seed = 0}) =>
    Uint8List.fromList(List<int>.generate(length, (i) => (i + seed) % 256));

/// Splits then reassembles, returning what the sink received.
Future<Uint8List> _roundTrip(
  List<List<int>> source, {
  int chunkSize = 1024,
}) async {
  final splitter = KubusFrameSplitter(chunkSize: chunkSize);
  final received = BytesBuilder();
  final reassembler = KubusStreamReassembler(
    requestId: 1,
    onChunk: (chunk) async => received.add(chunk),
  );

  await for (final frame in splitter.split(1, Stream.fromIterable(source))) {
    // Frames go over the wire, so exercise the codec too rather than passing
    // objects straight across.
    await reassembler
        .accept(KubusFrameCodec.decode(KubusFrameCodec.encode(frame)));
  }

  expect(reassembler.isFinished, isTrue);
  return received.takeBytes();
}

void main() {
  group('Crc32', () {
    test('matches the known IEEE check value', () {
      final crc = Crc32()..add('123456789'.codeUnits);
      expect(crc.value, 0xCBF43926);
    });

    test('is order sensitive, so a swapped chunk is caught', () {
      final forward = Crc32()
        ..add([1, 2, 3])
        ..add([4, 5, 6]);
      final swapped = Crc32()
        ..add([4, 5, 6])
        ..add([1, 2, 3]);
      expect(forward.value, isNot(swapped.value));
    });

    test('incremental equals one-shot', () {
      final data = _bytes(5000);
      final oneShot = Crc32()..add(data);
      final incremental = Crc32();
      for (var i = 0; i < data.length; i += 97) {
        incremental.add(
          data.sublist(i, (i + 97).clamp(0, data.length)),
        );
      }
      expect(incremental.value, oneShot.value);
    });
  });

  group('splitting', () {
    test('a payload smaller than one chunk becomes a single final frame',
        () async {
      final frames = await KubusFrameSplitter(chunkSize: 1024)
          .split(1, Stream.value(_bytes(100)))
          .toList();

      expect(frames, hasLength(1));
      expect(frames.single.isFinal, isTrue);
      expect(frames.single.payload!.length, 100);
    });

    test('an exact multiple still terminates with a final frame', () async {
      final frames = await KubusFrameSplitter(chunkSize: 100)
          .split(1, Stream.value(_bytes(300)))
          .toList();

      // Three full chunks, then an empty final frame that carries the totals.
      expect(frames, hasLength(4));
      expect(frames.take(3).every((f) => f.payload!.length == 100), isTrue);
      expect(frames.last.isFinal, isTrue);
      expect(frames.last.payload, isNull);
      expect(frames.last.metadata!['length'], 300);
    });

    test('no frame ever exceeds the chunk size, whatever the source emits',
        () async {
      // A source that emits one enormous list must still produce bounded
      // frames — otherwise a single read would blow the DataChannel limit.
      final frames = await KubusFrameSplitter(chunkSize: 256)
          .split(1, Stream.value(_bytes(10000)))
          .toList();

      for (final frame in frames) {
        expect((frame.payload?.length ?? 0), lessThanOrEqualTo(256));
      }
      expect(frames.last.metadata!['length'], 10000);
    });

    test('tiny source events are coalesced, not turned into a frame each',
        () async {
      final source = List.generate(1000, (i) => [i % 256]);
      final frames = await KubusFrameSplitter(chunkSize: 256)
          .split(1, Stream.fromIterable(source))
          .toList();

      expect(frames.length, lessThan(10));
      expect(frames.last.metadata!['length'], 1000);
    });

    test('an empty stream still produces one final frame', () async {
      final frames = await KubusFrameSplitter(chunkSize: 64)
          .split(1, const Stream<List<int>>.empty())
          .toList();

      expect(frames, hasLength(1));
      expect(frames.single.isFinal, isTrue);
      expect(frames.single.metadata!['length'], 0);
    });
  });

  group('round trip', () {
    test('bytes survive split, encode, decode and reassembly', () async {
      final data = _bytes(9999, seed: 7);
      final result = await _roundTrip([data], chunkSize: 256);
      expect(result, equals(data));
    });

    test('a multi-megabyte payload reassembles byte for byte', () async {
      final data = _bytes(3 * 1024 * 1024);
      final result = await _roundTrip([data], chunkSize: 64 * 1024);
      expect(result.length, data.length);
      expect(result, equals(data));
    });

    test('irregular source chunking does not affect the result', () async {
      final source = <List<int>>[
        _bytes(1),
        _bytes(5000, seed: 3),
        _bytes(0),
        _bytes(37, seed: 9),
      ];
      final expected = BytesBuilder()..add(source.expand((e) => e).toList());
      final result = await _roundTrip(source, chunkSize: 512);
      expect(result, equals(expected.takeBytes()));
    });
  });

  group('integrity', () {
    test('a dropped chunk is caught by the length check', () async {
      final splitter = KubusFrameSplitter(chunkSize: 128);
      final frames =
          await splitter.split(1, Stream.value(_bytes(1000))).toList();
      final reassembler = KubusStreamReassembler(
        requestId: 1,
        onChunk: (_) async {},
      );

      // Deliver everything except one middle chunk.
      for (final frame in frames) {
        if (identical(frame, frames[2])) continue;
        if (frame.isFinal) {
          await expectLater(
            reassembler.accept(frame),
            throwsA(isA<KubusStreamException>()),
          );
        } else {
          await reassembler.accept(frame);
        }
      }
    });

    test('a corrupted chunk is caught by the checksum', () async {
      final splitter = KubusFrameSplitter(chunkSize: 128);
      final frames =
          await splitter.split(1, Stream.value(_bytes(512))).toList();
      final reassembler = KubusStreamReassembler(
        requestId: 1,
        onChunk: (_) async {},
      );

      for (var i = 0; i < frames.length; i++) {
        var frame = frames[i];
        if (i == 1) {
          // Same length, different content: only a checksum finds this.
          final corrupted = Uint8List.fromList(frame.payload!);
          corrupted[0] = corrupted[0] ^ 0xFF;
          frame = KubusFrame(
            type: frame.type,
            requestId: frame.requestId,
            flags: frame.flags,
            metadata: frame.metadata,
            payload: corrupted,
          );
        }
        if (frame.isFinal) {
          await expectLater(
            reassembler.accept(frame),
            throwsA(isA<KubusStreamException>()),
          );
        } else {
          await reassembler.accept(frame);
        }
      }
    });
  });

  group('bounds and lifecycle', () {
    test('a frame for another request is rejected', () async {
      final reassembler = KubusStreamReassembler(
        requestId: 1,
        onChunk: (_) async {},
      );

      await expectLater(
        reassembler.accept(
          KubusFrame(
            type: KubusFrameType.requestChunk,
            requestId: 2,
            payload: _bytes(4),
          ),
        ),
        throwsA(isA<KubusStreamException>()),
      );
    });

    test('a frame after the final frame is rejected', () async {
      final reassembler = KubusStreamReassembler(
        requestId: 1,
        onChunk: (_) async {},
      );
      await reassembler.accept(
        const KubusFrame(
          type: KubusFrameType.requestChunk,
          requestId: 1,
          flags: KubusFrame.flagFinal,
        ),
      );

      await expectLater(
        reassembler.accept(
          KubusFrame(
            type: KubusFrameType.requestChunk,
            requestId: 1,
            payload: _bytes(4),
          ),
        ),
        throwsA(isA<KubusStreamException>()),
      );
    });

    test('exceeding the total size ceiling is refused', () async {
      final reassembler = KubusStreamReassembler(
        requestId: 1,
        onChunk: (_) async {},
        maxTotalBytes: 100,
      );

      await expectLater(
        reassembler.accept(
          KubusFrame(
            type: KubusFrameType.requestChunk,
            requestId: 1,
            payload: _bytes(101),
          ),
        ),
        throwsA(isA<KubusStreamException>()),
      );
    });

    test('a peer flooding past the flow-control window is cut off', () async {
      final reassembler = KubusStreamReassembler(
        requestId: 1,
        onChunk: (_) async {},
        maxBufferedBytes: 64,
      );

      await expectLater(
        reassembler.accept(
          KubusFrame(
            type: KubusFrameType.requestChunk,
            requestId: 1,
            payload: _bytes(65),
          ),
        ),
        throwsA(isA<KubusStreamException>()),
      );
    });

    test('backpressure: a slow sink slows acceptance rather than buffering',
        () async {
      var inFlight = 0;
      var maxInFlight = 0;
      final reassembler = KubusStreamReassembler(
        requestId: 1,
        onChunk: (_) async {
          inFlight += 1;
          maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
          await Future<void>.delayed(const Duration(milliseconds: 1));
          inFlight -= 1;
        },
      );

      final frames = await KubusFrameSplitter(chunkSize: 64)
          .split(1, Stream.value(_bytes(640)))
          .toList();
      for (final frame in frames) {
        await reassembler.accept(frame);
      }

      // Acceptance awaits the sink, so chunks are never processed
      // concurrently and nothing queues up behind a slow disk.
      expect(maxInFlight, 1);
      expect(reassembler.receivedBytes, 640);
    });

    test('a cancel frame stops the stream and blocks further frames', () async {
      final reassembler = KubusStreamReassembler(
        requestId: 1,
        onChunk: (_) async {},
      );

      final done = await reassembler.accept(
        const KubusFrame(type: KubusFrameType.cancel, requestId: 1),
      );

      expect(done, isFalse);
      expect(reassembler.isCancelled, isTrue);
      await expectLater(
        reassembler.accept(
          KubusFrame(
            type: KubusFrameType.requestChunk,
            requestId: 1,
            payload: _bytes(4),
          ),
        ),
        throwsA(isA<KubusStreamException>()),
      );
    });
  });
}
