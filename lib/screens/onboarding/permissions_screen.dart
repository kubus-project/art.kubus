import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../widgets/inline_loading.dart';
import '../../services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/onboarding_state_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/gradient_icon_card.dart';
import '../../screens/desktop/desktop_shell.dart';
import '../desktop/onboarding/desktop_permissions_screen.dart';
import '../../main_app.dart';
import '../../utils/app_color_utils.dart';

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
    bool locationGranted = false;
    bool cameraGranted = false;
    bool notificationsGranted = false;
    bool storageGranted = false;

    try {
      final locationStatus = await Permission.location.status;
      locationGranted = locationStatus.isGranted;

      final cameraStatus = await Permission.camera.status;
      cameraGranted = cameraStatus.isGranted;

      final notificationStatus = await Permission.notification.status;
      notificationsGranted = notificationStatus.isGranted;

      if (kIsWeb) {
        storageGranted = true;
      } else {
        final storageStatus = await Permission.photos.status;
        storageGranted = storageStatus.isGranted;
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('PermissionsScreen._checkExistingPermissions: permission status check failed: $e\n$st');
      }
      locationGranted = false;
      cameraGranted = false;
      notificationsGranted = false;
      storageGranted = false;
    }

    if (!mounted) return;

    setState(() {
      _locationGranted = locationGranted;
      _cameraGranted = cameraGranted;
      _notificationsGranted = notificationsGranted;
      _storageGranted = storageGranted;
      _isCheckingPermissions = false;
    });

    final requiredPermissions = <PermissionType>[
      PermissionType.location,
      PermissionType.camera,
      PermissionType.notifications,
      if (!kIsWeb) PermissionType.storage,
    ];

    if (requiredPermissions.every(_isPermissionGranted)) {
      _completeOnboarding();
    }
  }

  List<PermissionPage> get _allPages {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.primary;

    return [
    PermissionPage(
      title: l10n.permissionsLocationTitle,
      subtitle: l10n.permissionsLocationSubtitle,
      description: l10n.permissionsLocationDescription,
      benefits: [
        l10n.permissionsLocationBenefit1,
        l10n.permissionsLocationBenefit2,
        l10n.permissionsLocationBenefit3,
        l10n.permissionsLocationBenefit4,
      ],
      iconData: Icons.location_on_outlined,
      gradient: LinearGradient(
        colors: [base, AppColorUtils.shiftLightness(base, 0.10)],
      ),
      permissionType: PermissionType.location,
    ),
    PermissionPage(
      title: l10n.permissionsCameraTitle,
      subtitle: l10n.permissionsCameraSubtitle,
      description: l10n.permissionsCameraDescription,
      benefits: [
        l10n.permissionsCameraBenefit1,
        l10n.permissionsCameraBenefit2,
        l10n.permissionsCameraBenefit3,
        l10n.permissionsCameraBenefit4,
      ],
      iconData: Icons.camera_alt_outlined,
      gradient: LinearGradient(
        colors: [AppColorUtils.shiftLightness(base, -0.10), base],
      ),
      permissionType: PermissionType.camera,
    ),
    PermissionPage(
      title: l10n.permissionsNotificationsTitle,
      subtitle: l10n.permissionsNotificationsSubtitle,
      description: l10n.permissionsNotificationsDescription,
      benefits: [
        l10n.permissionsNotificationsBenefit1,
        l10n.permissionsNotificationsBenefit2,
        l10n.permissionsNotificationsBenefit3,
        l10n.permissionsNotificationsBenefit4,
      ],
      iconData: Icons.notifications_outlined,
      gradient: LinearGradient(
        colors: [base, AppColorUtils.shiftLightness(base, 0.18)],
      ),
      permissionType: PermissionType.notifications,
    ),
    PermissionPage(
      title: l10n.permissionsPhotosTitle,
      subtitle: l10n.permissionsPhotosSubtitle,
      description: l10n.permissionsPhotosDescription,
      benefits: [
        l10n.permissionsPhotosBenefit1,
        l10n.permissionsPhotosBenefit2,
        l10n.permissionsPhotosBenefit3,
        l10n.permissionsPhotosBenefit4,
      ],
      iconData: Icons.photo_library_outlined,
      gradient: LinearGradient(
        colors: [base, AppColorUtils.shiftLightness(base, -0.14)],
      ),
      permissionType: PermissionType.storage,
    ),
    ];
  }

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
    final l10n = AppLocalizations.of(context)!;
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
                l10n.permissionsChecking,
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
    final l10n = AppLocalizations.of(context)!;
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
                l10n.appTitle,
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
              l10n.permissionsSkipAll,
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
    final l10n = AppLocalizations.of(context)!;
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
                              color: AppColorUtils.greenAccent,
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
                          l10n.permissionsBenefitsTitle,
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
                            l10n.permissionsPrivacyNote,
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
    final l10n = AppLocalizations.of(context)!;
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
                    color: AppColorUtils.greenAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColorUtils.greenAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColorUtils.greenAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.permissionsGrantedLabel,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColorUtils.greenAccent,
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
                        ? (isLastPage ? l10n.permissionsGetStarted : l10n.permissionsNextPermission)
                        : l10n.permissionsGrantPermission,
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
                  isLastPage ? l10n.commonSkipForNow : l10n.permissionsSkipThisPermission,
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
            ? AppColorUtils.greenAccent
            : (isActive 
                ? AppColorUtils.amberAccent
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

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    PermissionStatus status;
    try {
      status = await permission.request();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('PermissionsScreen._requestPermission: permission.request failed: $e\n$st');
      }
      status = PermissionStatus.denied;
    }
    if (!mounted) return;
    
    bool nowGranted = false;
    if (type == PermissionType.notifications && kIsWeb) {
      final pn = PushNotificationService();
      try {
        nowGranted = await pn.requestPermission();
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('PermissionsScreen._requestPermission: web notification request failed: $e\n$st');
        }
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

    if (nowGranted) {
      // Show success feedback
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.permissionsPermissionGrantedToast(_getPermissionName(l10n, type)),
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColorUtils.greenAccent,
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

  String _getPermissionName(AppLocalizations l10n, PermissionType type) {
    switch (type) {
      case PermissionType.location:
        return l10n.permissionsLocationTitle;
      case PermissionType.camera:
        return l10n.permissionsCameraTitle;
      case PermissionType.notifications:
        return l10n.permissionsNotificationsTitle;
      case PermissionType.storage:
        return l10n.permissionsPhotosTitle;
    }
  }

  void _showSettingsDialog(PermissionType type) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.permissionsPermissionRequiredTitle,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          l10n.permissionsOpenSettingsDialogContent(_getPermissionName(l10n, type)),
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonCancel,
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
              l10n.permissionsOpenSettings,
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
    await OnboardingStateService.markCompleted(prefs: prefs);
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
