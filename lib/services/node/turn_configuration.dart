/// ICE server configuration, obtained from the control plane at connection
/// time.
///
/// The relay is **not** part of the art.kubus backend. It is a separate
/// service (coturn or equivalent) that forwards encrypted WebRTC traffic and
/// understands nothing about captures, libraries, or any other application
/// concept. The backend's only role here is to *authenticate the request* and
/// *issue a short-lived credential* for that separate service.
///
/// Three distinct things, deliberately never merged:
///
/// - **control plane** — authenticates, signals, issues credentials
/// - **data plane** — the Node itself, holding private content
/// - **relay** — carries opaque encrypted bytes, only when nothing else works
library;

/// A credential could not be accepted.
class TurnCredentialException implements Exception {
  const TurnCredentialException(this.message);

  final String message;

  @override
  String toString() => 'TurnCredentialException: $message';
}

/// A STUN server. Needs no credentials: it only reports the address a peer
/// appears to come from.
class StunServer {
  const StunServer(this.url);

  final String url;

  Map<String, Object?> toIceServerJson() => <String, Object?>{'urls': url};
}

/// A short-lived TURN credential, issued by the authenticated control plane
/// for use against a separate relay service.
///
/// There is no constructor for a non-expiring credential, and none should be
/// added. A permanent TURN credential shipped in a client is a standing
/// invitation to use someone else's bandwidth: it can be extracted from any
/// binary or bundle, cannot be revoked per user, and turns the relay into open
/// infrastructure for whoever finds it.
class TurnCredentials {
  const TurnCredentials({
    required this.urls,
    required this.username,
    required this.credential,
    required this.expiresAt,
  });

  /// Relay endpoints, e.g. `turn:relay.example:3478?transport=udp`.
  final List<String> urls;

  /// Time-scoped username, typically `<expiry>:<user>` for coturn's REST
  /// mechanism.
  final String username;

  /// Credential derived from the shared secret. The client never holds that
  /// secret, only this short-lived product of it.
  final String credential;

  final DateTime expiresAt;

  /// Longest credential lifetime the client will accept.
  ///
  /// Enforced on receipt rather than trusted: a control plane that starts
  /// handing out day-long credentials should fail loudly here, not quietly
  /// widen the window in which a leaked credential is useful.
  static const Duration maxLifetime = Duration(hours: 1);

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  bool isUsableAt(DateTime now) => !isExpired(now);

  /// Validates a freshly-issued credential.
  void validate({required DateTime now, required DateTime issuedAt}) {
    if (urls.isEmpty) {
      throw const TurnCredentialException('no relay URLs');
    }
    if (username.trim().isEmpty || credential.trim().isEmpty) {
      throw const TurnCredentialException('incomplete credential');
    }
    if (isExpired(now)) {
      throw const TurnCredentialException('credential already expired');
    }
    if (expiresAt.difference(issuedAt) > maxLifetime) {
      throw const TurnCredentialException(
          'credential lifetime exceeds maximum');
    }
    for (final url in urls) {
      if (!url.startsWith('turn:') && !url.startsWith('turns:')) {
        throw TurnCredentialException('not a relay URL: $url');
      }
    }
  }

  Map<String, Object?> toIceServerJson() => <String, Object?>{
        'urls': urls,
        'username': username,
        'credential': credential,
      };

  /// Log form. The credential itself is never included.
  Map<String, Object?> toLogSafeJson() => <String, Object?>{
        'urls': urls,
        'expiresAt': expiresAt.toIso8601String(),
      };
}

/// The ICE configuration for one connection attempt.
///
/// TURN is optional by construction — [turn] may be null, and everything still
/// works. Owning or operating a kubus Node never requires a relay: it exists
/// for NAT and firewall topologies that defeat direct connectivity, and for
/// nothing else.
class IceConfiguration {
  const IceConfiguration({
    this.stun = const <StunServer>[],
    this.turn,
  });

  final List<StunServer> stun;

  /// Null when no relay is configured, or none was issued.
  final TurnCredentials? turn;

  /// Whether a relay is available for this attempt.
  bool relayAvailableAt(DateTime now) => turn?.isUsableAt(now) ?? false;

  /// ICE servers for the peer connection.
  ///
  /// An expired credential is dropped rather than offered: handing WebRTC a
  /// credential the relay will reject only wastes negotiation time and hides
  /// the real reason a connection failed.
  List<Map<String, Object?>> toIceServers(DateTime now) =>
      <Map<String, Object?>>[
        for (final server in stun) server.toIceServerJson(),
        if (turn != null && turn!.isUsableAt(now)) turn!.toIceServerJson(),
      ];
}
