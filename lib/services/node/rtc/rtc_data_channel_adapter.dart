import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../kubus_data_channel.dart';

/// Adapts a real `RTCDataChannel` to the small interface the transport needs.
///
/// The adapter exists so exactly one file in the app knows that flutter_webrtc
/// is the implementation. Everything above it works against
/// [KubusDataChannel], which is four members wide and can be exercised
/// exhaustively in memory — which is where nearly all of the protocol's real
/// risk lives. Leaking `RTCDataChannel` upward would make the framing layer
/// untestable without a peer connection, a platform channel, and a network.
class RtcDataChannelAdapter implements KubusDataChannel {
  RtcDataChannelAdapter(this._channel, {int? maxBufferedBytes})
      : _maxBufferedBytes = maxBufferedBytes ?? defaultMaxBufferedBytes {
    _channel.onMessage = _onMessage;
    _channel.onDataChannelState = _onStateChange;
    // The channel may already be open by the time we attach: flutter_webrtc
    // reports state through the same callback the peer connection used, so a
    // channel adopted after `onDataChannel` fires would otherwise never be
    // observed as open.
    _isOpen = _channel.state == RTCDataChannelState.RTCDataChannelOpen;
  }

  /// How many bytes may sit in the channel's send buffer before [send] waits.
  ///
  /// Without a ceiling, a fast producer (a capture streaming off disk) fills
  /// the native buffer as quickly as the file reads, which is unbounded memory
  /// growth in the native layer rather than in Dart — the same failure, just
  /// somewhere the Dart heap profiler will not show it.
  static const int defaultMaxBufferedBytes = 1 * 1024 * 1024;

  /// How long to wait for the buffer to drain before treating it as stalled.
  static const Duration bufferDrainTimeout = Duration(seconds: 30);

  final RTCDataChannel _channel;
  final int _maxBufferedBytes;
  final StreamController<Uint8List> _messages =
      StreamController<Uint8List>.broadcast();

  bool _isOpen = false;
  bool _closed = false;

  @override
  Stream<Uint8List> get messages => _messages.stream;

  @override
  bool get isOpen => _isOpen && !_closed;

  @override
  Future<void> send(Uint8List data) async {
    if (!isOpen) {
      throw const KubusDataChannelClosedException('channel is not open');
    }
    await _awaitBufferSpace();
    if (!isOpen) {
      throw const KubusDataChannelClosedException(
          'channel closed while sending');
    }
    await _channel.send(RTCDataChannelMessage.fromBinary(data));
  }

  /// Applies backpressure by waiting for the native send buffer to drain.
  ///
  /// Polling rather than using `onBufferedAmountLow`: the low-threshold
  /// callback is not implemented consistently across every platform this app
  /// ships on, and a missing callback would hang a transfer forever. A short
  /// poll is slower in the worst case and correct on all of them.
  Future<void> _awaitBufferSpace() async {
    final deadline = DateTime.now().add(bufferDrainTimeout);
    while (isOpen) {
      final buffered = _bufferedAmount();
      if (buffered == null || buffered < _maxBufferedBytes) return;
      if (DateTime.now().isAfter(deadline)) {
        throw const KubusDataChannelClosedException(
          'send buffer did not drain; peer is not reading',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// Returns null when the platform does not report a buffered amount, in
  /// which case backpressure is left to the native layer rather than guessed.
  int? _bufferedAmount() {
    try {
      return _channel.bufferedAmount;
    } on Object {
      return null;
    }
  }

  void _onMessage(RTCDataChannelMessage message) {
    // Text messages are not part of this protocol. A peer sending one is
    // speaking something else, and guessing at it is how a parser bug starts.
    if (!message.isBinary) return;
    if (_messages.isClosed) return;
    _messages.add(message.binary);
  }

  void _onStateChange(RTCDataChannelState state) {
    switch (state) {
      case RTCDataChannelState.RTCDataChannelOpen:
        _isOpen = true;
      case RTCDataChannelState.RTCDataChannelClosing:
      case RTCDataChannelState.RTCDataChannelClosed:
        _isOpen = false;
        _finish();
      case RTCDataChannelState.RTCDataChannelConnecting:
        _isOpen = false;
    }
  }

  void _finish() {
    if (_messages.isClosed) return;
    // Closing the stream is what tells the transport above to fail every
    // in-flight request at once, instead of letting each one time out.
    unawaited(_messages.close());
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _isOpen = false;
    _finish();
    try {
      await _channel.close();
    } on Object {
      // A channel already torn down by the peer throws on close. That is the
      // expected path after a disconnect, not a failure worth propagating.
      if (kDebugMode) {
        debugPrint('RtcDataChannelAdapter: close ignored a teardown error');
      }
    }
  }
}
