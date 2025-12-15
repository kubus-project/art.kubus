import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/gradient_icon_card.dart';
import '../../../providers/themeprovider.dart';
import '../../../services/push_notification_service.dart';
import '../../../main_app.dart';
import '../../../utils/app_animations.dart';
import '../desktop_shell.dart';

/// Desktop-optimized permissions screen with side-by-side layout
class DesktopPermissionsScreen extends StatefulWidget {
  const DesktopPermissionsScreen({super.key});

  @override
  State<DesktopPermissionsScreen> createState() =>
      _DesktopPermissionsScreenState();
}

class _DesktopPermissionsScreenState extends State<DesktopPermissionsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCheckingPermissions = true;

  // Track permission states
  bool _locationGranted = false;
  bool _cameraGranted = false;
  bool _notificationsGranted = false;
  bool _storageGranted = false;

  List<PermissionPage> get _allPages {
    final l10n = AppLocalizations.of(context)!;

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
        iconData: Icons.location_on,
        gradient: const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
        iconData: Icons.camera_alt,
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
        iconData: Icons.notifications,
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
        iconData: Icons.photo_library,
        gradient: const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFF0B6E4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        permissionType: PermissionType.storage,
      ),
    ];
  }

  List<PermissionPage> get _pages => kIsWeb
      ? _allPages.where((p) => p.permissionType != PermissionType.storage).toList()
      : _allPages;

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
        debugPrint('DesktopPermissionsScreen._checkExistingPermissions: $e\n$st');
      }
    }

    if (mounted) {
      setState(() {
        _locationGranted = locationGranted;
        _cameraGranted = cameraGranted;
        _notificationsGranted = notificationsGranted;
        _storageGranted = storageGranted;
        _isCheckingPermissions = false;
      });
    }

    // If all permissions granted, auto-complete
    final requiredPermissions = <PermissionType>[
      PermissionType.location,
      PermissionType.camera,
      PermissionType.notifications,
      if (!kIsWeb) PermissionType.storage,
    ];

    if (requiredPermissions.every(_isPermissionGranted)) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _completeOnboarding();
    }
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
    if (type == PermissionType.storage && kIsWeb) {
      setState(() => _storageGranted = true);
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
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DesktopPermissionsScreen._requestPermission: permission.request failed: $e');
      }
      status = PermissionStatus.denied;
    }

    if (!mounted) return;

    bool nowGranted = false;
    if (type == PermissionType.notifications && kIsWeb) {
      try {
        nowGranted = await PushNotificationService().requestPermission();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('DesktopPermissionsScreen._requestPermission: web notification request failed: $e');
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.permissionsPermissionGrantedToast(_getPermissionName(l10n, type)),
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (_currentPage < _pages.length - 1) {
        _nextPage();
      }
    } else if (status.isPermanentlyDenied) {
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
            child: Text(l10n.commonCancel, style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(l10n.permissionsOpenSettings, style: GoogleFonts.inter()),
          ),
        ],
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('completed_onboarding', true);
    await prefs.setBool('has_completed_onboarding', true);
    await prefs.setBool('has_seen_permissions', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainApp()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermissions) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.accentColor;
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;

    final contentWidth = screenWidth > DesktopBreakpoints.large
        ? 1400.0
        : screenWidth > DesktopBreakpoints.expanded
            ? 1100.0
            : 900.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Container(
          width: contentWidth,
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Row(
                  children: [
                    // Left side - Content
                    Expanded(
                      flex: 5,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() => _currentPage = index);
                        },
                        itemCount: _pages.length,
                        itemBuilder: (context, index) =>
                            _buildPageContent(_pages[index]),
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Right side - Navigation & Actions
                    Expanded(
                      flex: 3,
                      child: _buildSidebar(accentColor, animationTheme),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const AppLogo(width: 48, height: 48),
              const SizedBox(width: 16),
              Text(
                l10n.appTitle,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _completeOnboarding,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              l10n.permissionsSkipAll,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(PermissionPage page) {
    final l10n = AppLocalizations.of(context)!;
    final isGranted = _isPermissionGranted(page.permissionType);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon with status badge
            Stack(
              alignment: Alignment.center,
              children: [
                GradientIconCard(
                  start: page.gradient.colors.first,
                  end: page.gradient.colors.length > 1
                      ? page.gradient.colors[1]
                      : page.gradient.colors.first,
                  icon: page.iconData,
                  width: 140,
                  height: 140,
                  radius: 24,
                  iconSize: 70,
                ),
                if (isGranted)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 48),
            // Title
            Text(
              page.title,
              style: GoogleFonts.inter(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 16),
            // Subtitle
            Text(
              page.subtitle,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: page.gradient.colors.first,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 24),
            // Description
            Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(
                page.description,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Benefits list
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...page.benefits.map((benefit) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                gradient: page.gradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                benefit,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.8),
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
            const SizedBox(height: 24),
            // Privacy note
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      l10n.permissionsPrivacyNote,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
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

  Widget _buildSidebar(Color accentColor, AppAnimationTheme animationTheme) {
    final l10n = AppLocalizations.of(context)!;
    final currentPermission = _pages[_currentPage].permissionType;
    final isGranted = _isPermissionGranted(currentPermission);
    final isLastPage = _currentPage == _pages.length - 1;

    return Padding(
      padding: const EdgeInsets.only(right: 40, top: 20, bottom: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          // Permission indicators
          ..._pages.asMap().entries.map((entry) {
            final index = entry.key;
            final page = entry.value;
            final isActive = index == _currentPage;
            final isPageGranted = _isPermissionGranted(page.permissionType);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  // Status icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isPageGranted
                          ? Colors.green
                          : isActive
                              ? accentColor.withValues(alpha: 0.2)
                              : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isPageGranted
                            ? Colors.green
                            : isActive
                                ? accentColor
                                : Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isPageGranted ? Icons.check : page.iconData,
                      size: 16,
                      color: isPageGranted
                          ? Colors.white
                          : isActive
                              ? accentColor
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Label
                  Expanded(
                    child: Text(
                      page.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        color: isActive
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 32),
          // Status message
          if (isGranted)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    l10n.permissionsGrantedLabel,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          // Action buttons
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: isGranted
                  ? (isLastPage ? _completeOnboarding : _nextPage)
                  : () => _requestPermission(currentPermission),
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
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: isLastPage ? _completeOnboarding : _nextPage,
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isLastPage ? l10n.commonSkipForNow : l10n.permissionsSkipThisPermission,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
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
