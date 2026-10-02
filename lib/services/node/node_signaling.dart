import 'kubus_node_transport.dart';

/// What a signaling message carries.
///
/// Signaling is control-plane metadata used to *establish* a peer connection.
/// It is never the data plane: captures, processed scenes and any other
/// private content travel on the established transport, never through here.
enum SignalingMessageType {
  /// Session description from the initiating peer.
  offer,

  /// Session description in reply.
  answer,

  /// One ICE candidate.
  candidate,

  /// The initiator wants a connection; wakes a Node that is only polling.
  connectionAttempt,

  /// Either side abandoning the attempt.
  close,
}

/// A signaling message could not be accepted.
class SignalingValidationException implements Exception {
  const SignalingValidationException(this.message);

  final String message;

  @override
  String toString() => 'SignalingValidationException: $message';
}

/// One signaling message, bound to a session, a Node and a device.
///
/// Binding is what makes transport success meaningless on its own: a peer that
/// completes ICE has proved only that packets flow. It must still be the Node
/// this device paired with, and this envelope is where that expectation is
/// carried and checked.
class SignalingEnvelope {
  const SignalingEnvelope({
    required this.type,
    required this.sessionId,
    required this.nodeId,
    required this.deviceId,
    required this.nonce,
    required this.issuedAt,
    required this.expiresAt,
    this.payload,
  });

  final SignalingMessageType type;

  /// Short-lived session this message belongs to.
  final String sessionId;

  /// The paired Node's stable identity — never an IP, DNS name or peer id.
  final String nodeId;

  /// The device that initiated pairing.
  final String deviceId;

  /// Single-use value that makes a captured message useless if replayed.
  final String nonce;

  final DateTime issuedAt;
  final DateTime expiresAt;

  /// SDP or candidate string, absent for control-only messages.
  final String? payload;

  /// Longest a signaling session may live.
  ///
  /// Deliberately short: an SDP that is still valid tomorrow is an SDP worth
  /// stealing, and a session that outlives the attempt it describes is just
  /// retained personal data.
  static const Duration maxLifetime = Duration(minutes: 2);

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  /// Whether this message may be acted on.
  ///
  /// [expectedNodeId] and [expectedDeviceId] come from the local pairing
  /// record, so a message that is perfectly well-formed but describes someone
  /// else's session is refused rather than processed.
  void validate({
    required DateTime now,
    required String expectedNodeId,
    required String expectedDeviceId,
    required Set<String> seenNonces,
  }) {
    if (sessionId.trim().isEmpty) {
      throw const SignalingValidationException('missing session id');
    }
    if (nodeId != expectedNodeId) {
      throw const SignalingValidationException('node identity mismatch');
    }
    if (deviceId != expectedDeviceId) {
      throw const SignalingValidationException('device identity mismatch');
    }
    if (isExpired(now)) {
      throw const SignalingValidationException('signaling session expired');
    }
    if (expiresAt.difference(issuedAt) > maxLifetime) {
      // A peer does not get to grant itself a longer window than the protocol
      // allows simply by claiming one.
      throw const SignalingValidationException('lifetime exceeds maximum');
    }
    if (seenNonces.contains(nonce)) {
      throw const SignalingValidationException('nonce replayed');
    }
    if (type == SignalingMessageType.offer ||
        type == SignalingMessageType.answer ||
        type == SignalingMessageType.candidate) {
      if ((payload ?? '').trim().isEmpty) {
        throw SignalingValidationException('$type requires a payload');
      }
    }
  }

  /// A form safe to write to logs.
  ///
  /// SDP and ICE candidates contain host addresses and session credentials, so
  /// they are represented by length alone. Dumping them into production logs
  /// would leak network topology and undo the point of keeping sessions short.
  Map<String, Object?> toLogSafeJson() => <String, Object?>{
        'type': type.name,
        'sessionId': sessionId,
        'nodeId': nodeId,
        'deviceId': deviceId,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        if (payload != null) 'payloadLength': payload!.length,
      };
}

/// What a Node publishes so a paired device can find it.
///
/// Intentionally close to empty. Presence answers "is this Node around, and
/// what can it speak?" — nothing else. Anything that would let an observer
/// locate the operator, impersonate the Node, or learn what it is working on
/// has no place here.
class NodePresence {
  const NodePresence({
    required this.nodeId,
    required this.transports,
    required this.updatedAt,
    this.acceptsConnections = true,
  });

  final String nodeId;

  /// Rungs this Node can currently speak.
  final Set<KubusNodeTransportKind> transports;

  final DateTime updatedAt;
  final bool acceptsConnections;

  /// Keys that must never appear in a published presence record.
  ///
  /// Enforced rather than documented, because this is the record most likely
  /// to accumulate "just one useful field" over time.
  static const Set<String> forbiddenKeys = <String>{
    'lanIp',
    'localIp',
    'ipAddress',
    'endpoint',
    'endpoints',
    'pairingSecret',
    'secret',
    'credential',
    'token',
    'authorization',
    'captures',
    'captureCount',
    'jobs',
    'operatorWallet',
  };

  /// The publishable form.
  ///
  /// Private LAN addresses are deliberately absent: they belong in ICE
  /// candidate exchange between two already-authenticated peers, not in a
  /// record the control plane holds.
  Map<String, Object?> toJson() => <String, Object?>{
        'nodeId': nodeId,
        'transports': transports.map((t) => t.name).toList()..sort(),
        'acceptsConnections': acceptsConnections,
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Throws if [json] carries anything a presence record must not publish.
  static void assertPublishable(Map<String, Object?> json) {
    for (final key in json.keys) {
      final normalized = key.toLowerCase();
      for (final forbidden in forbiddenKeys) {
        if (normalized == forbidden.toLowerCase()) {
          throw SignalingValidationException(
            'presence must not publish "$key"',
          );
        }
      }
    }
  }
}
