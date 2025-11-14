import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:io';

// Platform-specific imports
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
// ARKit temporarily disabled due to vector_math 2.1.4 incompatibility
// import 'package:arkit_plugin/arkit_plugin.dart';

/// Unified AR Manager providing cross-platform AR functionality
/// Uses arcore_flutter_plugin for Android
/// iOS ARKit support temporarily disabled pending package update
class ARManager {
  static final ARManager _instance = ARManager._internal();
  factory ARManager() => _instance;
  ARManager._internal();

  bool _isInitialized = false;
  ArCoreController? _arCoreController;
  // ARKitController? _arKitController; // Disabled
  final List<Map<String, dynamic>> _placedNodes = [];

  /// Initialize AR manager
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Check platform support
      if (!Platform.isAndroid && !Platform.isIOS) {
        debugPrint('ARManager: Platform not supported');
        return false;
      }

      _isInitialized = true;
      debugPrint('ARManager: Initialized successfully for $platformInfo');
      return true;
    } catch (e) {
      debugPrint('ARManager: Initialization error: $e');
      return false;
    }
  }

  /// Set ARCore controller (Android only)
  void setArCoreController(ArCoreController controller) {
    _arCoreController = controller;
    debugPrint('ARManager: ARCore controller set');
  }

  /// Set ARKit controller (iOS only) - Currently disabled
  void setArKitController(dynamic controller) {
    // _arKitController = controller;
    debugPrint('ARManager: ARKit currently disabled - iOS AR not available');
  }

  /// Add a sphere to the AR scene
  void addSphere({
    required vector.Vector3 position,
    required double radius,
    Color? color,
    String? name,
  }) {
    if (Platform.isAndroid && _arCoreController != null) {
      _addArCoreSphere(position: position, radius: radius, color: color, name: name);
    } else if (Platform.isIOS) {
      debugPrint('ARManager: iOS AR (ARKit) currently disabled');
      // _addArKitSphere(position: position, radius: radius, color: color, name: name);
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
    } else if (Platform.isIOS) {
      debugPrint('ARManager: iOS AR (ARKit) currently disabled');
      // _addArKitCube(position: position, size: size, color: color, name: name);
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
    } else if (Platform.isIOS) {
      debugPrint('ARManager: iOS AR (ARKit) currently disabled');
      // await _addArKitModel(...);
    }
  }

  /// Remove a node by name
  void removeNode(String name) {
    if (Platform.isAndroid && _arCoreController != null) {
      _arCoreController!.removeNode(nodeName: name);
    } else if (Platform.isIOS) {
      debugPrint('ARManager: iOS AR (ARKit) currently disabled');
      // _arKitController!.remove(name);
    }
    _placedNodes.removeWhere((node) => node['name'] == name);
    debugPrint('ARManager: Removed node: $name');
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
    final sphere = ArCoreSphere(
      materials: [material],
      radius: radius,
    );
    final node = ArCoreNode(
      shape: sphere,
      position: position,
      name: name,
    );
    _arCoreController!.addArCoreNode(node);
    _trackNode(name ?? 'sphere_${DateTime.now().millisecondsSinceEpoch}', 'sphere');
  }

  void _addArCoreCube({
    required vector.Vector3 position,
    required vector.Vector3 size,
    Color? color,
    String? name,
  }) {
    final material = ArCoreMaterial(
      color: color ?? Colors.red,
      metallic: 1.0,
    );
    final cube = ArCoreCube(
      materials: [material],
      size: size,
    );
    final node = ArCoreNode(
      shape: cube,
      position: position,
      name: name,
    );
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
    _trackNode(name ?? 'model_${DateTime.now().millisecondsSinceEpoch}', 'model');
  }

  // iOS ARKit specific methods - DISABLED (arkit_plugin incompatible with vector_math 2.1.4)
  /*
  void _addArKitSphere({
    required vector.Vector3 position,
    required double radius,
    Color? color,
    String? name,
  }) {
    final material = ARKitMaterial(
      diffuse: ARKitMaterialProperty.color(color ?? Colors.blue),
    );
    final sphere = ARKitSphere(
      radius: radius,
      materials: [material],
    );
    final node = ARKitNode(
      geometry: sphere,
      position: vector.Vector3(position.x, position.y, position.z),
      name: name,
    );
    _arKitController!.add(node);
    _trackNode(name ?? 'sphere_${DateTime.now().millisecondsSinceEpoch}', 'sphere');
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
    // ARKit uses USDZ format for models
    // For GLTF/GLB files, you'll need to convert them to USDZ
    // Or use ARKitReferenceNode with local assets
    final node = ARKitNode(
      position: vector.Vector3(position.x, position.y, position.z),
      scale: vector.Vector3(
        scale?.x ?? 1.0,
        scale?.y ?? 1.0,
        scale?.z ?? 1.0,
      ),
      name: name,
    );
    _arKitController!.add(node);
    _trackNode(name ?? 'model_${DateTime.now().millisecondsSinceEpoch}', 'model');
    debugPrint('ARManager: Note - ARKit requires USDZ format for 3D models');
  }
  */

  void _trackNode(String name, String type) {
    _placedNodes.add({
      'name': name,
      'type': type,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    debugPrint('ARManager: Added $type node: $name');
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
    debugPrint('ARManager: Cleared all placed nodes');
  }

  /// Check if AR is initialized
  bool get isInitialized => _isInitialized;

  /// Check if controller is ready
  bool get isControllerReady {
    if (Platform.isAndroid) {
      return _arCoreController != null;
    } else if (Platform.isIOS) {
      return false; // ARKit currently disabled
    }
    return false;
  }

  /// Get platform info
  String get platformInfo {
    if (Platform.isAndroid) {
      return 'Android (ARCore)';
    } else if (Platform.isIOS) {
      return 'iOS (ARKit - currently disabled)';
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
      );
    } else if (Platform.isIOS) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'iOS AR Currently Unavailable',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'ARKit support is temporarily disabled due to package compatibility issues. '
                'Please use an Android device for AR features.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Text('Platform not supported: ${Platform.operatingSystem}'),
    );
  }

  /// Dispose resources
  void dispose() {
    _arCoreController?.dispose();
    // _arKitController?.dispose(); // Disabled
    _placedNodes.clear();
    _arCoreController = null;
    // _arKitController = null; // Disabled
    _isInitialized = false;
    debugPrint('ARManager: Disposed');
  }
}
