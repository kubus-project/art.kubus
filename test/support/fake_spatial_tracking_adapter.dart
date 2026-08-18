import 'dart:async';
import 'dart:math' as math;

import 'package:art_kubus/services/spatial_tracking_adapter.dart';
import 'package:art_kubus/services/ar_placement_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

/// Everything an AR session can be doing, from the app's point of view.
enum FakeArSessionState {
  unsupported,
  permissionRequired,
  mounting,
  initializing,
  searching,
  tracking,
  trackingLost,
  recovering,
  cameraUnavailable,
  disposed,
}

/// One node in the fake AR scene, with the transform the app last applied.
@immutable
class FakeArNode {
  const FakeArNode({
    required this.name,
    required this.modelPath,
    required this.anchor,
    required this.localScale,
    required this.localYawRadians,
  });

  final String name;
  final String modelPath;
  final ArPlacementAnchorPose anchor;
  final double localScale;
  final double localYawRadians;

  vector.Vector3 get position => anchor.position;
  vector.Vector4 get anchorRotation => anchor.rotation;
  double get scale => localScale;
  double get yawRadians => localYawRadians;

  FakeArNode copyWith({
    ArPlacementAnchorPose? anchor,
    double? localScale,
    double? localYawRadians,
  }) =>
      FakeArNode(
        name: name,
        modelPath: modelPath,
        anchor: anchor ?? this.anchor,
        localScale: localScale ?? this.localScale,
        localYawRadians: localYawRadians ?? this.localYawRadians,
      );
}

/// A controllable stand-in for a real AR session.
///
/// Lets tests drive tracking acquisition, tracking loss, camera contention,
/// transient frame misses, fatal native errors, and disposal races without a
/// device — the states that otherwise only appear on hardware.
class FakeSpatialTrackingAdapter implements SpatialTrackingAdapter {
  FakeSpatialTrackingAdapter({this.initialState = FakeArSessionState.mounting})
      : _state = initialState;

  final FakeArSessionState initialState;

  FakeArSessionState _state;
  final ValueNotifier<bool> _isTracking = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _failureReason = ValueNotifier<String?>(null);

  void Function(List<ArPlacementAnchorPose> hits)? _onSurfaceTap;
  void Function()? _onSurfaceDetected;

  /// Frames handed out by [captureFrame], in order.
  int _frameIndex = 0;

  /// Queued platform errors; each [captureFrame] consumes at most one.
  final List<Object> _pendingErrors = <Object>[];

  /// Every call recorded, so tests can assert ordering.
  final List<String> calls = <String>[];

  bool _disposed = false;
  int _disposeCount = 0;

  FakeArSessionState get state => _state;
  int get disposeCount => _disposeCount;
  bool get isDisposed => _disposed;

  // --- Session driving -----------------------------------------------------

  /// Completes initialization and begins searching for a surface.
  void completeInitialization() {
    _state = FakeArSessionState.searching;
    calls.add('initialized');
  }

  /// Acquires tracking.
  void acquireTracking() {
    _state = FakeArSessionState.tracking;
    _failureReason.value = null;
    _isTracking.value = true;
  }

  /// Loses tracking with an ARCore failure reason.
  void loseTracking({String reason = 'INSUFFICIENT_FEATURES'}) {
    _state = FakeArSessionState.trackingLost;
    _failureReason.value = reason;
    _isTracking.value = false;
  }

  /// Reports a usable surface, firing the detection callback.
  void detectSurface() {
    _onSurfaceDetected?.call();
  }

  /// Delivers a hit test result to whoever is listening.
  void tapSurface(List<ArPlacementAnchorPose> hits) {
    _onSurfaceTap?.call(hits);
  }

  /// Makes the camera unavailable, as another owner holding it would.
  void makeCameraUnavailable() {
    _state = FakeArSessionState.cameraUnavailable;
    _isTracking.value = false;
  }

  /// Queues a transient frame miss: the next capture throws
  /// `frame_not_yet_available` and later captures succeed.
  void queueTransientFrameMiss() {
    _pendingErrors.add(
      PlatformException(code: 'frame_not_yet_available'),
    );
  }

  /// Queues an unexpected native failure.
  void queueFatalCaptureError([Object? error]) {
    _pendingErrors.add(error ?? StateError('native capture failed'));
  }

  // --- SpatialTrackingAdapter ---------------------------------------------

  @override
  Future<bool> initialize() async {
    calls.add('initialize');
    if (_state == FakeArSessionState.unsupported) return false;
    if (_state == FakeArSessionState.mounting) {
      _state = FakeArSessionState.initializing;
    }
    return true;
  }

  @override
  Future<void> pauseSession() async {
    calls.add('pauseSession');
  }

  @override
  Future<void> resumeSession() async {
    calls.add('resumeSession');
  }

  @override
  Widget buildTrackedView({
    required ValueChanged<Object?> onReady,
    ValueChanged<SpatialTrackingSessionError>? onError,
    bool enableTapRecognizer = true,
    bool enablePlaneDetection = true,
  }) {
    calls.add('buildTrackedView');
    return const SizedBox.shrink();
  }

  /// Nodes currently in the fake scene, with the transform last applied.
  ///
  /// Lets a test assert that rotation and scale actually reached the platform
  /// rather than only living in Dart state.
  final Map<String, FakeArNode> nodes = <String, FakeArNode>{};

  @override
  Future<void> addModel({
    required String modelPath,
    required vector.Vector3 position,
    vector.Vector3? scale,
    double yawRadians = 0,
    String? name,
  }) async {
    if (_disposed) {
      throw StateError('addModel after dispose');
    }
    final resolved = name ?? 'node_${nodes.length}';
    nodes[resolved] = FakeArNode(
      name: resolved,
      modelPath: modelPath,
      anchor: ArPlacementAnchorPose(
        position: position,
        rotation: vector.Vector4(0, 0, 0, 1),
      ),
      localScale: scale?.x ?? 1.0,
      localYawRadians: yawRadians,
    );
    calls.add('addModel:$name@${position.x},${position.y},${position.z}');
  }

  @override
  Future<void> addAnchoredModel({
    required String modelPath,
    required ArPlacementAnchorPose anchor,
    required double localYawRadians,
    required double localScale,
    required String name,
  }) async {
    if (_disposed) throw StateError('addAnchoredModel after dispose');
    nodes[name] = FakeArNode(
      name: name,
      modelPath: modelPath,
      anchor: anchor,
      localScale: localScale,
      localYawRadians: localYawRadians,
    );
    calls.add(
        'addAnchoredModel:$name@${anchor.position.x},${anchor.position.y},${anchor.position.z}');
  }

  @override
  Future<bool> updateAnchoredNode({
    required String name,
    ArPlacementAnchorPose? anchor,
    double? localYawRadians,
    double? localScale,
  }) async {
    if (_disposed) {
      throw StateError('updateAnchoredNode after dispose');
    }
    final node = nodes[name];
    if (node == null) return false;
    nodes[name] = node.copyWith(
      anchor: anchor,
      localYawRadians: localYawRadians,
      localScale: localScale,
    );
    calls.add(
      'updateAnchoredNode:$name(anchor:${anchor != null},yaw:${localYawRadians != null},scale:${localScale != null})',
    );
    return true;
  }

  @override
  Future<void> removeNode(String name) async {
    nodes.remove(name);
    calls.add('removeNode:$name');
  }

  @override
  Future<Map<String, dynamic>> captureFrame() async {
    if (_disposed) {
      throw PlatformException(code: 'capture_cancelled');
    }
    if (_pendingErrors.isNotEmpty) {
      throw _pendingErrors.removeAt(0);
    }
    if (!_isTracking.value) {
      throw PlatformException(code: 'tracking_unavailable');
    }
    final index = _frameIndex++;
    final angle = (index / 12) * 2 * math.pi;
    calls.add('captureFrame:$index');
    return <String, dynamic>{
      'rgb': Uint8List.fromList(List<int>.filled(64, 1)),
      'timestampNanos': index,
      'poseTranslation': [math.cos(angle), 0.0, math.sin(angle)],
      'poseRotation': [0.0, math.sin(angle / 2), 0.0, math.cos(angle / 2)],
      'intrinsics': {'width': 640, 'height': 480, 'fx': 100, 'fy': 100},
      'depthAvailable': false,
    };
  }

  @override
  String get platformDescription => 'Fake AR session';

  @override
  bool get isReady =>
      !_disposed &&
      _state != FakeArSessionState.mounting &&
      _state != FakeArSessionState.initializing &&
      _state != FakeArSessionState.unsupported &&
      _state != FakeArSessionState.permissionRequired;

  @override
  ValueListenable<bool> get isTracking => _isTracking;

  @override
  ValueListenable<String?> get trackingFailureReason => _failureReason;

  @override
  set onSurfaceTap(void Function(List<ArPlacementAnchorPose> hits)? handler) {
    _onSurfaceTap = handler;
  }

  @override
  set onSurfaceDetected(void Function()? handler) {
    _onSurfaceDetected = handler;
  }

  @override
  set onSessionError(ValueChanged<SpatialTrackingSessionError>? handler) {}

  @override
  Future<void> disposeSession() async {
    calls.add('disposeSession');
    _disposeCount++;
    _disposed = true;
    _state = FakeArSessionState.disposed;
    _isTracking.value = false;
    _failureReason.value = null;
    _onSurfaceTap = null;
    _onSurfaceDetected = null;
  }

  @override
  void dispose() {
    unawaited(disposeSession());
  }
}
