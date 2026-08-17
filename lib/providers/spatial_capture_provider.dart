import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/kubus_node_models.dart';
import '../services/kubus_node_service.dart';
import '../services/spatial_capture_policy.dart';
import '../services/spatial_capture_store.dart';
import 'kubus_node_provider.dart';
import '../config/config.dart';

enum SpatialCaptureState {
  idle,
  capturing,

  /// Sampling is suspended but the capture is intact and resumable. Reached by
  /// leaving the capture mode, losing tracking, backgrounding the app, or
  /// hitting a capture limit.
  paused,
  transferring,
  awaitingProcessingChoice,
  queued,
  processing,
  verifying,
  reviewReady,
  complete,
  error,
}

/// Why a capture is currently paused, so the UI can give truthful guidance.
enum SpatialCapturePauseReason {
  user,
  modeChanged,
  trackingLost,
  appBackgrounded,
  limitReached,
}

/// What the capture surface should be telling the user, as structured state.
///
/// The provider deliberately returns a case rather than a sentence: user-facing
/// copy is localized in the widget layer, so capture guidance exists in every
/// supported language instead of only English.
enum SpatialCaptureGuidance {
  /// Nothing is being captured yet.
  idle,

  /// Paused because AR lost track of the space.
  trackingLost,

  /// Paused at a capture ceiling.
  limitReached,

  /// Paused for a reason the user can simply undo.
  paused,

  /// Capturing, with too little coverage to be useful yet.
  coverageLow,
  coverageFair,
  coverageGood,

  /// Enough coverage and diversity to finish.
  coverageReady,
}

/// Stage of a streaming transfer to the paired node.
enum SpatialTransferPhase { idle, preparing, uploading, committing, complete }

/// Honest progress of a streaming capture transfer.
///
/// Every field is measured, never interpolated: the file counts come from the
/// upload loop and the byte totals from the files actually on disk.
@immutable
class SpatialTransferProgress {
  const SpatialTransferProgress({
    this.phase = SpatialTransferPhase.idle,
    this.uploadedFiles = 0,
    this.totalFiles = 0,
    this.uploadedBytes = 0,
    this.totalBytes = 0,
  });

  final SpatialTransferPhase phase;
  final int uploadedFiles;
  final int totalFiles;
  final int uploadedBytes;
  final int totalBytes;

  bool get isActive =>
      phase != SpatialTransferPhase.idle &&
      phase != SpatialTransferPhase.complete;

  /// Fraction of bytes delivered, or `null` while the total is not yet known.
  double? get fraction {
    if (totalBytes <= 0) return null;
    return (uploadedBytes / totalBytes).clamp(0.0, 1.0);
  }
}

/// A capture cannot be finished because it does not yet cover enough of the
/// subject. Typed so the UI shows coverage guidance rather than an error.
class SpatialCaptureNotReadyException implements Exception {
  const SpatialCaptureNotReadyException();

  @override
  String toString() => 'SpatialCaptureNotReadyException';
}

class SpatialCaptureProvider extends ChangeNotifier {
  SpatialCaptureProvider({
    SpatialCapturePolicy policy = const SpatialCapturePolicy(),
    Directory? storageRoot,
  })  : _policy = policy,
        _storageRoot = storageRoot,
        _gate = SpatialSamplingGate(policy: policy) {
    _coverage = SpatialCoverageAccumulator(policy: policy);
  }

  final SpatialCapturePolicy _policy;
  final Directory? _storageRoot;
  final SpatialSamplingGate _gate;
  late final SpatialCoverageAccumulator _coverage;

  SpatialCaptureState _state = SpatialCaptureState.idle;
  SpatialCaptureStore? _store;
  SpatialPose? _lastAcceptedPose;
  DateTime? _lastAcceptedAt;
  bool _requestInFlight = false;
  SpatialSampleOutcome? _lastOutcome;
  SpatialCapturePauseReason? _pauseReason;
  int _skippedSamples = 0;
  SpatialTransferProgress _transfer = const SpatialTransferProgress();

  String? _artworkId;
  String? _markerId;
  String? _capturedBy;
  DateTime? _startedAt;
  String? _captureId;
  String? _jobId;
  String? _error;
  String? _spatialId;
  Map<String, dynamic>? _remoteResult;
  String? _remoteJobState;
  String? _localJobState;
  double _localJobProgress = 0;
  int _operationGeneration = 0;

  SpatialCaptureState get state => _state;
  SpatialCapturePolicy get policy => _policy;
  SpatialCapturePauseReason? get pauseReason => _pauseReason;

  /// Samples durably written to disk.
  int get frameCount => _store?.sampleCount ?? 0;

  /// Bytes committed to disk. Not a RAM figure: payload is spooled out as it
  /// is produced.
  int get estimatedInputBytes => _store?.bytesWritten ?? 0;

  /// Viewpoint-diversity progress, not a frame-count ratio.
  double get coverage => _coverage.progress;
  SpatialCoverageGrade get coverageGrade => _coverage.grade;
  int get viewpointCount => _coverage.viewpointCount;
  double get baselineMeters => _coverage.baselineMeters;

  /// Measured progress of the streaming transfer to the paired node.
  SpatialTransferProgress get transfer => _transfer;

  /// Samples the policy declined, for diagnostics.
  int get skippedSamples => _skippedSamples;
  SpatialSampleOutcome? get lastSampleOutcome => _lastOutcome;

  bool get depthObserved => _store?.depthObserved ?? false;
  bool get isCapturing => _state == SpatialCaptureState.capturing;
  bool get isPaused => _state == SpatialCaptureState.paused;

  /// Who the capture belongs to, used to scope restart recovery to the
  /// signed-in account.
  String? get capturedBy => _capturedBy;

  /// Whether the capture has enough volume *and* viewpoint diversity to make a
  /// usable reconstruction.
  bool get canFinish =>
      (_state == SpatialCaptureState.capturing ||
          _state == SpatialCaptureState.paused) &&
      _coverage.isReadyToFinish;

  String? get captureId => _captureId;
  String? get jobId => _jobId;
  String? get error => _error;
  String? get spatialId => _spatialId;
  String? get artworkId => _artworkId;
  String? get markerId => _markerId;
  Map<String, dynamic>? get remoteResult => _remoteResult;
  String? get remoteJobState => _remoteJobState;
  String? get localJobState => _localJobState;
  double get localJobProgress => _localJobProgress;
  @visibleForTesting
  int get operationGeneration => _operationGeneration;

  /// Structured guidance for the current capture state.
  ///
  /// Returns a case, not a sentence. The AR screen maps it through
  /// [AppLocalizations], so every guidance path exists in EN and SL.
  SpatialCaptureGuidance get guidance {
    if (_state == SpatialCaptureState.paused) {
      switch (_pauseReason) {
        case SpatialCapturePauseReason.trackingLost:
          return SpatialCaptureGuidance.trackingLost;
        case SpatialCapturePauseReason.limitReached:
          return SpatialCaptureGuidance.limitReached;
        case SpatialCapturePauseReason.modeChanged:
        case SpatialCapturePauseReason.appBackgrounded:
        case SpatialCapturePauseReason.user:
        case null:
          return SpatialCaptureGuidance.paused;
      }
    }
    if (_state != SpatialCaptureState.capturing) {
      return SpatialCaptureGuidance.idle;
    }
    switch (_coverage.grade) {
      case SpatialCoverageGrade.low:
        return SpatialCaptureGuidance.coverageLow;
      case SpatialCoverageGrade.fair:
        return SpatialCaptureGuidance.coverageFair;
      case SpatialCoverageGrade.good:
        return SpatialCaptureGuidance.coverageGood;
      case SpatialCoverageGrade.ready:
        return SpatialCaptureGuidance.coverageReady;
    }
  }

  /// Starts a capture, opening its on-disk directory.
  Future<void> begin({
    required String artworkId,
    String? markerId,
    String? capturedBy,
  }) async {
    _operationGeneration++;
    await _store?.discard();
    _coverage.reset();
    final startedAt = DateTime.now().toUtc();
    final captureId = 'capture-${startedAt.microsecondsSinceEpoch}';
    // The store records the capture on disk immediately, so a process killed
    // during capture still leaves a directory recovery can find and offer back.
    _store = await SpatialCaptureStore.create(
      captureId: captureId,
      artworkId: artworkId,
      markerId: markerId,
      capturedBy: capturedBy,
      startedAt: startedAt,
      root: _storageRoot,
    );
    _startedAt = startedAt;
    _artworkId = artworkId;
    _markerId = markerId;
    _capturedBy = capturedBy;
    _lastAcceptedPose = null;
    _lastAcceptedAt = null;
    _requestInFlight = false;
    _lastOutcome = null;
    _pauseReason = null;
    _skippedSamples = 0;
    _captureId = null;
    _jobId = null;
    _error = null;
    _spatialId = null;
    _remoteResult = null;
    _remoteJobState = null;
    _localJobState = null;
    _localJobProgress = 0;
    _state = SpatialCaptureState.capturing;
    notifyListeners();
  }

  /// Capture directories left behind by an interrupted session.
  ///
  /// Only captures belonging to [capturedBy] are offered, so one account's
  /// work is never handed to whoever signs in next on a shared device.
  Future<List<InterruptedSpatialCapture>> findRecoverable({
    required String capturedBy,
  }) async {
    if (capturedBy.trim().isEmpty) {
      return const <InterruptedSpatialCapture>[];
    }
    final captures =
        await SpatialCaptureStore.findInterrupted(root: _storageRoot);
    return captures
        .where((capture) =>
            capture.hasRecoverableWork && capture.capturedBy == capturedBy)
        .toList(growable: false);
  }

  /// Adopts an interrupted capture so the user can keep working on it.
  ///
  /// The capture returns as `paused`, never as `capturing`: sampling only
  /// restarts once the screen has AR tracking again.
  Future<bool> resumeInterrupted(InterruptedSpatialCapture capture) async {
    final store = await SpatialCaptureStore.open(capture.directory);
    if (store == null || store.sampleCount == 0) return false;

    _operationGeneration++;
    await _store?.discard();
    _store = store;
    _coverage.reset();
    // Rebuild coverage from the poses already on disk, so a resumed capture
    // reports the diversity it actually has rather than starting from zero.
    for (final sample in store.samples) {
      final pose = SpatialPose.tryFromFramePayload(sample.metadata);
      if (pose != null) _coverage.addAccepted(pose);
    }
    _artworkId = store.artworkId;
    _markerId = store.markerId;
    _capturedBy = store.capturedBy;
    _startedAt = store.startedAt;
    _lastAcceptedPose = null;
    _lastAcceptedAt = null;
    _requestInFlight = false;
    _lastOutcome = null;
    _skippedSamples = 0;
    _captureId = null;
    _jobId = null;
    _error = null;
    _spatialId = null;
    _remoteResult = null;
    _remoteJobState = null;
    _localJobState = null;
    _localJobProgress = 0;
    _transfer = const SpatialTransferProgress();
    _state = SpatialCaptureState.paused;
    _pauseReason = SpatialCapturePauseReason.user;
    notifyListeners();
    return true;
  }

  /// Deletes an interrupted capture the user chose not to keep.
  Future<void> discardInterrupted(InterruptedSpatialCapture capture) async {
    if (_store?.directory.path == capture.directory.path) {
      await discard();
      return;
    }
    try {
      await capture.directory.delete(recursive: true);
    } catch (error) {
      if (kDebugMode) {
        AppConfig.debugPrint('SpatialCaptureProvider: discard failed: $error');
      }
    }
  }

  /// Whether the sampler should ask the platform for another frame right now.
  ///
  /// Cheap and synchronous, so the sampling loop can consult it every tick
  /// without touching the camera.
  SpatialSampleOutcome evaluateCandidate({
    required bool isTracking,
    SpatialPose? candidatePose,
  }) {
    return _gate.evaluate(
      isCapturing: _state == SpatialCaptureState.capturing,
      isTracking: isTracking,
      hasRequestInFlight: _requestInFlight,
      progress: _progressSnapshot(),
      candidatePose: candidatePose,
    );
  }

  SpatialCaptureProgress _progressSnapshot() {
    final startedAt = _startedAt;
    final lastAt = _lastAcceptedAt;
    final now = DateTime.now().toUtc();
    return SpatialCaptureProgress(
      acceptedSamples: frameCount,
      captureBytes: estimatedInputBytes,
      elapsed: startedAt == null ? Duration.zero : now.difference(startedAt),
      pendingWrites: _store?.pendingWrites ?? 0,
      sinceLastAccepted: lastAt == null ? null : now.difference(lastAt),
      lastAcceptedPose: _lastAcceptedPose,
    );
  }

  /// Marks a platform capture request as in flight so the gate does not start
  /// a second one.
  void markRequestInFlight() => _requestInFlight = true;
  void clearRequestInFlight() => _requestInFlight = false;

  /// Offers a captured frame to the policy, writing it to disk if accepted.
  ///
  /// Returns the outcome so the caller can surface guidance and diagnostics.
  /// Never throws for an ordinary skip; a skipped frame is normal operation.
  Future<SpatialSampleOutcome> offerFrame(
    Map<String, dynamic> frame, {
    required bool isTracking,
  }) async {
    final rgb = frame['rgb'];
    if (rgb is! Uint8List) {
      throw const FormatException('A tracked RGB frame is required.');
    }
    final pose = SpatialPose.tryFromFramePayload(frame);
    // The in-flight guard exists to stop a *second* platform request starting
    // while one is outstanding. This frame is already in hand, so applying the
    // guard here would reject the very sample it was protecting.
    final outcome = _gate.evaluate(
      isCapturing: _state == SpatialCaptureState.capturing,
      isTracking: isTracking,
      hasRequestInFlight: false,
      progress: _progressSnapshot(),
      candidatePose: pose,
    );
    _lastOutcome = outcome;

    if (outcome != SpatialSampleOutcome.accepted) {
      _skippedSamples++;
      // A capture that hit a ceiling stops sampling but keeps everything it
      // already recorded, so the user can still finish.
      if (outcome.isLimit && _state == SpatialCaptureState.capturing) {
        pause(SpatialCapturePauseReason.limitReached);
      } else {
        notifyListeners();
      }
      return outcome;
    }

    final store = _store;
    if (store == null) return SpatialSampleOutcome.captureInactive;

    final metadata = Map<String, dynamic>.from(frame)
      ..remove('rgb')
      ..remove('depth')
      ..remove('depthConfidence');

    await store.writeSample(
      rgb: rgb,
      depth: frame['depth'] as Uint8List?,
      confidence: frame['depthConfidence'] as Uint8List?,
      metadata: metadata,
    );

    if (pose != null) {
      _coverage.addAccepted(pose);
      _lastAcceptedPose = pose;
    }
    _lastAcceptedAt = DateTime.now().toUtc();
    notifyListeners();
    return outcome;
  }

  /// Suspends sampling without destroying the capture.
  ///
  /// Leaving the capture mode, losing tracking, or backgrounding the app must
  /// never strand the provider in `capturing` with no sampler running.
  void pause(SpatialCapturePauseReason reason) {
    if (_state != SpatialCaptureState.capturing) return;
    _state = SpatialCaptureState.paused;
    _pauseReason = reason;
    _requestInFlight = false;
    notifyListeners();
  }

  /// Resumes a paused capture. Everything recorded so far is retained.
  void resume() {
    if (_state != SpatialCaptureState.paused) return;
    _state = SpatialCaptureState.capturing;
    _pauseReason = null;
    _requestInFlight = false;
    // Force the next frame past the cadence gate so resuming feels immediate.
    _lastAcceptedAt = null;
    notifyListeners();
  }

  /// Abandons the capture and deletes its files. Explicit user intent only.
  Future<void> discard() async {
    _operationGeneration++;
    await _store?.discard();
    _store = null;
    _coverage.reset();
    _lastAcceptedPose = null;
    _lastAcceptedAt = null;
    _requestInFlight = false;
    _pauseReason = null;
    _skippedSamples = 0;
    _state = SpatialCaptureState.idle;
    _error = null;
    _transfer = const SpatialTransferProgress();
    notifyListeners();
  }

  /// Streams the capture to the paired node and finalizes it there.
  ///
  /// Files travel as raw bytes into a node-side draft, one at a time, straight
  /// off disk. Nothing assembles the capture into a single in-memory document:
  /// the previous base64 package inflated the payload by a third and required
  /// both ends to hold every frame at once, which a continuous mobile capture
  /// cannot afford.
  ///
  /// An interrupted transfer resumes against the same draft, so a retry
  /// re-sends only what is missing and never creates a second durable record.
  Future<void> finish(KubusNodeProvider node) async {
    final store = _store;
    if (store == null || !_coverage.isReadyToFinish) {
      throw const SpatialCaptureNotReadyException();
    }
    _state = SpatialCaptureState.transferring;
    _error = null;
    _transfer = const SpatialTransferProgress(
      phase: SpatialTransferPhase.preparing,
    );
    notifyListeners();
    try {
      await _streamToNode(node, store);
      _state = SpatialCaptureState.awaitingProcessingChoice;
      notifyListeners();
    } catch (error) {
      // The capture stays on disk so the transfer can be retried.
      _state = SpatialCaptureState.error;
      _error = _describe(error);
      _transfer = const SpatialTransferProgress();
      notifyListeners();
      rethrow;
    }
  }

  /// Resumes a transfer that failed, without recapturing anything.
  Future<void> retryTransfer(KubusNodeProvider node) async {
    if (_state != SpatialCaptureState.error) return;
    final store = _store;
    if (store == null) return;
    _state = SpatialCaptureState.transferring;
    _error = null;
    _transfer = const SpatialTransferProgress(
      phase: SpatialTransferPhase.preparing,
    );
    notifyListeners();
    try {
      await _streamToNode(node, store);
      _state = SpatialCaptureState.awaitingProcessingChoice;
      notifyListeners();
    } catch (error) {
      _state = SpatialCaptureState.error;
      _error = _describe(error);
      _transfer = const SpatialTransferProgress();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _streamToNode(
    KubusNodeProvider node,
    SpatialCaptureStore store,
  ) async {
    // Persist the canonical frame index before anything leaves the device, so
    // an interrupted transfer still has a complete local record.
    await store.writeManifest(
      extra: <String, dynamic>{
        'viewpointCount': _coverage.viewpointCount,
        'baselineMeters': _coverage.baselineMeters,
      },
    );

    final entries = store.uploadEntries;
    var totalBytes = 0;
    for (final entry in entries) {
      final file = store.fileAt(entry.path);
      if (await file.exists()) totalBytes += await file.length();
    }

    // Resume against an existing draft when one survived, so the retry sends
    // only the files that never landed.
    var draftId = store.draftId;
    var alreadyUploaded = const <String>{};
    if (draftId != null) {
      try {
        final progress = await node.service.getCaptureDraft(draftId);
        alreadyUploaded = progress.files.toSet();
      } catch (_) {
        // The node forgot the draft (a restart drops them). Start a new one
        // rather than committing a half-delivered capture.
        draftId = null;
        await store.recordDraftId(null);
      }
    }

    if (draftId == null) {
      final draft = await node.service.beginCaptureDraft(<String, dynamic>{
        'schema': 'kubus.capture/1',
        'artworkId': store.artworkId,
        if (store.markerId != null) 'markerId': store.markerId,
        'capturedAt': store.startedAt.toIso8601String(),
        'metadata': <String, dynamic>{
          'capturedBy': store.capturedBy,
          'frameCount': store.sampleCount,
          'depthAvailable': store.depthObserved,
          'viewpointCount': _coverage.viewpointCount,
          'baselineMeters': _coverage.baselineMeters,
          'source': 'art.kubus-mobile-tracking',
          'private': true,
        },
      });
      draftId = draft.id;
      // Record before the first byte moves: a crash mid-upload must leave a
      // draft the next attempt can find instead of orphaning it on the node.
      await store.recordDraftId(draftId);
    }

    var uploadedFiles = 0;
    var uploadedBytes = 0;
    _transfer = SpatialTransferProgress(
      phase: SpatialTransferPhase.uploading,
      totalFiles: entries.length,
      totalBytes: totalBytes,
    );
    notifyListeners();

    for (final entry in entries) {
      final file = store.fileAt(entry.path);
      if (!await file.exists()) continue;
      final length = await file.length();
      if (!alreadyUploaded.contains(entry.path)) {
        await node.service.uploadCaptureDraftFile(
          draftId: draftId,
          path: entry.path,
          file: file,
          mimeType: entry.mimeType,
        );
      }
      uploadedFiles++;
      uploadedBytes += length;
      _transfer = SpatialTransferProgress(
        phase: SpatialTransferPhase.uploading,
        uploadedFiles: uploadedFiles,
        totalFiles: entries.length,
        uploadedBytes: uploadedBytes,
        totalBytes: totalBytes,
      );
      notifyListeners();
    }

    _transfer = SpatialTransferProgress(
      phase: SpatialTransferPhase.committing,
      uploadedFiles: uploadedFiles,
      totalFiles: entries.length,
      uploadedBytes: uploadedBytes,
      totalBytes: totalBytes,
    );
    notifyListeners();

    final record = await node.service.commitCaptureDraft(draftId);
    final captureId = record['id']?.toString();
    if (captureId == null || captureId.isEmpty) {
      throw const KubusNodeRequestException(
        statusCode: 200,
        code: 'capture_id_missing',
      );
    }
    _captureId = captureId;
    // Delivered: restart recovery stops offering it, and cleanup may reclaim
    // the directory.
    await store.markTransferred();
    _transfer = SpatialTransferProgress(
      phase: SpatialTransferPhase.complete,
      uploadedFiles: uploadedFiles,
      totalFiles: entries.length,
      uploadedBytes: uploadedBytes,
      totalBytes: totalBytes,
    );
  }

  /// Diagnostic text for logs and the debug surface. Never shown to the user:
  /// the UI maps [state] and the typed exception to localized copy.
  static String _describe(Object error) => error.toString();

  Future<void> processLocally(KubusNodeProvider node) async {
    if (_state != SpatialCaptureState.awaitingProcessingChoice ||
        (_captureId ?? '').isEmpty) {
      throw StateError('Transfer a spatial capture before processing it.');
    }
    if (node.snapshot?.capabilityAvailable('spatial.reconstruction') != true) {
      throw StateError('No compatible local GPU worker is available.');
    }
    _state = SpatialCaptureState.processing;
    _localJobState = 'queued';
    _localJobProgress = 0;
    final generation = _operationGeneration;
    _error = null;
    notifyListeners();
    try {
      final job = await node.startReconstruction(
        captureId: _captureId!,
        artworkId: _artworkId!,
        markerId: _markerId,
      );
      if (generation != _operationGeneration) return;
      _jobId = job.id;
      await _observeJob(node, job.id, generation);
    } catch (error) {
      if (generation != _operationGeneration) return;
      _state = SpatialCaptureState.error;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> processOnNetwork(
    KubusNodeProvider node,
    KubusComputeCandidate provider,
  ) async {
    if (_state != SpatialCaptureState.awaitingProcessingChoice ||
        (_captureId ?? '').isEmpty) {
      throw StateError('Transfer a spatial capture before processing it.');
    }
    _state = SpatialCaptureState.transferring;
    _remoteJobState = 'REQUESTED';
    final generation = _operationGeneration;
    _error = null;
    notifyListeners();
    try {
      final job = await node.startRemoteReconstruction(
        captureId: _captureId!,
        provider: provider,
        requirements: {
          'frameCount': frameCount,
          'inputBytes': estimatedInputBytes,
          'sourceMegapixels': _estimateSourceMegapixels(),
          'reconstructionTier': 'standard',
          'iterationTier': 'standard',
          'outputTier': 'mobile_archive',
        },
      );
      if (generation != _operationGeneration) {
        await node.cancelRemoteJob(job.id);
        return;
      }
      _jobId = job.id;
      await _observeRemoteJob(node, job.id, generation);
    } catch (error) {
      if (generation != _operationGeneration) return;
      _state = SpatialCaptureState.error;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> approveRemoteResult(KubusNodeProvider node) async {
    if (_state != SpatialCaptureState.reviewReady || (_jobId ?? '').isEmpty) {
      throw StateError('No network result is ready for review.');
    }
    await node.acknowledgeRemoteResult(_jobId!, accepted: true);
    _state = SpatialCaptureState.complete;
    notifyListeners();
  }

  Future<void> rejectRemoteResult(
    KubusNodeProvider node, {
    String reason = 'requester_rejected_result',
  }) async {
    if ((_jobId ?? '').isEmpty) return;
    await node.acknowledgeRemoteResult(
      _jobId!,
      accepted: false,
      reason: reason,
    );
    _state = SpatialCaptureState.complete;
    notifyListeners();
  }

  double _estimateSourceMegapixels() {
    // Sample metadata carries the camera intrinsics the native capture
    // reported, so source resolution survives the move to disk-backed storage.
    final samples = _store?.samples ?? const <SpatialSampleRecord>[];
    final dimensions = samples.isEmpty
        ? null
        : (samples.first.metadata['intrinsics'] ??
            samples.first.metadata['imageSize']);
    if (dimensions is Map) {
      final width = double.tryParse((dimensions['width'] ?? 0).toString()) ?? 0;
      final height =
          double.tryParse((dimensions['height'] ?? 0).toString()) ?? 0;
      if (width > 0 && height > 0) {
        return width * height * samples.length / 1000000;
      }
    }
    return samples.length * 2;
  }

  Future<void> _observeRemoteJob(
    KubusNodeProvider node,
    String jobId,
    int generation,
  ) async {
    final deadline = DateTime.now().add(const Duration(hours: 2));
    while (DateTime.now().isBefore(deadline)) {
      if (generation != _operationGeneration || _jobId != jobId) return;
      final job = await node.refreshRemoteJob(jobId);
      if (generation != _operationGeneration || _jobId != jobId) return;
      _remoteJobState = job.state;
      switch (job.state) {
        case 'REQUESTED':
        case 'MATCHED':
        case 'ACCEPTED':
        case 'INPUT_READY':
          _state = SpatialCaptureState.queued;
          break;
        case 'RUNNING':
          _state = SpatialCaptureState.processing;
          break;
        case 'OUTPUT_READY':
        case 'VERIFYING':
        case 'VERIFIED':
        case 'COMPLETED':
          _state = SpatialCaptureState.verifying;
          _remoteJobState = 'RECEIVING';
          notifyListeners();
          final result = await node.retrieveRemoteResult(jobId);
          if (generation != _operationGeneration || _jobId != jobId) return;
          _remoteResult = result;
          _spatialId = (_remoteResult?['id'] ?? '').toString();
          _state = SpatialCaptureState.reviewReady;
          notifyListeners();
          return;
        case 'DECLINED':
        case 'EXPIRED':
        case 'FAILED':
        case 'CANCELLED':
        case 'DISPUTED':
          throw StateError(
            job.failure?['reason']?.toString() ??
                'Network processing ${job.state.toLowerCase()}.',
          );
      }
      notifyListeners();
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    throw TimeoutException('Network processing did not finish in 2 hours.');
  }

  Future<void> _observeJob(
    KubusNodeProvider node,
    String jobId,
    int generation,
  ) async {
    final deadline = DateTime.now().add(const Duration(minutes: 45));
    while (DateTime.now().isBefore(deadline)) {
      if (generation != _operationGeneration || _jobId != jobId) return;
      final job = await node.service.getJob(jobId);
      if (generation != _operationGeneration || _jobId != jobId) return;
      _localJobState = job.state;
      _localJobProgress = job.progress;
      switch (job.state) {
        case 'completed':
          _spatialId = (job.output?['id'] ?? '').toString();
          await node.refresh();
          if (generation != _operationGeneration || _jobId != jobId) return;
          _state = SpatialCaptureState.complete;
          notifyListeners();
          return;
        case 'failed':
        case 'cancelled':
          throw StateError(
            job.error?['message']?.toString() ??
                'Spatial processing ${job.state}.',
          );
      }
      notifyListeners();
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    throw TimeoutException('Spatial processing did not finish in 45 minutes.');
  }

  /// Returns to idle, releasing the capture directory.
  ///
  /// Files are only deleted for a capture that never reached the node, so a
  /// delivered capture stays recoverable until cleanup reclaims it.
  Future<void> reset() async {
    _operationGeneration++;
    final store = _store;
    _store = null;
    if (store != null && (_captureId ?? '').isEmpty) {
      await store.discard();
    }
    _coverage.reset();
    _lastAcceptedPose = null;
    _lastAcceptedAt = null;
    _requestInFlight = false;
    _pauseReason = null;
    _skippedSamples = 0;
    _state = SpatialCaptureState.idle;
    _error = null;
    _remoteResult = null;
    _spatialId = null;
    _remoteJobState = null;
    _localJobState = null;
    _localJobProgress = 0;
    _transfer = const SpatialTransferProgress();
    notifyListeners();
  }

  void prepareRetry() {
    if ((_captureId ?? '').isEmpty) return;
    _operationGeneration++;
    _jobId = null;
    _error = null;
    _remoteResult = null;
    _spatialId = null;
    _remoteJobState = null;
    _localJobState = null;
    _localJobProgress = 0;
    _state = SpatialCaptureState.awaitingProcessingChoice;
    notifyListeners();
  }
}
