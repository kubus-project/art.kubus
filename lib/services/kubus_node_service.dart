import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/kubus_node_models.dart';
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
            endpoint: () => _endpoint!,
            credential: () => _credential,
            remoteEndpoint: () => _remoteEndpoint,
            client: _client,
            contextForOperation: () => _network.read(),
          )
        : null;
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
  static const _nodeIdKey = 'kubus_node_id_v1';
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

  Future<bool> initialize() async {
    // Routing decisions must see a real network class before the first
    // request. A route that failed on the old network is reset immediately on
    // a switch rather than needlessly remaining in cooldown at the new one.
    unawaited(
      _network.start(
        onChanged: (_) => _resolver?.onNetworkChanged(),
      ),
    );
    final rawEndpoint = await _store.read(_endpointKey);
    _endpoint = Uri.tryParse(rawEndpoint ?? '');
    _credential = await _store.read(_credentialKey);
    _fingerprint = await _store.read(_fingerprintKey);
    _publicKeyBase64Url = await _store.read(_publicKeyKey);
    _nodeId = await _store.read(_nodeIdKey);
    _remoteEndpoint = Uri.tryParse(await _store.read(_remoteEndpointKey) ?? '');
    _adoptRemoteHttpsRoute();
    return isPaired;
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
      resolver.adopt(transport);
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
    if (_isWeb && payload.endpoint.scheme != 'https') {
      throw StateError('A secure HTTPS local node route is required on web.');
    }
    final response = await _client
        .post(
          _resolve(payload.endpoint, '/local/v1/pairing/exchange'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'sessionId': payload.sessionId,
            'secret': payload.secret,
            'label': label,
          }),
        )
        .timeout(const Duration(seconds: 10));
    // Pairing deliberately bypasses the transport: it runs against the
    // endpoint in the scanned payload, before any credential exists to
    // authenticate a transport with. Its response still goes through the same
    // protocol decoder, so error semantics are identical everywhere.
    final data = _decode(
      KubusNodeResponse(
        statusCode: response.statusCode,
        body: response.body,
        requestPath: response.request?.url.path,
      ),
    );
    final token = (data['token'] ?? '').toString();
    if (!token.startsWith('kubus_local_')) {
      throw StateError('Node returned an invalid local credential.');
    }
    // The Node's public key must match the fingerprint printed beside the QR.
    // If they disagree, the payload was tampered with in transit and the
    // fingerprint the user just compared means nothing — refuse rather than
    // pair against an identity nobody actually verified.
    final publicKey = payload.publicKey;
    if (publicKey != null && publicKey.isNotEmpty) {
      final decoded = _decodePublicKey(publicKey);
      if (decoded == null) {
        throw StateError('Node returned a malformed identity key.');
      }
      final derived = nodeFingerprintFromPublicKey(decoded);
      final claimed = (payload.fingerprint ?? '').toLowerCase();
      if (claimed.isNotEmpty && claimed != derived) {
        throw StateError('Node identity does not match its fingerprint.');
      }
    }

    _endpoint = payload.endpoint;
    _credential = token;
    _fingerprint = payload.fingerprint;
    _publicKeyBase64Url = publicKey;
    _nodeId = payload.nodeId;
    _remoteEndpoint = _httpsAlternate(payload.alternateEndpoints);
    _adoptRemoteHttpsRoute();
    await _store.write(_endpointKey, payload.endpoint.toString());
    await _store.write(_credentialKey, token);
    if ((payload.fingerprint ?? '').isNotEmpty) {
      await _store.write(_fingerprintKey, payload.fingerprint!);
    }
    if ((publicKey ?? '').isNotEmpty) {
      await _store.write(_publicKeyKey, publicKey!);
    } else {
      // An older payload carries no key. Clear any key from a previous pairing
      // rather than leaving a stale one that would verify the wrong Node.
      await _store.delete(_publicKeyKey);
    }
    if ((payload.nodeId ?? '').isNotEmpty) {
      await _store.write(_nodeIdKey, payload.nodeId!);
    } else {
      await _store.delete(_nodeIdKey);
    }
    if (_remoteEndpoint != null) {
      await _store.write(_remoteEndpointKey, _remoteEndpoint.toString());
    } else {
      await _store.delete(_remoteEndpointKey);
    }
  }

  static Uri? _httpsAlternate(List<Uri> endpoints) {
    for (final endpoint in endpoints) {
      if (endpoint.scheme == 'https' && endpoint.hasAuthority) return endpoint;
    }
    return null;
  }

  void _adoptRemoteHttpsRoute() {
    final endpoint = _remoteEndpoint;
    final resolver = _resolver;
    if (endpoint == null || resolver == null) return;
    resolver.adopt(
      NodeTransportFactory.remoteHttps(
        endpoint: () => _remoteEndpoint ?? endpoint,
        credential: () => _credential,
        client: _client,
      ),
    );
  }

  static Uint8List? _decodePublicKey(String encoded) {
    try {
      final bytes = base64Url.decode(base64Url.normalize(encoded));
      return bytes.length == 32 ? Uint8List.fromList(bytes) : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> unpair() async {
    await _signaling?.dispose();
    _signaling = null;
    _resolver?.release(KubusNodeTransportKind.webRtcDirect);
    _resolver?.release(KubusNodeTransportKind.webRtcRelay);
    _endpoint = null;
    _credential = null;
    _fingerprint = null;
    _publicKeyBase64Url = null;
    _nodeId = null;
    _remoteEndpoint = null;
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
  /// Opens a draft the capture's files are streamed into.
  ///
  /// [localCaptureId] is the capture's stable client-side identity and is what
  /// the draft is keyed on. It must be the same value across every retry of
  /// the same capture — including after an app restart — or the Node cannot
  /// tell a resumed upload from a second capture of the same scene.
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
    String raw,
  ) async {
    final cid = _extractCid(raw);
    if (cid == null) {
      return StorageConfig.resolveAllUrls(raw)
          .map(
            (url) => KubusContentCandidate(
              uri: Uri.parse(url),
              source: 'configured',
            ),
          )
          .toList(growable: false);
    }
    final candidates = <KubusContentCandidate>[];
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
