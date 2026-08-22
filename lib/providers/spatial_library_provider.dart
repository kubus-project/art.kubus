import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../models/kubus_node_models.dart';
import '../models/spatial_capture_target.dart';
import '../services/backend_api_service.dart';
import '../services/kubus_node_service.dart';
import '../services/spatial_capture_store.dart';
import '../services/spatial_library_store.dart';
import '../services/spatial_result_importer.dart';
import 'kubus_node_provider.dart';

/// How the user's own paired Node can be reached right now.
enum SpatialOwnNodeReachability {
  /// No Node is paired to this device.
  unpaired,

  /// Reachable on the local network.
  localNetwork,

  /// Reachable over remote HTTPS. Still the user's own Node.
  remote,
}

abstract class SpatialPublicationClient {
  Future<Map<String, dynamic>> publish({
    required Map<String, dynamic> spatial,
    required String artworkId,
    String? markerId,
  });
}

class BackendSpatialPublicationClient implements SpatialPublicationClient {
  BackendSpatialPublicationClient({BackendApiService? api})
      : _api = api ?? BackendApiService();

  final BackendApiService _api;

  @override
  Future<Map<String, dynamic>> publish({
    required Map<String, dynamic> spatial,
    required String artworkId,
    String? markerId,
  }) =>
      _api.publishExistingSpatialCid(
        spatial: spatial,
        artworkId: artworkId,
        markerId: markerId,
      );
}

/// App-wide controller for private captures, processing and publication.
///
/// Capture completion itself never depends on this provider or on a Node. The
/// provider starts from already-durable records and can resume them after an
/// app restart.
class SpatialLibraryProvider extends ChangeNotifier {
  SpatialLibraryProvider({
    SpatialLibraryStore? store,
    SpatialPublicationClient? publicationClient,
    Directory? legacyCaptureRoot,
    Duration pollInterval = const Duration(seconds: 2),
    Duration providerSearchInterval = const Duration(seconds: 30),
  })  : store = store ?? SpatialLibraryStore(),
        _publicationClient =
            publicationClient ?? BackendSpatialPublicationClient(),
        _legacyCaptureRoot = legacyCaptureRoot,
        _pollInterval = pollInterval,
        _providerSearchInterval = providerSearchInterval {
    _importer = SpatialResultImporter(store: this.store);
  }

  final SpatialLibraryStore store;
  final SpatialPublicationClient _publicationClient;
  final Directory? _legacyCaptureRoot;
  final Duration _pollInterval;
  final Duration _providerSearchInterval;
  late final SpatialResultImporter _importer;
  KubusNodeProvider? _node;
  List<SpatialLibraryRecord> _records = const <SpatialLibraryRecord>[];
  bool _initialized = false;
  bool _loading = false;
  String? _error;

  /// Records whose persisted network request is currently being driven, so a
  /// resume sweep and a user tap cannot start two searches for one capture.
  final Set<String> _drivingNetworkRequests = <String>{};

  /// How long an unmatched network request stays open before it expires.
  static const Duration networkRequestLifetime = Duration(hours: 24);

  List<SpatialLibraryRecord> get records => List.unmodifiable(_records);
  bool get loading => _loading;
  String? get error => _error;

  /// One record by id, without a linear scan at every call site.
  SpatialLibraryRecord? recordFor(String localSpatialId) {
    for (final record in _records) {
      if (record.localSpatialId == localSpatialId) return record;
    }
    return null;
  }

  /// The records captured for one artwork, newest first.
  ///
  /// Resolved from each record's own `artworkId`, never from a shared
  /// selection, so one artwork's drafts cannot appear under another.
  List<SpatialLibraryRecord> recordsForArtwork(String artworkId) {
    final id = artworkId.trim();
    if (id.isEmpty) return const <SpatialLibraryRecord>[];
    return _records
        .where((record) => record.artworkId == id)
        .toList(growable: false);
  }

  /// Every local record in one capture lineage, oldest revision first.
  List<SpatialLibraryRecord> lineageOf(SpatialLibraryRecord record) {
    var root = record;
    // Walk to the oldest ancestor still on the device.
    final guard = <String>{root.localSpatialId};
    while (root.parentLocalSpatialId != null) {
      final parent = recordFor(root.parentLocalSpatialId!);
      if (parent == null || !guard.add(parent.localSpatialId)) break;
      root = parent;
    }
    final lineage = <SpatialLibraryRecord>[root];
    var changed = true;
    while (changed) {
      changed = false;
      for (final candidate in _records) {
        if (lineage
            .any((item) => item.localSpatialId == candidate.localSpatialId)) {
          continue;
        }
        final parentId = candidate.parentLocalSpatialId;
        if (parentId == null) continue;
        if (!lineage.any((item) => item.localSpatialId == parentId)) continue;
        lineage.add(candidate);
        changed = true;
      }
    }
    lineage.sort((a, b) => a.revision.compareTo(b.revision));
    return List<SpatialLibraryRecord>.unmodifiable(lineage);
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  void bindNode(KubusNodeProvider node) {
    if (identical(_node, node)) return;
    _node = node;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final legacyRoot =
        _legacyCaptureRoot ?? await SpatialCaptureStore.defaultRoot();
    await store.migrateLegacy(legacyRoot);
    await store.recoverInterruptedProcessing();
    await reload();
    // A request the user made before closing the app is still their request.
    await resumeNetworkRequests();
  }

  Future<void> reload() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _records = await store.list();
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<SpatialLibraryRecord> processWithOwnNode(
    String localSpatialId,
  ) async {
    final node = _requireNode();
    try {
      var record = await _uploadToNode(localSpatialId, node);
      if (node.snapshot?.capabilityAvailable('spatial.reconstruction') !=
          true) {
        await node.refresh();
      }
      if (node.snapshot?.capabilityAvailable('spatial.reconstruction') !=
          true) {
        throw StateError('processor_unavailable');
      }
      await store.updateProcessing(
        localSpatialId,
        SpatialLibraryProcessingState.queued,
        target: 'ownNode',
      );
      // Choosing the user's own Node retires any open network request: two
      // processors racing on one capture is never what the user asked for.
      await _retireNetworkRequest(localSpatialId);
      final job = await node.startReconstruction(
        captureId: record.nodeCaptureId!,
        artworkId: record.artworkId,
        markerId: record.markerId,
      );
      await store.recordJob(
        localSpatialId,
        jobId: job.id,
        state: SpatialLibraryProcessingState.queued,
      );
      while (true) {
        final current = await node.service.getJob(job.id);
        if (current.state == 'completed') {
          final spatialId = current.output?['id']?.toString() ?? '';
          if (spatialId.isEmpty) throw StateError('spatial_result_missing');
          record = await _importer.importFromNode(
            localSpatialId: localSpatialId,
            spatialId: spatialId,
            node: node.service,
          );
          await reload();
          return record;
        }
        if (current.state == 'failed' || current.state == 'cancelled') {
          throw StateError(
            current.error?['code']?.toString() ?? 'processing_failed',
          );
        }
        await store.updateProcessing(
          localSpatialId,
          current.state == 'queued'
              ? SpatialLibraryProcessingState.queued
              : SpatialLibraryProcessingState.processing,
          target: 'ownNode',
        );
        await Future<void>.delayed(_pollInterval);
      }
    } catch (error) {
      await _recordProcessingFailure(localSpatialId, error);
      rethrow;
    }
  }

  /// Processes on a provider the caller has already chosen, and waits.
  ///
  /// Built on the same persisted request as [requestNetworkProcessing] rather
  /// than beside it, so there is one network state machine: a caller that
  /// awaits and a caller that walks away see the same durable record.
  Future<SpatialLibraryRecord> processWithNetwork(
    String localSpatialId,
    KubusComputeCandidate provider,
  ) async {
    final now = DateTime.now().toUtc();
    final opened = SpatialNetworkRequest(
      state: SpatialNetworkRequestState.networkRequested,
      requestedAt: now,
      updatedAt: now,
      requestId: 'netreq-${now.microsecondsSinceEpoch}',
    );
    await store.recordNetworkRequest(
      localSpatialId,
      opened,
      processingState: SpatialLibraryProcessingState.waitingForProcessor,
    );
    if (!await _startRemoteJob(localSpatialId, opened, provider)) {
      throw StateError(
        (await store.get(localSpatialId))?.networkRequest?.failureCode ??
            'network_compute_failed',
      );
    }
    while (!_disposed) {
      if (await advanceNetworkRequest(localSpatialId)) break;
      await Future<void>.delayed(_pollInterval);
    }
    final settled = await store.get(localSpatialId);
    if (settled?.networkRequest?.state != SpatialNetworkRequestState.complete) {
      throw StateError(
        settled?.networkRequest?.failureCode ?? 'network_compute_failed',
      );
    }
    await reload();
    return settled!;
  }

  Future<List<KubusComputeCandidate>> loadNetworkCandidates(
    SpatialLibraryRecord record,
  ) =>
      _requireNode().loadComputeCandidates(inputBytes: record.sourceBytes);

  /// Whether the paired Node is reachable and, if so, how.
  ///
  /// "My Node over the LAN" and "my Node over HTTPS" are the same Node and the
  /// same trust relationship; only the route differs. Neither is the same as
  /// a third party's GPU, so the UI must never present them as one list of
  /// interchangeable processors.
  SpatialOwnNodeReachability get ownNodeReachability {
    final node = _node;
    if (node == null || !node.isPaired) {
      return SpatialOwnNodeReachability.unpaired;
    }
    return node.service.isEndpointOnLocalNetwork
        ? SpatialOwnNodeReachability.localNetwork
        : SpatialOwnNodeReachability.remote;
  }

  // ---------------------------------------------------------------------
  // Association and local metadata
  // ---------------------------------------------------------------------

  /// Repoints a record at a different artwork and/or marker.
  ///
  /// Refuses to touch a published record: its association is part of what the
  /// public archive claims. The caller branches a revision instead.
  Future<SpatialLibraryRecord> updateAssociation(
    String localSpatialId,
    SpatialCaptureTarget target,
  ) async {
    final record = await store.updateAssociation(
      localSpatialId,
      artworkId: target.artworkId,
      markerId: target.markerId,
      artworkTitleSnapshot: target.artworkTitleSnapshot,
      artistNameSnapshot: target.artistNameSnapshot,
      markerLabelSnapshot: target.markerLabelSnapshot,
    );
    await reload();
    return record;
  }

  /// Updates the user-authored name and note. Technical facts are not
  /// reachable from here.
  Future<SpatialLibraryRecord> updateMetadata(
    String localSpatialId, {
    String? displayName,
    String? note,
  }) async {
    final record = await store.updateLocalMetadata(
      localSpatialId,
      displayName: displayName,
      note: note,
    );
    await reload();
    return record;
  }

  /// Branches a new private draft from an existing record.
  ///
  /// The parent keeps everything it has, published archives included. The
  /// branch starts from a copy of the parent's raw source so the user extends
  /// the archive rather than restarting it.
  Future<SpatialLibraryRecord> createRevision(String localSpatialId) async {
    final record = await store.createRevision(
      localSpatialId,
      newLocalSpatialId:
          'capture-${DateTime.now().toUtc().microsecondsSinceEpoch}',
    );
    await reload();
    return record;
  }

  // ---------------------------------------------------------------------
  // Durable network compute requests
  // ---------------------------------------------------------------------

  /// Opens a durable request for network compute.
  ///
  /// Deliberately independent of whether a provider is discoverable right now:
  /// network compute is asynchronous, so "no provider answered in the last two
  /// seconds" is not a reason to withhold the option. The request is written to
  /// disk first and driven afterwards, so it survives the app being closed.
  Future<SpatialLibraryRecord> requestNetworkProcessing(
    String localSpatialId,
  ) async {
    final record = await openNetworkRequest(localSpatialId);
    unawaited(driveNetworkRequest(localSpatialId));
    return record;
  }

  /// Writes the request to disk without starting to drive it.
  ///
  /// Separated from [requestNetworkProcessing] because the durable record is
  /// the promise to the user; driving it is just how that promise gets kept.
  /// Splitting them also lets a caller step the state machine deterministically
  /// instead of racing a background loop.
  Future<SpatialLibraryRecord> openNetworkRequest(
    String localSpatialId,
  ) async {
    final current = await store.get(localSpatialId);
    if (current == null) throw StateError('record_missing');
    if (!current.rawPresent) throw StateError('raw_source_required');
    // Network processing still uploads the raw capture through the user's
    // own paired Node (see SpatialProcessSheet's doc comment), so failing
    // fast and loud here beats persisting a request that can only fail once
    // driveNetworkRequest actually reaches _startRemoteJob's _requireNode().
    _requireNode();
    final now = DateTime.now().toUtc();
    final record = await store.recordNetworkRequest(
      localSpatialId,
      SpatialNetworkRequest(
        state: SpatialNetworkRequestState.networkRequested,
        requestedAt: now,
        updatedAt: now,
        requestId: 'netreq-${now.microsecondsSinceEpoch}',
      ),
      processingState: SpatialLibraryProcessingState.waitingForProcessor,
    );
    await reload();
    return record;
  }

  /// Withdraws an open request, telling the provider where the protocol
  /// supports it.
  Future<SpatialLibraryRecord> cancelNetworkRequest(
    String localSpatialId,
  ) async {
    final current = await store.get(localSpatialId);
    if (current == null) throw StateError('record_missing');
    final request = current.networkRequest;
    if (request == null || !request.isCancellable) {
      throw StateError('request_not_cancellable');
    }
    final jobId = request.jobId;
    if (jobId != null && jobId.isNotEmpty) {
      try {
        await _requireNode().cancelRemoteJob(jobId);
      } catch (error) {
        // A provider we cannot reach cannot be told, but the user's intent is
        // still recorded locally rather than silently dropped.
        if (kDebugMode) {
          AppConfig.debugPrint(
            'SpatialLibrary: remote cancel not delivered: $error',
          );
        }
      }
    }
    final record = await store.recordNetworkRequest(
      localSpatialId,
      request.copyWith(
        state: SpatialNetworkRequestState.cancelled,
        updatedAt: DateTime.now().toUtc(),
      ),
      processingState: SpatialLibraryProcessingState.capturedPrivate,
    );
    await reload();
    return record;
  }

  /// Picks up every request left open by a previous run.
  ///
  /// Called during initialization so closing the app never loses a request:
  /// the capture still reads "Finding a processor" when the user comes back.
  Future<void> resumeNetworkRequests() async {
    for (final record in _records) {
      if (record.networkRequest?.isActive != true) continue;
      unawaited(driveNetworkRequest(record.localSpatialId));
    }
  }

  /// Longest gap between provider-discovery attempts.
  ///
  /// A request may stay open for a day. Asking every thirty seconds for that
  /// long is a radio wake-up roughly three thousand times for a question whose
  /// answer changes slowly, so unanswered searches back off.
  static const Duration maxProviderSearchInterval = Duration(minutes: 5);

  /// Drives one persisted request forward until it terminates.
  ///
  /// Guarded so a resume sweep and a user tap cannot search twice for one
  /// capture.
  Future<void> driveNetworkRequest(String localSpatialId) async {
    if (!_drivingNetworkRequests.add(localSpatialId)) return;
    try {
      var searchDelay = _providerSearchInterval;
      while (!_disposed) {
        if (await advanceNetworkRequest(localSpatialId)) return;
        final running =
            (await store.get(localSpatialId))?.networkRequest?.jobId != null;
        if (running) {
          // A job in flight reports real progress, so it is polled steadily.
          searchDelay = _providerSearchInterval;
          await Future<void>.delayed(_pollInterval);
          continue;
        }
        await Future<void>.delayed(searchDelay);
        searchDelay = _nextSearchDelay(searchDelay);
      }
    } finally {
      _drivingNetworkRequests.remove(localSpatialId);
    }
  }

  Duration _nextSearchDelay(Duration current) {
    if (current <= Duration.zero) return current;
    final doubled = current * 2;
    return doubled > maxProviderSearchInterval
        ? maxProviderSearchInterval
        : doubled;
  }

  /// Advances a persisted request by exactly one step.
  ///
  /// Returns true when there is nothing left to do — the request settled, was
  /// cancelled, or the record is gone. Re-reads the record every time, so a
  /// cancel or a delete stops the loop rather than racing it.
  @visibleForTesting
  Future<bool> advanceNetworkRequest(String localSpatialId) async {
    final record = await store.get(localSpatialId);
    final request = record?.networkRequest;
    if (record == null || request == null || !request.isActive) return true;

    // A request nobody ever took is expired rather than left open forever.
    if (DateTime.now().toUtc().difference(request.requestedAt) >
            networkRequestLifetime &&
        request.jobId == null) {
      await _finishNetworkRequest(
        localSpatialId,
        request.copyWith(
          state: SpatialNetworkRequestState.expired,
          updatedAt: DateTime.now().toUtc(),
          failureCode: 'network_request_expired',
        ),
        SpatialLibraryProcessingState.failedRetryable,
      );
      return true;
    }

    final jobId = request.jobId;
    if (jobId != null && jobId.isNotEmpty) {
      return _pollRemoteJob(localSpatialId, record, request, jobId);
    }

    final provider = await _findProvider(localSpatialId, record, request);
    // No provider right now is not a failure: the request stays open.
    if (provider == null) return false;
    return !await _startRemoteJob(localSpatialId, request, provider);
  }

  /// Looks for a provider once. Null means "none right now", not "never".
  Future<KubusComputeCandidate?> _findProvider(
    String localSpatialId,
    SpatialLibraryRecord record,
    SpatialNetworkRequest request,
  ) async {
    if (request.state != SpatialNetworkRequestState.searchingProvider) {
      await store.recordNetworkRequest(
        localSpatialId,
        request.copyWith(
          state: SpatialNetworkRequestState.searchingProvider,
          updatedAt: DateTime.now().toUtc(),
        ),
        processingState: SpatialLibraryProcessingState.waitingForProcessor,
      );
      await reload();
    }
    try {
      final candidates = await loadNetworkCandidates(record);
      return candidates.isEmpty ? null : candidates.first;
    } catch (error) {
      // An unreachable discovery service is a reason to try again later, not
      // a reason to drop the user's request.
      if (kDebugMode) {
        AppConfig.debugPrint(
          'SpatialLibrary: provider search deferred: $error',
        );
      }
      return null;
    }
  }

  /// Uploads the source and hands the job to [provider].
  ///
  /// Returns false when the loop should stop — a failure the user has to act
  /// on rather than something waiting will fix.
  Future<bool> _startRemoteJob(
    String localSpatialId,
    SpatialNetworkRequest request,
    KubusComputeCandidate provider,
  ) async {
    final offered = request.copyWith(
      state: SpatialNetworkRequestState.providerOffered,
      updatedAt: DateTime.now().toUtc(),
      providerNodeId: provider.nodeId,
      providerLabel: provider.label,
      providerTier: provider.worker['tier']?.toString(),
      queuedAhead: provider.jobsAhead,
      estimatedDurationSeconds:
          _protocolInt(provider.queue['estimatedWaitSeconds']),
      estimatedCostKub8: _protocolDouble(provider.worker['priceKub8']),
    );
    await store.recordNetworkRequest(
      localSpatialId,
      offered,
      processingState: SpatialLibraryProcessingState.waitingForProcessor,
    );
    await reload();
    try {
      final node = _requireNode();
      final record = await _uploadToNode(localSpatialId, node);
      final job = await node.startRemoteReconstruction(
        captureId: record.nodeCaptureId!,
        provider: provider,
        requirements: <String, dynamic>{
          'frameCount': record.sampleCount,
          'inputBytes': record.sourceBytes,
          'reconstructionTier': 'standard',
          'iterationTier': 'standard',
          'outputTier': 'mobile_archive',
        },
      );
      await store.recordNetworkRequest(
        localSpatialId,
        offered.copyWith(
          state: SpatialNetworkRequestState.providerAccepted,
          updatedAt: DateTime.now().toUtc(),
          jobId: job.id,
        ),
        processingState: SpatialLibraryProcessingState.queued,
      );
      await reload();
      return true;
    } catch (error) {
      await _finishNetworkRequest(
        localSpatialId,
        offered.copyWith(
          state: SpatialNetworkRequestState.failed,
          updatedAt: DateTime.now().toUtc(),
          failureCode: _failureCodeFor(error),
        ),
        SpatialLibraryProcessingState.failedRetryable,
      );
      return false;
    }
  }

  /// Advances a running remote job by one poll. True means the loop is done.
  Future<bool> _pollRemoteJob(
    String localSpatialId,
    SpatialLibraryRecord record,
    SpatialNetworkRequest request,
    String jobId,
  ) async {
    final KubusRemoteComputeJob job;
    try {
      job = await _requireNode().refreshRemoteJob(jobId);
    } catch (error) {
      // A dropped connection is not a failed job. Leave the request open so
      // the next pass — or the next launch — picks it up again.
      if (kDebugMode) {
        AppConfig.debugPrint(
          'SpatialLibrary: remote job poll deferred: $error',
        );
      }
      return false;
    }

    if (const <String>{
      'OUTPUT_READY',
      'VERIFYING',
      'VERIFIED',
      'COMPLETED',
    }.contains(job.state)) {
      await store.recordNetworkRequest(
        localSpatialId,
        request.copyWith(
          state: SpatialNetworkRequestState.downloading,
          updatedAt: DateTime.now().toUtc(),
        ),
        processingState: SpatialLibraryProcessingState.downloadingResult,
      );
      await reload();
      try {
        final node = _requireNode();
        final result = await node.retrieveRemoteResult(jobId);
        final spatialId = result['id']?.toString() ?? '';
        if (spatialId.isEmpty) throw StateError('spatial_result_missing');
        await _importer.importFromNode(
          localSpatialId: localSpatialId,
          spatialId: spatialId,
          node: node.service,
        );
        await node.acknowledgeRemoteResult(jobId, accepted: true);
        await store.recordNetworkRequest(
          localSpatialId,
          request.copyWith(
            state: SpatialNetworkRequestState.complete,
            updatedAt: DateTime.now().toUtc(),
          ),
          processingState: SpatialLibraryProcessingState.readyPrivate,
        );
        await reload();
      } catch (error) {
        await _finishNetworkRequest(
          localSpatialId,
          request.copyWith(
            state: SpatialNetworkRequestState.failed,
            updatedAt: DateTime.now().toUtc(),
            failureCode: _failureCodeFor(error),
          ),
          SpatialLibraryProcessingState.failedRetryable,
        );
      }
      return true;
    }

    if (const <String>{'DECLINED', 'EXPIRED'}.contains(job.state)) {
      await _finishNetworkRequest(
        localSpatialId,
        request.copyWith(
          state: job.state == 'EXPIRED'
              ? SpatialNetworkRequestState.expired
              : SpatialNetworkRequestState.failed,
          updatedAt: DateTime.now().toUtc(),
          failureCode: job.state == 'EXPIRED'
              ? 'network_request_expired'
              : 'provider_declined',
        ),
        SpatialLibraryProcessingState.failedRetryable,
      );
      return true;
    }

    if (const <String>{'FAILED', 'CANCELLED', 'DISPUTED'}.contains(job.state)) {
      await _finishNetworkRequest(
        localSpatialId,
        request.copyWith(
          state: job.state == 'CANCELLED'
              ? SpatialNetworkRequestState.cancelled
              : SpatialNetworkRequestState.failed,
          updatedAt: DateTime.now().toUtc(),
          failureCode:
              job.failure?['reason']?.toString() ?? 'network_compute_failed',
        ),
        job.state == 'CANCELLED'
            ? SpatialLibraryProcessingState.capturedPrivate
            : SpatialLibraryProcessingState.failedRetryable,
      );
      return true;
    }

    final next = job.state == 'RUNNING'
        ? SpatialNetworkRequestState.processing
        : SpatialNetworkRequestState.queued;
    if (next != request.state) {
      await store.recordNetworkRequest(
        localSpatialId,
        request.copyWith(state: next, updatedAt: DateTime.now().toUtc()),
        processingState: next == SpatialNetworkRequestState.processing
            ? SpatialLibraryProcessingState.processing
            : SpatialLibraryProcessingState.queued,
      );
      await reload();
    }
    return false;
  }

  Future<void> _finishNetworkRequest(
    String localSpatialId,
    SpatialNetworkRequest request,
    SpatialLibraryProcessingState processingState,
  ) async {
    await store.recordNetworkRequest(
      localSpatialId,
      request,
      processingState: processingState,
    );
    if (request.failureCode != null) {
      await store.recordFailure(localSpatialId, code: request.failureCode!);
    }
    await reload();
  }

  static int? _protocolInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  static double? _protocolDouble(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  static String _failureCodeFor(Object error) {
    if (error is KubusNodeIdentityException) return 'node_identity_mismatch';
    if (error is SpatialResultValidationException) return error.code;
    if (error is StateError) {
      final message = error.message;
      if (message.isNotEmpty) return message;
    }
    return 'network_compute_failed';
  }

  Future<SpatialContent> loadLocalContent(String localSpatialId) async {
    final record = await store.get(localSpatialId);
    if (record == null) throw StateError('record_missing');
    return _importer.loadLocalContent(record);
  }

  Future<SpatialLibraryRecord> publish(String localSpatialId) async {
    var record = await store.get(localSpatialId);
    if (record == null || !record.hasLocalResult) {
      throw StateError('ready_private_result_required');
    }
    if (record.resultStale) {
      // The scene on disk no longer describes the capture it came from.
      // Publishing it would archive a version of the artwork that never
      // existed as a single scan.
      throw StateError('result_stale_reprocess_required');
    }
    await store.recordPublication(
      localSpatialId,
      state: SpatialLibraryPublicationState.publishing,
    );
    try {
      final manifestFile = File(record.resultManifestPath!);
      final decoded = jsonDecode(await manifestFile.readAsString());
      if (decoded is! Map<String, dynamic> ||
          record.resultManifestCid == null) {
        throw StateError('local_manifest_invalid');
      }
      final publicManifest = sanitizePublicationManifest(decoded);
      if (!_deepJsonEquals(publicManifest, decoded)) {
        throw StateError('local_manifest_not_public_safe');
      }
      final result = await _publicationClient.publish(
        spatial: <String, dynamic>{
          'id': publicManifest['id'],
          'manifestCid': record.resultManifestCid,
          'manifestSizeBytes': await manifestFile.length(),
          'manifest': publicManifest,
        },
        artworkId: record.artworkId,
        markerId: record.markerId,
      );
      final publication = result['publication'] is Map
          ? Map<String, dynamic>.from(result['publication'] as Map)
          : result;
      final currentVersion = publication['currentVersion'] is Map
          ? Map<String, dynamic>.from(publication['currentVersion'] as Map)
          : <String, dynamic>{};
      final variants = <String, String>{};
      for (final item
          in currentVersion['cids'] as List<dynamic>? ?? const <dynamic>[]) {
        if (item is! Map) continue;
        final role =
            item['role']?.toString() ?? item['cidRole']?.toString() ?? '';
        final cid = item['cid']?.toString() ?? '';
        if (role.startsWith('spatial_') && cid.isNotEmpty) {
          variants[role] = cid;
        }
      }
      record = await store.recordPublication(
        localSpatialId,
        state: SpatialLibraryPublicationState.published,
        publicSpatialId:
            publication['id']?.toString() ?? publicManifest['id'].toString(),
        version: int.tryParse(
          (publication['latestVersion'] ?? currentVersion['version'] ?? 0)
              .toString(),
        ),
        canonicalManifestCid: publication['currentManifestCid']?.toString() ??
            currentVersion['manifestCid']?.toString(),
        canonicalRecordCid: publication['currentRecordCid']?.toString() ??
            currentVersion['recordCid']?.toString(),
        variantCids: variants.isEmpty
            ? Map<String, String>.from(record.variantCids)
            : variants,
        publishedAt: DateTime.tryParse(
          publication['lastPublishedAt']?.toString() ??
              currentVersion['publishedAt']?.toString() ??
              '',
        )?.toUtc(),
      );
      await reload();
      return record;
    } catch (error) {
      await store.recordPublication(
        localSpatialId,
        state: SpatialLibraryPublicationState.failed,
      );
      await store.recordFailure(localSpatialId, code: 'publication_failed');
      await reload();
      rethrow;
    }
  }

  @visibleForTesting
  static Map<String, dynamic> sanitizePublicationManifest(
    Map<String, dynamic> manifest,
  ) {
    final variants = (manifest['variants'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => <String, dynamic>{
            for (final key in const <String>{
              'role',
              'cid',
              'sizeBytes',
              'mimeType',
              'format',
              'storageClass',
            })
              if (item.containsKey(key)) key: item[key],
          },
        )
        .toList(growable: false);
    final provenance = manifest['captureProvenance'] is Map
        ? Map<String, dynamic>.from(manifest['captureProvenance'] as Map)
        : <String, dynamic>{};
    final processing = manifest['processing'] is Map
        ? Map<String, dynamic>.from(manifest['processing'] as Map)
        : <String, dynamic>{};
    final reconstruction = processing['reconstruction'] is Map
        ? Map<String, dynamic>.from(processing['reconstruction'] as Map)
        : <String, dynamic>{};
    final transform = manifest['transform'] is Map
        ? Map<String, dynamic>.from(manifest['transform'] as Map)
        : <String, dynamic>{};
    final viewerDefaults = manifest['viewerDefaults'] is Map
        ? Map<String, dynamic>.from(manifest['viewerDefaults'] as Map)
        : <String, dynamic>{};
    return <String, dynamic>{
      for (final key in const <String>{
        'schema',
        'type',
        'id',
        'artworkId',
        'markerId',
        'captureId',
        'capturedAt',
        'capturedBy',
        'createdAt',
      })
        if (manifest.containsKey(key)) key: manifest[key],
      if (provenance.isNotEmpty)
        'captureProvenance': <String, dynamic>{
          for (final key in const <String>{
            'source',
            'captureId',
            'remoteComputeJobId',
          })
            if (provenance.containsKey(key)) key: provenance[key],
        },
      if (transform.isNotEmpty)
        'transform': <String, dynamic>{
          for (final key in const <String>{'position', 'rotation', 'scale'})
            if (transform.containsKey(key)) key: transform[key],
        },
      if (viewerDefaults.isNotEmpty)
        'viewerDefaults': <String, dynamic>{
          for (final key in const <String>{
            'quality',
            'background',
            'camera',
          })
            if (viewerDefaults.containsKey(key)) key: viewerDefaults[key],
        },
      if (processing.isNotEmpty)
        'processing': <String, dynamic>{
          for (final key in const <String>{'protocol', 'workerVersion'})
            if (processing.containsKey(key)) key: processing[key],
          if (reconstruction.isNotEmpty)
            'reconstruction': <String, dynamic>{
              for (final key in const <String>{
                'engine',
                'method',
                'iterations',
                'outputFormat',
              })
                if (reconstruction.containsKey(key)) key: reconstruction[key],
            },
        },
      'variants': variants,
    };
  }

  Future<SpatialLibraryRecord> deleteRaw(String id) async {
    final record = await store.deleteRaw(id);
    await reload();
    return record;
  }

  Future<SpatialLibraryRecord> deleteProcessed(String id) async {
    final record = await store.deleteProcessed(id);
    await reload();
    return record;
  }

  Future<void> deleteRecord(String id) async {
    await store.deleteRecord(id);
    await reload();
  }

  Future<SpatialLibraryRecord> _uploadToNode(
    String localSpatialId,
    KubusNodeProvider node,
  ) async {
    var record = await store.get(localSpatialId);
    if (record == null || !record.rawPresent) {
      throw StateError('raw_source_required');
    }
    final source = await SpatialCaptureStore.open(Directory(record.sourcePath));
    if (source == null) throw StateError('raw_source_unreadable');
    final activeNodeId = node.service.nodeId;
    if (activeNodeId == null || activeNodeId.isEmpty) {
      throw StateError('node_identity_unavailable');
    }
    final sameNode = record.nodeId == activeNodeId;
    if ((record.nodeCaptureId ?? '').isNotEmpty && sameNode) return record;
    if (!sameNode &&
        ((record.nodeCaptureId ?? '').isNotEmpty ||
            (record.draftId ?? '').isNotEmpty)) {
      await source.recordDraftId(null);
      record = await store.recordNodeTransfer(
        localSpatialId,
        nodeId: activeNodeId,
        draftId: null,
        nodeCaptureId: null,
        uploadedFiles: 0,
        uploadedBytes: 0,
      );
    }
    await store.updateProcessing(
      localSpatialId,
      SpatialLibraryProcessingState.uploading,
      target: 'ownNode',
    );
    final entries = source.uploadEntries;
    var totalBytes = 0;
    for (final entry in entries) {
      final file = source.fileAt(entry.path);
      if (await file.exists()) totalBytes += await file.length();
    }

    var draftId = record.draftId ?? source.draftId;
    var uploaded = const <String>{};
    if (draftId != null) {
      try {
        uploaded = (await node.service.getCaptureDraft(draftId)).files.toSet();
      } on KubusNodeRequestException catch (error) {
        if (error.code != 'capture_draft_not_found') rethrow;
        draftId = null;
        await source.recordDraftId(null);
        await store.recordNodeTransfer(localSpatialId, draftId: null);
      }
    }
    if (draftId == null) {
      final draft = await node.service.beginCaptureDraft(<String, dynamic>{
        'schema': 'kubus.capture/1',
        'artworkId': record.artworkId,
        if (record.markerId != null) 'markerId': record.markerId,
        'capturedAt': record.capturedAt.toIso8601String(),
        'metadata': <String, dynamic>{
          'capturedBy': record.ownerId,
          'frameCount': record.sampleCount,
          'depthAvailable': record.hasDepth,
          'coverage': record.coverageMetadata,
          'quality': record.qualityMetadata,
          'source': 'art.kubus-mobile-tracking',
          'private': true,
          'localCaptureId': record.localSpatialId,
        },
      });
      draftId = draft.id;
      await source.recordDraftId(draftId);
      await store.recordNodeTransfer(
        localSpatialId,
        nodeId: node.service.nodeId,
        draftId: draftId,
        totalFiles: entries.length,
        totalBytes: totalBytes,
      );
    }
    var uploadedFiles = 0;
    var uploadedBytes = 0;
    for (final entry in entries) {
      final file = source.fileAt(entry.path);
      if (!await file.exists()) continue;
      final length = await file.length();
      if (!uploaded.contains(entry.path)) {
        await node.service.uploadCaptureDraftFile(
          draftId: draftId,
          path: entry.path,
          file: file,
          mimeType: entry.mimeType,
        );
      }
      uploadedFiles++;
      uploadedBytes += length;
      await store.recordNodeTransfer(
        localSpatialId,
        nodeId: node.service.nodeId,
        draftId: draftId,
        uploadedFiles: uploadedFiles,
        totalFiles: entries.length,
        uploadedBytes: uploadedBytes,
        totalBytes: totalBytes,
      );
    }
    final committed = await node.service.commitCaptureDraft(draftId);
    final nodeCaptureId = committed['id']?.toString() ?? '';
    if (nodeCaptureId.isEmpty) throw StateError('capture_id_missing');
    await source.markTransferred();
    record = await store.recordNodeTransfer(
      localSpatialId,
      nodeId: node.service.nodeId,
      draftId: null,
      nodeCaptureId: nodeCaptureId,
      uploadedFiles: entries.length,
      totalFiles: entries.length,
      uploadedBytes: totalBytes,
      totalBytes: totalBytes,
    );
    return record;
  }

  /// Cancels and clears an open network request, best effort.
  Future<void> _retireNetworkRequest(String localSpatialId) async {
    final record = await store.get(localSpatialId);
    final request = record?.networkRequest;
    if (request == null) return;
    if (request.isCancellable && (request.jobId ?? '').isNotEmpty) {
      try {
        await _requireNode().cancelRemoteJob(request.jobId!);
      } catch (error) {
        if (kDebugMode) {
          AppConfig.debugPrint(
            'SpatialLibrary: remote cancel not delivered: $error',
          );
        }
      }
    }
    await store.clearNetworkRequest(localSpatialId);
  }

  Future<void> _recordProcessingFailure(
    String localSpatialId,
    Object error,
  ) async {
    final identityMismatch = error is KubusNodeIdentityException;
    await store.recordFailure(
      localSpatialId,
      code: identityMismatch
          ? 'node_identity_mismatch'
          : error is SpatialResultValidationException
              ? error.code
              : 'processor_unavailable',
      waitingForProcessor:
          !identityMismatch && error is! SpatialResultValidationException,
    );
    await reload();
  }

  KubusNodeProvider _requireNode() {
    final node = _node;
    if (node == null || !node.isPaired) throw StateError('node_unavailable');
    return node;
  }
}

bool _deepJsonEquals(Object? left, Object? right) {
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final key in left.keys) {
      if (!right.containsKey(key) || !_deepJsonEquals(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_deepJsonEquals(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}
