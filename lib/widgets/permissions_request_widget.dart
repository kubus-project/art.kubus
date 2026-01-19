import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'inline_loading.dart';
import 'glass_components.dart';
import '../services/push_notification_service.dart';
import '../services/notification_helper.dart';
import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';

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
    try {
      final locationStatus = await Permission.locationWhenInUse.status;
      final notificationGranted = kIsWeb
          ? await isWebNotificationPermissionGranted()
          : (await Permission.notification.status).isGranted;

      // On web, we don't request/check camera permission in the onboarding flow.
      final cameraGranted = kIsWeb ? true : (await Permission.camera.status).isGranted;

      if (mounted) {
        setState(() {
          _cameraGranted = cameraGranted;
          _locationGranted = locationStatus.isGranted;
          _notificationGranted = notificationGranted;
        });
      }
    } catch (e, st) {
      debugPrint('PermissionsRequestWidget._checkPermissions failed: $e\n$st');
      if (mounted) {
        setState(() {
          _cameraGranted = kIsWeb ? true : false;
          _locationGranted = false;
          _notificationGranted = false;
        });
      }
    }
  }

  Future<void> _requestAllPermissions() async {
    if (_isRequesting) return;
    
    setState(() {
      _isRequesting = true;
    });

    try {
      // Request camera permission (not requested on web)
      if (!kIsWeb) {
        try {
          final cameraStatus = await Permission.camera.request();
          setState(() {
            _cameraGranted = cameraStatus.isGranted;
          });
        } catch (e, st) {
          debugPrint('PermissionsRequestWidget._requestAllPermissions camera.request failed: $e\n$st');
          setState(() => _cameraGranted = false);
        }
      } else {
        setState(() => _cameraGranted = true);
      }

      // Request location permission
      try {
        final locationStatus = await Permission.locationWhenInUse.request();
        setState(() {
          _locationGranted = locationStatus.isGranted;
        });
      } catch (e, st) {
        debugPrint('PermissionsRequestWidget._requestAllPermissions location.request failed: $e\n$st');
        setState(() => _locationGranted = false);
      }

      // Request notification permission (platform-specific)
      bool pushGranted = false;
      if (kIsWeb) {
        try {
          pushGranted = await _pushNotificationService.requestPermission();
        } catch (e) {
          pushGranted = false;
        }
        setState(() => _notificationGranted = pushGranted);
      } else {
        bool notificationIsGranted = false;
        try {
          final notificationStatus = await Permission.notification.request();
          notificationIsGranted = notificationStatus.isGranted;
        } catch (e, st) {
          debugPrint('PermissionsRequestWidget._requestAllPermissions notification.request failed: $e\n$st');
          notificationIsGranted = false;
        }

        bool pushGrantedLocal = false;
        try {
          pushGrantedLocal = await _pushNotificationService.requestPermission();
        } catch (e, st) {
          debugPrint('PermissionsRequestWidget._requestAllPermissions push request failed: $e\n$st');
          pushGrantedLocal = false;
        }

        setState(() {
          _notificationGranted = notificationIsGranted || pushGrantedLocal;
        });
      }

      // On web we don't request camera permission; require only location for core UX.
      final requiredOk = kIsWeb ? _locationGranted : (_cameraGranted && _locationGranted);
      if (requiredOk) {
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
    showKubusDialog(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        title: const Text('Permissions Required'),
        content: Text(
          kIsWeb
              ? 'Location permission is essential for map discovery and nearby artwork features. You can continue without it, but some features will be limited.\n\nYou can enable permissions later in your browser settings.'
              : 'Camera and Location permissions are essential for AR experiences. You can continue without them, but some features will be limited.\n\nYou can enable permissions later in Settings.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              widget.onSkip?.call();
            },
            child: const Text('Continue Anyway'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final buttonRadius = BorderRadius.circular(KubusRadius.lg);
    final buttonTint = scheme.primary.withValues(alpha: isDark ? 0.82 : 0.88);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!kIsWeb) ...[
            _buildPermissionTile(
              icon: Icons.camera_alt,
              title: 'Camera Access',
              description: 'Required for AR experiences and scanning artworks',
              isGranted: _cameraGranted,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
          ],
          _buildPermissionTile(
            icon: Icons.location_on,
            title: 'Location Access',
            description: 'Find nearby artworks and enable location-based features',
            isGranted: _locationGranted,
            color: roles.positiveAction,
          ),
          const SizedBox(height: 16),
          _buildPermissionTile(
            icon: Icons.notifications,
            title: 'Notifications',
            description: 'Get alerts when you\'re near AR artworks',
            isGranted: _notificationGranted,
            color: roles.warningAction,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: buttonRadius,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.30),
                ),
              ),
              child: LiquidGlassPanel(
                padding: EdgeInsets.zero,
                margin: EdgeInsets.zero,
                borderRadius: buttonRadius,
                showBorder: false,
                backgroundColor: buttonTint,
                child: ElevatedButton(
                  onPressed: _isRequesting ? null : _requestAllPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: scheme.onPrimary,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor:
                        scheme.onPrimary.withValues(alpha: 0.55),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: buttonRadius,
                    ),
                  ),
                  child: _isRequesting
                      ? SizedBox(
                          width: KubusSpacing.lg,
                          height: KubusSpacing.lg,
                          child: InlineLoading(
                            expand: true,
                            shape: BoxShape.circle,
                            tileSize: 3.5,
                            color: scheme.onPrimary,
                          ),
                        )
                      : Text(
                          'Grant Permissions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
          TextButton(
            onPressed: widget.onSkip,
            child: Text(
              'Skip for Now',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final radius = BorderRadius.circular(KubusRadius.md);
    final glassTint = isGranted
        ? color.withValues(alpha: isDark ? 0.18 : 0.14)
        : scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: isGranted
              ? color.withValues(alpha: 0.55)
              : scheme.outline.withValues(alpha: 0.22),
          width: KubusSizes.hairline,
        ),
      ),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.all(KubusSpacing.md),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        child: Row(
          children: [
            Container(
              width: KubusSpacing.xxl,
              height: KubusSpacing.xxl,
              decoration: BoxDecoration(
                color: isGranted
                    ? color
                    : scheme.outlineVariant.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(KubusRadius.md),
              ),
              child: Icon(
                icon,
                color: scheme.onPrimary,
                size: KubusSpacing.lg,
              ),
            ),
            const SizedBox(width: KubusSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: scheme.onSurface,
                              ),
                        ),
                      ),
                      if (isGranted)
                        Icon(
                          Icons.check_circle,
                          color: color,
                          size: KubusSizes.sidebarActionIcon,
                        ),
                    ],
                  ),
                  const SizedBox(height: KubusSpacing.xs),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
