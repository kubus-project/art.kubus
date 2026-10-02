import 'dart:io';

import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/models/spatial_capture_target.dart';
import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/providers/spatial_capture_provider.dart';
import 'package:art_kubus/providers/spatial_library_provider.dart';
import 'package:art_kubus/services/kubus_node_service.dart';
import 'package:art_kubus/services/spatial_library_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spatial_test_fixtures.dart';

/// A network compute request is a promise to the user, so it lives on disk.
///
/// The previous behaviour derived the whole feature from a discovery call:
/// if no provider answered in the two seconds a sheet took to open, the
/// option simply was not there. These tests pin the opposite contract — the
/// request exists first, and a provider is found afterwards or not at all.
void main() {
  late Directory root;
  late SpatialLibraryStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kubus_spatial_network_');
    store = SpatialLibraryStore(root: Directory('${root.path}_library'));
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
    final libraryRoot = Directory('${root.path}_library');
    if (await libraryRoot.exists()) await libraryRoot.delete(recursive: true);
  });

  SpatialLibraryProvider buildLibrary(KubusNodeProvider node) {
    final library = SpatialLibraryProvider(
      store: store,
      legacyCaptureRoot: root,
      pollInterval: Duration.zero,
      providerSearchInterval: Duration.zero,
      publicationClient: _UnusedPublicationClient(),
    );
    library.bindNode(node);
    return library;
  }

  /// Marks a record as already delivered to the stub node.
  ///
  /// The upload path is covered end to end by the streaming transfer suite;
  /// these tests are about what happens to the *request* once a provider is in
  /// play, so they start from a capture the node already holds.
  Future<void> markUploaded(SpatialLibraryRecord record) =>
      store.recordNodeTransfer(
        record.localSpatialId,
        nodeId: 'stub-node',
        nodeCaptureId: 'node-capture-1',
      );

  Future<SpatialLibraryRecord> savedCapture() async {
    final capture = SpatialCaptureProvider(
      policy: eagerPolicy,
      storageRoot: root,
      libraryStore: store,
    );
    await capture.begin(
      target: const SpatialCaptureTarget(artworkId: 'artwork-1'),
      capturedBy: 'wallet-1',
    );
    await pushOrbit(capture, count: 26);
    return capture.finish();
  }

  test('a request is opened and persisted with no provider online', () async {
    final node = _StubNodeProvider(candidates: const <KubusComputeCandidate>[]);
    final library = buildLibrary(node);
    await library.reload();
    final record = await savedCapture();
    await library.reload();

    final requested = await library.openNetworkRequest(record.localSpatialId);

    expect(requested.networkRequest, isNotNull);
    expect(requested.hasActiveNetworkRequest, isTrue);
    expect(
      requested.processingState,
      SpatialLibraryProcessingState.waitingForProcessor,
    );

    // One discovery pass finds nobody, and the request stays open.
    expect(await library.advanceNetworkRequest(record.localSpatialId), isFalse);

    final searching = await store.get(record.localSpatialId);
    expect(
      searching!.networkRequest!.state,
      SpatialNetworkRequestState.searchingProvider,
    );
    expect(searching.hasActiveNetworkRequest, isTrue);
  });

  test('an open request survives a restart', () async {
    final node = _StubNodeProvider(candidates: const <KubusComputeCandidate>[]);
    final library = buildLibrary(node);
    await library.reload();
    final record = await savedCapture();
    await library.reload();
    await library.openNetworkRequest(record.localSpatialId);
    await library.advanceNetworkRequest(record.localSpatialId);

    // A completely fresh provider over the same on-disk library: exactly what
    // the next launch sees.
    final restarted = buildLibrary(node);
    await restarted.reload();

    final recovered = restarted.recordFor(record.localSpatialId);
    expect(recovered, isNotNull);
    expect(recovered!.hasActiveNetworkRequest, isTrue);
    expect(
      recovered.networkRequest!.state,
      SpatialNetworkRequestState.searchingProvider,
    );
  });

  test('a provider appearing later picks the waiting request up', () async {
    final node = _StubNodeProvider(candidates: const <KubusComputeCandidate>[]);
    final library = buildLibrary(node);
    await library.reload();
    final record = await savedCapture();
    await library.reload();
    await markUploaded(record);
    await library.openNetworkRequest(record.localSpatialId);
    await library.advanceNetworkRequest(record.localSpatialId);

    // A provider comes online.
    node.candidates = <KubusComputeCandidate>[_candidate];
    await library.advanceNetworkRequest(record.localSpatialId);

    final accepted = await store.get(record.localSpatialId);
    expect(
      accepted!.networkRequest!.state,
      SpatialNetworkRequestState.providerAccepted,
    );
    expect(accepted.networkRequest!.providerNodeId, 'provider-1');
    expect(accepted.networkRequest!.providerLabel, 'Shared GPU');
    expect(accepted.networkRequest!.jobId, 'remote-job-1');
    expect(accepted.processingState, SpatialLibraryProcessingState.queued);
  });

  test('a request can be cancelled while nobody has taken it', () async {
    final node = _StubNodeProvider(candidates: const <KubusComputeCandidate>[]);
    final library = buildLibrary(node);
    await library.reload();
    final record = await savedCapture();
    await library.reload();
    await library.openNetworkRequest(record.localSpatialId);

    final cancelled = await library.cancelNetworkRequest(record.localSpatialId);

    expect(
      cancelled.networkRequest!.state,
      SpatialNetworkRequestState.cancelled,
    );
    expect(cancelled.hasActiveNetworkRequest, isFalse);
    expect(
      cancelled.processingState,
      SpatialLibraryProcessingState.capturedPrivate,
    );
    // A settled request stops the driver rather than being retried.
    expect(await library.advanceNetworkRequest(record.localSpatialId), isTrue);
    // The capture itself is untouched.
    expect(cancelled.rawPresent, isTrue);
    expect(await Directory(cancelled.sourcePath).exists(), isTrue);
  });

  test('a request nobody took inside its lifetime expires', () async {
    final node = _StubNodeProvider(candidates: const <KubusComputeCandidate>[]);
    final library = buildLibrary(node);
    await library.reload();
    final record = await savedCapture();
    await library.reload();

    // Backdate the request past its lifetime.
    await store.recordNetworkRequest(
      record.localSpatialId,
      SpatialNetworkRequest(
        state: SpatialNetworkRequestState.searchingProvider,
        requestedAt: DateTime.now()
            .toUtc()
            .subtract(SpatialLibraryProvider.networkRequestLifetime * 2),
      ),
      processingState: SpatialLibraryProcessingState.waitingForProcessor,
    );

    expect(await library.advanceNetworkRequest(record.localSpatialId), isTrue);

    final expired = await store.get(record.localSpatialId);
    expect(expired!.networkRequest!.state, SpatialNetworkRequestState.expired);
    expect(expired.lastErrorCode, 'network_request_expired');
    expect(
      expired.processingState,
      SpatialLibraryProcessingState.failedRetryable,
    );
    expect(expired.rawPresent, isTrue);
  });

  test('a provider that declines fails the request and keeps the capture',
      () async {
    final node = _StubNodeProvider(candidates: <KubusComputeCandidate>[
      _candidate,
    ], jobStates: <String>[
      'DECLINED'
    ]);
    final library = buildLibrary(node);
    await library.reload();
    final record = await savedCapture();
    await markUploaded(record);
    await library.reload();
    await library.openNetworkRequest(record.localSpatialId);

    await library.advanceNetworkRequest(record.localSpatialId);
    expect(await library.advanceNetworkRequest(record.localSpatialId), isTrue);

    final declined = await store.get(record.localSpatialId);
    expect(declined!.networkRequest!.state, SpatialNetworkRequestState.failed);
    expect(declined.networkRequest!.failureCode, 'provider_declined');
    expect(declined.rawPresent, isTrue);
    expect(
      declined.processingState,
      SpatialLibraryProcessingState.failedRetryable,
    );
  });

  test('a failed request can be retried by opening a new one', () async {
    final node = _StubNodeProvider(
      candidates: <KubusComputeCandidate>[_candidate],
      jobStates: <String>['FAILED'],
    );
    final library = buildLibrary(node);
    await library.reload();
    final record = await savedCapture();
    await markUploaded(record);
    await library.reload();
    await library.openNetworkRequest(record.localSpatialId);
    await library.advanceNetworkRequest(record.localSpatialId);
    await library.advanceNetworkRequest(record.localSpatialId);
    expect(
      (await store.get(record.localSpatialId))!.networkRequest!.state,
      SpatialNetworkRequestState.failed,
    );

    final retried = await library.openNetworkRequest(record.localSpatialId);

    expect(
      retried.networkRequest!.state,
      SpatialNetworkRequestState.networkRequested,
    );
    expect(retried.hasActiveNetworkRequest, isTrue);
  });

  test('an unreachable discovery service defers rather than dropping the ask',
      () async {
    final node = _StubNodeProvider(candidates: const <KubusComputeCandidate>[])
      ..throwOnDiscovery = true;
    final library = buildLibrary(node);
    await library.reload();
    final record = await savedCapture();
    await library.reload();
    await library.openNetworkRequest(record.localSpatialId);

    expect(await library.advanceNetworkRequest(record.localSpatialId), isFalse);

    final open = await store.get(record.localSpatialId);
    expect(open!.hasActiveNetworkRequest, isTrue);
    expect(
      open.networkRequest!.state,
      SpatialNetworkRequestState.searchingProvider,
    );
  });
}

const KubusComputeCandidate _candidate = KubusComputeCandidate(
  nodeId: 'provider-1',
  label: 'Shared GPU',
  encryptionPublicKey: 'x25519-public',
  signingPublicKey: 'ed25519-public',
  gpu: <String, dynamic>{'model': 'RTX 4090'},
  worker: <String, dynamic>{'version': '1.1.5', 'tier': 'standard'},
  reliability: <String, dynamic>{'successRate': 1},
  queue: <String, dynamic>{'queuedJobs': 2, 'estimatedWaitSeconds': 300},
  rankScore: 1,
);

/// A node provider that answers discovery and job polling from a script.
///
/// Deliberately not a fake HTTP node: these tests are about what the library
/// persists and when, not about the wire protocol, which the streaming
/// transfer suite already covers end to end.
class _StubNodeProvider extends KubusNodeProvider {
  _StubNodeProvider({
    required this.candidates,
    this.jobStates = const <String>['RUNNING'],
  }) : super(service: _StubNodeService());

  List<KubusComputeCandidate> candidates;
  List<String> jobStates;
  bool throwOnDiscovery = false;
  int _polls = 0;

  @override
  bool get isPaired => true;

  @override
  Future<List<KubusComputeCandidate>> loadComputeCandidates({
    required int inputBytes,
    int minimumVramBytes = 0,
  }) async {
    if (throwOnDiscovery) throw StateError('discovery_unavailable');
    return candidates;
  }

  @override
  Future<KubusRemoteComputeJob> startRemoteReconstruction({
    required String captureId,
    required KubusComputeCandidate provider,
    required Map<String, dynamic> requirements,
  }) async =>
      const KubusRemoteComputeJob(
        id: 'remote-job-1',
        state: 'MATCHED',
        type: 'spatial.reconstruct',
        protocolVersion: '1',
        providerNodeId: 'provider-1',
      );

  @override
  Future<KubusRemoteComputeJob> refreshRemoteJob(String id) async {
    final state = jobStates[_polls.clamp(0, jobStates.length - 1)];
    _polls++;
    return KubusRemoteComputeJob(
      id: id,
      state: state,
      type: 'spatial.reconstruct',
      protocolVersion: '1',
      providerNodeId: 'provider-1',
      failure: state == 'FAILED'
          ? const <String, dynamic>{'reason': 'worker_crashed'}
          : null,
    );
  }

  @override
  Future<void> cancelRemoteJob(String id) async {}
}

/// The stub provider never reaches the wire, so the service is inert.
class _StubNodeService extends KubusNodeService {
  _StubNodeService() : super(isWeb: false);

  @override
  String? get nodeId => 'stub-node';

  @override
  bool get isPaired => true;
}

class _UnusedPublicationClient implements SpatialPublicationClient {
  @override
  Future<Map<String, dynamic>> publish({
    required Map<String, dynamic> spatial,
    required String artworkId,
    String? markerId,
  }) async =>
      throw StateError('publication is not exercised by these tests');
}
