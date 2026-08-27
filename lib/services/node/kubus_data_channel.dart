import 'dart:typed_data';

/// A duplex, reliable, ordered message channel.
///
/// This is the entire surface [WebRtcNodeTransport] needs from WebRTC. Keeping
/// it this small is deliberate: the transport can then be exercised
/// exhaustively against an in-memory pair of channels, with no peer
/// connection, no ICE, no signaling and no platform plugin — which is where
/// almost all of the protocol's real risk lives.
///
/// The concrete implementation wraps an `RTCDataChannel`; nothing above this
/// interface knows that.
abstract class KubusDataChannel {
  /// Messages from the peer, one event per DataChannel message.
  Stream<Uint8List> get messages;

  /// True while the channel can carry traffic.
  bool get isOpen;

  /// Sends one message.
  ///
  /// Implementations should apply the underlying channel's own buffering
  /// policy; the framing layer above already bounds message size.
  Future<void> send(Uint8List data);

  Future<void> close();
}

/// The channel closed, or was never open.
class KubusDataChannelClosedException implements Exception {
  const KubusDataChannelClosedException([this.reason]);

  final String? reason;

  @override
  String toString() =>
      'KubusDataChannelClosedException${reason == null ? '' : ': $reason'}';
}
