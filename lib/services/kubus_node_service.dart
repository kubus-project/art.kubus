import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/kubus_node_models.dart';
import 'storage_config.dart';

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
  })  : _client = client ?? http.Client(),
        _store = credentialStore ?? SecureKubusNodeCredentialStore(),
        _isWeb = isWeb ?? kIsWeb;
  static const _endpointKey = 'kubus_node_endpoint_v1';
  static const _credentialKey = 'kubus_node_credential_v1';
  static const _fingerprintKey = 'kubus_node_fingerprint_v1';
  final http.Client _client;
  final KubusNodeCredentialStore _store;
  final bool _isWeb;
  Uri? _endpoint;
  String? _credential;
  String? _fingerprint;

  Uri? get endpoint => _endpoint;
  String? get fingerprint => _fingerprint;
  bool get isPaired =>
      _endpoint != null && (_credential ?? '').startsWith('kubus_local_');

  Future<bool> initialize() async {
    final rawEndpoint = await _store.read(_endpointKey);
    _endpoint = Uri.tryParse(rawEndpoint ?? '');
    _credential = await _store.read(_credentialKey);
    _fingerprint = await _store.read(_fingerprintKey);
    return isPaired;
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
    final data = _decode(response);
    final token = (data['token'] ?? '').toString();
    if (!token.startsWith('kubus_local_')) {
      throw StateError('Node returned an invalid local credential.');
    }
    _endpoint = payload.endpoint;
    _credential = token;
    _fingerprint = payload.fingerprint;
    await _store.write(_endpointKey, payload.endpoint.toString());
    await _store.write(_credentialKey, token);
    if ((payload.fingerprint ?? '').isNotEmpty) {
      await _store.write(_fingerprintKey, payload.fingerprint!);
    }
  }

  Future<void> unpair() async {
    _endpoint = null;
    _credential = null;
    _fingerprint = null;
    await Future.wait([
      _store.delete(_endpointKey),
      _store.delete(_credentialKey),
      _store.delete(_fingerprintKey),
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

  Future<Map<String, dynamic>> createCapture(
    Map<String, dynamic> capturePackage,
  ) =>
      _post(
        '/local/v1/captures',
        capturePackage,
        timeout: const Duration(minutes: 10),
      );
  Future<Map<String, dynamic>> getCapture(String id) =>
      _get('/local/v1/captures/${Uri.encodeComponent(id)}');
  Future<void> deleteCapture(String id) async {
    await _request('DELETE', '/local/v1/captures/${Uri.encodeComponent(id)}');
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
  }) async =>
      _decode(await _request('POST', path, body: body, timeout: timeout));
  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (!isPaired) throw StateError('No kubus Node is paired.');
    final request = http.Request(method, _resolve(_endpoint!, path));
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $_credential',
    });
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final streamed = await _client.send(request).timeout(timeout);
    return http.Response.fromStream(streamed);
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final body = jsonDecode(response.body.isEmpty ? '{}' : response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        body is Map
            ? (body['error'] ?? body['message'] ?? 'Node request failed')
                .toString()
            : 'Node request failed',
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
