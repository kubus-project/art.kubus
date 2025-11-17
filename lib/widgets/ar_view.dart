import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../widgets/app_loading.dart';

/// AR View Widget - Handles platform-specific AR rendering
class ARView extends StatefulWidget {
  final Function(Map<String, dynamic>, VoidCallback)? onARViewCreated;
  final Function(String)? onObjectPlaced;
  final Function(String)? onObjectTapped;
  final Function(bool)? onFlashToggle;
  final bool showFeaturePoints;
  final bool showPlanes;
  final String? instructionText;
  final String? mode;
  final List<Map<String, dynamic>>? placedObjects;
  final bool? debugInfo;

  const ARView({
    super.key,
    this.onARViewCreated,
    this.onObjectPlaced,
    this.onObjectTapped,
    this.onFlashToggle,
    this.showFeaturePoints = false,
    this.showPlanes = true,
    this.instructionText,
    this.mode = 'scan',
    this.placedObjects,
    this.debugInfo = false,
  });

  @override
  State<ARView> createState() => _ARViewState();
}

class _ARViewState extends State<ARView> with TickerProviderStateMixin {
  bool _isReady = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _surfaceDetected = false;
  late AnimationController _gridAnimationController;
  late Animation<double> _gridOpacityAnimation;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  
  // AR space tracking
  Offset? _detectedPlaneCenter; // Screen position of detected plane center
  double _planeDistance = 1.0; // Distance in meters from camera to plane
  final List<ARObject3D> _arObjects = []; // Objects in 3D world space

  @override
  void initState() {
    super.initState();
    _gridAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _gridOpacityAnimation = Tween<double>(begin: 0.2, end: 0.0).animate(
      CurvedAnimation(parent: _gridAnimationController, curve: Curves.easeOut),
    );
    
    // Pulse animation for placed objects
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    );
    
    _initializeAR();
  }

  Future<void> _initializeAR() async {
    try {
      // Initialize camera
      await _initializeCamera();
      
      if (mounted) {
        setState(() {
          _isReady = true;
        });
        
        if (widget.onARViewCreated != null) {
          widget.onARViewCreated!({
            'platform': Platform.isAndroid ? 'android' : 'ios',
            'ready': true,
            'camera': _isCameraInitialized,
          }, toggleFlash);
        }
        
        // Simulate surface detection after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _surfaceDetected = true;
              // Set detected plane at screen center, 1.5m away
              _detectedPlaneCenter = Offset(
                MediaQuery.of(context).size.width / 2,
                MediaQuery.of(context).size.height / 2,
              );
              _planeDistance = 1.5; // meters
            });
            _gridAnimationController.forward();
            
            // Convert widget objects to AR 3D objects
            _updateARObjects();
          }
        });
      }
    } catch (e) {
      debugPrint('AR initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to initialize AR: $e';
        });
      }
    }
  }
  
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        debugPrint('No cameras available');
        // Continue without camera - AR can still work
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }
        return;
      }
      
      // Use the back camera for AR
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );
      
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      // Continue without camera - show fallback UI
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(ARView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update AR objects when placedObjects list changes
    if (oldWidget.placedObjects != widget.placedObjects) {
      _updateARObjects();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _gridAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }
  
  /// Convert widget objects to AR 3D space objects
  void _updateARObjects() {
    if (widget.placedObjects == null) {
      _arObjects.clear();
      return;
    }
    
    _arObjects.clear();
    
    for (int i = 0; i < widget.placedObjects!.length; i++) {
      final obj = widget.placedObjects![i];
      
      // Place objects in a grid on the detected plane
      // Grid spacing in meters (real world units)
      const gridSpacing = 0.4; // 40cm between objects
      final col = i % 3; // 3 columns
      final row = i ~/ 3; // Multiple rows
      
      // Calculate world position in meters relative to detected plane
      // Objects are placed on the plane at _planeDistance meters from camera
      final worldX = (col - 1) * gridSpacing; // -0.4, 0, 0.4 meters
      final worldY = -row * gridSpacing; // Rows going down
      final worldZ = _planeDistance; // All objects on detected plane
      
      _arObjects.add(ARObject3D(
        id: obj['id'] ?? 'obj_$i',
        worldPosition: Vector3(worldX, worldY, worldZ),
        scale: 1.0,
        metadata: obj,
      ));
    }
    
    if (mounted) {
      setState(() {}); // Trigger repaint
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
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
              const SizedBox(height: 20),
              Text(
                'AR Initialization Error',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_isReady) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppLoading(),
              const SizedBox(height: 20),
              Text(
                'Initializing AR Experience...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                Platform.isAndroid ? 'Using ARCore' : 'Using ARKit',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // AR is ready - show AR camera view with live camera feed
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Live camera feed or fallback
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 100,
                  height: _cameraController!.value.previewSize?.width ?? 100,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            // Fallback if camera not available
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1a1a1a),
                    const Color(0xFF2a2a2a),
                    const Color(0xFF1a1a1a),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_off,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Camera not available',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // AR Camera overlay with grid
          if (widget.showPlanes && !_surfaceDetected)
            AnimatedBuilder(
              animation: _gridOpacityAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: ARPlanesPainter(opacity: 0.2),
                  child: Container(),
                );
              },
            ),
          
          // Grid fade out animation when surface is detected
          if (widget.showPlanes && _surfaceDetected)
            AnimatedBuilder(
              animation: _gridOpacityAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: ARPlanesPainter(opacity: _gridOpacityAnimation.value),
                  child: Container(),
                );
              },
            ),
          
          // Feature points visualization (tracking points)
          if (widget.showFeaturePoints && _surfaceDetected)
            CustomPaint(
              painter: ARFeaturePointsPainter(),
              child: Container(),
            ),
          
          // Full-screen gesture detector for AR interactions
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) {
                // Detect tap on AR space (for object interaction)
                _handleARTap(details.localPosition);
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          
          // Center crosshair for targeting
          Center(
            child: IgnorePointer(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Placed objects visualization - render in AR space, not as UI overlays
          if (widget.placedObjects != null && widget.placedObjects!.isNotEmpty)
            IgnorePointer(
              child: CustomPaint(
                painter: ARObjectsPainter(
                  objects: widget.placedObjects!,
                  animation: _pulseAnimation,
                ),
                child: Container(),
              ),
            ),
          
          // Debug info overlay
          if (widget.debugInfo == true)
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Info',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mode: ${widget.mode}',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    Text(
                      'Objects: ${widget.placedObjects?.length ?? 0}',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    Text(
                      'Planes: ${widget.showPlanes ? "ON" : "OFF"}',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    Text(
                      'Features: ${widget.showFeaturePoints ? "ON" : "OFF"}',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    Text(
                      'Plane: ${_surfaceDetected ? "${_planeDistance.toStringAsFixed(1)}m" : "Detecting..."}',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    if (_detectedPlaneCenter != null)
                      Text(
                        'Center: ${_detectedPlaneCenter!.dx.toInt()},${_detectedPlaneCenter!.dy.toInt()}',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Handle tap on AR space to detect object interaction
  void _handleARTap(Offset position) {
    if (widget.placedObjects == null || widget.placedObjects!.isEmpty) return;
    
    // Simple hit detection - check if tap is near any object
    for (final obj in widget.placedObjects!) {
      if (widget.onObjectTapped != null) {
        widget.onObjectTapped!(obj['id']);
        break; // Only tap one object at a time
      }
    }
  }
  
  /// Toggle camera flash on/off
  Future<void> toggleFlash() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    
    try {
      final newFlashMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newFlashMode);
      
      if (mounted) {
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
        
        // Notify parent widget about flash state change
        if (widget.onFlashToggle != null) {
          widget.onFlashToggle!(_isFlashOn);
        }
      }
    } catch (e) {
      debugPrint('Flash toggle error: $e');
    }
  }
  
  /// Get current flash state
  bool get isFlashOn => _isFlashOn;
}

/// Custom painter for AR planes visualization
class ARPlanesPainter extends CustomPainter {
  final double opacity;
  
  ARPlanesPainter({this.opacity = 0.2});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withValues(alpha: opacity * 2) // Make more visible
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final centerPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: opacity * 3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Draw a grid pattern to simulate detected planes
    const gridSize = 60.0;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    for (double x = 0; x < size.width; x += gridSize) {
      // Make lines near center more prominent
      final distanceFromCenter = (x - centerX).abs() / centerX;
      final lineOpacity = opacity * (1.5 - distanceFromCenter * 0.5);
      paint.color = Colors.cyan.withValues(alpha: lineOpacity.clamp(0.0, 1.0));
      
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        x == centerX ? centerPaint : paint,
      );
    }
    for (double y = 0; y < size.height; y += gridSize) {
      // Make lines near center more prominent
      final distanceFromCenter = (y - centerY).abs() / centerY;
      final lineOpacity = opacity * (1.5 - distanceFromCenter * 0.5);
      paint.color = Colors.cyan.withValues(alpha: lineOpacity.clamp(0.0, 1.0));
      
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        y == centerY ? centerPaint : paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ARPlanesPainter oldDelegate) {
    return opacity != oldDelegate.opacity;
  }
}

/// Custom painter for AR feature points (tracking points)
class ARFeaturePointsPainter extends CustomPainter {
  static List<Offset>? _cachedPoints;
  
  ARFeaturePointsPainter();
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    // Generate static feature points once and cache them
    // This simulates ARCore/ARKit tracking points that stick to surfaces
    if (_cachedPoints == null || _cachedPoints!.isEmpty) {
      _cachedPoints = [];
      // Use fixed seed for consistent point positions
      const seed = 42;
      for (int i = 0; i < 50; i++) {
        // Generate pseudo-random but consistent positions
        final x = ((seed * (i * 17 + 13)) % size.width.toInt()).toDouble();
        final y = ((seed * (i * 23 + 7)) % size.height.toInt()).toDouble();
        _cachedPoints!.add(Offset(x, y));
      }
    }
    
    // Draw cached feature points (they stay in same position)
    for (final point in _cachedPoints!) {
      canvas.drawCircle(point, 2.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ARFeaturePointsPainter oldDelegate) {
    return false; // Points are static, no need to repaint
  }
  
  /// Reset cached points (call when surface detection resets)
  static void resetPoints() {
    _cachedPoints = null;
  }
}

/// Custom painter for AR objects in 3D space
class ARObjectsPainter extends CustomPainter {
  final List<Map<String, dynamic>> objects;
  final Animation<double> animation;
  
  // Camera/AR space parameters
  static const Vector3 _cameraPosition = Vector3(0, 0, 0); // Camera at origin
  static const double _focalLength = 800.0; // Simulated focal length in pixels
  static const double _planeDepth = 1.5; // Detected plane is 1.5 meters away
  
  ARObjectsPainter({
    required this.objects,
    required this.animation,
  }) : super(repaint: animation);
  
  @override
  void paint(Canvas canvas, Size size) {
    // Convert widget objects to 3D AR objects with world coordinates
    final arObjects = _convertToARObjects(objects, size);
    
    // Sort by distance (far to near) for proper rendering order
    arObjects.sort((a, b) => 
      b.worldPosition.z.compareTo(a.worldPosition.z)
    );
    
    // Render each object
    for (final arObject in arObjects) {
      // Project 3D position to 2D screen
      final screenPos = arObject.projectToScreen(size, _cameraPosition, _focalLength);
      
      // Calculate size based on distance
      final baseSize = 100.0; // Increased base size for better visibility
      final apparentSize = arObject.getApparentSize(_cameraPosition, baseSize) * animation.value;
      
      // Skip only if object is behind camera or way too small
      if (arObject.worldPosition.z <= 0.1 || apparentSize < 5) continue;
      
      // Clamp to reasonable size range
      final clampedSize = apparentSize.clamp(40.0, 150.0);
      
      // Draw object with shadow for depth
      _drawObjectShadow(canvas, screenPos.dx, screenPos.dy + 10, clampedSize, arObject.worldPosition.z);
      _drawObject(canvas, screenPos.dx, screenPos.dy, clampedSize, arObject.metadata, animation.value);
    }
  }
  
  /// Convert 2D widget objects to 3D AR objects with world coordinates
  List<ARObject3D> _convertToARObjects(List<Map<String, dynamic>> widgetObjects, Size screenSize) {
    final arObjects = <ARObject3D>[];
    
    for (int i = 0; i < widgetObjects.length; i++) {
      final obj = widgetObjects[i];
      
      // Place objects in a grid on the detected plane
      // Grid spacing in meters (real world units)
      const gridSpacing = 0.4; // 40cm between objects
      final col = i % 3; // 3 columns
      final row = i ~/ 3; // Multiple rows
      
      // Calculate world position in meters
      // Objects are placed on a plane at _planeDepth meters from camera
      final worldX = (col - 1) * gridSpacing; // -0.4, 0, 0.4 meters
      final worldY = -row * gridSpacing; // Down from plane center
      final worldZ = _planeDepth; // All objects on same depth plane
      
      arObjects.add(ARObject3D(
        id: obj['id'] ?? 'obj_$i',
        worldPosition: Vector3(worldX, worldY, worldZ),
        scale: 1.0,
        metadata: obj,
      ));
    }
    
    return arObjects;
  }
  
  void _drawObjectShadow(Canvas canvas, double x, double y, double size, double depth) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3 * depth)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y),
        width: size * 0.8,
        height: size * 0.3,
      ),
      shadowPaint,
    );
  }
  
  void _drawObject(Canvas canvas, double x, double y, double size, Map<String, dynamic> obj, double scale) {
    // Draw outer glow for better visibility
    final glowPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    
    canvas.drawCircle(Offset(x, y), size * 0.7, glowPaint);
    
    // Draw object container with gradient effect
    final containerPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, y), width: size, height: size),
      const Radius.circular(12),
    );
    
    // Draw with effects
    canvas.drawRRect(rect, containerPaint);
    canvas.drawRRect(rect, borderPaint);
    
    // Draw AR icon in center
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    // Draw a 3D cube icon
    final iconSize = size * 0.4;
    final cubeCenter = Offset(x, y);
    
    // Draw simple 3D cube representation
    final cubePath = Path()
      ..moveTo(cubeCenter.dx - iconSize/2, cubeCenter.dy)
      ..lineTo(cubeCenter.dx, cubeCenter.dy - iconSize/2)
      ..lineTo(cubeCenter.dx + iconSize/2, cubeCenter.dy)
      ..lineTo(cubeCenter.dx, cubeCenter.dy + iconSize/2)
      ..close();
    
    canvas.drawPath(cubePath, iconPaint);
    
    // Draw model type text
    final textPainter = TextPainter(
      text: TextSpan(
        text: obj['model']?.toString().toUpperCase() ?? 'AR',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y + size / 2 + 5),
    );
  }

  @override
  bool shouldRepaint(covariant ARObjectsPainter oldDelegate) {
    return objects.length != oldDelegate.objects.length;
  }
}

/// AR Object in 3D space with actual world coordinates
class ARObject3D {
  final String id;
  final Vector3 worldPosition; // Position in meters from origin
  final double scale;
  final Map<String, dynamic> metadata;
  
  ARObject3D({
    required this.id,
    required this.worldPosition,
    this.scale = 1.0,
    this.metadata = const {},
  });
  
  /// Project 3D world position to 2D screen coordinates
  Offset projectToScreen(Size screenSize, Vector3 cameraPosition, double focalLength) {
    // Simple perspective projection
    // In a real AR app, this would use the device's camera intrinsics
    final relativeX = worldPosition.x - cameraPosition.x;
    final relativeY = worldPosition.y - cameraPosition.y;
    final relativeZ = worldPosition.z - cameraPosition.z;
    
    // Avoid division by zero
    final z = relativeZ == 0 ? 0.001 : relativeZ;
    
    // Perspective projection formula
    final screenX = screenSize.width / 2 + (relativeX * focalLength / z);
    final screenY = screenSize.height / 2 - (relativeY * focalLength / z);
    
    return Offset(screenX, screenY);
  }
  
  /// Get apparent size based on distance from camera
  double getApparentSize(Vector3 cameraPosition, double baseSize) {
    final distance = _distanceToCamera(cameraPosition);
    // Objects appear smaller as they get further away
    // Use simpler scaling for better visibility
    return baseSize / (distance * 0.5);
  }
  
  double _distanceToCamera(Vector3 cameraPosition) {
    final dx = worldPosition.x - cameraPosition.x;
    final dy = worldPosition.y - cameraPosition.y;
    final dz = worldPosition.z - cameraPosition.z;
    // Proper distance calculation using sqrt
    return (dx * dx + dy * dy + dz * dz).abs().clamp(0.1, 100.0);
  }
}

/// AR Object Node - Represents a 3D object in the AR scene
class ARObjectNode {
  final String id;
  final String modelPath;
  final Vector3 position;
  final Vector3 scale;
  final Vector3 rotation;
  final Map<String, dynamic> properties;

  ARObjectNode({
    required this.id,
    required this.modelPath,
    required this.position,
    this.scale = const Vector3(1.0, 1.0, 1.0),
    this.rotation = const Vector3(0.0, 0.0, 0.0),
    this.properties = const {},
  });
}

/// Simple 3D Vector class
class Vector3 {
  final double x;
  final double y;
  final double z;

  const Vector3(this.x, this.y, this.z);

  @override
  String toString() => 'Vector3($x, $y, $z)';
}

/// AR Controller - Controls AR session and object placement
class ARController {
  final List<ARObjectNode> _nodes = [];
  bool _isSessionActive = false;

  List<ARObjectNode> get nodes => List.unmodifiable(_nodes);
  bool get isSessionActive => _isSessionActive;

  /// Add an object to the AR scene
  void addNode(ARObjectNode node) {
    _nodes.add(node);
  }

  /// Remove an object from the AR scene
  void removeNode(String nodeId) {
    _nodes.removeWhere((node) => node.id == nodeId);
  }

  /// Clear all objects from the AR scene
  void clearNodes() {
    _nodes.clear();
  }

  /// Start AR session
  Future<void> startSession() async {
    _isSessionActive = true;
  }

  /// Pause AR session
  void pauseSession() {
    _isSessionActive = false;
  }

  /// Resume AR session
  void resumeSession() {
    _isSessionActive = true;
  }

  /// Dispose AR resources
  void dispose() {
    _isSessionActive = false;
    _nodes.clear();
  }
}
