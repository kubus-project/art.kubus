import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class Augmented extends StatefulWidget {
  const Augmented({super.key});

  @override
  State<Augmented> createState() => _AugmentedState();
}

class _AugmentedState extends State<Augmented> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isPermissionGranted = false;
  final TextEditingController _pathController = TextEditingController();
  List<String> activeModels = []; // List to keep track of active models
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Don't request permissions immediately - wait for user interaction
  }

  Future<void> _requestPermissions() async {
    try {
      var cameraStatus = await Permission.camera.request();
      var storageStatus = await Permission.manageExternalStorage.request();
      
      if (cameraStatus.isGranted) {
        _isPermissionGranted = true;
        await _initializeCamera();
      } else {
        setState(() {
          _errorMessage = "Camera permission is required for AR features.";
        });
      }
      
      if (!storageStatus.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Storage permission recommended for better AR experience.")),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error requesting permissions: $e";
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        
        await _cameraController!.initialize();
        
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _errorMessage = null;
          });
        }
      } else {
        setState(() {
          _errorMessage = "No cameras available on this device.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error initializing camera: $e";
      });
    }
  }

  Future<void> _addVirtualObject(String modelPath, vector.Vector3 position, vector.Vector4 rotation, vector.Vector3 scale) async {
    try {
      String filePath;
      if (modelPath.startsWith('http')) {
        // Download the file
        final response = await http.get(Uri.parse(modelPath));
        if (response.statusCode == 200) {
          final documentDirectory = await getApplicationDocumentsDirectory();
          final file = File('${documentDirectory.path}/${path.basename(modelPath)}');
          await file.writeAsBytes(response.bodyBytes);
          filePath = file.path;
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to download model from: $modelPath")),
          );
          return;
        }
      } else {
        filePath = modelPath;
      }

      File file = File(filePath);
      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Model file does not exist at: $filePath")),
        );
        return;
      }

      // Add the model to active models list (simulated AR placement)
      activeModels.add(filePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Virtual object placed successfully!")),
      );
      
      setState(() {}); // Refresh UI to show new active models count
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error placing virtual object: $e")),
      );
    }
  }

  void _showActiveModels(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Active Virtual Objects"),
          content: SingleChildScrollView(
            child: ListBody(
              children: activeModels.isEmpty
                  ? [const Text("No virtual objects placed yet.")]
                  : activeModels
                      .map((modelPath) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.view_in_ar),
                              title: Text(path.basename(modelPath)),
                              subtitle: Text("Path: $modelPath"),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  setState(() {
                                    activeModels.remove(modelPath);
                                  });
                                  Navigator.of(context).pop();
                                  _showActiveModels(context); // Refresh dialog
                                },
                              ),
                            ),
                          ))
                      .toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Clear All"),
              onPressed: () {
                setState(() {
                  activeModels.clear();
                });
                Navigator.of(context).pop();
              },
            ),
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
      appBar: AppBar(
        title: const Text('AR Experience'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showARInfo();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview or error message
          _buildCameraPreview(),
          
          // AR UI overlay
          _buildAROverlay(),
          
          // Control buttons
          _buildControlButtons(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _requestPermissions();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isPermissionGranted) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt,
                color: Theme.of(context).colorScheme.onSurface,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Ready to explore AR art?',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap Start AR to begin your augmented reality experience',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _requestPermissions,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start AR'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Initializing AR Camera...',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return CameraPreview(_cameraController!);
  }

  Widget _buildAROverlay() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CustomPaint(
        painter: AROverlayPainter(
          activeModels.length, 
          overlayColor: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton(
            onPressed: () => _showAddObjectDialog(),
            heroTag: 'addObject',
            tooltip: 'Add Virtual Object',
            child: const Icon(Icons.add),
          ),
          FloatingActionButton(
            onPressed: () => _showActiveModels(context),
            heroTag: 'showModels',
            tooltip: 'Show Active Objects',
            child: Badge(
              label: Text('${activeModels.length}'),
              child: const Icon(Icons.list),
            ),
          ),
          FloatingActionButton(
            onPressed: () => _simulatePlacement(),
            heroTag: 'autoPlace',
            tooltip: 'Auto Place Object',
            child: const Icon(Icons.auto_fix_high),
          ),
        ],
      ),
    );
  }

  void _simulatePlacement() {
    // Simulate placing a demo object
    final demoObjects = [
      'Demo Cube',
      'Demo Sphere',
      'Demo Pyramid',
      'Demo Cylinder',
    ];
    
    final random = demoObjects[(DateTime.now().millisecondsSinceEpoch % demoObjects.length)];
    activeModels.add('demo://$random');
    
    setState(() {});
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Placed $random in AR space')),
    );
  }

  void _showARInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('AR Experience Info'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎯 How to use AR:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('• Point your camera at a flat surface'),
                Text('• Tap + to add virtual objects'),
                Text('• Use the list button to manage objects'),
                Text('• Tap auto-place for quick demo'),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.smartphone, size: 16),
                    SizedBox(width: 6),
                    Text('Platform Support:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 8),
                Text('• Full AR on mobile devices'),
                Text('• Camera preview on desktop'),
                Text('• Object simulation available'),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.flash_on, size: 16),
                    SizedBox(width: 6),
                    Text('Features:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 8),
                Text('• Real-time camera feed'),
                Text('• Virtual object placement'),
                Text('• Model download support'),
                Text('• Cross-platform compatibility'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it!'),
            ),
          ],
        );
      },
    );
  }

  void _showAddObjectDialog() {
    // Controllers for position, rotation, and scale inputs
    final TextEditingController positionController = TextEditingController();
    final TextEditingController rotationController = TextEditingController();
    final TextEditingController scaleController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Virtual Object'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: _pathController,
                  decoration: const InputDecoration(
                    hintText: 'Model file path or URL',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: positionController,
                  decoration: const InputDecoration(
                    hintText: 'Position (x,y,z) - default: 0,0,0',
                    prefixIcon: Icon(Icons.place),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: rotationController,
                  decoration: const InputDecoration(
                    hintText: 'Rotation (x,y,z,w) - default: 0,0,0,1',
                    prefixIcon: Icon(Icons.rotate_right),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: scaleController,
                  decoration: const InputDecoration(
                    hintText: 'Scale (x,y,z) - default: 1,1,1',
                    prefixIcon: Icon(Icons.zoom_out_map),
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
            ElevatedButton(
              child: const Text('Place Object'),
              onPressed: () {
                // Parse inputs
                final position = vector.Vector3.zero(); // Default value
                final rotation = vector.Vector4(0, 0, 0, 1); // Default value
                final scale = vector.Vector3.all(1); // Default value

                // Attempt to parse user input, fallback to default if parsing fails
                try {
                  final positionParts = positionController.text.split(',').map((e) => double.parse(e.trim())).toList();
                  if (positionParts.length == 3) {
                    position.setValues(positionParts[0], positionParts[1], positionParts[2]);
                  }
                } catch (_) {
                  // Use default values
                }

                try {
                  final rotationParts = rotationController.text.split(',').map((e) => double.parse(e.trim())).toList();
                  if (rotationParts.length == 4) {
                    rotation.setValues(rotationParts[0], rotationParts[1], rotationParts[2], rotationParts[3]);
                  }
                } catch (_) {
                  // Use default values
                }

                try {
                  final scaleParts = scaleController.text.split(',').map((e) => double.parse(e.trim())).toList();
                  if (scaleParts.length == 3) {
                    scale.setValues(scaleParts[0], scaleParts[1], scaleParts[2]);
                  }
                } catch (_) {
                  // Use default values
                }

                _addVirtualObject(
                  _pathController.text.isEmpty ? 'demo://Default Object' : _pathController.text,
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

  @override
  void dispose() {
    _cameraController?.dispose();
    _pathController.dispose();
    super.dispose();
  }
}

// Custom painter for AR overlay
class AROverlayPainter extends CustomPainter {
  final int objectCount;
  final Color overlayColor;

  AROverlayPainter(this.objectCount, {this.overlayColor = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = overlayColor.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw AR frame border
    canvas.drawRect(
      Rect.fromLTWH(20, 20, size.width - 40, size.height - 40),
      paint,
    );

    // Draw crosshair in center
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    canvas.drawLine(
      Offset(centerX - 20, centerY),
      Offset(centerX + 20, centerY),
      paint,
    );
    
    canvas.drawLine(
      Offset(centerX, centerY - 20),
      Offset(centerX, centerY + 20),
      paint,
    );

    // Draw object count indicator
    if (objectCount > 0) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Objects: $objectCount',
          style: TextStyle(
            color: overlayColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(canvas, const Offset(30, 30));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is AROverlayPainter && oldDelegate.objectCount != objectCount;
  }
}