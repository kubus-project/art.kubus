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
  ValueListenable<ArCoreTrackingState> get trackingState;
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
  ValueListenable<ArCoreTrackingState> get trackingState =>
      _manager.trackingState;

  @override
  String get platformDescription => _manager.platformInfo;

  @override
  void dispose() => _manager.dispose();
}
