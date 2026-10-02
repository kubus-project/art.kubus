/// The control plane's rendezvous for reaching a Node that has no reachable
/// address.
///
/// This client coordinates a connection and carries nothing else. It never
/// sees a capture, a result, or a credential: those move on the data channel
/// this negotiates, directly between the phone and the Node, encrypted end to
/// end. Keeping that boundary is the entire reason the backend can be
/// untrusted infrastructure rather than a party to the user's private data.
///
/// It is also not an identity authority. Presence carries a fingerprint, but
/// it is advisory — a compromised control plane could put anything there. The
/// real check is a signed challenge over the data channel against the public
/// key recorded at pairing.
///
/// Event names and payload shapes mirror the backend's `/node-signaling`
/// namespace exactly. They are restated here rather than referenced loosely,
/// because a mismatch produces a connection that simply never completes, with
/// nothing in either log saying why.
library;

import 'dart:async';
import 'dart:math';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../config/config.dart';

/// Why a session could not be established, in terms the UI can act on.
enum SignalingFailure {
  /// The control plane could not be reached at all.
  unavailable,

  /// The user is not authenticated, or the token expired.
  unauthenticated,

  /// The backend has no record of this Node. Remote coordination is
  /// impossible until it registers — distinct from the Node being offline.
  nodeUnregistered,

  /// The Node is registered but not currently connected.
  nodeOffline,

  /// The Node declined the connection.
  rejected,

  /// The session expired before it completed.
  expired,

  /// The Node closed the session.
  closed,

  /// A malformed or unexpected response.
  protocol,
}

class SignalingException implements Exception {
  const SignalingException(this.failure, [this.detail]);

  final SignalingFailure failure;
  final String? detail;

  @override
  String toString() => 'SignalingException(${failure.name}'
      '${detail == null ? '' : ': $detail'})';
}

/// What the control plane knows about a Node right now.
///
/// Deliberately thin. Anything richer here would be the backend accumulating
/// knowledge about a Node's private contents, which is exactly what this
/// architecture is arranged to avoid.
class NodePresenceSnapshot {
  const NodePresenceSnapshot({
    required this.nodeId,
    required this.online,
    this.registered = true,
    this.protocolVersion,
    this.fingerprint,
    this.capabilities = const <String, bool>{},
    this.lastSeenAt,
  });

  /// Registered with the control plane, but not connected right now.
  factory NodePresenceSnapshot.offline(String nodeId) =>
      NodePresenceSnapshot(nodeId: nodeId, online: false, registered: true);

  /// The control plane has no record of this Node at all.
  factory NodePresenceSnapshot.unregistered(String nodeId) =>
      NodePresenceSnapshot(nodeId: nodeId, online: false, registered: false);

  factory NodePresenceSnapshot.fromJson(
    String nodeId,
    Map<String, dynamic> json,
  ) =>
      NodePresenceSnapshot(
        nodeId: nodeId,
        online: true,
        registered: true,
        protocolVersion: (json['protocolVersion'] as num?)?.toInt(),
        fingerprint: json['fingerprint'] as String?,
        capabilities: <String, bool>{
          for (final entry in (json['capabilities'] as Map<dynamic, dynamic>? ??
                  const <dynamic, dynamic>{})
              .entries)
            entry.key.toString(): entry.value == true,
        },
        lastSeenAt: DateTime.tryParse(json['lastSeenAt'] as String? ?? ''),
      );

  final String nodeId;
  final bool online;

  /// Whether the control plane has ever heard of this Node.
  ///
  /// Distinct from offline: a Node the backend does not know cannot be reached
  /// remotely at all until it registers, whereas an offline Node just needs
  /// turning on. Telling a user the wrong one sends them looking in the wrong
  /// place.
  final bool registered;

  /// Wire protocol the Node speaks. Used to detect a version mismatch before
  /// spending a negotiation on a peer that cannot talk to us.
  final int? protocolVersion;

  /// Advisory only. Compared against the paired fingerprint as an early
  /// mismatch hint, never as proof — see the library comment.
  final String? fingerprint;

  /// Flags describing what a connection to this Node could do, e.g. whether it
  /// can relay. Named flags rather than a free-form list, matching the control
  /// plane's allowlist exactly.
  final Map<String, bool> capabilities;
  final DateTime? lastSeenAt;

  /// Whether this Node advertises a protocol this client can speak.
  bool get isProtocolCompatible =>
      protocolVersion == null || protocolVersion == supportedProtocolVersion;

  /// The wire protocol version this client implements.
  static const int supportedProtocolVersion = 1;
}

/// One negotiated signalling session.
class SignalingSession {
  SignalingSession({
    required this.sessionId,
    required this.expiresAt,
    required this.nodeId,
  });

  final String sessionId;
  final DateTime? expiresAt;
  final String nodeId;
}

/// A message relayed from the Node.
class SignalingMessage {
  const SignalingMessage(this.event, this.payload);

  final String event;
  final Map<String, dynamic> payload;
}

/// Connects to `/node-signaling` and coordinates one connection at a time.
class NodeSignalingClient {
  NodeSignalingClient({
    required String baseUrl,
    required Future<String?> Function() authToken,
    io.Socket Function(String uri, Map<String, dynamic> options)? socketFactory,
  })  : _baseUrl = baseUrl,
        _authToken = authToken,
        _socketFactory = socketFactory ?? _defaultSocketFactory;

  static const String namespace = '/node-signaling';

  /// How long to wait for the control plane to answer a request.
  static const Duration ackTimeout = Duration(seconds: 15);

  final String _baseUrl;
  final Future<String?> Function() _authToken;
  final io.Socket Function(String, Map<String, dynamic>) _socketFactory;

  io.Socket? _socket;
  Completer<void>? _connecting;

  final StreamController<SignalingMessage> _messages =
      StreamController<SignalingMessage>.broadcast();

  /// Relayed offers, answers, candidates, ICE-restart requests, and session
  /// lifecycle events from the Node.
  Stream<SignalingMessage> get messages => _messages.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Opens the control-plane connection, or reuses an open one.
  Future<void> connect() async {
    if (isConnected) return;
    final existing = _connecting;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _connecting = completer;

    try {
      final token = await _authToken();
      if (token == null || token.isEmpty) {
        throw const SignalingException(SignalingFailure.unauthenticated);
      }

      final socket = _socketFactory('$_baseUrl$namespace', <String, dynamic>{
        'transports': <String>['websocket'],
        'autoConnect': false,
        // The token goes in the handshake rather than a query parameter so it
        // does not land in an access log or a proxy's URL history.
        'auth': <String, dynamic>{'token': token},
        'reconnection': true,
        'reconnectionAttempts': 8,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 15000,
      });
      _socket = socket;
      _wireEvents(socket, completer);
      socket.connect();

      return await completer.future.timeout(
        ackTimeout,
        onTimeout: () {
          throw const SignalingException(
            SignalingFailure.unavailable,
            'control plane did not answer',
          );
        },
      );
    } finally {
      _connecting = null;
    }
  }

  void _wireEvents(io.Socket socket, Completer<void> ready) {
    socket.onConnect((_) {
      if (!ready.isCompleted) ready.complete();
    });
    socket.onConnectError((Object? error) {
      if (!ready.isCompleted) {
        ready.completeError(
          SignalingException(
            _isAuthError(error)
                ? SignalingFailure.unauthenticated
                : SignalingFailure.unavailable,
          ),
        );
      }
    });
    socket.onError((Object? error) {
      // Never the payload: an error can echo the message that caused it,
      // and those carry SDP.
      AppConfig.debugPrint('NodeSignalingClient: socket error');
    });

    for (final event in const <String>[
      'signal:offer',
      'signal:answer',
      'signal:candidate',
      'session:incoming',
      'session:accepted',
      'session:rejected',
      'session:closed',
      'session:expired',
      'session:ice-restart',
    ]) {
      socket.on(event, (Object? data) {
        if (_messages.isClosed) return;
        _messages.add(SignalingMessage(event, _asMap(data)));
      });
    }
  }

  static bool _isAuthError(Object? error) {
    final text = error?.toString().toLowerCase() ?? '';
    return text.contains('auth') || text.contains('401');
  }

  /// Asks whether a Node is reachable right now.
  ///
  /// Distinguishes "the backend has never heard of this Node" from "the Node
  /// is offline", because they need different words in the UI: the first is
  /// solved by registering the Node, the second by turning it on.
  Future<NodePresenceSnapshot> queryPresence(String nodeId) async {
    await connect();
    final result = await _emitWithAck('presence:query', <String, dynamic>{
      'nodeId': nodeId,
    });
    switch (result['status']) {
      case 'online':
        final presence = result['presence'];
        return NodePresenceSnapshot.fromJson(
          nodeId,
          presence is Map ? _asMap(presence) : const <String, dynamic>{},
        );
      case 'unregistered':
        return NodePresenceSnapshot.unregistered(nodeId);
      default:
        return NodePresenceSnapshot.offline(nodeId);
    }
  }

  /// Requests a session with a Node and waits for it to be accepted.
  Future<SignalingSession> openSession(
    String nodeId, {
    Duration acceptTimeout = const Duration(seconds: 20),
  }) async {
    await connect();
    final result = await _emitWithAck('session:request', <String, dynamic>{
      'nodeId': nodeId,
    });
    final sessionId = result['sessionId'] as String?;
    if (sessionId == null || sessionId.isEmpty) {
      throw const SignalingException(SignalingFailure.protocol);
    }

    final accepted = Completer<SignalingSession>();
    late final StreamSubscription<SignalingMessage> subscription;
    subscription = messages.listen((message) {
      if (message.payload['sessionId'] != sessionId) return;
      switch (message.event) {
        case 'session:accepted':
          if (!accepted.isCompleted) {
            accepted.complete(
              SignalingSession(
                sessionId: sessionId,
                expiresAt: DateTime.tryParse(
                  message.payload['expiresAt'] as String? ?? '',
                ),
                nodeId: nodeId,
              ),
            );
          }
        case 'session:rejected':
          if (!accepted.isCompleted) {
            accepted.completeError(
              const SignalingException(SignalingFailure.rejected),
            );
          }
        case 'session:expired':
          if (!accepted.isCompleted) {
            accepted.completeError(
              const SignalingException(SignalingFailure.expired),
            );
          }
        case 'session:closed':
          if (!accepted.isCompleted) {
            accepted.completeError(
              const SignalingException(SignalingFailure.closed),
            );
          }
      }
    });

    try {
      return await accepted.future.timeout(
        acceptTimeout,
        onTimeout: () => throw const SignalingException(
          SignalingFailure.nodeOffline,
          'the Node did not answer the connection request',
        ),
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> sendOffer(
    String sessionId,
    String sdp,
    String type, {
    List<Map<String, Object?>> iceServers = const <Map<String, Object?>>[],
  }) =>
      _emitWithAck('signal:offer', <String, dynamic>{
        'sessionId': sessionId,
        'messageId': _messageId(),
        'sdp': sdp,
        'type': type,
        // The Node needs the same ephemeral ICE configuration to allocate its
        // relay side. These are short-lived user credentials, never coturn's
        // static secret, and the signaling client never logs the payload.
        if (iceServers.isNotEmpty) 'iceServers': iceServers,
      });

  Future<void> sendCandidate(
    String sessionId, {
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  }) =>
      _emitWithAck('signal:candidate', <String, dynamic>{
        'sessionId': sessionId,
        'messageId': _messageId(),
        'candidate': <String, dynamic>{
          'candidate': candidate,
          if (sdpMid != null) 'sdpMid': sdpMid,
          if (sdpMLineIndex != null) 'sdpMLineIndex': sdpMLineIndex,
        },
      });

  Future<void> requestIceRestart(String sessionId) =>
      _emitWithAck('session:ice-restart', <String, dynamic>{
        'sessionId': sessionId,
        'messageId': _messageId(),
      });

  Future<void> closeSession(String sessionId, {String reason = 'done'}) async {
    if (!isConnected) return;
    try {
      await _emitWithAck('session:close', <String, dynamic>{
        'sessionId': sessionId,
        'reason': reason,
      });
    } on SignalingException {
      // Best effort: the session may already be gone, and failing to announce
      // a close must not surface as an error to the user.
    }
  }

  /// A per-message identifier the control plane uses for replay rejection.
  ///
  /// Random rather than sequential so a message cannot be predicted and
  /// pre-empted by anyone who has seen an earlier one.
  String _messageId() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<Map<String, dynamic>> _emitWithAck(
    String event,
    Map<String, dynamic> payload,
  ) async {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      throw const SignalingException(SignalingFailure.unavailable);
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(
      event,
      payload,
      ack: (Object? response) {
        if (completer.isCompleted) return;
        final map = _asMap(response);
        // The control plane answers `{ok: true, ...}` or
        // `{ok: false, code, error}`. The code is the part worth acting on;
        // the message is for a log, never for a user.
        if (map['ok'] == false) {
          final code = map['code'];
          completer.completeError(
            SignalingException(
              _failureFor(code is String ? code : null),
              code is String ? code : null,
            ),
          );
          return;
        }
        completer.complete(map);
      },
    );
    return completer.future.timeout(
      ackTimeout,
      onTimeout: () => throw const SignalingException(
        SignalingFailure.unavailable,
        'the control plane did not acknowledge',
      ),
    );
  }

  static SignalingFailure _failureFor(String? code) {
    switch (code) {
      case 'NODE_UNREGISTERED':
        return SignalingFailure.nodeUnregistered;
      case 'NODE_OFFLINE':
        return SignalingFailure.nodeOffline;
      case 'SESSION_EXPIRED':
      case 'SESSION_NOT_FOUND':
        return SignalingFailure.expired;
      case 'ROLE_NOT_ALLOWED':
      case 'INVALID_PAYLOAD':
      case 'MESSAGE_TOO_LARGE':
      case 'REPLAYED_MESSAGE':
        return SignalingFailure.protocol;
      default:
        return SignalingFailure.unavailable;
    }
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  Future<void> dispose() async {
    final socket = _socket;
    _socket = null;
    try {
      socket?.dispose();
    } on Object {
      // Already gone.
    }
    if (!_messages.isClosed) await _messages.close();
  }

  static io.Socket _defaultSocketFactory(
    String uri,
    Map<String, dynamic> options,
  ) =>
      io.io(uri, options);
}
