import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/push_notification_service.dart';

class PermissionsRequestWidget extends StatefulWidget {
  final VoidCallback? onPermissionsGranted;
  final VoidCallback? onSkip;
  
  const PermissionsRequestWidget({
    super.key,
    this.onPermissionsGranted,
    this.onSkip,
  });

  @override
  State<PermissionsRequestWidget> createState() => _PermissionsRequestWidgetState();
}

class _PermissionsRequestWidgetState extends State<PermissionsRequestWidget> {
  bool _cameraGranted = false;
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _isRequesting = false;
  
  final PushNotificationService _pushNotificationService = PushNotificationService();

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _checkPermissions();
  }
  
  Future<void> _initializeServices() async {
    await _pushNotificationService.initialize();
  }

  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final locationStatus = await Permission.locationWhenInUse.status;
    final notificationStatus = await Permission.notification.status;

    if (mounted) {
      setState(() {
        _cameraGranted = cameraStatus.isGranted;
        _locationGranted = locationStatus.isGranted;
        _notificationGranted = notificationStatus.isGranted;
      });
    }
  }

  Future<void> _requestAllPermissions() async {
    if (_isRequesting) return;
    
    setState(() {
      _isRequesting = true;
    });

    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      setState(() {
        _cameraGranted = cameraStatus.isGranted;
      });

      // Request location permission
      final locationStatus = await Permission.locationWhenInUse.request();
      setState(() {
        _locationGranted = locationStatus.isGranted;
      });

      // Request notification permission (both OS and push notification service)
      final notificationStatus = await Permission.notification.request();
      final pushGranted = await _pushNotificationService.requestPermission();
      setState(() {
        _notificationGranted = notificationStatus.isGranted || pushGranted;
      });

      // Check if all critical permissions are granted (camera and location are critical for AR)
      if (_cameraGranted && _locationGranted) {
        widget.onPermissionsGranted?.call();
      } else {
        _showPermissionDeniedDialog();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Permissions Required',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Camera and Location permissions are essential for AR experiences. You can continue without them, but some features will be limited.\n\nYou can enable permissions later in Settings.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onSkip?.call();
            },
            child: Text('Continue Anyway', style: GoogleFonts.outfit()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: Text('Open Settings', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPermissionTile(
            icon: Icons.camera_alt,
            title: 'Camera Access',
            description: 'Required for AR experiences and scanning artworks',
            isGranted: _cameraGranted,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildPermissionTile(
            icon: Icons.location_on,
            title: 'Location Access',
            description: 'Find nearby artworks and enable location-based features',
            isGranted: _locationGranted,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          _buildPermissionTile(
            icon: Icons.notifications,
            title: 'Notifications',
            description: 'Get alerts when you\'re near AR artworks',
            isGranted: _notificationGranted,
            color: Colors.orange,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isRequesting ? null : _requestAllPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isRequesting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Grant Permissions',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onSkip,
            child: Text(
              'Skip for Now',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGranted
            ? color.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted
              ? color
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isGranted ? color : Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isGranted)
                      Icon(
                        Icons.check_circle,
                        color: color,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
