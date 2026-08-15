import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import 'ar_manager.dart';

abstract class SpatialTrackingAdapter {
  Future<bool> initialize();
  Widget buildTrackedView({
    required ValueChanged<Object?> onReady,
    bool enableTapRecognizer = true,
    bool enablePlaneDetection = true,
  });
  Future<void> addModel({
    required String modelPath,
    required vector.Vector3 position,
    vector.Vector3? scale,
    String? name,
  });
  Future<Map<String, dynamic>> captureFrame();
  String get platformDescription;
  bool get isReady;
  ValueListenable<bool> get isTracking;

  /// Why tracking is currently degraded, or `null` while tracking is healthy.
  ///
  /// Platform-neutral reason strings so the UI can show one localized
  /// explanation regardless of ARCore or ARKit underneath.
  ValueListenable<String?> get trackingFailureReason;

  /// Hit-tested world positions from a tap on a tracked surface, nearest
  /// first. Empty when the tap missed every tracked surface.
  set onSurfaceTap(void Function(List<vector.Vector3> hits)? handler);

  /// Fired when the session first has a usable surface.
  set onSurfaceDetected(void Function()? handler);

  void dispose();
}

class PlatformSpatialTrackingAdapter implements SpatialTrackingAdapter {
  PlatformSpatialTrackingAdapter({ARManager? manager})
      : _manager = manager ?? ARManager();

  final ARManager _manager;

  @override
  Future<bool> initialize() => _manager.initialize();

  @override
  Widget buildTrackedView({
    required ValueChanged<Object?> onReady,
    bool enableTapRecognizer = true,
    bool enablePlaneDetection = true,
  }) =>
      _manager.createARView(
        onARViewCreated: onReady,
        enableTapRecognizer: enableTapRecognizer,
        enablePlaneDetection: enablePlaneDetection,
      );

  @override
  Future<void> addModel({
    required String modelPath,
    required vector.Vector3 position,
    vector.Vector3? scale,
    String? name,
  }) =>
      _manager.addModel(
        modelPath: modelPath,
        position: position,
        scale: scale,
        name: name,
      );

  @override
  Future<Map<String, dynamic>> captureFrame() => _manager.captureSpatialFrame();

  @override
  bool get isReady => _manager.isControllerReady;

  @override
  ValueListenable<bool> get isTracking => _manager.isTracking;

  @override
  ValueListenable<String?> get trackingFailureReason =>
      _manager.trackingFailureReason;

  @override
  set onSurfaceTap(void Function(List<vector.Vector3> hits)? handler) {
    if (handler == null) {
      _manager.onPlaneTap = null;
      return;
    }
    _manager.onPlaneTap = (hits) {
      // Nearest first: the native side has already discarded anything outside
      // a tracked plane polygon.
      final sorted = hits.toList()
        ..sort((a, b) => a.distance.compareTo(b.distance));
      handler(
          sorted.map((hit) => hit.pose.translation).toList(growable: false));
    };
  }

  @override
  set onSurfaceDetected(void Function()? handler) {
    _manager.onSurfaceDetected = handler;
  }

  @override
  String get platformDescription => _manager.platformInfo;

  @override
  void dispose() => _manager.dispose();
}
