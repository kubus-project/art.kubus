import 'dart:convert';
import 'dart:typed_data';

/// Wire framing for Node operations carried over a WebRTC DataChannel.
///
/// A DataChannel gives us ordered, reliable messages with a practical size
/// limit far below a spatial capture, so the same logical `/local/v1/...`
/// operation has to be cut into frames and reassembled. This defines that
/// format — and nothing else. It knows no HTTP, no ICE, and no Node
/// semantics, which is what lets it be tested exhaustively without a peer
/// connection or a socket.
///
/// Layout, big-endian:
///
/// ```
///   0       1       2       3       4              8
///   +-------+-------+-------+-------+--------------+
///   | magic | ver   | type  | flags | requestId    |
///   +-------+-------+-------+-------+--------------+
///   | metadataLength (u32) | payloadLength (u32)   |
///   +----------------------+-----------------------+
///   | metadata (UTF-8 JSON, metadataLength bytes)  |
///   +----------------------------------------------+
///   | payload (payloadLength bytes)                |
///   +----------------------------------------------+
/// ```
///
/// Metadata is JSON because it is small, self-describing and versionable;
/// payload stays raw bytes because base64-ing a capture would inflate it by a
/// third for no benefit.
class KubusFrameCodec {
  KubusFrameCodec._();

  /// Identifies our frames on a channel, so a foreign or corrupt message is
  /// rejected immediately rather than parsed into nonsense.
  static const int magic = 0x6B; // 'k'

  static const int protocolVersion = 1;

  static const int headerLength = 16;

  /// Maximum bytes of payload in one frame.
  ///
  /// DataChannel implementations vary in what they accept, and large messages
  /// are the classic way to stall a peer or blow up memory. 64 KiB is well
  /// inside every implementation's comfortable range and bounds the cost of a
  /// single malicious frame.
  static const int maxPayloadLength = 64 * 1024;

  /// Maximum bytes of metadata in one frame.
  static const int maxMetadataLength = 16 * 1024;

  static Uint8List encode(KubusFrame frame) {
    final metadataBytes = frame.metadata == null
        ? Uint8List(0)
        : Uint8List.fromList(utf8.encode(jsonEncode(frame.metadata)));
    final payload = frame.payload ?? Uint8List(0);

    if (metadataBytes.length > maxMetadataLength) {
      throw KubusFrameException('metadata exceeds $maxMetadataLength bytes');
    }
    if (payload.length > maxPayloadLength) {
      throw KubusFrameException('payload exceeds $maxPayloadLength bytes');
    }

    final buffer =
        Uint8List(headerLength + metadataBytes.length + payload.length);
    final view = ByteData.view(buffer.buffer);
    view.setUint8(0, magic);
    view.setUint8(1, protocolVersion);
    view.setUint8(2, frame.type.wireValue);
    view.setUint8(3, frame.flags);
    view.setUint32(4, frame.requestId);
    view.setUint32(8, metadataBytes.length);
    view.setUint32(12, payload.length);
    buffer.setRange(
        headerLength, headerLength + metadataBytes.length, metadataBytes);
    buffer.setRange(
        headerLength + metadataBytes.length, buffer.length, payload);
    return buffer;
  }

  static KubusFrame decode(Uint8List bytes) {
    if (bytes.length < headerLength) {
      throw KubusFrameException('frame shorter than header');
    }
    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    if (view.getUint8(0) != magic) {
      throw KubusFrameException('not a kubus frame');
    }
    final version = view.getUint8(1);
    if (version != protocolVersion) {
      // Explicitly typed so a peer can report a version mismatch as something
      // the operator can act on (update one side) rather than as corruption.
      throw KubusFrameVersionException(version);
    }
    final type = KubusFrameType.fromWire(view.getUint8(2));
    final flags = view.getUint8(3);
    final requestId = view.getUint32(4);
    final metadataLength = view.getUint32(8);
    final payloadLength = view.getUint32(12);

    if (metadataLength > maxMetadataLength ||
        payloadLength > maxPayloadLength) {
      throw KubusFrameException('declared length exceeds limit');
    }
    // A length header that disagrees with the bytes actually present is the
    // cheapest possible DoS: trust the buffer, never the claim.
    if (bytes.length != headerLength + metadataLength + payloadLength) {
      throw KubusFrameException('declared length does not match frame size');
    }

    final metadata = metadataLength == 0
        ? null
        : _decodeMetadata(
            bytes.sublist(headerLength, headerLength + metadataLength),
          );
    final payload = payloadLength == 0
        ? null
        : Uint8List.sublistView(bytes, headerLength + metadataLength);

    return KubusFrame(
      type: type,
      requestId: requestId,
      flags: flags,
      metadata: metadata,
      payload: payload,
    );
  }

  static Map<String, dynamic> _decodeMetadata(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw KubusFrameException('metadata is not an object');
      }
      return decoded;
    } on FormatException {
      throw KubusFrameException('metadata is not valid JSON');
    }
  }
}

/// What a frame is for.
enum KubusFrameType {
  /// Opens a request: method, path, query, headers in metadata.
  requestHead(1),

  /// A chunk of request body.
  requestChunk(2),

  /// Opens a response: status in metadata.
  responseHead(3),

  /// A chunk of response body.
  responseChunk(4),

  /// Caller abandoned the request; receiver should stop work.
  cancel(5),

  /// Receiver is ready for more chunks (application-level backpressure).
  windowUpdate(6),

  /// Transport-level failure for one request.
  error(7);

  const KubusFrameType(this.wireValue);

  final int wireValue;

  static KubusFrameType fromWire(int value) {
    for (final type in KubusFrameType.values) {
      if (type.wireValue == value) return type;
    }
    throw KubusFrameException('unknown frame type $value');
  }
}

/// One framed message.
class KubusFrame {
  const KubusFrame({
    required this.type,
    required this.requestId,
    this.flags = 0,
    this.metadata,
    this.payload,
  });

  /// Marks the last frame of a body, so a receiver knows a stream ended
  /// rather than stalled.
  static const int flagFinal = 0x01;

  final KubusFrameType type;

  /// Correlates chunks and responses with their request, so one channel can
  /// carry several operations without them becoming ambiguous.
  final int requestId;

  final int flags;
  final Map<String, dynamic>? metadata;
  final Uint8List? payload;

  bool get isFinal => (flags & flagFinal) != 0;

  KubusFrame copyWith({int? flags}) => KubusFrame(
        type: type,
        requestId: requestId,
        flags: flags ?? this.flags,
        metadata: metadata,
        payload: payload,
      );
}

/// A frame could not be encoded or decoded.
class KubusFrameException implements Exception {
  const KubusFrameException(this.message);

  final String message;

  @override
  String toString() => 'KubusFrameException: $message';
}

/// The peer speaks a different framing version.
class KubusFrameVersionException extends KubusFrameException {
  const KubusFrameVersionException(this.peerVersion)
      : super('unsupported frame version');

  final int peerVersion;

  @override
  String toString() => 'KubusFrameVersionException(peer: $peerVersion, ours: '
      '${KubusFrameCodec.protocolVersion})';
}
