import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../../services/notification_helper.dart';
import '../../../services/onboarding_state_service.dart';
import '../../../services/push_notification_service.dart';
import '../../../services/telemetry/telemetry_service.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/gradient_icon_card.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/kubus_color_roles.dart';
import '../desktop_shell.dart';
import '../../../widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

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
  bool _isCompletingOnboarding = false;

  // Track permission states
  bool _locationGranted = false;
  bool _cameraGranted = false;
  bool _notificationsGranted = false;

  List<PermissionPage> get _allPages {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);

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
        gradient: LinearGradient(
          colors: [
            roles.statTeal,
            AppColorUtils.shiftLightness(roles.statTeal, 0.10)
          ],
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
        gradient: LinearGradient(
          colors: [
            roles.positiveAction,
            AppColorUtils.shiftLightness(roles.positiveAction, -0.10)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        permissionType: PermissionType.camera,
      ),
      if (kIsWeb)
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
          gradient: LinearGradient(
            colors: [
              roles.statAmber,
              AppColorUtils.shiftLightness(roles.statAmber, 0.10)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          permissionType: PermissionType.notifications,
        ),
    ];
  }

  // Only request the core permissions needed for the first-run experience.
  List<PermissionPage> get _pages => kIsWeb
      ? _allPages
          .where((p) => p.permissionType != PermissionType.camera)
          .toList()
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

    try {
      final locationStatus = await Permission.location.status;
      locationGranted = locationStatus.isGranted;

      if (kIsWeb) {
        cameraGranted = true;
      } else {
        final cameraStatus = await Permission.camera.status;
        cameraGranted = cameraStatus.isGranted;
      }

      if (kIsWeb) {
        notificationsGranted = await isWebNotificationPermissionGranted();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
            'DesktopPermissionsScreen._checkExistingPermissions: $e\n$st');
      }
    }

    if (mounted) {
      setState(() {
        _locationGranted = locationGranted;
        _cameraGranted = cameraGranted;
        _notificationsGranted = notificationsGranted;
        _isCheckingPermissions = false;
      });
    }

    // If all permissions granted, auto-complete
    final requiredPermissions = <PermissionType>[
      PermissionType.location,
      if (!kIsWeb) PermissionType.camera,
      if (kIsWeb) PermissionType.notifications,
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
    }
  }

  Future<void> _requestPermission(PermissionType type) async {
    if (type == PermissionType.notifications) {
      final l10n = AppLocalizations.of(context)!;
      final messenger = ScaffoldMessenger.of(context);

      bool granted = false;
      try {
        granted = await PushNotificationService().requestPermission();
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint(
            'DesktopPermissionsScreen._requestPermission: notifications request failed: $e\n$st',
          );
        }
        granted = false;
      }

      if (!mounted) return;

      setState(() {
        _notificationsGranted = granted;
      });

      if (granted) {
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(
              l10n.permissionsPermissionGrantedToast(
                  _getPermissionName(l10n, type)),
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
      }

      return;
    }

    if (type == PermissionType.camera && kIsWeb) {
      // Camera access is intentionally not requested on web.
      setState(() => _cameraGranted = true);
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
        throw StateError('notifications permission is handled separately');
    }

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    PermissionStatus status;
    try {
      status = await permission.request();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'DesktopPermissionsScreen._requestPermission: permission.request failed: $e');
      }
      status = PermissionStatus.denied;
    }

    if (!mounted) return;

    final nowGranted = status.isGranted;

    setState(() {
      switch (type) {
        case PermissionType.location:
          _locationGranted = status.isGranted;
          break;
        case PermissionType.camera:
          _cameraGranted = status.isGranted;
          break;
        case PermissionType.notifications:
          _notificationsGranted = status.isGranted;
          break;
      }
    });

    if (nowGranted) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            l10n.permissionsPermissionGrantedToast(
                _getPermissionName(l10n, type)),
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
    }
  }

  void _showSettingsDialog(PermissionType type) {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.permissionsPermissionRequiredTitle,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          l10n.permissionsOpenSettingsDialogContent(
              _getPermissionName(l10n, type)),
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
            child:
                Text(l10n.permissionsOpenSettings, style: GoogleFonts.inter()),
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
    if (_isCompletingOnboarding) return;

    final navigator = Navigator.of(context);

    setState(() => _isCompletingOnboarding = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_permissions', true);
      await OnboardingStateService.markCompleted(prefs: prefs);
      unawaited(
        TelemetryService()
            .trackOnboardingComplete(reason: 'permissions_complete_to_main'),
      );

      if (!mounted) return;
      navigator.pushReplacementNamed('/main');
    } finally {
      if (mounted) {
        setState(() => _isCompletingOnboarding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermissions) {
      return AnimatedGradientBackground(
        duration: const Duration(seconds: 10),
        intensity: 0.25,
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.accentColor;
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;

    final current = _pages[_currentPage.clamp(0, _pages.length - 1)];
    final start = current.gradient.colors.first.withValues(alpha: 0.55);
    final end = (current.gradient.colors.length > 1
            ? current.gradient.colors[1]
            : current.gradient.colors.first)
        .withValues(alpha: 0.50);
    final mid = (Color.lerp(start, end, 0.55) ?? end).withValues(alpha: 0.52);
    final bgColors = <Color>[start, mid, end, start];

    final contentWidth = screenWidth > DesktopBreakpoints.large
        ? 1400.0
        : screenWidth > DesktopBreakpoints.expanded
            ? 1100.0
            : 900.0;

    return AnimatedGradientBackground(
      duration: const Duration(seconds: 10),
      intensity: 0.25,
      colors: bgColors,
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const AppLogo(width: 48, height: 48),
          TextButton(
            onPressed: _isCompletingOnboarding ? null : _completeOnboarding,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              l10n.permissionsSkipAll,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(PermissionPage page) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isGranted = _isPermissionGranted(page.permissionType);

    final message = page.subtitle.replaceAll('\n', ' ').trim().isNotEmpty
        ? page.subtitle.replaceAll('\n', ' ').trim()
        : page.description.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  GradientIconCard(
                    start: page.gradient.colors.first,
                    end: page.gradient.colors.length > 1
                        ? page.gradient.colors[1]
                        : page.gradient.colors.first,
                    icon: page.iconData,
                    width: 120,
                    height: 120,
                    radius: 22,
                    iconSize: 60,
                  ),
                  if (isGranted)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColorUtils.greenAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                page.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.82),
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.permissionsPrivacyNote,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.65),
                      height: 1.25,
                    ),
              ),
            ],
          ),
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
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
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
              onPressed: _isCompletingOnboarding
                  ? null
                  : isGranted
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
              child: _isCompletingOnboarding
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      isGranted
                          ? (isLastPage
                              ? l10n.permissionsGetStarted
                              : l10n.permissionsNextPermission)
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
              onPressed: _isCompletingOnboarding
                  ? null
                  : (isLastPage ? _completeOnboarding : _nextPage),
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
                isLastPage
                    ? l10n.commonSkipForNow
                    : l10n.permissionsSkipThisPermission,
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
