import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../widgets/inline_loading.dart';
import '../../services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/gradient_icon_card.dart';
import '../../screens/desktop/desktop_shell.dart';
import '../desktop/onboarding/desktop_permissions_screen.dart';
import '../../main_app.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCheckingPermissions = true;
  
  // Track permission states
  bool _locationGranted = false;
  bool _cameraGranted = false;
  bool _notificationsGranted = false;
  bool _storageGranted = false;

  @override
  void initState() {
    super.initState();
    _checkExistingPermissions();
  }

  Future<void> _checkExistingPermissions() async {
    // Check if all permissions are already granted; wrap calls in try/catch
    bool locationGranted = false;
    bool cameraGranted = false;
    bool notificationsGranted = false;
    bool storageGranted = false;

    try {
      // Only query permission status for the pages that apply on this platform
      for (final page in _pages) {
        switch (page.permissionType) {
          case PermissionType.location:
            final locationStatus = await Permission.location.status;
            locationGranted = locationStatus.isGranted;
            break;
          case PermissionType.camera:
            final cameraStatus = await Permission.camera.status;
            cameraGranted = cameraStatus.isGranted;
            break;
          case PermissionType.notifications:
            final notificationStatus = await Permission.notification.status;
            notificationsGranted = notificationStatus.isGranted;
            break;
          case PermissionType.storage:
            if (kIsWeb) {
              // Storage/photo permission is irrelevant on web - treat as granted
              storageGranted = true;
            } else {
              final storageStatus = await Permission.photos.status;
              storageGranted = storageStatus.isGranted;
            }
            break;
        }
      }
    } catch (e, st) {
      debugPrint('PermissionsScreen._checkExistingPermissions: permission status check failed: $e\n$st');
      // Keep defaults (false) on failures
      locationGranted = false;
      cameraGranted = false;
      notificationsGranted = false;
      storageGranted = false;
    }
    // Update the state for UI rendering
    if (mounted) {
      setState(() {
        _locationGranted = locationGranted;
        _cameraGranted = cameraGranted;
        _notificationsGranted = notificationsGranted;
        _storageGranted = storageGranted;
        _isCheckingPermissions = false;
      });
    }

    // If all visible (platform-specific) permissions are granted, complete onboarding and go to main app
    if (_pages.every((p) => _isPermissionGranted(p.permissionType))) {
      if (mounted) {
        _completeOnboarding();
      }
      return;
    }

    setState(() {
      _isCheckingPermissions = false;
    });
  }

  List<PermissionPage> get _allPages => [
    PermissionPage(
      title: 'Location Access',
      subtitle: 'Discover Art Near You',
      description: 'We use your location to show AR artworks placed in your area. Find hidden art pieces, discover local artists, and explore galleries nearby.',
      benefits: [
        'Find AR artworks near you',
        'Discover local galleries and exhibitions',
        'Get notified about nearby art events',
        'Track your art exploration journey',
      ],
      iconData: Icons.location_on_outlined,
      gradient: LinearGradient(
        colors: [Color(0xFF00D4AA), Color(0xFF4ECDC4)],
      ),
      permissionType: PermissionType.location,
    ),
    PermissionPage(
      title: 'Camera Access',
      subtitle: 'Experience AR Magic',
      description: 'The camera is essential for viewing AR artworks in your space. Place, interact with, and photograph stunning 3D art installations anywhere.',
      benefits: [
        'View AR artworks in real-world',
        'Place virtual sculptures in your space',
        'Take photos of AR art to share',
        'Scan QR codes to unlock content',
      ],
      iconData: Icons.camera_alt_outlined,
      gradient: LinearGradient(
        colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
      ),
      permissionType: PermissionType.camera,
    ),
    PermissionPage(
      title: 'Notifications',
      subtitle: 'Stay Connected to Art',
      description: 'Get notified about new artworks, achievement unlocks, NFT sales, and community updates. Never miss important moments.',
      benefits: [
        'New artwork discoveries',
        'Achievement & reward notifications',
        'NFT sale confirmations',
        'Community event reminders',
      ],
      iconData: Icons.notifications_outlined,
      gradient: LinearGradient(
        colors: [Color(0xFFFFD93D), Color(0xFFFFBE0B)],
      ),
      permissionType: PermissionType.notifications,
    ),
    PermissionPage(
      title: 'Photo Library Access',
      subtitle: 'Save Your Creations',
      description: 'Save AR screenshots, download artwork images, and keep your collection in your photo library. Your art memories, always accessible.',
      benefits: [
        'Save AR screenshots to your photos',
        'Download artwork images',
        'Export your creations to share',
        'Keep your art collection accessible',
      ],
      iconData: Icons.photo_library_outlined,
      gradient: LinearGradient(
        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
      ),
      permissionType: PermissionType.storage,
    ),
  ];

  // Filter pages for the current platform. Do not request storage/photos on web.
  List<PermissionPage> get _pages => kIsWeb
      ? _allPages.where((p) => p.permissionType != PermissionType.storage).toList()
      : _allPages;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Redirect to desktop permissions if on desktop
    if (DesktopBreakpoints.isDesktop(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DesktopPermissionsScreen()),
          );
        }
      });
    }

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenHeight < 700 || screenWidth < 375;
    
    // Show loading while checking permissions
    if (_isCheckingPermissions) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
              children: [
              SizedBox(width: 56, height: 56, child: InlineLoading(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary, tileSize: 6.0)),
              SizedBox(height: 24),
              Text(
                'Checking permissions...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isSmallScreen),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], isSmallScreen);
                },
              ),
            ),
            _buildBottomSection(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader([bool isSmallScreen = false]) {
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(
            children: [
              AppLogo(
                width: isSmallScreen ? 36 : 40,
                height: isSmallScreen ? 36 : 40,
              ),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Text(
                'art.kubus',
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          // Skip button
          TextButton(
            onPressed: _completeOnboarding,
            child: Text(
              'Skip All',
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 14 : 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(PermissionPage page, [bool isSmallScreen = false]) {
    final isGranted = _isPermissionGranted(page.permissionType);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final constraintSmallScreen = constraints.maxHeight < 700;
        final isVerySmallScreen = constraints.maxHeight < 600;
        final effectiveSmallScreen = isSmallScreen || constraintSmallScreen;
        
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: effectiveSmallScreen ? 20 : 24),
              child: Column(
                children: [
                  SizedBox(height: isVerySmallScreen ? 20 : effectiveSmallScreen ? 30 : 40),
                  // Icon with gradient background (shared widget) + granted badge
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      GradientIconCard(
                        start: page.gradient.colors.first,
                        end: page.gradient.colors.length > 1 ? page.gradient.colors[1] : page.gradient.colors.first,
                        icon: page.iconData,
                        width: isVerySmallScreen ? 100 : effectiveSmallScreen ? 110 : 120,
                        height: isVerySmallScreen ? 100 : effectiveSmallScreen ? 110 : 120,
                        radius: 20,
                        iconSize: isVerySmallScreen ? 50 : effectiveSmallScreen ? 55 : 60,
                      ),
                      if (isGranted)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: isVerySmallScreen ? 24 : effectiveSmallScreen ? 32 : 40),
                  // Title
                  Text(
                    page.title,
                    style: GoogleFonts.inter(
                      fontSize: isVerySmallScreen ? 26 : effectiveSmallScreen ? 28 : 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isVerySmallScreen ? 8 : 12),
                  // Subtitle (single-line & responsive)
                  Text(
                    page.subtitle.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: GoogleFonts.inter(
                      fontSize: isVerySmallScreen ? 18 : effectiveSmallScreen ? 20 : 22,
                      fontWeight: FontWeight.w600,
                      color: page.gradient.colors.first,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isVerySmallScreen ? 16 : 20),
                  // Description
                  Text(
                    page.description,
                    style: GoogleFonts.inter(
                      fontSize: isVerySmallScreen ? 14 : 15,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isVerySmallScreen ? 24 : 32),
                  // Benefits list
                  Container(
                    padding: EdgeInsets.all(isVerySmallScreen ? 16 : 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: page.gradient.colors.first.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What you can do:',
                          style: GoogleFonts.inter(
                            fontSize: isVerySmallScreen ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: isVerySmallScreen ? 12 : 16),
                        ...page.benefits.map((benefit) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  gradient: page.gradient,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  benefit,
                                  style: GoogleFonts.inter(
                                    fontSize: isVerySmallScreen ? 13 : 14,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  SizedBox(height: isVerySmallScreen ? 20 : 24),
                  // Privacy note
                  Container(
                    padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: isVerySmallScreen ? 18 : 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your privacy is protected. We never share your data.',
                            style: GoogleFonts.inter(
                              fontSize: isVerySmallScreen ? 12 : 13,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSection([bool isSmallScreen = false]) {
    final currentPermission = _pages[_currentPage].permissionType;
    final isGranted = _isPermissionGranted(currentPermission);
    final isLastPage = _currentPage == _pages.length - 1;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final constraintSmallScreen = MediaQuery.of(context).size.height < 700;
        final effectiveSmallScreen = isSmallScreen || constraintSmallScreen;
        
        return Padding(
          padding: EdgeInsets.all(effectiveSmallScreen ? 20 : 24),
          child: Column(
            children: [
              // Page indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildDot(index),
                ),
              ),
              SizedBox(height: effectiveSmallScreen ? 20 : 24),
              // Permission status
              if (isGranted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Permission Granted',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              // Grant permission button
              SizedBox(
                width: double.infinity,
                height: effectiveSmallScreen ? 50 : 56,
                child: ElevatedButton(
                  onPressed: isGranted ? (isLastPage ? _completeOnboarding : _nextPage) : () => _requestPermission(currentPermission),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isGranted 
                        ? Theme.of(context).colorScheme.primary
                        : _pages[_currentPage].gradient.colors.first,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isGranted 
                        ? (isLastPage ? 'Get Started' : 'Next Permission')
                        : 'Grant Permission',
                    style: GoogleFonts.inter(
                      fontSize: effectiveSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: effectiveSmallScreen ? 12 : 16),
              // Skip button
              TextButton(
                onPressed: isLastPage ? _completeOnboarding : _nextPage,
                child: Text(
                  isLastPage ? 'Skip for Now' : 'Skip This Permission',
                  style: GoogleFonts.inter(
                    fontSize: effectiveSmallScreen ? 14 : 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDot(int index) {
    final isActive = index == _currentPage;
    final isGranted = _isPermissionGranted(_pages[index].permissionType);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isGranted
            ? Colors.green
            : (isActive 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  bool _isPermissionGranted(PermissionType type) {
    switch (type) {
      case PermissionType.location:
        return _locationGranted;
      case PermissionType.camera:
        return _cameraGranted;
      case PermissionType.notifications:
        return _notificationsGranted;
      case PermissionType.storage:
        return _storageGranted;
    }
  }

  Future<void> _requestPermission(PermissionType type) async {
    // If the permission is not applicable on this platform, skip the request
    if (type == PermissionType.storage && kIsWeb) {
      // On web storage/photos are not requested; treat as granted/irrelevant
      if (mounted) {
        setState(() {
          _storageGranted = true;
        });
      }
      return;
    }

    Permission permission;
    
    switch (type) {
      case PermissionType.location:
        permission = Permission.location;
        break;
      case PermissionType.camera:
        permission = Permission.camera;
        break;
      case PermissionType.notifications:
        permission = Permission.notification;
        break;
      case PermissionType.storage:
        permission = Permission.photos;
        break;
    }

    final messenger = ScaffoldMessenger.of(context);
    PermissionStatus status;
    try {
      status = await permission.request();
    } catch (e, st) {
      debugPrint('PermissionsScreen._requestPermission: permission.request failed: $e\n$st');
      status = PermissionStatus.denied;
    }
    if (!mounted) return;
    
    bool nowGranted = false;
    if (type == PermissionType.notifications && kIsWeb) {
      final pn = PushNotificationService();
      try {
        nowGranted = await pn.requestPermission();
      } catch (e, st) {
        debugPrint('PermissionsScreen._requestPermission: web notification request failed: $e\n$st');
        nowGranted = false;
      }
    } else {
      nowGranted = status.isGranted;
    }
    
    setState(() {
      switch (type) {
        case PermissionType.location:
          _locationGranted = status.isGranted;
          break;
        case PermissionType.camera:
          _cameraGranted = status.isGranted;
          break;
        case PermissionType.notifications:
          _notificationsGranted = nowGranted;
          break;
        case PermissionType.storage:
          _storageGranted = status.isGranted;
          break;
      }
    });

    if (status.isGranted) {
      // Show success feedback
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${_getPermissionName(type)} permission granted!',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Auto-advance after a short delay
            await Future.delayed(const Duration(milliseconds: 500));
      if (_currentPage < _pages.length - 1) {
        _nextPage();
      }
    } else if (status.isPermanentlyDenied) {
      // Show dialog to open settings
      _showSettingsDialog(type);
    }
  }

  String _getPermissionName(PermissionType type) {
    switch (type) {
      case PermissionType.location:
        return 'Location';
      case PermissionType.camera:
        return 'Camera';
      case PermissionType.notifications:
        return 'Notification';
      case PermissionType.storage:
        return 'Storage';
    }
  }

  void _showSettingsDialog(PermissionType type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Permission Required',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'To enable ${_getPermissionName(type).toLowerCase()} access, please open Settings and grant the permission.',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(
              'Open Settings',
              style: GoogleFonts.inter(
                color: Colors.white,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeOnboarding() async {
    // Mark onboarding as completed - users will see feature-specific onboarding when accessing Web3 features
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('completed_onboarding', true);
    await prefs.setBool('has_completed_onboarding', true);
    await prefs.setBool('has_seen_permissions', true);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainApp(),
        ),
      );
    }
  }
}

enum PermissionType {
  location,
  camera,
  notifications,
  storage,
}

class PermissionPage {
  final String title;
  final String subtitle;
  final String description;
  final List<String> benefits;
  final IconData iconData;
  final LinearGradient gradient;
  final PermissionType permissionType;

  PermissionPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.benefits,
    required this.iconData,
    required this.gradient,
    required this.permissionType,
  });
}
