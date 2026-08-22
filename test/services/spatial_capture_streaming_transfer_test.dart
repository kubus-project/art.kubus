import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/models/spatial_capture_target.dart';
import 'package:art_kubus/providers/spatial_capture_provider.dart';
import 'package:art_kubus/providers/spatial_library_provider.dart';
import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/services/kubus_node_service.dart';
import 'package:art_kubus/services/spatial_capture_policy.dart';
import 'package:art_kubus/services/spatial_library_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in kubus Node speaking the real `/local/v1/captures/drafts` contract.
///
/// Modelled on `src/localApi/localApiRouter.ts` and `src/captures/captureStore.ts`
/// so the client is exercised against the routes, status codes and payload
/// shapes the node actually implements, rather than a shape invented here.
class FakeKubusNode {
  FakeKubusNode({this.failUploadsBefore = 0, this.supportsDrafts = true});

  /// Number of file uploads to reject before starting to accept them, so a
  /// resumable transfer can be exercised.
  int failUploadsBefore;

  /// When false, draft routes 404 the way a node predating the streaming API
  /// would.
  final bool supportsDrafts;

  HttpServer? _server;
  Uri get endpoint => Uri.parse('http://127.0.0.1:${_server!.port}');

  /// Drafts by id: path -> bytes received.
  final Map<String, Map<String, List<int>>> drafts = {};
  final Map<String, Map<String, dynamic>> draftMetadata = {};
  final List<String> committed = [];
  final List<int> processedVariant = List<int>.generate(4096, (i) => i % 251);
  static const manifestCid = 'Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  static const variantCid = 'Qmbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  String? committedCaptureId;

  Map<String, dynamic> get spatialManifest => <String, dynamic>{
        'schema': 'kubus.spatial/1',
        'id': 'spatial-1',
        'type': 'gaussianSplat',
        'artworkId': 'art-1',
        'captureId': committedCaptureId,
        'capturedAt': '2026-08-18T00:00:00.000Z',
        'variants': <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'spatial_mobile',
            'cid': variantCid,
            'sizeBytes': processedVariant.length,
            'mimeType': 'application/octet-stream',
            'format': 'spz',
            'storageClass': 'warm',
          },
        ],
      };

  /// Every request line, so a test can assert nothing base64-shaped was posted.
  final List<String> requests = [];

  /// Bodies of any non-streaming JSON posts, for the same reason.
  final List<String> jsonBodies = [];

  int _uploadAttempts = 0;
  int _nextId = 0;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(_serve());
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }

  Future<void> _serve() async {
    await for (final request in _server!) {
      try {
        await _handle(request);
      } catch (_) {
        request.response.statusCode = 500;
        await request.response.close();
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    requests.add('${request.method} $path');

    if (request.method == 'GET' && path == '/local/v1/info') {
      return _json(request, 200, {
        'nodeId': 'fake-node-1',
        'fingerprint': 'fake-node-fingerprint',
      });
    }

    if (request.method == 'POST' && path == '/local/v1/jobs') {
      return _json(request, 201, {
        'id': 'job-1',
        'type': 'spatial.reconstruct',
        'state': 'queued',
        'progress': 0,
      });
    }

    if (request.method == 'GET' && path == '/local/v1/jobs/job-1') {
      return _json(request, 200, {
        'id': 'job-1',
        'type': 'spatial.reconstruct',
        'state': 'completed',
        'progress': 1,
        'output': {'id': 'spatial-1'},
      });
    }

    if (request.method == 'GET' && path == '/local/v1/spatial/spatial-1') {
      return _json(request, 200, {
        'id': 'spatial-1',
        'manifestCid': manifestCid,
        'manifest': spatialManifest,
      });
    }

    if (request.method == 'GET' && path == '/local/v1/content/$manifestCid') {
      final bytes = utf8.encode(jsonEncode(spatialManifest));
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
      await request.response.close();
      return;
    }

    if (request.method == 'GET' && path == '/local/v1/content/$variantCid') {
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.binary;
      request.response.contentLength = processedVariant.length;
      request.response.add(processedVariant);
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && path == '/local/v1/captures/drafts') {
      final body = await utf8.decoder.bind(request).join();
      jsonBodies.add(body);
      if (!supportsDrafts) {
        return _json(request, 404, {'error': 'local_route_not_found'});
      }
      final id = 'draft-${_nextId++}';
      drafts[id] = {};
      draftMetadata[id] = jsonDecode(body) as Map<String, dynamic>;
      return _json(request, 201, {
        'id': id,
        'state': 'draft',
        'fileCount': 0,
        'sizeBytes': 0,
      });
    }

    final fileMatch =
        RegExp(r'^/local/v1/captures/drafts/([^/]+)/files$').firstMatch(path);
    if (request.method == 'PUT' && fileMatch != null) {
      final id = fileMatch.group(1)!;
      final filePath = request.uri.queryParameters['path'];
      if (filePath == null) {
        return _json(request, 400, {'error': 'capture_file_path_invalid'});
      }
      final bytes = <int>[];
      await for (final chunk in request) {
        bytes.addAll(chunk);
      }
      _uploadAttempts++;
      if (_uploadAttempts <= failUploadsBefore) {
        return _json(request, 503, {'error': 'node_busy'});
      }
      final draft = drafts[id];
      if (draft == null) {
        return _json(request, 404, {'error': 'capture_draft_not_found'});
      }
      // Re-uploading a path overwrites it, so a retry converges.
      draft[filePath] = bytes;
      return _json(request, 200, {
        'id': id,
        'state': 'draft',
        'fileCount': draft.length,
        'sizeBytes': draft.values.fold<int>(0, (sum, b) => sum + b.length),
      });
    }

    final commitMatch =
        RegExp(r'^/local/v1/captures/drafts/([^/]+)/commit$').firstMatch(path);
    if (request.method == 'POST' && commitMatch != null) {
      final id = commitMatch.group(1)!;
      final draft = drafts[id];
      if (draft == null) {
        return _json(request, 404, {'error': 'capture_draft_not_found'});
      }
      if (draft.isEmpty) {
        return _json(request, 400, {'error': 'capture_package_empty'});
      }
      committed.add(id);
      committedCaptureId = 'capture-$id';
      return _json(request, 201, {
        'id': committedCaptureId,
        'state': 'stored',
        'private': true,
        'fileCount': draft.length,
        'sizeBytes': draft.values.fold<int>(0, (sum, b) => sum + b.length),
      });
    }

    final draftMatch =
        RegExp(r'^/local/v1/captures/drafts/([^/]+)$').firstMatch(path);
    if (draftMatch != null) {
      final id = draftMatch.group(1)!;
      final draft = drafts[id];
      if (draft == null) {
        return _json(request, 404, {'error': 'capture_draft_not_found'});
      }
      if (request.method == 'DELETE') {
        drafts.remove(id);
        return _json(request, 200, {'discarded': true});
      }
      return _json(request, 200, {
        'id': id,
        'state': 'draft',
        'fileCount': draft.length,
        'sizeBytes': draft.values.fold<int>(0, (sum, b) => sum + b.length),
        'files': draft.keys.toList(),
      });
    }

    // The old whole-package endpoint. Present so the test can prove the client
    // never falls back to it.
    if (request.method == 'POST' && path == '/local/v1/captures') {
      jsonBodies.add(await utf8.decoder.bind(request).join());
      return _json(request, 201, {'id': 'legacy-capture'});
    }

    return _json(request, 404, {'error': 'local_route_not_found'});
  }

  Future<void> _json(
    HttpRequest request,
    int status,
    Map<String, dynamic> body,
  ) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }
}

/// Minimal node provider exposing a service pointed at the fake node.
class _TestNodeProvider implements KubusNodeProvider {
  _TestNodeProvider(this.service);

  @override
  final KubusNodeService service;

  @override
  bool get isPaired => service.isPaired;

  @override
  KubusNodeSnapshot? get snapshot => const KubusNodeSnapshot(
        status: <String, dynamic>{},
        capabilities: <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'spatial.reconstruction',
            'available': true,
            'healthy': true,
          },
        ],
      );

  @override
  Future<KubusNodeJob> startReconstruction({
    required String captureId,
    required String artworkId,
    String? markerId,
  }) =>
      service.createJob(
        type: 'spatial.reconstruct',
        input: <String, dynamic>{
          'captureId': captureId,
          'artworkId': artworkId,
          if (markerId != null) 'markerId': markerId,
        },
      );

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected node call: ${invocation.memberName}');
}

class _NetworkTestNodeProvider extends _TestNodeProvider {
  _NetworkTestNodeProvider(super.service);

  bool acknowledged = false;

  @override
  Future<KubusRemoteComputeJob> startRemoteReconstruction({
    required String captureId,
    required KubusComputeCandidate provider,
    required Map<String, dynamic> requirements,
  }) async =>
      const KubusRemoteComputeJob(
        id: 'network-job-1',
        state: 'REQUESTED',
        type: 'spatial.reconstruct',
        protocolVersion: 'kubus.compute/1',
        providerNodeId: 'provider-1',
      );

  @override
  Future<KubusRemoteComputeJob> refreshRemoteJob(String id) async =>
      const KubusRemoteComputeJob(
        id: 'network-job-1',
        state: 'OUTPUT_READY',
        type: 'spatial.reconstruct',
        protocolVersion: 'kubus.compute/1',
        providerNodeId: 'provider-1',
      );

  @override
  Future<Map<String, dynamic>> retrieveRemoteResult(String id) async =>
      <String, dynamic>{'id': 'spatial-1'};

  @override
  Future<KubusRemoteComputeJob> acknowledgeRemoteResult(
    String id, {
    required bool accepted,
    String? reason,
  }) async {
    acknowledged = accepted;
    return const KubusRemoteComputeJob(
      id: 'network-job-1',
      state: 'COMPLETED',
      type: 'spatial.reconstruct',
      protocolVersion: 'kubus.compute/1',
      providerNodeId: 'provider-1',
    );
  }
}

class _MemoryCredentialStore implements KubusNodeCredentialStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

Map<String, dynamic> orbitFrame(int index) {
  final angle = (index / 12) * 2 * math.pi;
  return <String, dynamic>{
    'rgb': Uint8List.fromList(List<int>.filled(48, index % 256)),
    'timestampNanos': index,
    'poseTranslation': [math.cos(angle), 0.0, math.sin(angle)],
    'poseRotation': [0.0, math.sin(angle / 2), 0.0, math.cos(angle / 2)],
    'intrinsics': {'width': 640, 'height': 480},
    'depthAvailable': false,
  };
}

void main() {
  late Directory root;
  late FakeKubusNode node;
  late KubusNodeService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kubus_stream_');
    node = FakeKubusNode();
    await node.start();
    service = KubusNodeService(
      credentialStore: _MemoryCredentialStore(),
      isWeb: false,
    );
  });

  tearDown(() async {
    await node.stop();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<KubusNodeProvider> pairedNode() async {
    final store = _MemoryCredentialStore();
    await store.write('kubus_node_endpoint_v1', node.endpoint.toString());
    await store.write('kubus_node_credential_v1', 'kubus_local_testtoken');
    await store.write('kubus_node_id_v2', 'fake-node-1');
    await store.write('kubus_node_fingerprint_v1', 'fake-node-fingerprint');
    service = KubusNodeService(credentialStore: store, isWeb: false);
    await service.initialize();
    return _TestNodeProvider(service);
  }

  Future<SpatialCaptureProvider> readyCapture({
    SpatialLibraryStore? libraryStore,
    Future<void> Function()? onLibraryChanged,
  }) async {
    final provider = SpatialCaptureProvider(
      storageRoot: root,
      libraryStore: libraryStore,
      onLibraryChanged: onLibraryChanged,
      policy: const SpatialCapturePolicy(minSampleInterval: Duration.zero),
    );
    await provider.begin(
      target: const SpatialCaptureTarget(artworkId: 'art-1'),
      capturedBy: 'wallet-1',
    );
    for (var i = 0; i < 30; i++) {
      await provider.offerFrame(orbitFrame(i), isTracking: true);
    }
    expect(provider.canFinish, isTrue);
    return provider;
  }

  Future<SpatialLibraryProvider> openLibrary(
      KubusNodeProvider nodeProvider) async {
    final library = SpatialLibraryProvider(
      store: SpatialLibraryStore(
        root: Directory('${root.path}_spatial-library'),
      ),
      legacyCaptureRoot: root,
      pollInterval: Duration.zero,
    );
    library.bindNode(nodeProvider);
    await library.initialize();
    return library;
  }

  test('finish is durable before Node processing and result returns to phone',
      () async {
    final capture = await readyCapture();
    final accepted = capture.frameCount;
    final record = await capture.finish();

    expect(capture.state, SpatialCaptureState.complete);
    expect(record.sampleCount, accepted);
    expect(node.requests, isEmpty,
        reason: 'Finish Capture must not contact a processor');

    final nodeProvider = await pairedNode();
    final library = await openLibrary(nodeProvider);
    final ready = await library.processWithOwnNode(record.localSpatialId);

    expect(ready.processingState, SpatialLibraryProcessingState.readyPrivate);
    expect(ready.integrityState, SpatialLibraryIntegrityState.valid);
    expect(ready.rawPresent, isTrue);
    expect(await File(ready.resultManifestPath!).exists(), isTrue);
    expect(await File(ready.resultVariantPaths['spatial_mobile']!).exists(),
        isTrue);
    expect(node.committed, hasLength(1));
    final draft = node.drafts.values.single;
    expect(draft.length, accepted + 1);
    expect(draft.containsKey('frames.json'), isTrue);
  });

  test('Node outage cannot turn a successful finish into capture failure',
      () async {
    final capture = await readyCapture();
    final accepted = capture.frameCount;
    await node.stop();

    final record = await capture.finish();

    expect(capture.state, SpatialCaptureState.complete);
    expect(
        record.processingState, SpatialLibraryProcessingState.capturedPrivate);
    expect(record.sampleCount, accepted);
    expect(record.rawPresent, isTrue);
    expect(await Directory(record.sourcePath).exists(), isTrue);
  });

  test('finish immediately refreshes the app-wide Spatial Library', () async {
    final store = SpatialLibraryStore(
      root: Directory('${root.path}_spatial-library'),
    );
    final library = SpatialLibraryProvider(
      store: store,
      legacyCaptureRoot: root,
    );
    await library.initialize();
    final capture = await readyCapture(
      libraryStore: store,
      onLibraryChanged: library.reload,
    );

    final record = await capture.finish();

    expect(library.records.map((item) => item.localSpatialId),
        contains(record.localSpatialId));
  });

  test('initialization makes an interrupted processing record retryable',
      () async {
    final capture = await readyCapture();
    final record = await capture.finish();
    final store = SpatialLibraryStore(
      root: Directory('${root.path}_spatial-library'),
    );
    await store.updateProcessing(
      record.localSpatialId,
      SpatialLibraryProcessingState.downloadingResult,
    );
    final library = SpatialLibraryProvider(
      store: store,
      legacyCaptureRoot: root,
    );

    await library.initialize();

    expect(library.records.single.processingState,
        SpatialLibraryProcessingState.failedRetryable);
    expect(library.records.single.lastErrorCode, 'result_download_interrupted');
  });

  test('processing streams files and never creates aggregate base64 JSON',
      () async {
    final capture = await readyCapture();
    final record = await capture.finish();
    final nodeProvider = await pairedNode();
    final library = await openLibrary(nodeProvider);

    await library.processWithOwnNode(record.localSpatialId);

    expect(node.requests.where((r) => r == 'POST /local/v1/captures'), isEmpty);
    for (final body in node.jsonBodies) {
      expect(body.contains('contentBase64'), isFalse);
      expect(body.contains('"files"'), isFalse);
      expect(body.length, lessThan(4096));
    }
  });

  test('measured upload progress is persisted in the library record', () async {
    final capture = await readyCapture();
    final accepted = capture.frameCount;
    final record = await capture.finish();
    final library = await openLibrary(await pairedNode());

    final ready = await library.processWithOwnNode(record.localSpatialId);

    expect(ready.uploadedFiles, accepted + 1);
    expect(ready.totalFiles, accepted + 1);
    expect(ready.uploadedBytes, ready.totalUploadBytes);
    expect(ready.uploadedBytes, greaterThan(0));
  });

  test('an interrupted upload resumes the persisted draft', () async {
    final capture = await readyCapture();
    final record = await capture.finish();
    final library = await openLibrary(await pairedNode());
    node.failUploadsBefore = 5;

    await expectLater(
      library.processWithOwnNode(record.localSpatialId),
      throwsA(anything),
    );
    final failed = await library.store.get(record.localSpatialId);
    expect(failed!.processingState,
        SpatialLibraryProcessingState.waitingForProcessor);
    expect(failed.draftId, isNotNull);
    final draftsAfterFailure = node.drafts.length;

    node.failUploadsBefore = 0;
    final ready = await library.processWithOwnNode(record.localSpatialId);
    expect(ready.processingState, SpatialLibraryProcessingState.readyPrivate);
    expect(node.drafts.length, draftsAfterFailure);
    expect(node.committed, hasLength(1));
  });

  test('a missing Node draft is recreated without duplicate final capture',
      () async {
    final capture = await readyCapture();
    final record = await capture.finish();
    final library = await openLibrary(await pairedNode());
    node.failUploadsBefore = 3;
    await expectLater(
      library.processWithOwnNode(record.localSpatialId),
      throwsA(anything),
    );
    node.drafts.clear();
    node.failUploadsBefore = 0;

    final ready = await library.processWithOwnNode(record.localSpatialId);

    expect(ready.processingState, SpatialLibraryProcessingState.readyPrivate);
    expect(node.committed, hasLength(1));
  });

  test('a capture transferred to a different Node is uploaded again', () async {
    final capture = await readyCapture();
    final record = await capture.finish();
    final library = await openLibrary(await pairedNode());
    await library.store.recordNodeTransfer(
      record.localSpatialId,
      nodeId: 'previous-node',
      draftId: 'previous-draft',
      nodeCaptureId: 'previous-capture',
      uploadedFiles: record.sampleCount,
      uploadedBytes: record.sourceBytes,
    );

    final ready = await library.processWithOwnNode(record.localSpatialId);

    expect(ready.nodeId, 'fake-node-1');
    expect(ready.nodeCaptureId, isNot('previous-capture'));
    expect(node.committed, hasLength(1));
  });

  test('a node without streaming reports typed incompatibility and keeps raw',
      () async {
    await node.stop();
    node = FakeKubusNode(supportsDrafts: false);
    await node.start();
    final capture = await readyCapture();
    final record = await capture.finish();
    final library = await openLibrary(await pairedNode());

    await expectLater(
      library.processWithOwnNode(record.localSpatialId),
      throwsA(isA<KubusNodeUnsupportedException>()),
    );
    final preserved = await library.store.get(record.localSpatialId);
    expect(preserved!.rawPresent, isTrue);
    expect(await Directory(preserved.sourcePath).exists(), isTrue);
    expect(node.requests.where((r) => r == 'POST /local/v1/captures'), isEmpty);
  });

  test('network GPU uses the same durable record and result import pipeline',
      () async {
    final capture = await readyCapture();
    final record = await capture.finish();
    final baseProvider = await pairedNode();
    final networkProvider = _NetworkTestNodeProvider(baseProvider.service);
    final library = await openLibrary(networkProvider);
    const candidate = KubusComputeCandidate(
      nodeId: 'provider-1',
      label: 'Shared GPU',
      encryptionPublicKey: 'x25519-public',
      signingPublicKey: 'ed25519-public',
      gpu: <String, dynamic>{'model': 'RTX 4090'},
      worker: <String, dynamic>{'version': '1.1.5'},
      reliability: <String, dynamic>{'successRate': 1},
      queue: <String, dynamic>{'queuedJobs': 0},
      rankScore: 1,
    );

    final ready =
        await library.processWithNetwork(record.localSpatialId, candidate);

    expect(ready.processingState, SpatialLibraryProcessingState.readyPrivate);
    expect(ready.networkProviderNodeId, 'provider-1');
    expect(ready.networkRequestId, 'network-job-1');
    expect(ready.integrityState, SpatialLibraryIntegrityState.valid);
    expect(ready.rawPresent, isTrue);
    expect(networkProvider.acknowledged, isTrue);
    expect(await File(ready.resultVariantPaths['spatial_mobile']!).exists(),
        isTrue);
  });
}
