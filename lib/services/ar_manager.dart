import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:io';

// Platform-specific imports
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:arkit_plugin/arkit_plugin.dart';

/// Unified AR Manager providing cross-platform AR functionality
/// Uses arcore_flutter_plugin for Android
/// Uses the maintained ARKit plugin on iOS. Spatial capture exposes only the
/// sensors actually returned by each platform/device.
class ARManager {
  static final ARManager _instance = ARManager._internal();
  factory ARManager() => _instance;
  ARManager._internal();

  bool _isInitialized = false;
  ArCoreController? _arCoreController;
  final ValueNotifier<bool> isTracking = ValueNotifier(false);
  ARKitController? _arKitController;
  final List<Map<String, dynamic>> _placedNodes = [];

  /// Initialize AR manager
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Check platform support
      if (!Platform.isAndroid && !Platform.isIOS) {
        if (kDebugMode) debugPrint('ARManager: Platform not supported');
        return false;
      }

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('ARManager: Initialized successfully for $platformInfo');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('ARManager: Initialization error: $e');
      return false;
    }
  }

  /// Set ARCore controller (Android only)
  void setArCoreController(ArCoreController controller) {
    _arCoreController = controller;
    controller.onTrackingStateChanged =
        (state) => isTracking.value = state.isTracking;
    if (kDebugMode) debugPrint('ARManager: ARCore controller set');
  }

  /// Set ARKit controller (iOS only).
  void setArKitController(ARKitController controller) {
    _arKitController = controller;
    controller.onCameraDidChangeTrackingState =
        (state, reason) => isTracking.value = state == ARTrackingState.normal;
    if (kDebugMode) debugPrint('ARManager: ARKit controller set');
  }

  /// Add a sphere to the AR scene
  void addSphere({
    required vector.Vector3 position,
    required double radius,
    Color? color,
    String? name,
  }) {
    if (Platform.isAndroid && _arCoreController != null) {
      _addArCoreSphere(
        position: position,
        radius: radius,
        color: color,
        name: name,
      );
    } else if (Platform.isIOS && _arKitController != null) {
      _addArKitSphere(
        position: position,
        radius: radius,
        color: color,
        name: name,
      );
    }
  }

  /// Add a cube to the AR scene
  void addCube({
    required vector.Vector3 position,
    required vector.Vector3 size,
    Color? color,
    String? name,
  }) {
    if (Platform.isAndroid && _arCoreController != null) {
      _addArCoreCube(position: position, size: size, color: color, name: name);
    } else if (Platform.isIOS && _arKitController != null) {
      _addArKitCube(position: position, size: size, color: color, name: name);
    }
  }

  /// Add a GLTF/GLB model to the AR scene
  Future<void> addModel({
    required String modelPath,
    required vector.Vector3 position,
    vector.Vector3? scale,
    String? name,
  }) async {
    if (Platform.isAndroid && _arCoreController != null) {
      await _addArCoreModel(
        modelPath: modelPath,
        position: position,
        scale: scale,
        name: name,
      );
    } else if (Platform.isIOS && _arKitController != null) {
      await _addArKitModel(
        modelPath: modelPath,
        position: position,
        scale: scale,
        name: name,
      );
    }
  }

  /// Remove a node by name
  void removeNode(String name) {
    if (Platform.isAndroid && _arCoreController != null) {
      _arCoreController!.removeNode(nodeName: name);
    } else if (Platform.isIOS && _arKitController != null) {
      _arKitController!.remove(name);
    }
    _placedNodes.removeWhere((node) => node['name'] == name);
    if (kDebugMode) debugPrint('ARManager: Removed node: $name');
  }

  // Android ARCore specific methods
  void _addArCoreSphere({
    required vector.Vector3 position,
    required double radius,
    Color? color,
    String? name,
  }) {
    final material = ArCoreMaterial(
      color: color ?? Colors.blue,
      reflectance: 1.0,
    );
    final sphere = ArCoreSphere(materials: [material], radius: radius);
    final node = ArCoreNode(shape: sphere, position: position, name: name);
    _arCoreController!.addArCoreNode(node);
    _trackNode(
      name ?? 'sphere_${DateTime.now().millisecondsSinceEpoch}',
      'sphere',
    );
  }

  void _addArCoreCube({
    required vector.Vector3 position,
    required vector.Vector3 size,
    Color? color,
    String? name,
  }) {
    final material = ArCoreMaterial(color: color ?? Colors.red, metallic: 1.0);
    final cube = ArCoreCube(materials: [material], size: size);
    final node = ArCoreNode(shape: cube, position: position, name: name);
    _arCoreController!.addArCoreNode(node);
    _trackNode(name ?? 'cube_${DateTime.now().millisecondsSinceEpoch}', 'cube');
  }

  Future<void> _addArCoreModel({
    required String modelPath,
    required vector.Vector3 position,
    vector.Vector3? scale,
    String? name,
  }) async {
    final node = ArCoreReferenceNode(
      name: name,
      objectUrl: modelPath,
      position: position,
      scale: scale ?? vector.Vector3.all(1.0),
    );
    _arCoreController!.addArCoreNodeWithAnchor(node);
    _trackNode(
      name ?? 'model_${DateTime.now().millisecondsSinceEpoch}',
      'model',
    );
  }

  // iOS ARKit specific methods.
  void _addArKitSphere({
    required vector.Vector3 position,
    required double radius,
    Color? color,
    String? name,
  }) {
    final material = ARKitMaterial(
      diffuse: ARKitMaterialProperty.color(color ?? Colors.blue),
    );
    final sphere = ARKitSphere(radius: radius, materials: [material]);
    final node = ARKitNode(
      geometry: sphere,
      position: vector.Vector3(position.x, position.y, position.z),
      name: name,
    );
    _arKitController!.add(node);
    _trackNode(
      name ?? 'sphere_${DateTime.now().millisecondsSinceEpoch}',
      'sphere',
    );
  }

  void _addArKitCube({
    required vector.Vector3 position,
    required vector.Vector3 size,
    Color? color,
    String? name,
  }) {
    final material = ARKitMaterial(
      diffuse: ARKitMaterialProperty.color(color ?? Colors.red),
    );
    final box = ARKitBox(
      width: size.x,
      height: size.y,
      length: size.z,
      materials: [material],
    );
    final node = ARKitNode(
      geometry: box,
      position: vector.Vector3(position.x, position.y, position.z),
      name: name,
    );
    _arKitController!.add(node);
    _trackNode(name ?? 'cube_${DateTime.now().millisecondsSinceEpoch}', 'cube');
  }

  Future<void> _addArKitModel({
    required String modelPath,
    required vector.Vector3 position,
    vector.Vector3? scale,
    String? name,
  }) async {
    final node = ARKitReferenceNode(
      url: modelPath,
      position: vector.Vector3(position.x, position.y, position.z),
      scale: vector.Vector3(scale?.x ?? 1.0, scale?.y ?? 1.0, scale?.z ?? 1.0),
      name: name,
    );
    _arKitController!.add(node);
    _trackNode(
      name ?? 'model_${DateTime.now().millisecondsSinceEpoch}',
      'model',
    );
    if (kDebugMode) {
      debugPrint('ARManager: ARKit reference model added from $modelPath');
    }
  }

  /// Capture one tracked spatial sample. Android returns RGB, pose,
  /// intrinsics, and optional depth/confidence. iOS returns the same metadata
  /// available through ARKit and includes depth only on supported hardware.
  Future<Map<String, dynamic>> captureSpatialFrame() async {
    if (Platform.isAndroid && _arCoreController != null) {
      return _arCoreController!.captureSpatialFrame();
    }
    if (Platform.isIOS && _arKitController != null) {
      final snapshot = await _arKitController!.snapshotWithDepthData();
      final image = snapshot?['image'];
      final rgb = image is MemoryImage
          ? image.bytes
          : (await _arKitController!.snapshot() as MemoryImage).bytes;
      final intrinsics = await _arKitController!.getCameraIntrinsics();
      final resolution = await _arKitController!.getCameraImageResolution();
      final transform = await _arKitController!.pointOfViewTransform();
      final payload = <String, dynamic>{
        'rgb': Uint8List.fromList(rgb),
        'timestampNanos': DateTime.now().microsecondsSinceEpoch * 1000,
        'poseMatrix': transform?.storage.toList(growable: false),
        'intrinsics': {
          'width': resolution.width.round(),
          'height': resolution.height.round(),
          'matrix': intrinsics.storage.toList(growable: false),
        },
        'depthAvailable':
            snapshot != null && snapshot.keys.any((key) => key != 'image'),
      };
      if (snapshot != null) {
        for (final entry in snapshot.entries.where(
          (entry) => entry.key != 'image',
        )) {
          payload[entry.key] = entry.value;
        }
      }
      return payload;
    }
    throw StateError('Spatial tracking is not ready on this device.');
  }

  void _trackNode(String name, String type) {
    _placedNodes.add({
      'name': name,
      'type': type,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    if (kDebugMode) debugPrint('ARManager: Added $type node: $name');
  }

  /// Get list of placed nodes
  List<Map<String, dynamic>> getPlacedNodes() {
    return List.unmodifiable(_placedNodes);
  }

  /// Get number of placed nodes
  int get placedNodesCount => _placedNodes.length;

  /// Clear all placed nodes
  void clearPlacedNodes() {
    _placedNodes.clear();
    if (kDebugMode) debugPrint('ARManager: Cleared all placed nodes');
  }

  /// Check if AR is initialized
  bool get isInitialized => _isInitialized;

  /// Whether the platform AR session is genuinely usable.
  ///
  /// On Android a controller reference is not sufficient: the native ARCore
  /// session initializes asynchronously and the controller can already be
  /// torn down, so readiness comes from the controller's own lifecycle.
  bool get isControllerReady {
    if (Platform.isAndroid) {
      return _arCoreController?.isReady ?? false;
    } else if (Platform.isIOS) {
      return _arKitController != null;
    }
    return false;
  }

  /// Get platform info
  String get platformInfo {
    if (Platform.isAndroid) {
      return 'Android (ARCore)';
    } else if (Platform.isIOS) {
      return 'iOS (ARKit)';
    }
    return 'Unsupported Platform';
  }

  /// Get platform-specific view widget
  Widget createARView({
    required Function onARViewCreated,
    bool enableTapRecognizer = true,
    bool enablePlaneDetection = true,
  }) {
    if (Platform.isAndroid) {
      return ArCoreView(
        onArCoreViewCreated: (ArCoreController controller) {
          setArCoreController(controller);
          onARViewCreated();
        },
        enableTapRecognizer: enableTapRecognizer,
        enableUpdateListener: true,
      );
    } else if (Platform.isIOS) {
      return ARKitSceneView(
        onARKitViewCreated: (controller) {
          setArKitController(controller);
          onARViewCreated(controller);
        },
        configuration: ARKitConfiguration.worldTracking,
        planeDetection: enablePlaneDetection
            ? ARPlaneDetection.horizontalAndVertical
            : ARPlaneDetection.none,
        enableTapRecognizer: enableTapRecognizer,
      );
    }
    return Center(
      child: Text('Platform not supported: ${Platform.operatingSystem}'),
    );
  }

  /// Dispose resources.
  ///
  /// Awaitable so a caller handing the camera to another owner can wait for
  /// the native session to actually release it. Never throws, so callers that
  /// cannot await (a `State.dispose()`, for instance) can safely drop the
  /// future without leaving an unobserved rejection behind.
  Future<void> dispose() async {
    final arCore = _arCoreController;
    final arKit = _arKitController;
    // Drop the references before awaiting so nothing observes a
    // half-torn-down session as ready.
    _arCoreController = null;
    _arKitController = null;
    _placedNodes.clear();
    isTracking.value = false;
    _isInitialized = false;

    try {
      arKit?.dispose();
    } catch (error) {
      if (kDebugMode) debugPrint('ARManager: ARKit dispose failed: $error');
    }
    // ArCoreController.dispose() is idempotent and absorbs its own failures.
    await arCore?.dispose();
    if (kDebugMode) debugPrint('ARManager: Disposed');
  }
}
