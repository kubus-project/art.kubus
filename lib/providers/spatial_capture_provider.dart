import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'kubus_node_provider.dart';

enum SpatialCaptureState {
  idle,
  capturing,
  transferring,
  processing,
  complete,
  error
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

  SpatialCaptureState get state => _state;
  int get frameCount => _frames.length;
  double get coverage => (_frames.length / 40).clamp(0, 1);
  bool get depthObserved =>
      _frames.any((frame) => frame['depthAvailable'] == true);
  String? get captureId => _captureId;
  String? get jobId => _jobId;
  String? get error => _error;

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

  void begin(
      {required String artworkId, String? markerId, String? capturedBy}) {
    _frames.clear();
    _artworkId = artworkId;
    _markerId = markerId;
    _capturedBy = capturedBy;
    _startedAt = DateTime.now().toUtc();
    _captureId = null;
    _jobId = null;
    _error = null;
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
          'Capture at least 8 overlapping views before finishing.');
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
          utf8.encode(jsonEncode(
              {'schema': 'kubus.capture.frames/1', 'frames': samples})),
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
      if (node.snapshot?.capabilityAvailable('spatial.reconstruction') ==
          true) {
        _state = SpatialCaptureState.processing;
        final job = await node.startReconstruction(
          captureId: _captureId!,
          artworkId: _artworkId!,
          markerId: _markerId,
        );
        _jobId = job.id;
      } else {
        _state = SpatialCaptureState.complete;
      }
      notifyListeners();
    } catch (error) {
      _state = SpatialCaptureState.error;
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  void reset() {
    _frames.clear();
    _state = SpatialCaptureState.idle;
    _error = null;
    notifyListeners();
  }
}
