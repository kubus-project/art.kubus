import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/services/node/kubus_data_channel.dart';
import 'package:art_kubus/services/node/kubus_node_transport.dart';
import 'package:art_kubus/services/node/node_transport_policy.dart';
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

  @override
  Stream<Uint8List> get messages => _incoming.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<void> send(Uint8List data) async {
    if (!_open) throw const KubusDataChannelClosedException();
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

const _infoPath = '/local/v1/info';
const _reportPath = '/local/v1/spatial/report';
const _floodPath = '/local/v1/flood';

/// A Node-side responder whose reply shape is chosen by the requested path.
///
/// `/local/v1/flood` is the hostile case: an endless run of individually valid,
/// individually under-cap, non-final response chunks — the sequence the 64 KiB
/// per-frame limit does nothing about.
class _ScriptedNode {
  _ScriptedNode(this.channel) {
    channel.messages.listen(_onMessage);
  }

  final _LoopbackChannel channel;

  /// Request ids the client told us to abandon.
  final Set<int> cancelled = <int>{};

  /// Request ids by path, so a test can name the request it flooded.
  final Map<String, int> requestIds = <String, int>{};

  /// Response chunks actually put on the wire, across every response.
  int chunksSent = 0;

  String smallBody = '{"ok":true}';

  /// Body for [_reportPath], delivered in [streamChunkSize] pieces.
  Uint8List streamedBody = Uint8List(0);
  int streamChunkSize = 64 * 1024;

  /// How far the flood runs before giving up unprompted. Reaching this budget
  /// means the client never told it to stop.
  int floodChunkBudget = 512;
  int floodChunkSize = 8 * 1024;

  Future<void> _onMessage(Uint8List data) async {
    final KubusFrame frame;
    try {
      frame = KubusFrameCodec.decode(data);
    } on KubusFrameException {
      return;
    }
    if (frame.type == KubusFrameType.cancel) {
      cancelled.add(frame.requestId);
      return;
    }
    if (frame.type != KubusFrameType.requestHead) return;

    final path = frame.metadata?['path'];
    if (path is! String) return;
    requestIds[path] = frame.requestId;

    if (path == _infoPath) {
      await _sendWhole(
        frame.requestId,
        Uint8List.fromList(utf8.encode(smallBody)),
      );
    } else if (path == _reportPath) {
      await _sendChunked(frame.requestId, streamedBody);
    } else if (path == _floodPath) {
      await _flood(frame.requestId);
    }
    // Any other path is left unanswered, so a test can drive the timeout path.
  }

  Future<void> _sendWhole(int id, Uint8List payload) async {
    final crc = Crc32()..add(payload);
    await channel.send(
      KubusFrameCodec.encode(
        KubusFrame(
          type: KubusFrameType.responseHead,
          requestId: id,
          flags: KubusFrame.flagFinal,
          metadata: <String, dynamic>{
            'status': 200,
            'length': payload.length,
            'crc32': crc.value,
          },
          payload: payload.isEmpty ? null : payload,
        ),
      ),
    );
  }

  Future<void> _sendChunked(int id, Uint8List payload) async {
    await _openResponse(id);
    final crc = Crc32();
    for (var offset = 0; offset < payload.length; offset += streamChunkSize) {
      final end = (offset + streamChunkSize).clamp(0, payload.length);
      final chunk = Uint8List.sublistView(payload, offset, end);
      crc.add(chunk);
      chunksSent++;
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
                    'crc32': crc.value,
                  }
                : null,
            payload: chunk,
          ),
        ),
      );
    }
  }

  Future<void> _flood(int id) async {
    await _openResponse(id);
    final chunk = Uint8List(floodChunkSize);
    for (var i = 0; i < floodChunkBudget; i++) {
      if (cancelled.contains(id) || !channel.isOpen) return;
      chunksSent++;
      await channel.send(
        KubusFrameCodec.encode(
          KubusFrame(
            type: KubusFrameType.responseChunk,
            requestId: id,
            payload: chunk,
          ),
        ),
      );
      // Yield so the client can act on what has arrived, exactly as a real
      // channel would interleave.
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _openResponse(int id) => channel.send(
        KubusFrameCodec.encode(
          KubusFrame(
            type: KubusFrameType.responseHead,
            requestId: id,
            metadata: const <String, dynamic>{'status': 200},
          ),
        ),
      );
}

/// A frame built by hand, so a peer can claim a payload the codec would refuse
/// to encode.
Uint8List _rawFrame({
  required int requestId,
  required int payloadLength,
  int flags = 0,
}) {
  final bytes = Uint8List(KubusFrameCodec.headerLength + payloadLength);
  final view = ByteData.view(bytes.buffer);
  view.setUint8(0, KubusFrameCodec.magic);
  view.setUint8(1, KubusFrameCodec.protocolVersion);
  view.setUint8(2, KubusFrameType.responseChunk.wireValue);
  view.setUint8(3, flags);
  view.setUint32(4, requestId);
  view.setUint32(8, 0);
  view.setUint32(12, payloadLength);
  return bytes;
}

const _info = KubusNodeRequest(
  method: 'GET',
  path: _infoPath,
  timeout: Duration(seconds: 5),
);

void main() {
  group('aggregate response bounds', () {
    test('an endless run of valid chunks is cut off at the aggregate cap',
        () async {
      final channels = _pair();
      final node = _ScriptedNode(channels.node);
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
        // Small enough to breach quickly; the mechanism is identical at 4 MiB.
        maxResponseBytes: 64 * 1024,
      );
      addTearDown(transport.close);

      final flood = transport.request(
        const KubusNodeRequest(
          method: 'GET',
          path: _floodPath,
          // Far longer than the test needs: the cap must be what stops this,
          // not the request timeout.
          timeout: Duration(seconds: 20),
        ),
      );
      final concurrent = transport.request(_info);

      Object? failure;
      try {
        await flood;
      } on Object catch (error) {
        failure = error;
      }

      // Terminated by the aggregate bound, with the same typed error the
      // upload path raises for the same offence.
      expect(failure, isA<KubusStreamException>());
      expect('$failure', contains('exceeds maximum size'));

      // The flood is told to stop rather than being left to run until the
      // channel closes.
      final floodId = node.requestIds[_floodPath];
      expect(floodId, isNotNull);
      expect(node.cancelled, contains(floodId));
      expect(node.chunksSent, lessThan(node.floodChunkBudget));

      // An unrelated request in flight at the same moment is untouched.
      final response = await concurrent;
      expect(response.statusCode, 200);
      expect(response.body, '{"ok":true}');

      // And the channel is still usable afterwards: one response died, not the
      // transport.
      final again = await transport.request(_info);
      expect(again.statusCode, 200);
      expect(again.body, '{"ok":true}');
    });

    test('chunks arriving after a rejected response are ignored', () async {
      final channels = _pair();
      final node = _ScriptedNode(channels.node);
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
        maxResponseBytes: 32 * 1024,
      );
      addTearDown(transport.close);

      await expectLater(
        transport.request(
          const KubusNodeRequest(
            method: 'GET',
            path: _floodPath,
            timeout: Duration(seconds: 20),
          ),
        ),
        throwsA(isA<KubusStreamException>()),
      );

      final floodId = node.requestIds[_floodPath]!;
      // Late chunks for a request whose buffer was already dropped must not
      // reopen it, error, or wedge the channel.
      for (var i = 0; i < 8; i++) {
        await channels.node.send(
          KubusFrameCodec.encode(
            KubusFrame(
              type: KubusFrameType.responseChunk,
              requestId: floodId,
              payload: Uint8List(8 * 1024),
            ),
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final response = await transport.request(_info);
      expect(response.statusCode, 200);
    });

    test('a body of exactly the cap is accepted', () async {
      final channels = _pair();
      final node = _ScriptedNode(channels.node)
        // ASCII, so the decoded body length is directly comparable.
        ..streamedBody = Uint8List.fromList(
          List<int>.generate(64 * 1024, (i) => 0x41 + (i % 26)),
        )
        ..streamChunkSize = 8 * 1024;
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
        maxResponseBytes: 64 * 1024,
      );
      addTearDown(transport.close);

      final response = await transport.request(
        const KubusNodeRequest(
          method: 'GET',
          path: _reportPath,
          timeout: Duration(seconds: 10),
        ),
      );

      expect(response.statusCode, 200);
      expect(response.body.length, node.streamedBody.length);
    });

    test('the default ceiling is below the bulk-transfer threshold', () {
      final channels = _pair();
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      // Anything at or above the bulk threshold is routed as a bulk transfer,
      // and a bulk transfer belongs in a sink on disk rather than in a String.
      expect(
        transport.maxResponseBytes,
        WebRtcNodeTransport.defaultMaxResponseBytes,
      );
      expect(
        transport.maxResponseBytes,
        lessThan(TransportSelectionContext.defaultBulkTransferThresholdBytes),
      );
    });
  });

  group('per-frame bounds', () {
    test('the codec refuses to encode an oversized payload', () {
      expect(
        () => KubusFrameCodec.encode(
          KubusFrame(
            type: KubusFrameType.responseChunk,
            requestId: 1,
            payload: Uint8List(KubusFrameCodec.maxPayloadLength + 1),
          ),
        ),
        throwsA(isA<KubusFrameException>()),
      );
    });

    test('an oversized chunk from a peer never reaches the buffer', () async {
      final channels = _pair();
      final node = _ScriptedNode(channels.node);
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      const silentPath = '/local/v1/never-answered';
      final pending = transport.request(
        const KubusNodeRequest(
          method: 'GET',
          path: silentPath,
          timeout: Duration(milliseconds: 200),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // A hand-built frame declaring — and carrying — twice the per-frame cap.
      await channels.node.send(
        _rawFrame(
          requestId: node.requestIds[silentPath]!,
          payloadLength: KubusFrameCodec.maxPayloadLength * 2,
          flags: KubusFrame.flagFinal,
        ),
      );

      // Dropped at decode, so the request runs out its own clock rather than
      // completing with 128 KiB of unbounded peer data.
      await expectLater(pending, throwsA(isA<TimeoutException>()));

      final response = await transport.request(_info);
      expect(response.statusCode, 200);
    });
  });

  group('ordinary responses still work', () {
    test('a small JSON response round-trips', () async {
      final channels = _pair();
      _ScriptedNode(channels.node).smallBody = '{"status":"idle","jobs":0}';
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      final response = await transport.request(_info);

      expect(response.statusCode, 200);
      expect(response.body, '{"status":"idle","jobs":0}');
      expect(response.requestPath, _infoPath);
    });

    test('a large chunked response under the ceiling is reassembled intact',
        () async {
      final channels = _pair();
      final body = List.generate(40000, (i) => 'row$i').join(',');
      final node = _ScriptedNode(channels.node)
        ..streamedBody = Uint8List.fromList(utf8.encode(body))
        ..streamChunkSize = 32 * 1024;
      final transport = WebRtcNodeTransport(
        channel: channels.client,
        kind: KubusNodeTransportKind.webRtcDirect,
      );
      addTearDown(transport.close);

      final response = await transport.request(
        const KubusNodeRequest(
          method: 'GET',
          path: _reportPath,
          timeout: Duration(seconds: 20),
        ),
      );

      // Many frames, one body, in order — the CRC on the final frame proves the
      // ordering rather than merely the size.
      expect(node.chunksSent, greaterThan(4));
      expect(response.statusCode, 200);
      expect(response.body, body);
    });
  });
}
