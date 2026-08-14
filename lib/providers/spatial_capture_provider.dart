import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/kubus_node_models.dart';
import '../services/spatial_capture_policy.dart';
import '../services/spatial_capture_store.dart';
import 'kubus_node_provider.dart';

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

  /// Samples the policy declined, for diagnostics.
  int get skippedSamples => _skippedSamples;
  SpatialSampleOutcome? get lastSampleOutcome => _lastOutcome;

  bool get depthObserved => _store?.depthObserved ?? false;
  bool get isCapturing => _state == SpatialCaptureState.capturing;
  bool get isPaused => _state == SpatialCaptureState.paused;

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

  String get guidance {
    if (_state == SpatialCaptureState.paused) {
      switch (_pauseReason) {
        case SpatialCapturePauseReason.trackingLost:
          return 'AR lost track of the space. Move your phone slowly to '
              'continue.';
        case SpatialCapturePauseReason.limitReached:
          return 'Capture is full. Finish to process what you have.';
        case SpatialCapturePauseReason.modeChanged:
        case SpatialCapturePauseReason.appBackgrounded:
        case SpatialCapturePauseReason.user:
        case null:
          return 'Capture is paused. Resume when you are ready.';
      }
    }
    switch (_coverage.grade) {
      case SpatialCoverageGrade.low:
        return 'Move slowly around the artwork.';
      case SpatialCoverageGrade.fair:
        return 'Keep the artwork in view and maintain overlap.';
      case SpatialCoverageGrade.good:
        return 'Capture the sides and details you have not covered.';
      case SpatialCoverageGrade.ready:
        return 'Coverage is ready. You can finish or add a few more angles.';
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
    final captureId =
        'capture-${DateTime.now().toUtc().microsecondsSinceEpoch}';
    _store = await SpatialCaptureStore.create(
      captureId: captureId,
      root: _storageRoot,
    );
    _artworkId = artworkId;
    _markerId = markerId;
    _capturedBy = capturedBy;
    _startedAt = DateTime.now().toUtc();
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
    final outcome =
        evaluateCandidate(isTracking: isTracking, candidatePose: pose);
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
    notifyListeners();
  }

  Future<void> finish(KubusNodeProvider node) async {
    final store = _store;
    if (store == null || !_coverage.isReadyToFinish) {
      throw StateError('Capture a few more angles before finishing.');
    }
    _state = SpatialCaptureState.transferring;
    _error = null;
    notifyListeners();
    try {
      await store.writeManifest(
        artworkId: _artworkId!,
        markerId: _markerId,
        capturedBy: _capturedBy,
        startedAt: _startedAt ?? DateTime.now().toUtc(),
      );

      // Read back from disk one file at a time. The raw bytes are released as
      // soon as each entry is encoded, so the capture is never held twice.
      final files = <Map<String, dynamic>>[];
      final samples = <Map<String, dynamic>>[];
      for (final sample in store.samples) {
        files.add(await _encodeFile(store, sample.rgbPath, 'image/jpeg'));
        final depthPath = sample.depthPath;
        if (depthPath != null) {
          files.add(
            await _encodeFile(store, depthPath, 'application/octet-stream'),
          );
        }
        final confidencePath = sample.confidencePath;
        if (confidencePath != null) {
          files.add(
            await _encodeFile(
              store,
              confidencePath,
              'application/octet-stream',
            ),
          );
        }
        samples.add(sample.toJson());
      }
      files.add({
        'path': 'transforms.json',
        'mimeType': 'application/json',
        'contentBase64': base64Encode(
          utf8.encode(
            jsonEncode({'schema': 'kubus.capture.frames/1', 'frames': samples}),
          ),
        ),
      });

      final record = await node.service.createCapture({
        'schema': 'kubus.capture/1',
        'artworkId': _artworkId,
        if (_markerId != null) 'markerId': _markerId,
        'capturedAt': (_startedAt ?? DateTime.now().toUtc()).toIso8601String(),
        'metadata': {
          'capturedBy': _capturedBy,
          'frameCount': store.sampleCount,
          'depthAvailable': store.depthObserved,
          'viewpointCount': _coverage.viewpointCount,
          'baselineMeters': _coverage.baselineMeters,
          'source': 'art.kubus-mobile-tracking',
          'private': true,
        },
        'files': files,
      });
      _captureId = record['id']?.toString();
      if (_captureId == null || _captureId!.isEmpty) {
        throw StateError('The node did not return a capture ID.');
      }
      // Delivered: restart recovery stops offering it, and cleanup may reclaim
      // the directory.
      await store.markTransferred();
      _state = SpatialCaptureState.awaitingProcessingChoice;
      notifyListeners();
    } catch (error) {
      // The capture stays on disk so the transfer can be retried.
      _state = SpatialCaptureState.error;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _encodeFile(
    SpatialCaptureStore store,
    String relativePath,
    String mimeType,
  ) async {
    final bytes = await store.fileAt(relativePath).readAsBytes();
    return {
      'path': relativePath,
      'mimeType': mimeType,
      'contentBase64': base64Encode(bytes),
    };
  }

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
