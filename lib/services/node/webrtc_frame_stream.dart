import 'dart:async';
import 'dart:typed_data';

import 'webrtc_frame.dart';

/// CRC-32 (IEEE), computed incrementally.
///
/// DTLS already guarantees the bytes on the wire are intact, so this is not
/// about transmission corruption. It catches *reassembly* mistakes — a
/// dropped, duplicated, or misordered chunk — which are our own bugs and
/// exactly the class of fault that would otherwise surface much later as an
/// unreadable capture.
class Crc32 {
  Crc32();

  static final Uint32List _table = _buildTable();
  int _crc = 0xFFFFFFFF;

  static Uint32List _buildTable() {
    final table = Uint32List(256);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
      }
      table[i] = c;
    }
    return table;
  }

  void add(List<int> bytes) {
    var crc = _crc;
    for (final byte in bytes) {
      crc = _table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }
    _crc = crc;
  }

  int get value => (_crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// Splits a byte stream into bounded frames.
///
/// Never materialises the whole source: a 100 MB capture becomes thousands of
/// 64 KiB frames while memory stays flat, which is the entire reason the
/// streaming path exists.
class KubusFrameSplitter {
  const KubusFrameSplitter({
    this.chunkSize = KubusFrameCodec.maxPayloadLength,
  }) : assert(chunkSize > 0);

  final int chunkSize;

  /// Frames [source] for [requestId].
  ///
  /// The final frame carries [KubusFrame.flagFinal] plus the total length and
  /// CRC, so the receiver can prove it reassembled exactly what was sent
  /// rather than merely stopping when the stream went quiet.
  Stream<KubusFrame> split(
    int requestId,
    Stream<List<int>> source, {
    KubusFrameType type = KubusFrameType.requestChunk,
  }) async* {
    final crc = Crc32();
    var total = 0;
    // Carries at most one chunk's worth, so a source that emits tiny lists
    // does not produce a frame per byte, and one that emits huge lists does
    // not produce an oversized frame.
    final pending = BytesBuilder(copy: false);

    await for (final bytes in source) {
      pending.add(bytes);
      while (pending.length >= chunkSize) {
        final taken = pending.takeBytes();
        var offset = 0;
        while (taken.length - offset >= chunkSize) {
          final chunk = Uint8List.sublistView(
            taken,
            offset,
            offset + chunkSize,
          );
          crc.add(chunk);
          total += chunk.length;
          yield KubusFrame(type: type, requestId: requestId, payload: chunk);
          offset += chunkSize;
        }
        if (offset < taken.length) {
          pending.add(Uint8List.sublistView(taken, offset));
        }
      }
    }

    final remainder = pending.takeBytes();
    crc.add(remainder);
    total += remainder.length;
    yield KubusFrame(
      type: type,
      requestId: requestId,
      flags: KubusFrame.flagFinal,
      metadata: <String, dynamic>{'length': total, 'crc32': crc.value},
      payload: remainder.isEmpty ? null : remainder,
    );
  }
}

/// A reassembled stream ended in a way the receiver rejects.
class KubusStreamException implements Exception {
  const KubusStreamException(this.message);

  final String message;

  @override
  String toString() => 'KubusStreamException: $message';
}

/// Reassembles frames back into bytes, with bounded memory.
///
/// Deliberately push-based and sink-oriented: the receiver hands each chunk
/// onward (to disk, typically) as it arrives rather than accumulating a
/// capture in RAM. [maxBufferedBytes] exists so a peer that floods chunks
/// faster than the sink drains them is cut off instead of exhausting memory —
/// the chunk-flooding case in the threat model.
class KubusStreamReassembler {
  KubusStreamReassembler({
    required this.requestId,
    required Future<void> Function(Uint8List chunk) onChunk,
    this.maxTotalBytes = 8 * 1024 * 1024 * 1024,
    this.maxBufferedBytes = 4 * 1024 * 1024,
  }) : _onChunk = onChunk;

  final int requestId;
  final Future<void> Function(Uint8List chunk) _onChunk;

  /// Hard ceiling on a single reassembled stream, so a peer cannot fill the
  /// disk by never sending a final frame.
  final int maxTotalBytes;

  /// Ceiling on bytes accepted but not yet drained by the sink.
  final int maxBufferedBytes;

  final Crc32 _crc = Crc32();
  int _received = 0;
  int _buffered = 0;
  bool _finished = false;
  bool _cancelled = false;

  int get receivedBytes => _received;
  bool get isFinished => _finished;
  bool get isCancelled => _cancelled;

  /// Feeds one frame.
  ///
  /// Returns true when the stream is complete.
  Future<bool> accept(KubusFrame frame) async {
    if (_cancelled) {
      throw const KubusStreamException('stream was cancelled');
    }
    if (_finished) {
      // A frame after the final one is either a bug or an attempt to append
      // to a committed stream. Neither may be silently accepted.
      throw const KubusStreamException('frame after final frame');
    }
    if (frame.requestId != requestId) {
      throw const KubusStreamException('frame belongs to another request');
    }

    if (frame.type == KubusFrameType.cancel) {
      _cancelled = true;
      return false;
    }

    final payload = frame.payload;
    if (payload != null && payload.isNotEmpty) {
      if (_received + payload.length > maxTotalBytes) {
        throw const KubusStreamException('stream exceeds maximum size');
      }
      if (_buffered + payload.length > maxBufferedBytes) {
        throw const KubusStreamException('peer exceeded flow-control window');
      }
      _buffered += payload.length;
      _crc.add(payload);
      _received += payload.length;
      // Awaiting the sink is the backpressure: a slow disk slows acceptance
      // rather than growing an unbounded queue.
      await _onChunk(payload);
      _buffered -= payload.length;
    }

    if (!frame.isFinal) return false;

    _verify(frame.metadata);
    _finished = true;
    return true;
  }

  void _verify(Map<String, dynamic>? metadata) {
    if (metadata == null) return;
    final declaredLength = metadata['length'];
    if (declaredLength is int && declaredLength != _received) {
      throw KubusStreamException(
        'length mismatch: expected $declaredLength, received $_received',
      );
    }
    final declaredCrc = metadata['crc32'];
    if (declaredCrc is int && declaredCrc != _crc.value) {
      throw const KubusStreamException('checksum mismatch');
    }
  }
}
