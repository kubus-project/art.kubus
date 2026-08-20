import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/kubus_node_models.dart';
import 'node/http_node_transport.dart';
import 'node/kubus_node_transport.dart';
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

/// An endpoint answered, but it is not the Node the user paired. Treat this
/// as a security failure: never fail over private capture traffic to it.
class KubusNodeIdentityException implements Exception {
  const KubusNodeIdentityException();

  @override
  String toString() => 'KubusNodeIdentityException';
}

/// A PUT whose body is read from disk as it is sent.
///
/// Keeps a capture file out of Dart memory: the bytes flow from the file
/// straight into the socket.
class _StreamedFileRequest extends http.BaseRequest {
  _StreamedFileRequest(super.method, super.url, this._file, this._length);

  final File _file;
  final int _length;

  @override
  int? get contentLength => _length;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_file.openRead());
  }
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
    _transport = transport ?? HttpNodeTransport(
      endpoint: () => _endpoint!,
      credential: () => _credential,
      kind: KubusNodeTransportKind.localDirect,
      client: _client,
    );
  }
  static const _endpointKey = 'kubus_node_endpoint_v1';
  static const _endpointsKey = 'kubus_node_endpoints_v2';
  static const _credentialKey = 'kubus_node_credential_v1';
  static const _fingerprintKey = 'kubus_node_fingerprint_v1';
  static const _nodeIdKey = 'kubus_node_id_v2';
  final http.Client _client;
  final KubusNodeCredentialStore _store;
  final bool _isWeb;
  late final KubusNodeTransport _transport;
  Uri? _endpoint;
  List<Uri> _endpoints = const [];
  String? _credential;
  String? _fingerprint;
  String? _nodeId;
  static const Duration _identityVerificationTtl = Duration(seconds: 30);
  final Map<String, DateTime> _verifiedEndpoints = <String, DateTime>{};

  Uri? get endpoint => _endpoint;
  List<Uri> get endpoints => List.unmodifiable(_endpoints);
  String? get fingerprint => _fingerprint;
  String? get nodeId => _nodeId;
  bool get isPaired =>
      _endpoint != null && (_credential ?? '').startsWith('kubus_local_');

  Future<bool> initialize() async {
    final rawEndpoint = await _store.read(_endpointKey);
    _endpoint = Uri.tryParse(rawEndpoint ?? '');
    if (_endpoint != null && !_isAllowedStoredEndpoint(_endpoint!)) {
      _endpoint = null;
    }
    final rawEndpoints = await _store.read(_endpointsKey);
    if (rawEndpoints != null) {
      try {
        final decoded = jsonDecode(rawEndpoints);
        if (decoded is List) {
          _endpoints = decoded
              .map((value) => Uri.tryParse(value.toString()))
              .whereType<Uri>()
              .where(_isAllowedStoredEndpoint)
              .toList(growable: false);
        }
      } on FormatException {
        _endpoints = const [];
      }
    }
    if (_endpoints.isEmpty && _endpoint != null) {
      _endpoints = [_endpoint!];
    }
    if (_endpoint == null && _endpoints.isNotEmpty) {
      _endpoint = _endpoints.first;
    }
    _credential = await _store.read(_credentialKey);
    _fingerprint = await _store.read(_fingerprintKey);
    _nodeId = await _store.read(_nodeIdKey);
    return isPaired;
  }

  Future<void> pair(
    KubusNodePairingPayload payload, {
    String label = 'art.kubus app',
  }) async {
    if (payload.endpoints
        .any((endpoint) => !_isAllowedStoredEndpoint(endpoint))) {
      throw const FormatException(
        'Remote Node endpoints require HTTPS; HTTP is private-LAN only.',
      );
    }
    if (_isWeb &&
        payload.endpoints.any((endpoint) => endpoint.scheme != 'https')) {
      throw StateError('A secure HTTPS local node route is required on web.');
    }
    if ((payload.nodeId ?? '').isEmpty || (payload.fingerprint ?? '').isEmpty) {
      throw const FormatException('Pairing code is missing Node identity.');
    }
    Map<String, dynamic>? data;
    Uri? connectedEndpoint;
    Object? lastError;
    for (final endpoint in payload.endpoints) {
      try {
        data = _decode(await _client
            .post(
              _resolve(endpoint, '/local/v1/pairing/exchange'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({
                'sessionId': payload.sessionId,
                'secret': payload.secret,
                'label': label
              }),
            )
            .timeout(const Duration(seconds: 10)));
        final token = (data['token'] ?? '').toString();
        if (!token.startsWith('kubus_local_')) {
          throw StateError('Node returned an invalid local credential.');
        }
        await _verifyEndpoint(
          endpoint,
          credential: token,
          expectedNodeId: payload.nodeId!,
          expectedFingerprint: payload.fingerprint!,
        );
        connectedEndpoint = endpoint;
        break;
      } catch (error) {
        lastError = error;
      }
    }
    if (data == null || connectedEndpoint == null) {
      throw StateError('Unable to reach this paired kubus Node: $lastError');
    }
    final token = (data['token'] ?? '').toString();
    _endpoint = connectedEndpoint;
    _endpoints = payload.endpoints;
    _credential = token;
    _fingerprint = payload.fingerprint;
    _nodeId = payload.nodeId;
    _verifiedEndpoints[connectedEndpoint.toString()] = DateTime.now().toUtc();
    await _store.write(_endpointKey, connectedEndpoint.toString());
    await _store.write(_endpointsKey,
        jsonEncode(_endpoints.map((endpoint) => endpoint.toString()).toList()));
    await _store.write(_credentialKey, token);
    await _store.write(_nodeIdKey, payload.nodeId!);
    if ((payload.fingerprint ?? '').isNotEmpty) {
      await _store.write(_fingerprintKey, payload.fingerprint!);
    }
  }

  Future<void> unpair() async {
    _endpoint = null;
    _endpoints = const [];
    _credential = null;
    _fingerprint = null;
    _nodeId = null;
    _verifiedEndpoints.clear();
    await Future.wait([
      _store.delete(_endpointKey),
      _store.delete(_endpointsKey),
      _store.delete(_credentialKey),
      _store.delete(_fingerprintKey),
      _store.delete(_nodeIdKey),
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
  Future<void> deleteCapture(String id) async {
    await _request('DELETE', '/local/v1/captures/${Uri.encodeComponent(id)}');
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
  Future<KubusCaptureDraft> beginCaptureDraft(
    Map<String, dynamic> metadata,
  ) async =>
      KubusCaptureDraft.fromJson(
        await _post(
          '/local/v1/captures/drafts',
          metadata,
          requireFreshIdentity: true,
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
  Future<Map<String, dynamic>> commitCaptureDraft(String draftId) => _post(
        '/local/v1/captures/drafts/${Uri.encodeComponent(draftId)}/commit',
        const {},
        timeout: const Duration(minutes: 5),
      );

  /// Abandons a draft and everything already uploaded into it.
  Future<void> discardCaptureDraft(String draftId) async {
    await _request(
      'DELETE',
      '/local/v1/captures/drafts/${Uri.encodeComponent(draftId)}',
    );
  }

  Future<KubusNodeJob> createJob({
    required String type,
    required Map<String, dynamic> input,
  }) async =>
      KubusNodeJob.fromJson(
        await _post('/local/v1/jobs', {'type': type, 'input': input}),
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
            '/local/v1/jobs/${Uri.encodeComponent(id)}/cancel', const {}),
      );
  Future<Map<String, dynamic>> getSpatial(String id) =>
      _get('/local/v1/spatial/${Uri.encodeComponent(id)}');

  Future<Map<String, dynamic>> publishSpatial({
    required String spatialId,
    required String backendAuthorization,
    required String artworkId,
    String? markerId,
  }) =>
      _post('/local/v1/spatial/${Uri.encodeComponent(spatialId)}/publish', {
        'backendAuthorization': backendAuthorization,
        'artworkId': artworkId,
        if (markerId != null) 'markerId': markerId,
      });

  /// Streams a private Node content object directly to disk. This is used for
  /// processed variants; `bodyBytes` would otherwise retain a large splat in
  /// the Dart heap before it reaches the phone library.
  Future<void> downloadContentToFile(String cid, File destination) async {
    if (!isPaired) throw StateError('No kubus Node is paired.');
    final endpoint = await _selectVerifiedEndpoint(forceIdentityCheck: true);
    final request = http.Request(
      'GET',
      _resolve(endpoint, '/local/v1/content/${Uri.encodeComponent(cid)}'),
    )..headers['Authorization'] = 'Bearer $_credential';
    final response =
        await _client.send(request).timeout(const Duration(minutes: 5));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(await http.Response.fromStream(response));
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
    final data = await _post('/local/v1/compute/candidates', {
      'backendAuthorization': backendAuthorization,
      'type': type,
      'inputBytes': inputBytes,
      'minimumVramBytes': minimumVramBytes,
    });
    return (data['nodes'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(KubusComputeCandidate.fromJson)
        .toList(growable: false);
  }

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
            timeout: const Duration(minutes: 10)),
      );

  Future<KubusRemoteComputeJob> getRemoteComputeJob(
    String id,
    String backendAuthorization,
  ) async =>
      KubusRemoteComputeJob.fromJson(
        await _post(
            '/local/v1/compute/jobs/${Uri.encodeComponent(id)}/status', {
          'backendAuthorization': backendAuthorization,
        }),
      );

  Future<Map<String, dynamic>> retrieveRemoteComputeResult(
    String id,
    String backendAuthorization,
  ) =>
      _post(
        '/local/v1/compute/jobs/${Uri.encodeComponent(id)}/retrieve',
        {'backendAuthorization': backendAuthorization},
        timeout: const Duration(minutes: 10),
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
        ),
      );

  Future<KubusRemoteComputeJob> cancelRemoteComputeJob(
    String id,
    String backendAuthorization,
  ) async =>
      KubusRemoteComputeJob.fromJson(
        await _post(
            '/local/v1/compute/jobs/${Uri.encodeComponent(id)}/cancel', {
          'backendAuthorization': backendAuthorization,
        }),
      );

  Future<Map<String, dynamic>> getComputeSettings() =>
      _get('/local/v1/compute/settings');

  Future<Map<String, dynamic>> updateComputeSettings(
    Map<String, dynamic> settings,
  ) async =>
      _decode(
        await _request('PUT', '/local/v1/compute/settings', body: settings),
      );

  Future<List<KubusContentCandidate>> resolveContentCandidates(
    String raw, {
    String? localPath,
  }) async {
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
    bool requireFreshIdentity = false,
  }) async =>
      _decode(
        await _request(
          'POST',
          path,
          body: body,
          timeout: timeout,
          requireFreshIdentity: requireFreshIdentity,
        ),
      );
  Future<KubusNodeResponse> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 20),
    bool requireFreshIdentity = false,
  }) async {
    if (!isPaired) throw StateError('No kubus Node is paired.');
    return _transport.request(KubusNodeRequest(
      method: method,
      path: path,
      jsonBody: body,
      timeout: timeout,
    ));
  }

  List<Uri> _orderedEndpoints() {
    final primary = _endpoint;
    if (primary == null) return _endpoints;
    return [primary, ..._endpoints.where((endpoint) => endpoint != primary)];
  }

  Future<Uri> _selectVerifiedEndpoint({bool forceIdentityCheck = false}) async {
    Object? lastError;
    for (final endpoint in _orderedEndpoints()) {
      try {
        await _verifyEndpoint(endpoint, force: forceIdentityCheck);
        _endpoint = endpoint;
        return endpoint;
      } on KubusNodeIdentityException {
        rethrow;
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('kubus Node is unavailable: $lastError');
  }

  Future<void> _verifyEndpoint(
    Uri endpoint, {
    String? credential,
    String? expectedNodeId,
    String? expectedFingerprint,
    bool force = false,
  }) async {
    final expectedId = expectedNodeId ?? _nodeId;
    final expectedPrint = expectedFingerprint ?? _fingerprint;
    if (expectedId == null || expectedPrint == null) {
      throw const KubusNodeIdentityException();
    }
    final verifiedAt = _verifiedEndpoints[endpoint.toString()];
    if (!force && credential == null && verifiedAt != null) {
      if (DateTime.now().toUtc().difference(verifiedAt) <
          _identityVerificationTtl) {
        return;
      }
    }
    final response = await _client.get(
      _resolve(endpoint, '/local/v1/info'),
      headers: {'Authorization': 'Bearer ${credential ?? _credential}'},
    ).timeout(const Duration(seconds: 10));
    final info = _decode(KubusNodeResponse(
      statusCode: response.statusCode,
      body: response.body,
      requestPath: response.request?.url.path,
    ));
    if (info['nodeId']?.toString() != expectedId ||
        info['fingerprint']?.toString() != expectedPrint) {
      throw const KubusNodeIdentityException();
    }
    _verifiedEndpoints[endpoint.toString()] = DateTime.now().toUtc();
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

  static bool _isAllowedStoredEndpoint(Uri endpoint) {
    if (!endpoint.hasAuthority) return false;
    if (endpoint.scheme == 'https') return true;
    if (endpoint.scheme != 'http') return false;
    return isPrivateLanHost(endpoint);
  }

  /// Whether [endpoint] addresses a host on the user's own network.
  ///
  /// Exposed because the difference matters to the user: reaching *their* Node
  /// over the LAN and reaching *their* Node over the internet are the same
  /// trust relationship shown differently, and neither is the same as handing
  /// the capture to a stranger's GPU.
  static bool isPrivateLanHost(Uri endpoint) {
    final host = endpoint.host.toLowerCase();
    if (host.isEmpty) return false;
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host.endsWith('.local') ||
        host.endsWith('.internal') ||
        host.startsWith('10.') ||
        host.startsWith('192.168.')) {
      return true;
    }
    final parts = host.split('.');
    final second = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return parts.first == '172' &&
        second != null &&
        second >= 16 &&
        second <= 31;
  }

  /// True when the paired Node is currently reached over the local network.
  ///
  /// False for a paired Node reached over remote HTTPS, and false when there
  /// is no endpoint at all.
  bool get isEndpointOnLocalNetwork {
    final active = _endpoint;
    return active != null && isPrivateLanHost(active);
  }

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
