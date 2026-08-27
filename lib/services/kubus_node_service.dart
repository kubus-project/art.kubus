import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/kubus_node_models.dart';
import 'node/http_node_transport.dart';
import 'node/kubus_node_transport.dart';
import 'node/node_identity_proof.dart';
import 'node/node_idempotency_key.dart';
import 'node/node_transport_factory.dart';
import 'node/node_transport_health.dart';
import 'node/node_transport_resolver.dart';
import 'node/rtc/node_rtc_connector.dart';
import 'node/rtc/node_signaling_client.dart';
import 'node/turn_configuration.dart';
import 'storage_config.dart';

/// A request the paired node rejected, carrying its stable error code.
///
/// Typed so the UI can map an expected failure to localized product language
/// instead of showing a raw HTTP body.
class KubusNodeRequestException implements Exception {
  const KubusNodeRequestException({
    required this.statusCode,
    required this.code,
  });

  final int statusCode;

  /// The node's machine-readable error code, or `node_request_failed`.
  final String code;

  @override
  String toString() => 'KubusNodeRequestException($statusCode): $code';
}

/// The paired node does not implement a route this app version requires.
///
/// Distinct from an ordinary failure: the remedy is updating the node, not
/// retrying.
class KubusNodeUnsupportedException implements Exception {
  const KubusNodeUnsupportedException(this.route);

  final String route;

  @override
  String toString() => 'KubusNodeUnsupportedException($route)';
}

/// An address answered, but it did not prove it is the paired Node.
///
/// Raised *before* anything is sent, so nothing was disclosed: a reachable
/// address is never enough authority to receive the Node credential or a
/// private spatial capture. Treat it as a security failure rather than a
/// transient one — retrying the same address is not a remedy, and failing over
/// private traffic to it is exactly what must not happen.
class KubusNodeIdentityException implements Exception {
  const KubusNodeIdentityException([this.origin]);

  /// The scheme/host/port that failed to prove itself, for diagnostics.
  final String? origin;

  @override
  String toString() =>
      'KubusNodeIdentityException${origin == null ? '' : '($origin)'}';
}

abstract class KubusNodeCredentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureKubusNodeCredentialStore implements KubusNodeCredentialStore {
  SecureKubusNodeCredentialStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class KubusContentCandidate {
  const KubusContentCandidate({
    required this.uri,
    required this.source,
    this.headers = const {},
  });
  final Uri uri;
  final String source;
  final Map<String, String> headers;
}

class KubusNodeService {
  KubusNodeService({
    http.Client? client,
    KubusNodeCredentialStore? credentialStore,
    bool? isWeb,
    KubusNodeTransport? transport,
  })  : _client = client ?? http.Client(),
        _store = credentialStore ?? SecureKubusNodeCredentialStore(),
        _isWeb = isWeb ?? kIsWeb {
    final resolver = transport == null
        ? NodeTransportFactory.build(
            endpoint: _requireEndpoint,
            credential: () => _credential,
            remoteEndpoint: () => _remoteEndpoint,
            client: _client,
            contextForOperation: () => _network.read(),
          )
        : null;
    // Every rung is refused until it proves it still reaches the paired Node.
    // Installed here rather than passed to the factory because the factory
    // assembles the ladder while this service is still constructing.
    resolver?.identityGuard = _proveRungBeforeSend;
    _resolver = resolver;
    _transport = transport ?? resolver!;
  }
  static const _endpointKey = 'kubus_node_endpoint_v1';
  static const _credentialKey = 'kubus_node_credential_v1';
  static const _fingerprintKey = 'kubus_node_fingerprint_v1';

  /// The paired Node's Ed25519 public key, base64url.
  ///
  /// Recorded at pairing and never updated from a live connection: a peer that
  /// could rewrite this could then verify as itself, which is the whole attack
  /// the key exists to stop. Changing it requires re-pairing.
  static const _publicKeyKey = 'kubus_node_public_key_v1';

  /// The Node's stable public id, used to reach it via the control plane.
  ///
  /// `_v2` is deliberate and must not be lowered: every device already paired
  /// on a shipped build wrote its node id under this exact name. Reading a
  /// different key would find nothing, leave [nodeId] null, and — now that a
  /// missing id makes the identity guard refuse every HTTP rung — silently
  /// unpair every existing user until they scanned a new code.
  static const _nodeIdKey = 'kubus_node_id_v2';
  static const _remoteEndpointKey = 'kubus_node_remote_endpoint_v1';
  final http.Client _client;
  final KubusNodeCredentialStore _store;
  final bool _isWeb;

  /// The route Node API operations travel over.
  ///
  /// Injectable so a test can assert the service's protocol behaviour without
  /// a socket, and so later rungs (WebRTC direct, relayed) can be substituted
  /// without touching any caller.
  late final KubusNodeTransport _transport;

  /// Present for the app-owned production transport. Null for a test-injected
  /// transport, where changing route health would be surprising.
  late final KubusNodeTransportResolver? _resolver;

  final NetworkContextSource _network = NetworkContextSource();

  Uri? _endpoint;
  String? _credential;
  String? _fingerprint;
  String? _publicKeyBase64Url;
  String? _nodeId;
  Uri? _remoteEndpoint;
  NodeSignalingClient? _signaling;

  /// How long a proved endpoint identity is reused before it is proved again.
  ///
  /// See [_proveEndpointIdentity] for the full caching rule.
  static const Duration _identityVerificationTtl = Duration(minutes: 5);

  /// Origins (scheme, host, port) proved to belong to the paired Node, and
  /// when. Deliberately in memory only — see [_proveEndpointIdentity].
  final Map<String, DateTime> _provenOrigins = <String, DateTime>{};

  /// Probes currently in flight, keyed by origin.
  ///
  /// [fetchSnapshot] issues five requests at once; without this every one of
  /// them would open its own identity probe against the same host before the
  /// first had answered.
  final Map<String, Future<void>> _probesInFlight = <String, Future<void>>{};

  Uri? get endpoint => _endpoint;
  String? get fingerprint => _fingerprint;
  String? get nodeId => _nodeId;

  /// The route that last delivered a Node request, for diagnostics/UI state.
  KubusNodeTransportKind? get activeTransport => _resolver?.activeKind;

  Map<KubusNodeTransportKind, TransportHealthRecord> get transportHealth =>
      _resolver?.health ??
      const <KubusNodeTransportKind, TransportHealthRecord>{};

  /// The paired Node's public key, or null when this pairing predates it.
  ///
  /// Returned as raw bytes because that is what verification needs, and
  /// decoding in one place means a corrupt stored value fails here rather than
  /// somewhere deep in a handshake.
  Uint8List? get pairedPublicKey {
    final encoded = _publicKeyBase64Url;
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final bytes = base64Url.decode(base64Url.normalize(encoded));
      return bytes.length == 32 ? Uint8List.fromList(bytes) : null;
    } on FormatException {
      return null;
    }
  }

  /// Whether this pairing can support a verified remote connection.
  ///
  /// A pairing without a public key still works on the local network, where
  /// the user chose the address, but it cannot prove the identity of a peer
  /// that dials in from elsewhere. Surfacing this lets the app ask for a
  /// re-pair instead of silently treating an unverifiable route as safe.
  bool get supportsRemoteIdentityVerification => pairedPublicKey != null;

  bool get isPaired =>
      _endpoint != null && (_credential ?? '').startsWith('kubus_local_');

  /// True when the paired Node is currently reached over the local network.
  ///
  /// False for a paired Node reached over remote HTTPS or a WebRTC rung, and
  /// false when there is no endpoint at all. The distinction matters to the
  /// user: reaching *their* Node over the LAN and reaching *their* Node over
  /// the internet are the same trust relationship shown differently, and
  /// neither is the same as handing the capture to a stranger's GPU.
  bool get isEndpointOnLocalNetwork {
    final active = activeTransport;
    if (active != null && active != KubusNodeTransportKind.localDirect) {
      return false;
    }
    final endpoint = _endpoint;
    return endpoint != null && isPrivateNetworkHost(endpoint);
  }

  Future<bool> initialize() async {
    // Routing decisions must see a real network class before the first
    // request. A route that failed on the old network is reset immediately on
    // a switch rather than needlessly remaining in cooldown at the new one.
    unawaited(
      _network.start(
        onChanged: (_) {
          // The same address can name a different machine on a different
          // network, so a proof taken on the old one is worth nothing here.
          _provenOrigins.clear();
          _resolver?.onNetworkChanged();
        },
      ),
    );
    _endpoint = _readStoredEndpoint(await _store.read(_endpointKey));
    _credential = await _store.read(_credentialKey);
    _fingerprint = await _store.read(_fingerprintKey);
    _publicKeyBase64Url = await _store.read(_publicKeyKey);
    _nodeId = await _store.read(_nodeIdKey);
    _remoteEndpoint = _readStoredEndpoint(
      await _store.read(_remoteEndpointKey),
    );
    _syncHttpTransports();
    return isPaired;
  }

  /// Re-reads a stored address, dropping one this build would refuse to store.
  ///
  /// The scheme rule is applied on the way in as well as on the way out: a
  /// pairing written by an earlier build must not grant a public cleartext
  /// address the credential just because it is already on disk.
  static Uri? _readStoredEndpoint(String? raw) {
    final parsed = Uri.tryParse(raw ?? '');
    if (parsed == null || !isCredentialSafeEndpoint(parsed)) return null;
    return parsed;
  }

  /// Negotiates and installs a cryptographically verified WebRTC route.
  ///
  /// The calling UI supplies its authenticated backend token; the Node's local
  /// credential never goes to the control plane. On failure the existing LAN
  /// and HTTPS rungs remain untouched, so a coordination outage cannot turn a
  /// paired Node into a global failure.
  Future<KubusNodeTransportKind?> connectRemote({
    required String signalingBaseUrl,
    required Future<String?> Function() authToken,
    required Future<IceConfiguration> Function() iceConfiguration,
  }) async {
    final resolver = _resolver;
    final nodeId = _nodeId;
    if (resolver == null || nodeId == null || nodeId.isEmpty) return null;
    if (!supportsRemoteIdentityVerification) {
      throw StateError('Re-pair this Node before enabling remote access.');
    }
    final previous = _signaling;
    if (previous != null) await previous.dispose();
    final signaling = NodeSignalingClient(
      baseUrl: signalingBaseUrl,
      authToken: authToken,
    );
    _signaling = signaling;
    try {
      final transport = await NodeRtcConnector(
        signaling: signaling,
        iceConfiguration: iceConfiguration,
        pairedPublicKey: () => pairedPublicKey,
        credential: () => _credential,
      ).connect(nodeId);
      // Only a previous WebRTC rung can be displaced here — kinds match — and
      // this service built it on a peer connection of its own, so it is this
      // service's to close.
      resolver.adopt(transport)?.close();
      return transport.kind;
    } on Object {
      if (identical(_signaling, signaling)) _signaling = null;
      await signaling.dispose();
      rethrow;
    }
  }

  /// Drops sockets and network subscriptions owned by this service.
  Future<void> dispose() async {
    await _signaling?.dispose();
    _signaling = null;
    await _network.dispose();
  }

  Future<void> pair(
    KubusNodePairingPayload payload, {
    String label = 'art.kubus app',
  }) async {
    final candidates = payload.endpoints;
    // Scheme policy is enforced here, at the transport boundary, and not only
    // in the QR parser: a caller can build a [KubusNodePairingPayload] by hand,
    // so the parser is a convenience and this is the boundary. Nothing has
    // been sent at this point, so a refusal costs the attacker nothing and
    // discloses nothing.
    for (final endpoint in candidates) {
      if (!isCredentialSafeEndpoint(endpoint)) {
        throw const FormatException(
          'A kubus Node reached over the public internet must use HTTPS; '
          'cleartext HTTP is accepted only for a private network address.',
        );
      }
      if (_isWeb && endpoint.scheme != 'https') {
        throw StateError('A secure HTTPS local node route is required on web.');
      }
    }
    final nodeId = (payload.nodeId ?? '').trim();
    final fingerprint = (payload.fingerprint ?? '').trim();
    if (nodeId.isEmpty || fingerprint.isEmpty) {
      throw const FormatException('Pairing code is missing Node identity.');
    }
    // The Node's public key must match the fingerprint printed beside the QR.
    // If they disagree, the payload was tampered with in transit and the
    // fingerprint the user just compared means nothing — refuse rather than
    // pair against an identity nobody actually verified.
    final publicKey = (payload.publicKey ?? '').trim();
    if (publicKey.isNotEmpty) {
      final decoded = _decodePublicKey(publicKey);
      if (decoded == null) {
        throw StateError('Node returned a malformed identity key.');
      }
      if (nodeFingerprintFromPublicKey(decoded) != fingerprint.toLowerCase()) {
        throw StateError('Node identity does not match its fingerprint.');
      }
    }

    // A proof recorded for a previous pairing says nothing about this one.
    _provenOrigins.clear();

    Uri? connected;
    String? token;
    Object? lastError;
    for (final endpoint in candidates) {
      try {
        // Identity first, secret second. The pairing secret is single-use but
        // it is still a secret, and an address that cannot show the node id,
        // fingerprint and public key from the QR has no business receiving it.
        await _probeEndpointIdentity(
          endpoint,
          expectedNodeId: nodeId,
          expectedFingerprint: fingerprint,
          expectedPublicKey: publicKey.isEmpty ? null : publicKey,
        );
        // Pairing deliberately bypasses the transport: it runs against the
        // endpoint in the scanned payload, before any credential exists to
        // authenticate a transport with. Its response still goes through the
        // same protocol decoder, so error semantics are identical everywhere.
        final response = await _client
            .post(
              _resolve(endpoint, '/local/v1/pairing/exchange'),
              headers: const {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'sessionId': payload.sessionId,
                'secret': payload.secret,
                'label': label,
              }),
            )
            .timeout(const Duration(seconds: 10));
        final data = _decode(
          KubusNodeResponse(
            statusCode: response.statusCode,
            body: response.body,
            requestPath: response.request?.url.path,
          ),
        );
        final issued = (data['token'] ?? '').toString();
        if (!issued.startsWith('kubus_local_')) {
          throw StateError('Node returned an invalid local credential.');
        }
        connected = endpoint;
        token = issued;
        break;
      } on Object catch (error) {
        lastError = error;
      }
    }
    if (connected == null || token == null) {
      _provenOrigins.clear();
      throw StateError('Unable to reach this paired kubus Node: $lastError');
    }

    _endpoint = connected;
    _credential = token;
    _fingerprint = fingerprint;
    _publicKeyBase64Url = publicKey.isEmpty ? null : publicKey;
    _nodeId = nodeId;
    _remoteEndpoint = _httpsEndpoint(candidates);
    _syncHttpTransports();
    await _store.write(_endpointKey, connected.toString());
    await _store.write(_credentialKey, token);
    await _store.write(_fingerprintKey, fingerprint);
    await _store.write(_nodeIdKey, nodeId);
    if (publicKey.isNotEmpty) {
      await _store.write(_publicKeyKey, publicKey);
    } else {
      // An older payload carries no key. Clear any key from a previous pairing
      // rather than leaving a stale one that would verify the wrong Node.
      await _store.delete(_publicKeyKey);
    }
    final remote = _remoteEndpoint;
    if (remote != null) {
      await _store.write(_remoteEndpointKey, remote.toString());
    } else {
      await _store.delete(_remoteEndpointKey);
    }
  }

  /// The first address in [endpoints] that can work from outside the LAN.
  static Uri? _httpsEndpoint(List<Uri> endpoints) {
    for (final endpoint in endpoints) {
      if (endpoint.scheme == 'https' && endpoint.hasAuthority) return endpoint;
    }
    return null;
  }

  /// Rebuilds the HTTP rungs from the pairing this service currently holds.
  ///
  /// The single place HTTP routes are installed and removed, so there is one
  /// answer to "which Node does this rung talk to": whichever one is paired
  /// right now. Both rungs read [_endpoint] and [_remoteEndpoint] through
  /// method tear-offs rather than capturing a URL, so no closure can outlive a
  /// pairing holding the previous Node's address — the defect that let a
  /// surviving remote rung route Node B's credential to Node A.
  void _syncHttpTransports() {
    final resolver = _resolver;
    if (resolver == null) return;
    if (_endpoint == null) {
      _detachRung(resolver.release(KubusNodeTransportKind.localDirect));
    } else {
      _detachRung(
        resolver.adopt(
          HttpNodeTransport(
            endpoint: _requireEndpoint,
            credential: () => _credential,
            kind: KubusNodeTransportKind.localDirect,
            client: _client,
          ),
        ),
      );
    }
    if (_remoteEndpoint == null) {
      _detachRung(resolver.release(KubusNodeTransportKind.remoteHttps));
    } else {
      _detachRung(
        resolver.adopt(
          NodeTransportFactory.remoteHttps(
            endpoint: _requireRemoteEndpoint,
            credential: () => _credential,
            client: _client,
          ),
        ),
      );
    }
  }

  /// Disposes a rung the ladder no longer holds.
  ///
  /// Both HTTP rungs are built on [_client], which this service also uses for
  /// pairing, identity probes and content fetches. `HttpNodeTransport.close()`
  /// closes the client it was given, so closing one detached HTTP rung would
  /// close every other HTTP route with it. An HTTP rung owns nothing else —
  /// two callbacks and a borrowed client — so dropping the reference disposes
  /// it completely. A WebRTC rung owns a peer connection and a data channel
  /// and leaks unless it is closed.
  void _detachRung(KubusNodeTransport? rung) {
    if (rung == null) return;
    switch (rung.kind) {
      case KubusNodeTransportKind.localDirect:
      case KubusNodeTransportKind.remoteHttps:
        return;
      case KubusNodeTransportKind.webRtcDirect:
      case KubusNodeTransportKind.webRtcRelay:
        rung.close();
    }
  }

  Uri _requireEndpoint() {
    final endpoint = _endpoint;
    if (endpoint == null) throw StateError('No kubus Node is paired.');
    return endpoint;
  }

  Uri _requireRemoteEndpoint() {
    final endpoint = _remoteEndpoint;
    if (endpoint == null) {
      throw StateError('This kubus Node has no remote HTTPS endpoint.');
    }
    return endpoint;
  }

  static Uint8List? _decodePublicKey(String encoded) {
    try {
      final bytes = base64Url.decode(base64Url.normalize(encoded));
      return bytes.length == 32 ? Uint8List.fromList(bytes) : null;
    } on FormatException {
      return null;
    }
  }

  // --- Endpoint identity ----------------------------------------------------
  //
  // A stored address is a hint about where the Node was, never a statement
  // about who is there now. DHCP reassigns a LAN lease, a home router's DNS
  // changes, an operator's ingress is repointed — and the address the app
  // recorded at pairing keeps resolving, to somebody else. Reachability is not
  // identity, so every rung proves who it is before it is trusted with the
  // Node credential or a private capture.

  /// The guard the resolver runs before anything is sent on a rung.
  ///
  /// WebRTC rungs are exempt for a real reason rather than convenience: a
  /// WebRTC rung only exists because the peer signed a challenge with the
  /// paired Ed25519 private key while the connection was being set up. That is
  /// a strictly stronger proof than this one, and it is bound to the very
  /// channel the bytes travel on. Probing an HTTP address would prove nothing
  /// about it.
  Future<void> _proveRungBeforeSend(
    KubusNodeTransport transport,
    KubusNodeRequest request,
  ) async {
    final Uri? endpoint;
    switch (transport.kind) {
      case KubusNodeTransportKind.localDirect:
        endpoint = _endpoint;
      case KubusNodeTransportKind.remoteHttps:
        endpoint = _remoteEndpoint;
      case KubusNodeTransportKind.webRtcDirect:
      case KubusNodeTransportKind.webRtcRelay:
        return;
    }
    if (endpoint == null) {
      throw KubusNodeIdentityException(transport.kind.name);
    }
    await _proveEndpointIdentity(
      endpoint,
      fresh: _carriesPrivatePayload(request),
    );
  }

  /// Whether [request] carries — or returns — data that must never reach the
  /// wrong machine even once.
  ///
  /// Capture routes carry the spatial capture itself. Content routes return
  /// it. Spatial and compute routes carry manifests and the user's backend
  /// authorization. All of them prove identity again immediately before
  /// sending rather than trusting a cached verdict, because "verified four
  /// minutes ago" and "verified now" are different claims and only one of them
  /// is worth a capture.
  static bool _carriesPrivatePayload(KubusNodeRequest request) =>
      request.path.startsWith('/local/v1/captures/') ||
      request.path.startsWith('/local/v1/content/') ||
      request.path.startsWith('/local/v1/spatial/') ||
      request.path.startsWith('/local/v1/compute/');

  /// Proves [endpoint] still belongs to the paired Node.
  ///
  /// ## The caching rule
  ///
  /// A verdict is cached against the endpoint's *origin* — scheme, host and
  /// port — because that is exactly what decides which machine receives the
  /// bytes; a different path on the same origin is the same machine. Four
  /// rules bound how stale a cached verdict can be:
  ///
  ///  * it lives in memory only, so a new process or session starts with
  ///    nothing proved and re-proves on its first request;
  ///  * it expires after [_identityVerificationTtl];
  ///  * a network change clears it outright, because the same address can name
  ///    a different machine on a different network;
  ///  * [fresh] bypasses it entirely, and every private transfer sets it.
  ///
  /// A resolved endpoint that changes host or port is a different origin with
  /// no entry of its own, so it is proved before it is used. Concurrent
  /// callers share one probe rather than opening one each.
  Future<void> _proveEndpointIdentity(
    Uri endpoint, {
    required bool fresh,
  }) {
    final origin = _originOf(endpoint);
    // Joining a probe that is already running is safe even for a fresh check:
    // it started moments ago and has not answered yet.
    final inFlight = _probesInFlight[origin];
    if (inFlight != null) return inFlight;
    if (!fresh) {
      final provenAt = _provenOrigins[origin];
      if (provenAt != null &&
          DateTime.now().toUtc().difference(provenAt) <
              _identityVerificationTtl) {
        return Future<void>.value();
      }
    }
    final nodeId = _nodeId;
    final fingerprint = _fingerprint;
    if ((nodeId ?? '').isEmpty || (fingerprint ?? '').isEmpty) {
      // Nothing to compare against. Refuse rather than treat "we cannot check"
      // as "it checked out".
      return Future<void>.error(
        KubusNodeIdentityException(origin),
        StackTrace.current,
      );
    }
    final probe = _probeEndpointIdentity(
      endpoint,
      expectedNodeId: nodeId!,
      expectedFingerprint: fingerprint!,
      expectedPublicKey: _publicKeyBase64Url,
    );
    _probesInFlight[origin] = probe;
    return probe.whenComplete(() => _probesInFlight.remove(origin));
  }

  /// Requires [endpoint] to *prove* it is the paired Node, and records it.
  ///
  /// The request is unauthenticated. That is the whole point: this is the only
  /// thing this app is willing to send to an address it has not yet proved, so
  /// it must disclose nothing. Attaching the bearer credential here would hand
  /// the Node credential to whoever answered — precisely the disclosure this
  /// check exists to prevent — and inspecting the response of a request that
  /// already carried the credential would be too late to matter.
  ///
  /// ## Why a signature, and not a matching node id or fingerprint
  ///
  /// Reading identity fields back from the endpoint and comparing them proves
  /// nothing. The node id, fingerprint and public key are all printed in the
  /// pairing QR code, so anyone who has seen it — or seen any earlier answer
  /// from any endpoint — can repeat all three. Comparing them catches a DHCP
  /// lease that moved; it does not catch anybody who is trying.
  ///
  /// The only thing that distinguishes the real Node is possession of the
  /// private key whose public half this device recorded at pairing. So this
  /// picks a fresh random challenge and requires a signature over it, verified
  /// against the recorded key — the same proof, built by the same canonical
  /// builder, that the data channel demands after it opens.
  ///
  /// A live relay that forwards the challenge to the real Node and returns its
  /// answer is not defeated by this, and cannot be without binding the proof to
  /// the channel. On an HTTPS rung TLS already authenticates the host; on a
  /// cleartext LAN rung the attacker must already be on the network.
  ///
  /// The node id and fingerprint are still compared, after the signature: the
  /// signature settles *who* answered, and those settle that it is the same
  /// record this device is holding.
  Future<void> _probeEndpointIdentity(
    Uri endpoint, {
    required String expectedNodeId,
    required String expectedFingerprint,
    String? expectedPublicKey,
  }) async {
    final origin = _originOf(endpoint);
    // Without the Node's public key there is nothing to verify a signature
    // against, and this refuses rather than falling back to comparing values
    // anyone could repeat. A pairing recorded before the Node published its
    // key has to be made again: "we cannot check" must never read as "it
    // checked out".
    final pairedKey = _decodePublicKey(expectedPublicKey ?? '');
    if (pairedKey == null) throw KubusNodeIdentityException(origin);

    final challenge = NodeIdentityChallenge.generate(
      sessionId: kHttpIdentitySessionId,
    );
    // A route that will not answer at all is a transport failure, not an
    // identity failure, and is allowed to propagate as one so the ladder can
    // fail over normally.
    final response = await _client
        .post(
          _resolve(endpoint, '/local/v1/identity/proof'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(challenge.toRequestMetadata()),
        )
        .timeout(const Duration(seconds: 10));
    Object? body;
    try {
      body = jsonDecode(response.body.isEmpty ? '{}' : response.body);
    } on FormatException {
      body = null;
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body is! Map<String, dynamic>) {
      throw KubusNodeIdentityException(origin);
    }
    final info = body['success'] == true && body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : body;
    try {
      await verifyNodeIdentityProof(
        challenge: challenge,
        response: info,
        pairedPublicKey: pairedKey,
      );
    } on NodeIdentityException {
      // Deliberately collapsed: the ladder only needs to know this rung is not
      // the paired Node. Why it failed is a diagnostic, not a routing input.
      throw KubusNodeIdentityException(origin);
    }
    if (!_identityMatches(
      info,
      expectedNodeId: expectedNodeId,
      expectedFingerprint: expectedFingerprint,
      expectedPublicKey: expectedPublicKey,
    )) {
      throw KubusNodeIdentityException(origin);
    }
    _provenOrigins[origin] = DateTime.now().toUtc();
  }

  /// Whether an `/local/v1/info` answer is the paired Node's.
  ///
  /// The node id and the fingerprint are both compared because they fail
  /// differently: an id is what the control plane routes on, a fingerprint is
  /// what a person compared on screen at pairing. When this device also
  /// recorded the Node's Ed25519 public key, the endpoint must present the
  /// same key — a v3 pairing means the Node publishes it, so an endpoint that
  /// cannot show it is not that Node.
  static bool _identityMatches(
    Map<String, dynamic> info, {
    required String expectedNodeId,
    required String expectedFingerprint,
    String? expectedPublicKey,
  }) {
    if ((info['nodeId'] ?? '').toString().trim() != expectedNodeId) {
      return false;
    }
    if ((info['fingerprint'] ?? '').toString().trim().toLowerCase() !=
        expectedFingerprint.toLowerCase()) {
      return false;
    }
    if ((expectedPublicKey ?? '').isEmpty) return true;
    final expected = _decodePublicKey(expectedPublicKey!);
    final presented = _decodePublicKey((info['publicKey'] ?? '').toString());
    if (expected == null || presented == null) return false;
    return listEquals(expected, presented);
  }

  /// Scheme, host and port — what actually decides which machine is reached.
  static String _originOf(Uri endpoint) =>
      '${endpoint.scheme}://${endpoint.host}:${endpoint.port}';

  /// An HTTP endpoint that has just proved it is the paired Node.
  ///
  /// Used by the streaming download, which is not yet a transport operation.
  /// Candidates are proved one at a time and never on each other's authority:
  /// a failure on the LAN address does not authorize the HTTPS ingress.
  Future<Uri> _provenHttpEndpoint() async {
    final seen = <String>{};
    Object? lastError;
    StackTrace? lastStack;
    for (final endpoint
        in <Uri?>[_endpoint, _remoteEndpoint].whereType<Uri>()) {
      if (!seen.add(_originOf(endpoint))) continue;
      try {
        await _proveEndpointIdentity(endpoint, fresh: true);
        return endpoint;
      } on Object catch (error, stack) {
        lastError = error;
        lastStack = stack;
      }
    }
    if (lastError != null) {
      Error.throwWithStackTrace(lastError, lastStack ?? StackTrace.current);
    }
    throw const KubusNodeIdentityException();
  }

  // --- Endpoint address policy ----------------------------------------------

  /// Whether [endpoint] may be trusted with the Node credential.
  ///
  /// HTTPS is allowed on ordinary trust rules — the transport authenticates
  /// the host and encrypts the credential. Cleartext HTTP is allowed only for
  /// an address that cannot exist outside a private network, because a pairing
  /// secret or a bearer token sent in the clear across the public internet is
  /// readable by every hop in between.
  static bool isCredentialSafeEndpoint(Uri endpoint) {
    if (!endpoint.hasAuthority || endpoint.host.isEmpty) return false;
    if (endpoint.scheme == 'https') return true;
    if (endpoint.scheme != 'http') return false;
    return isPrivateNetworkHost(endpoint);
  }

  /// Whether [endpoint] names a host that can only exist on a private network.
  ///
  /// Answers the question the scheme rule needs: could these bytes cross the
  /// public internet? An IP literal is decided by its range; a name is decided
  /// by whether it belongs to a namespace that cannot be delegated publicly.
  ///
  /// Names are matched on whole labels, never as substrings, so
  /// `192.168.1.1.evil.com` — a perfectly ordinary public name that happens to
  /// begin with a private address — is rejected, as is `notlocal`.
  static bool isPrivateNetworkHost(Uri endpoint) {
    var host = endpoint.host.toLowerCase();
    if (host.isEmpty) return false;
    // A fully qualified name may carry a trailing root label.
    if (host.endsWith('.')) host = host.substring(0, host.length - 1);
    if (host.isEmpty) return false;

    final address = InternetAddress.tryParse(host);
    if (address != null) return _isPrivateAddress(address);

    // Not an IP literal, so it is a name.
    if (host == 'localhost') return true;
    return host.endsWith('.localhost') ||
        // mDNS, and the namespaces reserved for names that never leave a site.
        host.endsWith('.local') ||
        host.endsWith('.home.arpa') ||
        host.endsWith('.internal');
  }

  static bool _isPrivateAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return _isPrivateIPv4(bytes);
    }
    if (bytes.length != 16) return false;
    // ::1 — loopback.
    if (_allZero(bytes, 0, 15) && bytes[15] == 1) return true;
    // fe80::/10 — link-local.
    if (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) return true;
    // fc00::/7 — unique local addresses.
    if ((bytes[0] & 0xfe) == 0xfc) return true;
    // ::ffff:a.b.c.d — an IPv4 address wearing an IPv6 shape. Judge it by the
    // address it actually carries, or a public host reached as
    // `[::ffff:203.0.113.9]` would slip past every IPv4 rule above.
    if (_allZero(bytes, 0, 10) && bytes[10] == 0xff && bytes[11] == 0xff) {
      return _isPrivateIPv4(bytes.sublist(12));
    }
    // ::a.b.c.d — the deprecated IPv4-compatible form, judged the same way.
    // `::` and `::1` are already handled above.
    if (_allZero(bytes, 0, 12)) return _isPrivateIPv4(bytes.sublist(12));
    return false;
  }

  static bool _isPrivateIPv4(List<int> b) {
    if (b.length != 4) return false;
    // 10.0.0.0/8
    if (b[0] == 10) return true;
    // 127.0.0.0/8 — loopback.
    if (b[0] == 127) return true;
    // 169.254.0.0/16 — link-local.
    if (b[0] == 169 && b[1] == 254) return true;
    // 172.16.0.0/12
    if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true;
    // 192.168.0.0/16
    if (b[0] == 192 && b[1] == 168) return true;
    // 100.64.0.0/10 — carrier-grade NAT. Not the user's own network, but it is
    // never routed across the public internet either.
    if (b[0] == 100 && b[1] >= 64 && b[1] <= 127) return true;
    return false;
  }

  static bool _allZero(List<int> bytes, int start, int end) {
    for (var i = start; i < end; i++) {
      if (bytes[i] != 0) return false;
    }
    return true;
  }

  /// Forgets the paired Node completely.
  ///
  /// Every rung goes, not just the WebRTC ones: a surviving remote HTTPS rung
  /// kept the previous Node's URL alive, and pairing a second Node then let
  /// that rung carry the *new* Node's credential, requests and capture uploads
  /// to the *old* Node's address whenever the LAN route was unavailable. The
  /// proof cache goes with them, so the next pairing proves every address from
  /// scratch instead of inheriting a verdict about a Node that is no longer
  /// paired.
  Future<void> unpair() async {
    await _signaling?.dispose();
    _signaling = null;
    final resolver = _resolver;
    if (resolver != null) {
      for (final kind in KubusNodeTransportKind.values) {
        _detachRung(resolver.release(kind));
      }
    }
    _endpoint = null;
    _credential = null;
    _fingerprint = null;
    _publicKeyBase64Url = null;
    _nodeId = null;
    _remoteEndpoint = null;
    _provenOrigins.clear();
    _probesInFlight.clear();
    await Future.wait([
      _store.delete(_endpointKey),
      _store.delete(_credentialKey),
      _store.delete(_fingerprintKey),
      _store.delete(_publicKeyKey),
      _store.delete(_nodeIdKey),
      _store.delete(_remoteEndpointKey),
    ]);
  }

  Future<KubusNodeSnapshot> fetchSnapshot() async {
    final responses = await Future.wait([
      _get('/local/v1/info'),
      _get('/local/v1/status'),
      _get('/local/v1/capabilities'),
      _get('/local/v1/storage'),
      _get('/local/v1/network'),
    ]);
    final capabilityData = responses[2];
    return KubusNodeSnapshot(
      info: responses[0],
      status: responses[1],
      capabilities:
          (capabilityData['capabilities'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList(growable: false),
      worker: capabilityData['worker'] is Map<String, dynamic>
          ? capabilityData['worker'] as Map<String, dynamic>
          : const {},
      storage: responses[3],
      network: responses[4],
    );
  }

  Future<Map<String, dynamic>> fetchStorage() => _get('/local/v1/storage');
  Future<Map<String, dynamic>> fetchNetwork() => _get('/local/v1/network');

  Future<Map<String, dynamic>> getCapture(String id) =>
      _get('/local/v1/captures/${Uri.encodeComponent(id)}');

  /// Deletes a capture.
  ///
  /// Keyed on the capture itself: deleting `c1` twice is deleting `c1`, so a
  /// failover that replays this converges instead of doing something new.
  Future<void> deleteCapture(String id) async {
    await _request(
      'DELETE',
      '/local/v1/captures/${Uri.encodeComponent(id)}',
      idempotencyKey:
          NodeIdempotencyKey.forOperation('capture.delete', scope: id),
    );
  }

  // --- Streaming capture transfer -------------------------------------------
  //
  // Spatial captures are streamed into a node-side draft one file at a time.
  // The older whole-package JSON endpoint required base64-encoding the entire
  // capture into a single document, which inflated it by a third on the wire
  // and forced both sides to hold every frame at once — unusable for a
  // continuous mobile capture.

  /// Opens a draft the capture's files are streamed into.
  ///
  /// Throws [KubusNodeUnsupportedException] when the paired node predates the
  /// streaming API, so the caller can ask the user to update it rather than
  /// surfacing a bare 404.
  ///
  /// [localCaptureId] is the capture's stable client-side identity and is what
  /// the draft is keyed on. It must be the same value across every retry of
  /// the same capture — including after an app restart — or the Node cannot
  /// tell a resumed upload from a second capture of the same scene.
  ///
  /// It is required, and cannot be derived from [metadata]. A digest of the
  /// metadata is not an identity: two genuinely distinct captures of the same
  /// scene, taken with the same device against the same artwork, produce byte
  /// identical metadata and would collide onto one idempotency key — the Node
  /// would answer the second with the first capture's draft and the second
  /// capture would be silently discarded. Only the caller knows which capture
  /// this is, so only the caller can name it.
  Future<KubusCaptureDraft> beginCaptureDraft(
    Map<String, dynamic> metadata, {
    required String localCaptureId,
  }) async =>
      KubusCaptureDraft.fromJson(
        await _post(
          '/local/v1/captures/drafts',
          metadata,
          idempotencyKey: NodeIdempotencyKey.forOperation(
            'capture.draft',
            scope: localCaptureId,
          ),
        ),
      );

  /// Streams one file into a draft straight off disk.
  ///
  /// The body is a [Stream], so a frame is never materialized in Dart memory
  /// as a whole capture — only the HTTP client's own buffer is in play.
  /// Re-uploading a path overwrites it, so a retry converges rather than
  /// duplicating.
  Future<KubusCaptureDraft> uploadCaptureDraftFile({
    required String draftId,
    required String path,
    required File file,
    required String mimeType,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (!isPaired) throw StateError('No kubus Node is paired.');
    final response = await _transport.streamUpload(
      KubusNodeRequest(
        method: 'PUT',
        path: '/local/v1/captures/drafts/${Uri.encodeComponent(draftId)}/files',
        query: <String, String>{'path': path},
        timeout: timeout,
        // A PUT names the exact slot it fills, so replaying it rewrites the
        // same file rather than appending a second one. That is what makes an
        // interrupted large upload safe to resume on a different rung.
        idempotencyKey: NodeIdempotencyKey.forOperation(
          'capture.draft-file',
          scope: '$draftId:$path',
        ),
      ),
      file: file,
      contentType: mimeType,
    );
    return KubusCaptureDraft.fromJson(_decode(response));
  }

  /// Draft progress, so an interrupted transfer resumes instead of restarting.
  Future<KubusCaptureDraft> getCaptureDraft(String draftId) async =>
      KubusCaptureDraft.fromJson(
        await _get('/local/v1/captures/drafts/${Uri.encodeComponent(draftId)}'),
      );

  /// Finalizes a draft into a durable capture record.
  ///
  /// The highest-stakes mutation in the flow: a commit whose response is lost
  /// is indistinguishable from one that never ran, and an unkeyed retry would
  /// produce a second durable capture of the same scene. Keyed on the draft,
  /// which is stable for the life of the transfer, so the Node returns the
  /// already-committed record instead of committing again.
  Future<Map<String, dynamic>> commitCaptureDraft(String draftId) => _post(
        '/local/v1/captures/drafts/${Uri.encodeComponent(draftId)}/commit',
        const {},
        timeout: const Duration(minutes: 5),
        idempotencyKey:
            NodeIdempotencyKey.forOperation('capture.commit', scope: draftId),
      );

  /// Abandons a draft and everything already uploaded into it.
  Future<void> discardCaptureDraft(String draftId) async {
    await _request(
      'DELETE',
      '/local/v1/captures/drafts/${Uri.encodeComponent(draftId)}',
      idempotencyKey: NodeIdempotencyKey.forOperation(
        'capture.draft-discard',
        scope: draftId,
      ),
    );
  }

  /// Creates a processing job.
  ///
  /// [requestId] is the caller's stable identity for *this* request and must
  /// be held across retries — minting a fresh one per attempt would defeat
  /// deduplication and start the same reconstruction twice. Callers that
  /// already have a durable handle (a capture id) should pass it.
  Future<KubusNodeJob> createJob({
    required String type,
    required Map<String, dynamic> input,
    required String requestId,
  }) async =>
      KubusNodeJob.fromJson(
        await _post(
          '/local/v1/jobs',
          {'type': type, 'input': input},
          idempotencyKey:
              NodeIdempotencyKey.forOperation('job.create', scope: requestId),
        ),
      );
  Future<List<KubusNodeJob>> listJobs() async =>
      ((await _get('/local/v1/jobs'))['jobs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(KubusNodeJob.fromJson)
          .toList(growable: false);
  Future<KubusNodeJob> getJob(String id) async => KubusNodeJob.fromJson(
        await _get('/local/v1/jobs/${Uri.encodeComponent(id)}'),
      );
  Future<KubusNodeJob> cancelJob(String id) async => KubusNodeJob.fromJson(
        await _post(
          '/local/v1/jobs/${Uri.encodeComponent(id)}/cancel',
          const {},
          idempotencyKey:
              NodeIdempotencyKey.forOperation('job.cancel', scope: id),
        ),
      );
  Future<Map<String, dynamic>> getSpatial(String id) =>
      _get('/local/v1/spatial/${Uri.encodeComponent(id)}');

  /// Streams a private Node content object straight to disk.
  ///
  /// Used for processed variants, which are far too large to sit in the Dart
  /// heap: `bodyBytes` would retain the whole splat until it reached the phone
  /// library. The bytes go from the socket to the file and are never
  /// accumulated.
  ///
  /// This route still bypasses the transport ladder — it needs a raw streamed
  /// response, which the ladder does not model yet — so it proves the
  /// endpoint's identity itself via [_provenHttpEndpoint] rather than relying
  /// on the resolver's guard. The proof happens *before* the bearer credential
  /// is attached: a private capture and the Node credential are exactly what
  /// must not reach a host that turned out to be someone else.
  Future<void> downloadContentToFile(String cid, File destination) async {
    if (!isPaired) throw StateError('No kubus Node is paired.');
    final endpoint = await _provenHttpEndpoint();
    final path = '/local/v1/content/${Uri.encodeComponent(cid)}';
    final request = http.Request('GET', _resolve(endpoint, path))
      ..headers['Authorization'] = 'Bearer $_credential';
    final response =
        await _client.send(request).timeout(const Duration(minutes: 5));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Lets the shared decoder raise the Node's own error, rather than
      // inventing a second error vocabulary for this one route. The body is
      // only drained on the failure path, where it is small.
      final failure = await http.Response.fromStream(response);
      _decode(
        KubusNodeResponse(
          statusCode: failure.statusCode,
          body: failure.body,
          requestPath: path,
        ),
      );
    }
    await destination.parent.create(recursive: true);
    final sink = destination.openWrite();
    try {
      await sink.addStream(response.stream);
    } finally {
      await sink.close();
    }
  }

  Future<List<KubusComputeCandidate>> findComputeCandidates({
    required String backendAuthorization,
    required int inputBytes,
    int minimumVramBytes = 0,
    String type = 'spatial.reconstruct',
  }) async {
    // A POST only because the query carries a bearer token in the body. It
    // creates nothing, so keying it on the query lets a failover retry it.
    final data = await _post(
      '/local/v1/compute/candidates',
      {
        'backendAuthorization': backendAuthorization,
        'type': type,
        'inputBytes': inputBytes,
        'minimumVramBytes': minimumVramBytes,
      },
      idempotencyKey: NodeIdempotencyKey.forOperation(
        'compute.candidates',
        scope: '$type:$inputBytes:$minimumVramBytes',
      ),
    );
    return (data['nodes'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(KubusComputeCandidate.fromJson)
        .toList(growable: false);
  }

  /// Requests reconstruction on someone else's GPU.
  ///
  /// Keyed on the capture and the chosen provider: a lost response must not
  /// dispatch the same private capture to a second paid provider.
  Future<KubusRemoteComputeJob> createRemoteComputeJob({
    required String backendAuthorization,
    required String captureId,
    required KubusComputeCandidate provider,
    required Map<String, dynamic> requirements,
  }) async =>
      KubusRemoteComputeJob.fromJson(
        await _post(
          '/local/v1/compute/jobs',
          {
            'backendAuthorization': backendAuthorization,
            'captureId': captureId,
            'provider': provider.toJson(),
            'requirements': requirements,
            'type': 'spatial.reconstruct',
          },
          timeout: const Duration(minutes: 10),
          idempotencyKey: NodeIdempotencyKey.forOperation(
            'compute.job',
            scope: '$captureId:${provider.nodeId}',
          ),
        ),
      );

  Future<KubusRemoteComputeJob> getRemoteComputeJob(
    String id,
    String backendAuthorization,
  ) async =>
      KubusRemoteComputeJob.fromJson(
        await _post(
          '/local/v1/compute/jobs/${Uri.encodeComponent(id)}/status',
          {'backendAuthorization': backendAuthorization},
          idempotencyKey: NodeIdempotencyKey.forOperation(
            'compute.job-status',
            scope: id,
          ),
        ),
      );

  Future<Map<String, dynamic>> retrieveRemoteComputeResult(
    String id,
    String backendAuthorization,
  ) =>
      _post(
        '/local/v1/compute/jobs/${Uri.encodeComponent(id)}/retrieve',
        {'backendAuthorization': backendAuthorization},
        timeout: const Duration(minutes: 10),
        idempotencyKey: NodeIdempotencyKey.forOperation(
          'compute.job-retrieve',
          scope: id,
        ),
      );

  Future<KubusRemoteComputeJob> acknowledgeRemoteComputeResult({
    required String id,
    required String backendAuthorization,
    required bool accepted,
    String? reason,
  }) async =>
      KubusRemoteComputeJob.fromJson(
        await _post(
          '/local/v1/compute/jobs/${Uri.encodeComponent(id)}/acknowledge',
          {
            'backendAuthorization': backendAuthorization,
            'accepted': accepted,
            if (reason != null) 'reason': reason,
          },
          // The verdict is part of the key: re-sending "accepted" is a replay,
          // but a later rejection is a different decision and must get through.
          idempotencyKey: NodeIdempotencyKey.forOperation(
            'compute.job-acknowledge',
            scope: '$id:${accepted ? 'accept' : 'reject'}',
          ),
        ),
      );

  Future<KubusRemoteComputeJob> cancelRemoteComputeJob(
    String id,
    String backendAuthorization,
  ) async =>
      KubusRemoteComputeJob.fromJson(
        await _post(
          '/local/v1/compute/jobs/${Uri.encodeComponent(id)}/cancel',
          {'backendAuthorization': backendAuthorization},
          idempotencyKey: NodeIdempotencyKey.forOperation(
            'compute.job-cancel',
            scope: id,
          ),
        ),
      );

  Future<Map<String, dynamic>> getComputeSettings() =>
      _get('/local/v1/compute/settings');

  /// Replaces the Node's remote-compute settings.
  ///
  /// Keyed on a digest of the settings themselves: replaying the same write is
  /// a no-op the Node can recognise, while a genuinely different update is a
  /// different key and is never mistaken for a replay.
  Future<Map<String, dynamic>> updateComputeSettings(
    Map<String, dynamic> settings,
  ) async =>
      _decode(
        await _request(
          'PUT',
          '/local/v1/compute/settings',
          body: settings,
          idempotencyKey: NodeIdempotencyKey.forOperation(
            'compute.settings',
            scope: sha256
                .convert(utf8.encode(jsonEncode(settings)))
                .toString()
                .substring(0, 32),
          ),
        ),
      );

  Future<List<KubusContentCandidate>> resolveContentCandidates(
    String raw, {
    String? localPath,
  }) async {
    // A variant already downloaded to this device is offered before any
    // network route: it is the same object, costs nothing to read, and works
    // with no connectivity at all. A path that no longer exists is skipped
    // rather than returned, so a cache the OS reclaimed falls through to the
    // network instead of failing the load.
    final local = localPath == null ? null : File(localPath);
    final localCandidates = <KubusContentCandidate>[];
    if (local != null && await local.exists()) {
      localCandidates.add(
        KubusContentCandidate(uri: local.uri, source: 'spatial_library'),
      );
    }
    final cid = _extractCid(raw);
    if (cid == null) {
      return <KubusContentCandidate>[
        ...localCandidates,
        ...StorageConfig.resolveAllUrls(raw).map(
          (url) => KubusContentCandidate(
            uri: Uri.parse(url),
            source: 'configured',
          ),
        ),
      ];
    }
    final candidates = <KubusContentCandidate>[...localCandidates];
    if (!_isWeb && isPaired) {
      candidates.add(
        KubusContentCandidate(
          uri: _resolve(
            _endpoint!,
            '/local/v1/content/${Uri.encodeComponent(cid)}',
          ),
          source: 'kubus_node',
          headers: {'Authorization': 'Bearer $_credential'},
        ),
      );
    }
    candidates.addAll(
      StorageConfig.resolveAllUrls('ipfs://$cid').map(
        (url) =>
            KubusContentCandidate(uri: Uri.parse(url), source: 'ipfs_gateway'),
      ),
    );
    final backend = StorageConfig.httpBackend;
    if (backend.isNotEmpty) {
      candidates.add(
        KubusContentCandidate(
          uri: Uri.parse('$backend/uploads/${Uri.encodeComponent(cid)}'),
          source: 'legacy_static_upload',
        ),
      );
    }
    return candidates;
  }

  Future<Uint8List> fetchContent(String raw) async {
    Object? lastError;
    for (final candidate in await resolveContentCandidates(raw)) {
      try {
        final response = await _client
            .get(candidate.uri, headers: candidate.headers)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response.bodyBytes;
        }
        lastError = StateError(
          '${candidate.source} returned ${response.statusCode}',
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('Content is unavailable: $lastError');
  }

  Future<Map<String, dynamic>> _get(String path) async =>
      _decode(await _request('GET', path));
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
    NodeIdempotencyKey? idempotencyKey,
  }) async =>
      _decode(await _request(
        'POST',
        path,
        body: body,
        timeout: timeout,
        idempotencyKey: idempotencyKey,
      ));
  Future<KubusNodeResponse> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 20),
    NodeIdempotencyKey? idempotencyKey,
  }) async {
    if (!isPaired) throw StateError('No kubus Node is paired.');
    return _transport.request(
      KubusNodeRequest(
        method: method,
        path: path,
        jsonBody: body,
        timeout: timeout,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  static Map<String, dynamic> _decode(KubusNodeResponse response) {
    final Object? body;
    try {
      body = jsonDecode(response.body.isEmpty ? '{}' : response.body);
    } on FormatException {
      throw KubusNodeRequestException(
        statusCode: response.statusCode,
        code: 'node_response_invalid',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = body is Map
          ? (body['error'] ?? body['code'] ?? 'node_request_failed').toString()
          : 'node_request_failed';
      // A node that has never heard of a route is a version mismatch, not a
      // transient failure: the client asks the user to update it.
      if (response.statusCode == 404 &&
          const {
            'local_route_not_found',
            'not_found',
            'route_not_found',
            'node_request_failed',
          }.contains(code)) {
        throw KubusNodeUnsupportedException(
          response.requestPath ?? 'unknown',
        );
      }
      throw KubusNodeRequestException(
        statusCode: response.statusCode,
        code: code,
      );
    }
    if (body is Map<String, dynamic> &&
        body['success'] == true &&
        body['data'] is Map<String, dynamic>) {
      return body['data'] as Map<String, dynamic>;
    }
    if (body is Map<String, dynamic>) return body;
    throw const FormatException('Invalid kubus Node response');
  }

  static Uri _resolve(Uri base, String path) =>
      base.replace(path: path, query: null, fragment: null);
  static String? _extractCid(String raw) {
    var value = raw.trim();
    if (StorageConfig.isLikelyCid(value)) return value;
    if (value.startsWith('ipfs://')) value = value.substring(7);
    if (value.startsWith('/ipfs/')) value = value.substring(6);
    if (value.startsWith('ipfs/')) value = value.substring(5);
    final cid = value.split('/').first;
    return StorageConfig.isLikelyCid(cid) ? cid : null;
  }
}
