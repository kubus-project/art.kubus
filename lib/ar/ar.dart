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
  TextEditingController _pathController = TextEditingController();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera and Storage permissions are required for AR features.")),
      );
    }
  }

  Future<void> _addGLBObjectToAR(String glbAssetPath) async {
    if (_arObjectManager == null) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("GLB file does not exist at the path: $filePath")),
      );
      return;
    }

    final node = ARNode(
      type: NodeType.webGLB,
      uri: filePath, // Use the full path for loading
      scale: vector.Vector3(1, 1, 1),
      position: vector.Vector3(0, 0, -1),
      rotation: vector.Vector4(0, 0, 0, 1),
    );
    await _arObjectManager!.addNode(node);
    activeModels.add(filePath); // Add the model to the list of active models

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("GLB file loaded successfully into AR.")),
    );
  }

  void _showActiveModels(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Active Models"),
          content: SingleChildScrollView(
            child: ListBody(
              children: activeModels.map((modelPath) => Text(modelPath)).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Close"),
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
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 1,
              onPressed: () => _showAddGLBDialog(),
              heroTag: 'loadModelFromFileFAB',
              child: const Icon(Icons.add_to_photos_outlined),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1,
            right: MediaQuery.of(context).size.width * 0.05,
            child: FloatingActionButton(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 1,
              onPressed: (null),
              heroTag: 'scanMarker',
              child: const Icon(Icons.qr_code_scanner),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1, // Adjust position as needed
            left: MediaQuery.of(context).size.width * 0.05,
            child: FloatingActionButton(
              onPressed: () => _showActiveModels(context),
              tooltip: 'Show Active Models',
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 1,
              child: Icon(Icons.list),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddGLBDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter GLB file path'),
          content: TextField(
            controller: _pathController,
            decoration: InputDecoration(
              hintText: 'GLB file path',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Load'),
              onPressed: () {
                _addGLBObjectToAR(_pathController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}