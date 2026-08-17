import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/providers/spatial_capture_provider.dart';
import 'package:art_kubus/services/kubus_node_service.dart';
import 'package:art_kubus/services/spatial_capture_policy.dart';
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
      return _json(request, 201, {
        'id': 'capture-$id',
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
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected node call: ${invocation.memberName}');
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
    service = KubusNodeService(credentialStore: store, isWeb: false);
    await service.initialize();
    return _TestNodeProvider(service);
  }

  Future<SpatialCaptureProvider> readyCapture() async {
    final provider = SpatialCaptureProvider(
      storageRoot: root,
      policy: const SpatialCapturePolicy(minSampleInterval: Duration.zero),
    );
    await provider.begin(artworkId: 'art-1', capturedBy: 'wallet-1');
    for (var i = 0; i < 30; i++) {
      await provider.offerFrame(orbitFrame(i), isTracking: true);
    }
    expect(provider.canFinish, isTrue);
    return provider;
  }

  test('a capture is streamed file by file and committed', () async {
    final provider = await readyCapture();
    final nodeProvider = await pairedNode();

    await provider.finish(nodeProvider);

    expect(provider.state, SpatialCaptureState.awaitingProcessingChoice);
    expect(provider.captureId, isNotNull);
    expect(node.committed, hasLength(1));

    final draft = node.drafts.values.single;
    // One RGB file per accepted sample, plus the frame index.
    expect(draft.length, provider.frameCount + 1);
    expect(draft.containsKey('frames.json'), isTrue);
    expect(draft.containsKey('rgb/00000.jpg'), isTrue);

    // Every file arrived as raw bytes on its own PUT.
    final puts = node.requests.where((r) => r.startsWith('PUT ')).length;
    expect(puts, provider.frameCount + 1);
  });

  test('no aggregate base64 capture payload is ever produced', () async {
    final provider = await readyCapture();
    final nodeProvider = await pairedNode();

    await provider.finish(nodeProvider);

    // The legacy whole-package endpoint is never touched.
    expect(
      node.requests.where((r) => r == 'POST /local/v1/captures'),
      isEmpty,
      reason: 'spatial capture must not use the base64 JSON package route',
    );

    // The only JSON body is the draft metadata, and it carries no file content.
    for (final body in node.jsonBodies) {
      expect(body.contains('contentBase64'), isFalse,
          reason: 'no file bytes may be base64-encoded into a JSON document');
      expect(body.contains('"files"'), isFalse,
          reason: 'the draft is opened from metadata alone');
      expect(body.length, lessThan(4096),
          reason: 'the metadata document must stay small regardless of capture '
              'size');
    }
  });

  test('transfer progress is measured, not interpolated', () async {
    final provider = await readyCapture();
    final nodeProvider = await pairedNode();

    final phases = <SpatialTransferPhase>[];
    final uploaded = <int>[];
    provider.addListener(() {
      final transfer = provider.transfer;
      if (phases.isEmpty || phases.last != transfer.phase) {
        phases.add(transfer.phase);
      }
      if (transfer.phase == SpatialTransferPhase.uploading) {
        uploaded.add(transfer.uploadedFiles);
      }
    });

    await provider.finish(nodeProvider);

    expect(phases, contains(SpatialTransferPhase.preparing));
    expect(phases, contains(SpatialTransferPhase.uploading));
    expect(phases, contains(SpatialTransferPhase.committing));
    // Counts advance one file at a time and end at the real total.
    expect(uploaded.first, lessThan(uploaded.last));
    expect(uploaded.last, provider.frameCount + 1);
  });

  test('an interrupted transfer resumes without duplicating the capture',
      () async {
    final provider = await readyCapture();
    final nodeProvider = await pairedNode();

    // Fail partway through the uploads.
    node.failUploadsBefore = 5;
    await expectLater(provider.finish(nodeProvider), throwsA(anything));
    expect(provider.state, SpatialCaptureState.error);
    expect(node.committed, isEmpty);

    final draftsAfterFailure = node.drafts.length;
    expect(draftsAfterFailure, 1);

    // Now let uploads through and resume.
    node.failUploadsBefore = 0;
    await provider.retryTransfer(nodeProvider);

    expect(provider.state, SpatialCaptureState.awaitingProcessingChoice);
    expect(
      node.drafts.length,
      draftsAfterFailure,
      reason: 'the retry resumes the existing draft rather than opening a new '
          'one',
    );
    expect(
      node.committed,
      hasLength(1),
      reason: 'exactly one durable capture record is created',
    );
    expect(node.drafts.values.single.length, provider.frameCount + 1);
  });

  test('a node without the streaming API reports a typed incompatibility',
      () async {
    await node.stop();
    node = FakeKubusNode(supportsDrafts: false);
    await node.start();

    final provider = await readyCapture();
    final nodeProvider = await pairedNode();

    await expectLater(
      provider.finish(nodeProvider),
      throwsA(isA<KubusNodeUnsupportedException>()),
    );
    expect(
      node.requests.where((r) => r == 'POST /local/v1/captures'),
      isEmpty,
      reason: 'an incompatible node is reported, not silently downgraded to '
          'the base64 route',
    );
  });
}
