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
///
/// Both directions are bounded by the same mechanism. An upload is framed by
/// [KubusFrameSplitter] and reassembled by the peer through
/// [KubusStreamReassembler]; a response is reassembled here by that same class,
/// the sink being memory instead of disk. The per-frame 64 KiB cap bounds one
/// frame and says nothing about a peer that sends a hundred thousand valid
/// ones, so [maxResponseBytes] is the aggregate bound that actually stops it.
class WebRtcNodeTransport implements KubusNodeTransport {
  WebRtcNodeTransport({
    required KubusDataChannel channel,
    required this.kind,
    String? credential,
    KubusFrameSplitter? splitter,
    int maxResponseBytes = defaultMaxResponseBytes,
  })  : assert(maxResponseBytes > 0),
        _channel = channel,
        _credential = credential,
        _splitter = splitter ?? const KubusFrameSplitter(),
        _maxResponseBytes = maxResponseBytes {
    _subscription = _channel.messages.listen(
      _onMessage,
      onError: _failAll,
      onDone: () => _failAll(
        const KubusDataChannelClosedException('channel closed by peer'),
      ),
    );
  }

  /// Ceiling on one reassembled response held in memory.
  ///
  /// A [KubusNodeResponse] carries its body as a `String`, so every response on
  /// this rung is reassembled in RAM. That is right for the JSON envelopes the
  /// canonical API returns and wrong for anything larger, which is why the
  /// ceiling is set here rather than raised: a payload that does not fit
  /// belongs in a sink on disk, the way a capture upload already travels.
  ///
  /// 4 MiB is the same in-memory ceiling the upload path applies to bytes it
  /// has accepted but not yet drained
  /// ([KubusStreamReassembler.maxBufferedBytes]), so there is one number for
  /// "how much peer data may sit in memory" rather than two. It is deliberately
  /// below `TransportSelectionContext.defaultBulkTransferThresholdBytes`:
  /// anything that size is a bulk transfer by the routing layer's own
  /// definition, and bulk transfers do not belong in a `String`.
  static const int defaultMaxResponseBytes = 4 * 1024 * 1024;

  final KubusDataChannel _channel;
  final String? _credential;
  final KubusFrameSplitter _splitter;
  final int _maxResponseBytes;

  @override
  final KubusNodeTransportKind kind;

  /// The aggregate response ceiling this transport enforces.
  int get maxResponseBytes => _maxResponseBytes;

  late final StreamSubscription<Uint8List> _subscription;
  final Map<int, _PendingRequest> _pending = <int, _PendingRequest>{};

  /// Inbound frames are handled one at a time, in arrival order.
  ///
  /// Reassembly hands each chunk to a sink and *awaits* it — the backpressure
  /// the upload path already relies on. A listener that returned before its
  /// chunk had landed would let the next frame overtake it, corrupting both the
  /// body order and the CRC that exists to prove that order.
  Future<void> _inbound = Future<void>.value();

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
    final pending = _PendingRequest(
      requestId: id,
      path: request.path,
      maxResponseBytes: _maxResponseBytes,
    );
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
              if (request.headers.isNotEmpty ||
                  (_credential ?? '').startsWith('kubus_local_'))
                'headers': <String, String>{
                  ...request.headers,
                  if ((_credential ?? '').startsWith('kubus_local_'))
                    'Authorization': 'Bearer $_credential',
                },
              if (contentType != null) 'contentType': contentType,
              if (request.idempotencyKey != null)
                'idempotencyKey': request.idempotencyKey!.value,
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
      // Removed *and* released: a request abandoned part-way through its
      // response would otherwise keep that partial body alive.
      _pending.remove(id)?.release();
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
    // A failure belonging to one response is routed to that request inside
    // `_handleFrame`. This guard is for anything that escaped it: an error left
    // sitting on the chain would stop every later frame from being handled at
    // all, wedging the channel silently instead of failing loudly.
    _inbound = _inbound.then((_) => _handleFrame(data)).catchError(_failAll);
  }

  Future<void> _handleFrame(Uint8List data) async {
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
    // A frame for an unknown or already-finished id is stale: its request
    // completed, timed out, or was cancelled. Silently ignored rather than
    // treated as an error, which would let a peer disrupt live requests.
    if (pending == null || pending.isCompleted) return;

    try {
      switch (frame.type) {
        case KubusFrameType.responseHead:
          pending.status = _readStatus(frame.metadata);
          await pending.accept(frame);
        case KubusFrameType.responseChunk:
          await pending.accept(frame);
        case KubusFrameType.error:
          pending.fail(
            KubusFrameException(
              (frame.metadata?['message'] ?? 'peer reported an error')
                  .toString(),
            ),
          );
        case KubusFrameType.cancel:
          pending.fail(const KubusFrameException('peer cancelled the request'));
        case KubusFrameType.requestHead:
        case KubusFrameType.requestChunk:
        case KubusFrameType.windowUpdate:
          // Not meaningful for a client-issued request; ignored so a confused
          // or hostile peer cannot desynchronise the table.
          break;
      }
    } on KubusStreamException catch (error) {
      // Reassembly rejected this response: it breached the aggregate ceiling,
      // contradicted its own declared length or checksum, or tried to append to
      // a committed stream. Exactly one request dies, its buffer is dropped
      // immediately, and the channel keeps carrying everything else.
      pending.release();
      // Same reasoning as the timeout path, and in the same order: the peer is
      // told to stop *before* the failure surfaces locally, so a chunk flood
      // stops at the ceiling instead of running on while the caller unwinds.
      // Awaited rather than fire-and-forget because the cancel would otherwise
      // be queued behind the waiting caller's own continuation, letting the
      // peer keep generating a response nobody will ever read.
      // `_sendCancel` swallows its own errors, so this cannot mask `error`.
      await _sendCancel(frame.requestId);
      pending.fail(error);
    }
  }

  static int? _readStatus(Map<String, dynamic>? metadata) {
    final status = metadata?['status'];
    return status is int ? status : null;
  }

  void _failAll(Object error) {
    // A dropped channel fails every in-flight request rather than leaving them
    // to time out one by one, so the resolver can demote this route at once.
    for (final pending in List<_PendingRequest>.from(_pending.values)) {
      pending.release();
      pending.fail(error);
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
///
/// Reassembly is delegated to [KubusStreamReassembler] rather than reimplemented
/// here, so a response is bounded, ordered and integrity-checked by the same
/// code an upload already is. The one difference between the directions is
/// where the chunks are handed: a file for an upload, memory for a response.
class _PendingRequest {
  _PendingRequest({
    required int requestId,
    required this.path,
    required int maxResponseBytes,
  }) {
    _reassembler = KubusStreamReassembler(
      requestId: requestId,
      onChunk: (chunk) async => _body.add(chunk),
      // The aggregate bound. Without it, a peer sending an endless run of
      // perfectly valid 64 KiB chunks exhausts the process long before the
      // request's own timeout fires.
      maxTotalBytes: maxResponseBytes,
      // Memory drains synchronously, so nothing stays accepted-but-undrained
      // for longer than a single frame; the total above is the bound that
      // actually bites.
      maxBufferedBytes: maxResponseBytes,
    );
  }

  final String path;
  final Completer<KubusNodeResponse> completer = Completer<KubusNodeResponse>();
  final BytesBuilder _body = BytesBuilder();
  late final KubusStreamReassembler _reassembler;

  int? status;

  bool get isCompleted => completer.isCompleted;

  /// Feeds one response frame, completing the request on the final one.
  ///
  /// Throws [KubusStreamException] when the peer breaches the aggregate
  /// ceiling or contradicts its own declared length or checksum.
  Future<void> accept(KubusFrame frame) async {
    if (!await _reassembler.accept(frame)) return;
    completeWith(
      KubusNodeResponse(
        statusCode: status ?? 200,
        body: _takeBodyAsString(),
        requestPath: path,
      ),
    );
  }

  /// Drops whatever has been reassembled so far.
  void release() => _body.clear();

  String _takeBodyAsString() {
    final bytes = _body.takeBytes();
    if (bytes.isEmpty) return '';
    return utf8.decode(bytes, allowMalformed: true);
  }

  void completeWith(KubusNodeResponse response) {
    if (!completer.isCompleted) completer.complete(response);
  }

  void fail(Object error) {
    if (!completer.isCompleted) completer.completeError(error);
  }
}
