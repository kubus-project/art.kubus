import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../kubus_data_channel.dart';
import '../kubus_node_transport.dart';
import '../node_identity_proof.dart';
import '../turn_configuration.dart';
import '../webrtc_frame.dart';
import '../webrtc_node_transport.dart';
import 'kubus_rtc_peer.dart';
import 'node_signaling_client.dart';

/// Builds a usable, *verified* WebRTC transport to the paired Node.
///
/// This is where the three halves meet: the control plane arranges a
/// rendezvous, WebRTC negotiates a path, and the Node proves who it is. All
/// three must succeed before a single Node credential is sent, and the order
/// matters — a channel that opened is not a channel worth trusting.
///
/// The connector deliberately produces a [KubusNodeTransport] rather than a
/// connection object. Everything above it routes the same canonical
/// `/local/v1/...` operations and cannot tell which rung carried them, which
/// is what makes "one Node identity, many transports" true rather than
/// aspirational.
class NodeRtcConnector {
  NodeRtcConnector({
    required NodeSignalingClient signaling,
    required Future<IceConfiguration> Function() iceConfiguration,
    required Uint8List? Function() pairedPublicKey,
    String? Function()? credential,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration proofTimeout = const Duration(seconds: 10),
  })  : _signaling = signaling,
        _iceConfiguration = iceConfiguration,
        _pairedPublicKey = pairedPublicKey,
        _credential = credential ?? _noCredential,
        _connectTimeout = connectTimeout,
        _proofTimeout = proofTimeout;

  /// Request id reserved for the identity challenge.
  ///
  /// The challenge precedes every real operation on a fresh channel, so a
  /// fixed id cannot collide with one.
  static const int identityRequestId = 1;

  final NodeSignalingClient _signaling;
  final Future<IceConfiguration> Function() _iceConfiguration;
  final Uint8List? Function() _pairedPublicKey;
  final String? Function() _credential;

  static String? _noCredential() => null;
  final Duration _connectTimeout;
  final Duration _proofTimeout;

  /// Negotiates a connection to [nodeId] and returns a verified transport.
  ///
  /// Throws rather than returning an unverified transport. There is no
  /// "connected but unverified" state worth exposing: a caller handed one
  /// would have to remember never to use it, and eventually would not.
  Future<WebRtcNodeTransport> connect(String nodeId) async {
    final session = await _signaling.openSession(nodeId);
    final ice = await _iceConfiguration();

    KubusRtcPeer? peer;
    StreamSubscription<SignalingMessage>? subscription;
    try {
      final activePeer = KubusRtcPeer(
        iceConfiguration: ice,
        connectTimeout: _connectTimeout,
        onLocalDescription: (sdp, type) => _signaling.sendOffer(
          session.sessionId,
          sdp,
          type,
          iceServers: ice.toIceServers(DateTime.now()),
        ),
        onLocalCandidate: (candidate) => _signaling.sendCandidate(
          session.sessionId,
          candidate: candidate.candidate ?? '',
          sdpMid: candidate.sdpMid,
          sdpMLineIndex: candidate.sdpMLineIndex,
        ),
      );
      peer = activePeer;

      subscription = _signaling.messages.listen((message) {
        if (message.payload['sessionId'] != session.sessionId) return;
        unawaited(_applySignal(activePeer, message));
      });

      final channel = await activePeer.connect();

      // The channel is open. Nothing has been trusted yet.
      await verifyIdentityOver(channel, session.sessionId);

      final transport = WebRtcNodeTransport(
        channel: channel,
        kind: activePeer.isRelayed
            ? KubusNodeTransportKind.webRtcRelay
            : KubusNodeTransportKind.webRtcDirect,
        // The channel is identity-verified immediately above. Do not capture
        // this credential before that proof succeeds.
        credential: _credential(),
      );

      // Signalling has done its job. Leaving the session open would keep
      // ephemeral state on the control plane for a connection that no longer
      // needs it.
      await subscription.cancel();
      subscription = null;
      unawaited(
        _signaling.closeSession(session.sessionId, reason: 'connected'),
      );
      return transport;
    } on Object {
      await subscription?.cancel();
      await peer?.close();
      await _signaling.closeSession(session.sessionId, reason: 'failed');
      rethrow;
    }
  }

  Future<void> _applySignal(KubusRtcPeer peer, SignalingMessage message) async {
    switch (message.event) {
      case 'signal:answer':
        final sdp = message.payload['sdp'];
        final type = message.payload['type'];
        if (sdp is String && type is String) {
          await peer.acceptRemoteDescription(sdp, type);
        }
      case 'signal:candidate':
        final raw = message.payload['candidate'];
        if (raw is Map) {
          final candidate = raw['candidate'];
          if (candidate is String && candidate.isNotEmpty) {
            await peer.addRemoteCandidate(
              RTCIceCandidate(
                candidate,
                raw['sdpMid'] as String?,
                raw['sdpMLineIndex'] as int?,
              ),
            );
          }
        }
      case 'session:closed':
      case 'session:expired':
      case 'session:rejected':
        await peer.close();
      default:
        break;
    }
  }

  /// Demands a signature over a fresh challenge before anything else happens.
  ///
  /// Exposed so a test can drive it against a pair of in-memory channels
  /// without a peer connection — the verification logic is the part worth
  /// exercising exhaustively, and it does not depend on ICE.
  ///
  /// The challenge is sent as an ordinary framed request so it uses the same
  /// wire format as everything else, but it carries no credential: the entire
  /// point is to decide whether this peer deserves one.
  Future<void> verifyIdentityOver(
    KubusDataChannel channel,
    String sessionId,
  ) async {
    final challenge = NodeIdentityChallenge.generate(sessionId: sessionId);
    final response = await _requestProof(channel, challenge);
    await verifyNodeIdentityProof(
      challenge: challenge,
      response: response,
      pairedPublicKey: _pairedPublicKey(),
    );
  }

  Future<Map<String, dynamic>> _requestProof(
    KubusDataChannel channel,
    NodeIdentityChallenge challenge,
  ) async {
    final completer = Completer<Map<String, dynamic>>();
    final buffer = BytesBuilder(copy: false);

    final subscription = channel.messages.listen((data) {
      if (completer.isCompleted) return;
      final KubusFrame frame;
      try {
        frame = KubusFrameCodec.decode(data);
      } on KubusFrameException {
        // Unattributable, so dropped. The timeout below is the backstop.
        return;
      }
      if (frame.requestId != identityRequestId) return;
      if (frame.type == KubusFrameType.error) {
        completer.completeError(
          const NodeIdentityException(
            NodeIdentityFailure.malformed,
            'the peer refused the identity challenge',
          ),
        );
        return;
      }
      if (frame.payload != null) buffer.add(frame.payload!);
      if (!frame.isFinal) return;
      try {
        completer.complete(_decodeEnvelope(buffer.takeBytes()));
      } on Object catch (error) {
        completer.completeError(error);
      }
    });

    try {
      await channel.send(
        KubusFrameCodec.encode(
          KubusFrame(
            type: KubusFrameType.requestHead,
            requestId: identityRequestId,
            flags: KubusFrame.flagFinal,
            metadata: <String, dynamic>{
              'method': 'POST',
              'path': '/local/v1/identity/challenge',
              ...challenge.toRequestMetadata(),
            },
          ),
        ),
      );
      return await completer.future.timeout(
        _proofTimeout,
        onTimeout: () => throw const NodeIdentityException(
          NodeIdentityFailure.malformed,
          'the peer did not answer the identity challenge in time',
        ),
      );
    } finally {
      await subscription.cancel();
    }
  }

  /// Unwraps the Node's `{ success, data }` envelope.
  static Map<String, dynamic> _decodeEnvelope(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const NodeIdentityException(NodeIdentityFailure.malformed);
    }
    final Object? parsed;
    try {
      parsed = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } on FormatException {
      throw const NodeIdentityException(NodeIdentityFailure.malformed);
    }
    if (parsed is! Map) {
      throw const NodeIdentityException(NodeIdentityFailure.malformed);
    }
    final data = parsed['data'];
    if (data is! Map) {
      throw const NodeIdentityException(NodeIdentityFailure.malformed);
    }
    return data.map((key, value) => MapEntry(key.toString(), value));
  }
}
