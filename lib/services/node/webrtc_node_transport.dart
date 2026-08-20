import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'kubus_data_channel.dart';
import 'kubus_node_transport.dart';
import 'webrtc_frame.dart';
import 'webrtc_frame_stream.dart';

/// Carries canonical Node operations over a WebRTC DataChannel.
///
/// Frames the *same* `/local/v1/...` requests HTTP carries — there is no
/// parallel WebRTC API. Callers above cannot tell which rung they are on.
///
/// One reliable ordered channel multiplexes every in-flight operation by
/// `requestId`. See `docs/node/webrtc-protocol.md` for why a single channel
/// rather than several.
class WebRtcNodeTransport implements KubusNodeTransport {
  WebRtcNodeTransport({
    required KubusDataChannel channel,
    required this.kind,
    KubusFrameSplitter? splitter,
  })  : _channel = channel,
        _splitter = splitter ?? const KubusFrameSplitter() {
    _subscription = _channel.messages.listen(
      _onMessage,
      onError: _failAll,
      onDone: () => _failAll(
        const KubusDataChannelClosedException('channel closed by peer'),
      ),
    );
  }

  final KubusDataChannel _channel;
  final KubusFrameSplitter _splitter;

  @override
  final KubusNodeTransportKind kind;

  late final StreamSubscription<Uint8List> _subscription;
  final Map<int, _PendingRequest> _pending = <int, _PendingRequest>{};

  /// Odd/even allocation is not needed: both peers key their own tables by the
  /// id they issued, and a response always echoes the request's id.
  int _nextRequestId = 1;

  @override
  bool get isAvailable => _channel.isOpen;

  @override
  Future<KubusNodeResponse> request(KubusNodeRequest request) =>
      _perform(request, body: null, contentType: null);

  @override
  Future<KubusNodeResponse> streamUpload(
    KubusNodeRequest request, {
    required File file,
    required String contentType,
  }) =>
      _perform(request, body: file.openRead(), contentType: contentType);

  Future<KubusNodeResponse> _perform(
    KubusNodeRequest request, {
    Stream<List<int>>? body,
    String? contentType,
  }) async {
    if (!_channel.isOpen) {
      throw const KubusDataChannelClosedException();
    }
    final id = _allocateRequestId();
    final pending = _PendingRequest(request.path);
    _pending[id] = pending;

    try {
      await _channel.send(
        KubusFrameCodec.encode(
          KubusFrame(
            type: KubusFrameType.requestHead,
            requestId: id,
            // Bodyless requests finish at the head, so a peer never waits for
            // a chunk that is not coming.
            flags: body == null ? KubusFrame.flagFinal : 0,
            metadata: <String, dynamic>{
              'method': request.method,
              'path': request.path,
              if (request.query.isNotEmpty) 'query': request.query,
              if (request.headers.isNotEmpty) 'headers': request.headers,
              if (contentType != null) 'contentType': contentType,
              if (request.idempotencyKey != null)
                'idempotencyKey': request.idempotencyKey,
              if (request.jsonBody != null) 'json': request.jsonBody,
            },
          ),
        ),
      );

      if (body != null) {
        await for (final frame in _splitter.split(id, body)) {
          if (!_channel.isOpen) {
            throw const KubusDataChannelClosedException('closed mid-upload');
          }
          await _channel.send(KubusFrameCodec.encode(frame));
        }
      }

      return await pending.completer.future.timeout(
        request.timeout,
        onTimeout: () {
          // Tell the peer to stop working before giving up locally, so an
          // abandoned request does not keep a Node busy.
          unawaited(_sendCancel(id));
          throw TimeoutException('Node request timed out', request.timeout);
        },
      );
    } finally {
      _pending.remove(id);
    }
  }

  int _allocateRequestId() {
    // Wraps within u32, which the frame header carries. Collisions would
    // require 4 billion concurrent in-flight requests.
    if (_nextRequestId >= 0xFFFFFFFF) _nextRequestId = 1;
    return _nextRequestId++;
  }

  Future<void> _sendCancel(int id) async {
    if (!_channel.isOpen) return;
    try {
      await _channel.send(
        KubusFrameCodec.encode(
          KubusFrame(type: KubusFrameType.cancel, requestId: id),
        ),
      );
    } catch (_) {
      // Cancellation is best effort: the local request already failed, and a
      // failure to notify must not mask that.
    }
  }

  void _onMessage(Uint8List data) {
    final KubusFrame frame;
    try {
      frame = KubusFrameCodec.decode(data);
    } on KubusFrameException {
      // A malformed frame carries no usable request id, so it cannot be
      // attributed. Dropping it is the only safe action; the request's own
      // timeout remains the backstop.
      return;
    }

    final pending = _pending[frame.requestId];
    // A frame for an unknown id is stale (its request already completed,
    // timed out, or was cancelled). Silently ignored rather than treated as
    // an error, which would let a peer disrupt live requests.
    if (pending == null) return;

    switch (frame.type) {
      case KubusFrameType.responseHead:
        pending.status = _readStatus(frame.metadata);
        pending.appendPayload(frame.payload);
        if (frame.isFinal) _complete(pending, frame);
      case KubusFrameType.responseChunk:
        pending.appendPayload(frame.payload);
        if (frame.isFinal) _complete(pending, frame);
      case KubusFrameType.error:
        pending.completeError(
          KubusFrameException(
            (frame.metadata?['message'] ?? 'peer reported an error').toString(),
          ),
        );
      case KubusFrameType.cancel:
        pending.completeError(
          const KubusFrameException('peer cancelled the request'),
        );
      case KubusFrameType.requestHead:
      case KubusFrameType.requestChunk:
      case KubusFrameType.windowUpdate:
        // Not meaningful for a client-issued request; ignored so a confused
        // or hostile peer cannot desynchronise the table.
        break;
    }
  }

  void _complete(_PendingRequest pending, KubusFrame finalFrame) {
    try {
      pending.verify(finalFrame.metadata);
    } on KubusStreamException catch (error) {
      pending.completeError(error);
      return;
    }
    pending.completeWith(
      KubusNodeResponse(
        statusCode: pending.status ?? 200,
        body: pending.bodyAsString(),
        requestPath: pending.path,
      ),
    );
  }

  static int? _readStatus(Map<String, dynamic>? metadata) {
    final status = metadata?['status'];
    return status is int ? status : null;
  }

  void _failAll(Object error) {
    // A dropped channel fails every in-flight request rather than leaving them
    // to time out one by one, so the resolver can demote this route at once.
    for (final pending in List<_PendingRequest>.from(_pending.values)) {
      pending.completeError(error);
    }
    _pending.clear();
  }

  @override
  void close() {
    unawaited(_subscription.cancel());
    _failAll(const KubusDataChannelClosedException('transport closed'));
    unawaited(_channel.close());
  }
}

/// One in-flight request awaiting its response.
class _PendingRequest {
  _PendingRequest(this.path);

  final String path;
  final Completer<KubusNodeResponse> completer = Completer<KubusNodeResponse>();
  final BytesBuilder _body = BytesBuilder();
  final Crc32 _crc = Crc32();

  int? status;
  int _received = 0;

  void appendPayload(Uint8List? payload) {
    if (payload == null || payload.isEmpty) return;
    _body.add(payload);
    _crc.add(payload);
    _received += payload.length;
  }

  /// Applies the integrity metadata a well-behaved peer sends on its final
  /// frame. Absent metadata is tolerated so a minimal responder stays valid.
  void verify(Map<String, dynamic>? metadata) {
    if (metadata == null) return;
    final declaredLength = metadata['length'];
    if (declaredLength is int && declaredLength != _received) {
      throw KubusStreamException(
        'response length mismatch: expected $declaredLength, '
        'received $_received',
      );
    }
    final declaredCrc = metadata['crc32'];
    if (declaredCrc is int && declaredCrc != _crc.value) {
      throw const KubusStreamException('response checksum mismatch');
    }
  }

  String bodyAsString() {
    final bytes = _body.takeBytes();
    if (bytes.isEmpty) return '';
    return utf8.decode(bytes, allowMalformed: true);
  }

  void completeWith(KubusNodeResponse response) {
    if (!completer.isCompleted) completer.complete(response);
  }

  void completeError(Object error) {
    if (!completer.isCompleted) completer.completeError(error);
  }
}
