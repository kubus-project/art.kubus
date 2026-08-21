import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../kubus_data_channel.dart';
import '../turn_configuration.dart';
import 'rtc_data_channel_adapter.dart';

/// The sub-protocol label a kubus data channel is opened with.
///
/// The Node refuses a channel announcing anything else, so a peer speaking a
/// different protocol is turned away before its bytes reach the frame decoder.
const String kubusChannelProtocol = 'kubus/1';

/// How the connection attempt ended, in terms the UI can act on.
enum KubusRtcFailure {
  /// ICE never produced a working path. Usually means no relay was available.
  noRouteFound,

  /// The peer connection failed after having worked.
  connectionLost,

  /// The far side never opened a data channel within the deadline.
  channelNeverOpened,

  /// The attempt was abandoned before it completed.
  cancelled,
}

class KubusRtcException implements Exception {
  const KubusRtcException(this.failure, [this.detail]);

  final KubusRtcFailure failure;
  final String? detail;

  @override
  String toString() =>
      'KubusRtcException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// Signalling callbacks the caller wires to the control plane.
///
/// Deliberately plain functions rather than a client interface: this class
/// negotiates a connection and nothing else, so it can be driven by the real
/// signalling client, by a test harness, or by a loopback pair without any of
/// them needing to look like each other.
typedef SdpSink = Future<void> Function(String sdp, String type);
typedef CandidateSink = Future<void> Function(RTCIceCandidate candidate);

/// One WebRTC connection to the paired Node.
///
/// The app is always the offerer. The Node answers, which is what lets a Node
/// sit behind a NAT with no inbound reachability at all — the property the
/// whole ladder exists to obtain.
class KubusRtcPeer {
  KubusRtcPeer({
    required IceConfiguration iceConfiguration,
    required SdpSink onLocalDescription,
    required CandidateSink onLocalCandidate,
    this.connectTimeout = const Duration(seconds: 30),
  })  : _iceConfiguration = iceConfiguration,
        _onLocalDescription = onLocalDescription,
        _onLocalCandidate = onLocalCandidate;

  final IceConfiguration _iceConfiguration;
  final SdpSink _onLocalDescription;
  final CandidateSink _onLocalCandidate;
  final Duration connectTimeout;

  RTCPeerConnection? _connection;
  RTCDataChannel? _channel;
  RtcDataChannelAdapter? _adapter;
  Completer<KubusDataChannel>? _ready;
  bool _closed = false;

  /// Candidates that arrived before the remote description was applied.
  ///
  /// Trickle ICE means a candidate can legitimately overtake the answer. The
  /// spec requires the remote description first, so buffering here is not an
  /// optimisation — dropping them would silently lose the very paths that make
  /// a direct connection possible.
  final List<RTCIceCandidate> _pendingRemoteCandidates = <RTCIceCandidate>[];
  bool _remoteDescriptionApplied = false;

  /// Whether the established connection is carried by a relay.
  ///
  /// Diagnostics only, and not a trust statement: relayed traffic is still
  /// DTLS-encrypted end to end and the relay holds no key. It is surfaced so a
  /// user can be told why a transfer is slower than usual.
  bool get isRelayed => _isRelayed;
  bool _isRelayed = false;

  /// Opens the connection and resolves once the channel is usable.
  ///
  /// The returned channel is not yet trusted: the caller must still verify the
  /// Node's identity over it before sending a credential. Establishing a
  /// channel proves a peer answered, never which peer.
  Future<KubusDataChannel> connect() async {
    if (_ready != null) return _ready!.future;
    final ready = Completer<KubusDataChannel>();
    _ready = ready;

    try {
      final connection = await createPeerConnection(<String, dynamic>{
        // Expired credentials are dropped here rather than offered: handing
        // WebRTC a credential the relay will reject only wastes negotiation
        // time and hides the real reason a connection failed.
        'iceServers': _iceConfiguration.toIceServers(DateTime.now()),
        // Balanced bundling and a single transport: this connection carries one
        // data channel and no media, so there is nothing to bundle apart.
        'sdpSemantics': 'unified-plan',
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
        'iceCandidatePoolSize': 0,
      }, <String, dynamic>{});
      _connection = connection;

      connection.onIceCandidate = _handleLocalCandidate;
      connection.onConnectionState = _handleConnectionState;
      connection.onIceConnectionState = _handleIceConnectionState;

      // Ordered and reliable is not negotiable: the framing layer reassembles
      // a body by arrival order and verifies it with a CRC, so an unordered or
      // lossy channel would surface as a corrupted capture rather than as a
      // connection error.
      final init = RTCDataChannelInit()
        ..ordered = true
        ..protocol = kubusChannelProtocol;
      final channel = await connection.createDataChannel('kubus', init);
      _channel = channel;

      late final RtcDataChannelAdapter adapter;
      adapter = RtcDataChannelAdapter(
        channel,
        onStateChange: (RTCDataChannelState state) {
          if (state == RTCDataChannelState.RTCDataChannelOpen &&
              !ready.isCompleted) {
            ready.complete(adapter);
          }
          if (state == RTCDataChannelState.RTCDataChannelClosed &&
              !ready.isCompleted) {
            ready.completeError(
              const KubusRtcException(KubusRtcFailure.channelNeverOpened),
            );
          }
        },
      );
      _adapter = adapter;

      final offer = await connection.createOffer(<String, dynamic>{});
      await connection.setLocalDescription(offer);
      // The SDP is handed to the control plane and never logged: it carries
      // host addresses and the DTLS fingerprint.
      await _onLocalDescription(offer.sdp ?? '', offer.type ?? 'offer');

      return await ready.future.timeout(
        connectTimeout,
        onTimeout: () {
          unawaited(close());
          throw const KubusRtcException(
            KubusRtcFailure.noRouteFound,
            'no usable path was found before the deadline',
          );
        },
      );
    } on KubusRtcException {
      rethrow;
    } on Object catch (error) {
      unawaited(close());
      throw KubusRtcException(KubusRtcFailure.noRouteFound, error.toString());
    }
  }

  /// Applies the Node's answer, then drains any candidates that arrived first.
  Future<void> acceptRemoteDescription(String sdp, String type) async {
    final connection = _connection;
    if (connection == null || _closed) return;
    await connection.setRemoteDescription(RTCSessionDescription(sdp, type));
    _remoteDescriptionApplied = true;
    for (final candidate in _pendingRemoteCandidates) {
      await _addCandidate(connection, candidate);
    }
    _pendingRemoteCandidates.clear();
  }

  /// Adds a candidate from the Node, buffering it if the answer has not landed.
  Future<void> addRemoteCandidate(RTCIceCandidate candidate) async {
    final connection = _connection;
    if (connection == null || _closed) return;
    if (!_remoteDescriptionApplied) {
      // Bounded: a peer that floods candidates must not be able to grow this
      // without limit while we wait for an answer that may never come.
      if (_pendingRemoteCandidates.length < maxBufferedRemoteCandidates) {
        _pendingRemoteCandidates.add(candidate);
      }
      return;
    }
    await _addCandidate(connection, candidate);
  }

  /// Ceiling on candidates buffered before the remote description arrives.
  static const int maxBufferedRemoteCandidates = 64;

  Future<void> _addCandidate(
    RTCPeerConnection connection,
    RTCIceCandidate candidate,
  ) async {
    try {
      await connection.addCandidate(candidate);
    } on Object {
      // A rejected candidate is one fewer path, never a fatal condition — and
      // the candidate string is never logged.
    }
  }

  Future<void> _handleLocalCandidate(RTCIceCandidate candidate) async {
    if (_closed) return;
    if ((candidate.candidate ?? '').isEmpty) return;
    await _onLocalCandidate(candidate);
  }

  void _handleConnectionState(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        unawaited(_refreshRelayFlag());
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _failReady(
          const KubusRtcException(KubusRtcFailure.noRouteFound, 'ICE failed'),
        );
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        _failReady(const KubusRtcException(KubusRtcFailure.connectionLost));
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        break;
    }
  }

  void _handleIceConnectionState(RTCIceConnectionState state) {
    // Mapped only for diagnostics. ICE state is deliberately not surfaced to
    // the user: "disconnected" here routinely recovers on its own, and showing
    // it as a failure would make a working connection look broken.
    if (kDebugMode) {
      debugPrint('KubusRtcPeer: ice state ${state.name}');
    }
  }

  /// Reads the selected candidate pair to learn whether a relay is in use.
  ///
  /// Best effort: the stats report shape varies between platforms, so a
  /// missing field means "not known to be relayed" rather than an error.
  Future<void> _refreshRelayFlag() async {
    final connection = _connection;
    if (connection == null) return;
    try {
      final reports = await connection.getStats();
      final pairs = <String, dynamic>{};
      final candidates = <String, dynamic>{};
      for (final report in reports) {
        if (report.type == 'candidate-pair') {
          pairs[report.id] = report.values;
        } else if (report.type == 'local-candidate' ||
            report.type == 'remote-candidate') {
          candidates[report.id] = report.values;
        }
      }
      for (final pair in pairs.values) {
        final values = pair as Map<Object?, Object?>;
        final selected =
            values['selected'] == true || values['state'] == 'succeeded';
        if (!selected) continue;
        for (final key in const ['localCandidateId', 'remoteCandidateId']) {
          final candidate =
              candidates[values[key]] as Map<Object?, Object?>? ?? const {};
          if (candidate['candidateType'] == 'relay') {
            _isRelayed = true;
            return;
          }
        }
      }
    } on Object {
      // Diagnostics only; never fail a working connection over them.
    }
  }

  void _failReady(KubusRtcException error) {
    final ready = _ready;
    if (ready != null && !ready.isCompleted) ready.completeError(error);
  }

  /// Tears everything down exactly once, leaking neither channel nor connection.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _failReady(const KubusRtcException(KubusRtcFailure.cancelled));
    _pendingRemoteCandidates.clear();
    await _adapter?.close();
    _adapter = null;
    try {
      await _channel?.close();
    } on Object {
      // Already gone.
    }
    _channel = null;
    try {
      await _connection?.close();
    } on Object {
      // Already gone.
    }
    // `close()` stops the connection; `dispose()` releases the native object.
    // Skipping it is a leak that only shows up after many reconnections.
    try {
      await _connection?.dispose();
    } on Object {
      // Already disposed.
    }
    _connection = null;
  }
}
