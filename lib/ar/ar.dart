import 'dart:io';
import 'package:ar_flutter_plugin_flutterflow/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_flutterflow/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_flutterflow/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_flutterflow/models/ar_node.dart';
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin_flutterflow/ar_flutter_plugin.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:http/http.dart' as http;

class Augmented extends StatefulWidget {
  const Augmented({super.key});

  @override
  State<Augmented> createState() => _AugmentedState();
}

class _AugmentedState extends State<Augmented> {
  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;
  final TextEditingController _pathController = TextEditingController();
  List<String> activeModels = []; // List to keep track of active models

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    var cameraStatus = await Permission.camera.request();
    var storageStatus = await Permission.manageExternalStorage.request();
    if (!cameraStatus.isGranted || !storageStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera and Storage permissions are required for AR features.")),
      );
    }
  }

  Future<void> _addGLBObjectToAR(String glbAssetPath, vector.Vector3 position, vector.Vector4 rotation, vector.Vector3 scale) async {
    if (_arObjectManager == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("AR Object Manager is not initialized")),
      );
      return;
    }

    String filePath;
    if (glbAssetPath.startsWith('http')) {
      // It's a URL, download the file
      final response = await http.get(Uri.parse(glbAssetPath));
      if (response.statusCode == 200) {
        final documentDirectory = await getApplicationDocumentsDirectory();
        final file = File('${documentDirectory.path}/${path.basename(glbAssetPath)}');
        await file.writeAsBytes(response.bodyBytes);
        filePath = file.path;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to download GLB file from: $glbAssetPath")),
        );
        return;
      }
    } else {
      // It's a local file
      filePath = glbAssetPath;
    }

    File file = File(filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("GLB file does not exist at the path: $filePath")),
      );
      return;
    }

    final node = ARNode(
      type: NodeType.webGLB,
      uri: filePath, // Use the full path for loading
      scale: scale,
      position: position,
      rotation: rotation,
    );
    await _arObjectManager!.addNode(node);
    activeModels.add(filePath); // Add the model to the list of active models

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("GLB file loaded successfully into AR.")),
    );
  }

  void _showActiveModels(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Active Models"),
          content: SingleChildScrollView(
            child: ListBody(
              children: activeModels.map((modelPath) => Text(modelPath)).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ARView(
            onARViewCreated: (arSessionManager, arObjectManager, _, __) {
              _arSessionManager = arSessionManager;
              _arObjectManager = arObjectManager;
            },
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.18,
            left: MediaQuery.of(context).size.width * 0.05,
            child: FloatingActionButton(
              onPressed: () => _showAddGLBDialog(),
              heroTag: 'loadModelFromFileFAB',
              child: const Icon(Icons.add_to_photos_outlined),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1,
            right: MediaQuery.of(context).size.width * 0.05,
            child: const FloatingActionButton(
              onPressed: null,
              heroTag: 'scanMarker',
              child: Icon(Icons.qr_code_scanner),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1, // Adjust position as needed
            left: MediaQuery.of(context).size.width * 0.05,
            child: FloatingActionButton(
              onPressed: () => _showActiveModels(context),
              tooltip: 'Show Active Models',
              child: const Icon(Icons.list),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddGLBDialog() {
    // Controllers for position, rotation, and scale inputs
    final TextEditingController positionController = TextEditingController();
    final TextEditingController rotationController = TextEditingController();
    final TextEditingController scaleController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter GLB file path and Transformations'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: _pathController,
                  decoration: const InputDecoration(
                    hintText: 'GLB file path',
                  ),
                ),
                TextField(
                  controller: positionController,
                  decoration: const InputDecoration(
                    hintText: 'Position (x,y,z)',
                  ),
                ),
                TextField(
                  controller: rotationController,
                  decoration: const InputDecoration(
                    hintText: 'Rotation (x,y,z,w)',
                  ),
                ),
                TextField(
                  controller: scaleController,
                  decoration: const InputDecoration(
                    hintText: 'Scale (x,y,z)',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Load'),
              onPressed: () {
                // Parse inputs
                final position = vector.Vector3.zero(); // Default value
                final rotation = vector.Vector4.zero(); // Default value
                final scale = vector.Vector3.all(1); // Default value

                // Attempt to parse user input, fallback to default if parsing fails
                try {
                  final positionParts = positionController.text.split(',').map((e) => double.parse(e)).toList();
                  if (positionParts.length == 3) {
                    position.setValues(positionParts[0], positionParts[1], positionParts[2]);
                  }
                } catch (_) {
                  // Handle or ignore parsing error
                }

                try {
                  final rotationParts = rotationController.text.split(',').map((e) => double.parse(e)).toList();
                  if (rotationParts.length == 4) {
                    rotation.setValues(rotationParts[0], rotationParts[1], rotationParts[2], rotationParts[3]);
                  }
                } catch (_) {
                  // Handle or ignore parsing error
                }

                try {
                  final scaleParts = scaleController.text.split(',').map((e) => double.parse(e)).toList();
                  if (scaleParts.length == 3) {
                    scale.setValues(scaleParts[0], scaleParts[1], scaleParts[2]);
                  }
                } catch (_) {
                  // Handle or ignore parsing error
                }

                _addGLBObjectToAR(
                  _pathController.text,
                  position,
                  rotation,
                  scale,
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}