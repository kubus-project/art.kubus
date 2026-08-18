import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/kubus_node_models.dart';
import 'kubus_node_provider.dart';

enum SpatialCaptureState {
  idle,
  capturing,
  transferring,
  awaitingProcessingChoice,
  queued,
  processing,
  verifying,
  reviewReady,
  complete,
  error,
}

class SpatialCaptureProvider extends ChangeNotifier {
  SpatialCaptureState _state = SpatialCaptureState.idle;
  final List<Map<String, dynamic>> _frames = [];
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
  int get frameCount => _frames.length;
  double get coverage => (_frames.length / 40).clamp(0, 1);
  bool get depthObserved =>
      _frames.any((frame) => frame['depthAvailable'] == true);
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
  int get estimatedInputBytes => _frames.fold<int>(0, (total, frame) {
        var bytes = (frame['rgb'] as Uint8List?)?.length ?? 0;
        bytes += (frame['depth'] as Uint8List?)?.length ?? 0;
        bytes += (frame['depthConfidence'] as Uint8List?)?.length ?? 0;
        return total + bytes;
      });

  String get guidance {
    if (_frames.length < 8) return 'Move slowly around the artwork.';
    if (_frames.length < 20) {
      return 'Keep the artwork in view and maintain overlap.';
    }
    if (_frames.length < 36) {
      return 'Capture the sides and details you have not covered.';
    }
    return 'Coverage is ready. You can finish or add a few more angles.';
  }

  void begin({
    required String artworkId,
    String? markerId,
    String? capturedBy,
  }) {
    _operationGeneration++;
    _frames.clear();
    _artworkId = artworkId;
    _markerId = markerId;
    _capturedBy = capturedBy;
    _startedAt = DateTime.now().toUtc();
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

  void addTrackedFrame(Map<String, dynamic> frame) {
    if (_state != SpatialCaptureState.capturing) {
      throw StateError('No spatial capture is active.');
    }
    if (frame['rgb'] is! Uint8List) {
      throw const FormatException('A tracked RGB frame is required.');
    }
    _frames.add(Map<String, dynamic>.from(frame));
    notifyListeners();
  }

  Future<void> finish(KubusNodeProvider node) async {
    if (_frames.length < 8) {
      throw StateError(
        'Capture at least 8 overlapping views before finishing.',
      );
    }
    _state = SpatialCaptureState.transferring;
    _error = null;
    notifyListeners();
    try {
      final files = <Map<String, dynamic>>[];
      final samples = <Map<String, dynamic>>[];
      for (var index = 0; index < _frames.length; index++) {
        final frame = _frames[index];
        final stem = index.toString().padLeft(5, '0');
        files.add({
          'path': 'rgb/$stem.jpg',
          'mimeType': 'image/jpeg',
          'contentBase64': base64Encode(frame['rgb'] as Uint8List),
        });
        final sample = Map<String, dynamic>.from(frame)..remove('rgb');
        for (final key in ['depth', 'depthConfidence']) {
          final bytes = sample.remove(key);
          if (bytes is Uint8List) {
            final extension = key == 'depth' ? 'depth16' : 'confidence8';
            final path = '$extension/$stem.bin';
            files.add({
              'path': path,
              'mimeType': 'application/octet-stream',
              'contentBase64': base64Encode(bytes),
            });
            sample['${key}Path'] = path;
          }
        }
        sample['rgbPath'] = 'rgb/$stem.jpg';
        samples.add(sample);
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
          'frameCount': _frames.length,
          'depthAvailable': depthObserved,
          'source': 'art.kubus-mobile-tracking',
          'private': true,
        },
        'files': files,
      });
      _captureId = record['id']?.toString();
      if (_captureId == null || _captureId!.isEmpty) {
        throw StateError('The node did not return a capture ID.');
      }
      _state = SpatialCaptureState.awaitingProcessingChoice;
      notifyListeners();
    } catch (error) {
      _state = SpatialCaptureState.error;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
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
          'frameCount': _frames.length,
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
    final dimensions = _frames.isEmpty ? null : _frames.first['imageSize'];
    if (dimensions is Map) {
      final width = double.tryParse((dimensions['width'] ?? 0).toString()) ?? 0;
      final height =
          double.tryParse((dimensions['height'] ?? 0).toString()) ?? 0;
      if (width > 0 && height > 0) {
        return width * height * _frames.length / 1000000;
      }
    }
    return _frames.length * 2;
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

  void reset() {
    _operationGeneration++;
    _frames.clear();
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
