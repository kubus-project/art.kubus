import 'dart:io';

/// How a request reached the paired Node.
///
/// This is diagnostic and policy metadata only. It never changes what an
/// operation *means*: the same canonical `/local/v1/...` operation is carried
/// over whichever transport is currently usable, so services above this layer
/// cannot tell — and must not care — which rung was used.
enum KubusNodeTransportKind {
  /// Private-network HTTP to the Node (192.168/10/172.16-31, `.local`).
  localDirect,

  /// WebRTC peer connection established without a relay.
  webRtcDirect,

  /// WebRTC peer connection carried by a TURN relay.
  webRtcRelay,

  /// An operator-configured public HTTPS endpoint (reverse proxy, VPN
  /// ingress, tunnel, or their own domain). Deliberately provider-neutral.
  remoteHttps,
}

extension KubusNodeTransportKindX on KubusNodeTransportKind {
  /// Whether traffic on this rung is carried by a third-party relay.
  ///
  /// Used by transport policy to prefer unrelayed routes, and by diagnostics.
  /// It is not a trust statement: relayed WebRTC is still DTLS-encrypted and
  /// the Node identity is verified independently of the route.
  bool get isRelayed => this == KubusNodeTransportKind.webRtcRelay;

  /// Whether this rung requires the public internet to be reachable.
  bool get requiresInternet => this != KubusNodeTransportKind.localDirect;
}

/// A transport-neutral request against the canonical Node API.
///
/// Mirrors the shape of the existing local HTTP API rather than inventing a
/// parallel vocabulary, so a WebRTC implementation frames *these* operations
/// instead of introducing duplicate `/webrtc/...` routes.
class KubusNodeRequest {
  const KubusNodeRequest({
    required this.method,
    required this.path,
    this.query = const <String, String>{},
    this.headers = const <String, String>{},
    this.jsonBody,
    this.timeout = const Duration(seconds: 20),
    this.idempotencyKey,
  });

  final String method;

  /// Canonical Node path, e.g. `/local/v1/captures/drafts`.
  final String path;

  final Map<String, String> query;
  final Map<String, String> headers;

  /// Decoded JSON body, or null for bodyless requests. Encoding is the
  /// transport's concern.
  final Map<String, dynamic>? jsonBody;

  final Duration timeout;

  /// Set for operations that must not be duplicated if a transport fails and
  /// the request is retried on another rung — draft commits, job creation.
  /// Safe reads leave this null.
  final String? idempotencyKey;

  /// Whether this operation may be retried on a different transport without
  /// risking a duplicate side effect.
  ///
  /// Read-only verbs are always safe. Anything mutating is safe only when it
  /// carries an idempotency key the Node can deduplicate against.
  bool get isSafeToRetry {
    const readOnly = <String>{'GET', 'HEAD', 'OPTIONS'};
    return readOnly.contains(method.toUpperCase()) || idempotencyKey != null;
  }
}

/// A transport-neutral response.
///
/// Deliberately carries the raw status and body rather than a decoded result:
/// response *semantics* (success envelopes, typed error codes, unsupported
/// routes) are protocol concerns owned by the service, identically on every
/// rung.
class KubusNodeResponse {
  const KubusNodeResponse({
    required this.statusCode,
    required this.body,
    this.requestPath,
  });

  final int statusCode;

  /// Raw response body. Empty string for an empty body.
  final String body;

  /// Path the response belongs to, used to report unsupported routes.
  final String? requestPath;
}

/// One route to the paired Node.
///
/// Implementations differ only in how bytes move. They do not interpret
/// application semantics, do not decide policy, and must not carry a Node
/// identity of their own — transport success is never, by itself, proof that
/// the correct Node was reached.
abstract class KubusNodeTransport {
  /// Which rung this is, for policy and diagnostics.
  KubusNodeTransportKind get kind;

  /// Whether this transport currently believes it can carry a request.
  ///
  /// A cheap, non-blocking hint used to order candidates. It is not a
  /// guarantee; `request` may still fail.
  bool get isAvailable;

  /// Performs a request and returns the raw response.
  Future<KubusNodeResponse> request(KubusNodeRequest request);

  /// Streams a file as the request body without holding it in memory.
  ///
  /// Spatial captures are far too large to buffer, so this is a first-class
  /// transport operation rather than a convenience built on [request].
  Future<KubusNodeResponse> streamUpload(
    KubusNodeRequest request, {
    required File file,
    required String contentType,
  });

  /// Releases any underlying connection resources.
  void close();
}
