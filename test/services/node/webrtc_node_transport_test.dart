import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:art_kubus/services/node/kubus_data_channel.dart';
import 'package:art_kubus/services/node/kubus_node_transport.dart';
import 'package:art_kubus/services/node/webrtc_frame.dart';
import 'package:art_kubus/services/node/webrtc_frame_stream.dart';
import 'package:art_kubus/services/node/webrtc_node_transport.dart';
import 'package:flutter_test/flutter_test.dart';

/// One end of an in-memory duplex pair.
class _LoopbackChannel implements KubusDataChannel {
  _LoopbackChannel(this._name);

  final String _name;
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  late _LoopbackChannel peer;

  bool _open = true;
  final List<Uint8List> sent = <Uint8List>[];

  /// Drops outgoing messages instead of delivering them, to model a stall.
  bool blackhole = false;

  @override
  Stream<Uint8List> get messages => _incoming.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<void> send(Uint8List data) async {
    if (!_open) throw const KubusDataChannelClosedException();
    sent.add(data);
    if (blackhole) return;
    // Asynchronous delivery, like a real channel.
    scheduleMicrotask(() {
      if (peer._open && !peer._incoming.isClosed) peer._incoming.add(data);
    });
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _open = false;
    await _incoming.close();
  }

  void dropRemote() {
    _open = false;
    if (!_incoming.isClosed) _incoming.close();
  }

  @override
  String toString() => 'LoopbackChannel($_name)';
}

({_LoopbackChannel client, _LoopbackChannel node}) _pair() {
  final client = _LoopbackChannel('client');
  final node = _LoopbackChannel('node');
  client.peer = node;
  node.peer = client;
  return (client: client, node: node);
}

/// A minimal Node-side responder, so the protocol is exercised from both ends.
class _FakeNode {
  _FakeNode(this.channel, {this.status = 200, this.body = '{"ok":true}'}) {
    channel.messages.listen(_onMessage);
  }

  final _LoopbackChannel channel;
  int status;
  String body;

  /// Reassembles uploaded bodies, keyed by request id.
  final Map<int, KubusStreamReassembler> _uploads =
      <int, KubusStreamReassembler>{};
  final Map<int, BytesBuilder> received = <int, BytesBuilder>{};
  final List<Map<String, dynamic>> heads = <Map<String, dynamic>>[];

  /// Reply in chunks rather than one frame.
  int? respondInChunksOf;

  /// Emit an error frame instead of a response.
  String? failWithMessage;

  /// Never reply at all.
  bool silent = false;

  /// Corrupt the declared response length, to prove the client verifies it.
  bool lieAboutLength = false;

  Future<void> _onMessage(Uint8List data) async {
    final frame = KubusFrameCodec.decode(data);
    switch (frame.type) {
      case KubusFrameType.requestHead:
        heads.add(frame.metadata ?? <String, dynamic>{});
        final sink = BytesBuilder();
        received[frame.requestId] = sink;
        _uploads[frame.requestId] = KubusStreamReassembler(
          requestId: frame.requestId,
          onChunk: (chunk) async => sink.add(chunk),
        );
        if (frame.isFinal) await _respond(frame.requestId);
      case KubusFrameType.requestChunk:
        final reassembler = _uploads[frame.requestId];
        if (reassembler == null) return;
        final done = await reassembler.accept(frame);
        if (done) await _respond(frame.requestId);
      case KubusFrameType.cancel:
        _uploads.remove(frame.requestId);
      default:
        break;
    }
  }

  Future<void> _respond(int id) async {
    if (silent) return;

    final failure = failWithMessage;
    if (failure != null) {
      await channel.send(
        KubusFrameCodec.encode(
          KubusFrame(
            type: KubusFrameType.error,
            requestId: id,
            metadata: <String, dynamic>{'message': failure},
          ),
        ),
      );
      return;
    }

    final payload = Uint8List.fromList(utf8.encode(body));
    final chunkSize = respondInChunksOf;

    if (chunkSize == null) {
      final crc = Crc32()..add(payload);
      await channel.send(
        KubusFrameCodec.encode(
          KubusFrame(
            type: KubusFrameType.responseHead,
            requestId: id,
            flags: KubusFrame.flagFinal,
            metadata: <String, dynamic>{
              'status': status,
              'length': lieAboutLength ? payload.length + 10 : payload.length,
              'crc32': crc.value,
            },
            payload: payload.isEmpty ? null : payload,
          ),
        ),
      );
      return;
    }

    await channel.send(
      KubusFrameCodec.encode(
        KubusFrame(
          type: KubusFrameType.responseHead,
          requestId: id,
          metadata: <String, dynamic>{'status': status},
        ),
      ),
    );
    final crc = Crc32();
    for (var offset = 0; offset < payload.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, payload.length);
      final chunk = Uint8List.sublistView(payload, offset, end);
      crc.add(chunk);
      final isLast = end >= payload.length;
      await channel.send(
        KubusFrameCodec.encode(
          KubusFrame(
            type: KubusFrameType.responseChunk,
            requestId: id,
            flags: isLast ? KubusFrame.flagFinal : 0,
            metadata: isLast
                ? <String, dynamic>{
                    'length': payload.length,
                    'crc32': crc.value
                  }
                : null,
            payload: chunk,
          ),
        ),
      );
    }
  }
}

const _read = KubusNodeRequest(method: 'GET', path: '/local/v1/info');

void main() {
  group('request/response over a data channel', () {
    test('a bodyless request round-trips', () async {
      final channels = _pair();
      final node = _FakeNode(channels.node);
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      final response = await transport.request(_read);

      expect(response.statusCode, 200);
      expect(response.body, '{"ok":true}');
      expect(node.heads.single['method'], 'GET');
      expect(node.heads.single['path'], '/local/v1/info');
    });

    test('the canonical path and method cross the wire unchanged', () async {
      // There is one Node API; WebRTC frames it rather than replacing it.
      final channels = _pair();
      final node = _FakeNode(channels.node);
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      await transport.request(
        const KubusNodeRequest(
          method: 'POST',
          path: '/local/v1/captures/drafts/d1/commit',
          query: {'x': '1'},
          idempotencyKey: 'commit-d1',
          jsonBody: {'a': 1},
        ),
      );

      final head = node.heads.single;
      expect(head['path'], '/local/v1/captures/drafts/d1/commit');
      expect(head['method'], 'POST');
      expect((head['query'] as Map)['x'], '1');
      expect(head['idempotencyKey'], 'commit-d1');
      expect((head['json'] as Map)['a'], 1);
      expect(head.toString(), isNot(contains('/webrtc/')));
    });

    test('a chunked response is reassembled', () async {
      final channels = _pair();
      final body = List.generate(500, (i) => 'line$i').join(',');
      _FakeNode(channels.node, body: body).respondInChunksOf = 64;
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      final response = await transport.request(_read);

      expect(response.body, body);
    });

    test('a non-2xx status is delivered, not thrown', () async {
      final channels = _pair();
      _FakeNode(
        channels.node,
        status: 503,
        body: '{"error":"worker_unavailable"}',
      );
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      final response = await transport.request(_read);

      // The route worked; the Node is unhappy. Classifying that is the
      // service's job, identically on every rung.
      expect(response.statusCode, 503);
      expect(response.body, contains('worker_unavailable'));
    });

    test('concurrent requests are multiplexed by request id', () async {
      final channels = _pair();
      _FakeNode(channels.node);
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      final responses = await Future.wait([
        transport.request(_read),
        transport.request(_read),
        transport.request(_read),
      ]);

      expect(responses, hasLength(3));
      expect(responses.every((r) => r.statusCode == 200), isTrue);
    });
  });

  group('streaming upload', () {
    test('a file streams through and is reassembled by the peer', () async {
      final dir = Directory.systemTemp.createTempSync('kubus_webrtc');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}${Platform.pathSeparator}capture.bin');
      final bytes = Uint8List.fromList(
        List<int>.generate(200 * 1024, (i) => i % 256),
      );
      file.writeAsBytesSync(bytes);

      final channels = _pair();
      final node = _FakeNode(channels.node);
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      final response = await transport.streamUpload(
        const KubusNodeRequest(
          method: 'PUT',
          path: '/local/v1/captures/drafts/d1/files',
        ),
        file: file,
        contentType: 'application/octet-stream',
      );

      expect(response.statusCode, 200);
      expect(node.received.values.single.takeBytes(), equals(bytes));
    });

    test('a large upload never sends an oversized frame', () async {
      final dir = Directory.systemTemp.createTempSync('kubus_webrtc_big');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}${Platform.pathSeparator}c.bin');
      file.writeAsBytesSync(Uint8List(512 * 1024));

      final channels = _pair();
      _FakeNode(channels.node);
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      await transport.streamUpload(
        const KubusNodeRequest(
          method: 'PUT',
          path: '/local/v1/captures/drafts/d1/files',
        ),
        file: file,
        contentType: 'application/octet-stream',
      );

      for (final message in channels.client.sent) {
        expect(
          message.length,
          lessThanOrEqualTo(
            KubusFrameCodec.headerLength +
                KubusFrameCodec.maxPayloadLength +
                KubusFrameCodec.maxMetadataLength,
          ),
        );
      }
      expect(channels.client.sent.length, greaterThan(4));
    });
  });

  group('failure handling', () {
    test('a peer error frame surfaces as an error, not a response', () async {
      final channels = _pair();
      _FakeNode(channels.node).failWithMessage = 'worker exploded';
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      await expectLater(
        transport.request(_read),
        throwsA(isA<KubusFrameException>()),
      );
    });

    test('a silent peer times out and the request is cancelled', () async {
      final channels = _pair();
      final node = _FakeNode(channels.node)..silent = true;
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      await expectLater(
        transport.request(
          const KubusNodeRequest(
            method: 'GET',
            path: '/local/v1/info',
            timeout: Duration(milliseconds: 60),
          ),
        ),
        throwsA(isA<TimeoutException>()),
      );

      // Give the cancel frame a turn to arrive: an abandoned request must not
      // leave the Node working.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(node.received.containsKey(1), isTrue);
      final cancels = channels.client.sent
          .map(KubusFrameCodec.decode)
          .where((f) => f.type == KubusFrameType.cancel);
      expect(cancels, isNotEmpty);
    });

    test('a dropped channel fails every in-flight request at once', () async {
      final channels = _pair();
      _FakeNode(channels.node).silent = true;
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );

      final first = transport.request(_read);
      final second = transport.request(_read);
      await Future<void>.delayed(Duration.zero);

      channels.client.dropRemote();

      // Rather than each waiting out its own timeout, so the resolver can
      // demote this route immediately.
      await expectLater(first, throwsA(isA<Object>()));
      await expectLater(second, throwsA(isA<Object>()));
    });

    test('sending on a closed channel fails fast', () async {
      final channels = _pair();
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      await channels.client.close();

      await expectLater(
        transport.request(_read),
        throwsA(isA<KubusDataChannelClosedException>()),
      );
    });

    test('a response whose declared length is wrong is rejected', () async {
      final channels = _pair();
      _FakeNode(channels.node).lieAboutLength = true;
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      await expectLater(
        transport.request(_read),
        throwsA(isA<KubusStreamException>()),
      );
    });

    test('a malformed frame is ignored rather than crashing the transport',
        () async {
      final channels = _pair();
      final node = _FakeNode(channels.node);
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      // Garbage from the peer must not poison a healthy channel.
      await channels.node.send(Uint8List.fromList([1, 2, 3, 4, 5]));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final response = await transport.request(_read);
      expect(response.statusCode, 200);
      expect(node.heads, isNotEmpty);
    });

    test('a frame for an unknown request id is ignored', () async {
      final channels = _pair();
      _FakeNode(channels.node);
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      await channels.node.send(
        KubusFrameCodec.encode(
          const KubusFrame(
            type: KubusFrameType.responseHead,
            requestId: 999999,
            flags: KubusFrame.flagFinal,
            metadata: {'status': 500},
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final response = await transport.request(_read);
      expect(response.statusCode, 200);
    });
  });

  group('lifecycle', () {
    test('availability tracks the channel', () async {
      final channels = _pair();
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );

      expect(transport.isAvailable, isTrue);
      await channels.client.close();
      expect(transport.isAvailable, isFalse);
    });

    test('close fails pending requests and closes the channel', () async {
      final channels = _pair();
      _FakeNode(channels.node).silent = true;
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );

      final pending = transport.request(_read);
      await Future<void>.delayed(Duration.zero);
      transport.close();

      await expectLater(pending, throwsA(isA<Object>()));
      expect(channels.client.isOpen, isFalse);
    });

    test('reports the rung it was constructed for', () {
      final channels = _pair();
      for (final kind in [
        KubusNodeTransportKind.webRtcDirect,
        KubusNodeTransportKind.webRtcRelay,
      ]) {
        final transport =
            WebRtcNodeTransport(channel: channels.client, kind: kind);
        expect(transport.kind, kind);
      }
    });
  });
}
