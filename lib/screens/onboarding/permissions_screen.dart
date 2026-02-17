import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../widgets/inline_loading.dart';
import '../../services/notification_helper.dart';
import '../../services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/onboarding_state_service.dart';
import '../../services/telemetry/telemetry_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/gradient_icon_card.dart';
import '../../screens/desktop/desktop_shell.dart';
import '../desktop/onboarding/desktop_permissions_screen.dart';
import 'onboarding_flow_screen.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../widgets/kubus_button.dart';
import '../../widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  static const int _onboardingFlowVersion = 2;
  static const String _welcomeStepId = 'welcome';
  static const String _permissionsStepId = 'permissions';

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCheckingPermissions = true;
  bool _isCompletingOnboarding = false;

  // Track permission states
  bool _locationGranted = false;
  bool _cameraGranted = false;
  bool _notificationsGranted = false;

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

      // On web we do not request or check camera permission in onboarding.
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
            'PermissionsScreen._checkExistingPermissions: permission status check failed: $e\n$st');
      }
      locationGranted = false;
      cameraGranted = false;
      notificationsGranted = false;
    }

    if (!mounted) return;

    setState(() {
      _locationGranted = locationGranted;
      _cameraGranted = cameraGranted;
      _notificationsGranted = notificationsGranted;
      _isCheckingPermissions = false;
    });

    final requiredPermissions = <PermissionType>[
      PermissionType.location,
      if (!kIsWeb) PermissionType.camera,
      if (kIsWeb) PermissionType.notifications,
    ];

    if (requiredPermissions.every(_isPermissionGranted)) {
      _completeOnboarding();
    }
  }

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
        iconData: Icons.location_on_outlined,
        gradient: LinearGradient(
          colors: [
            roles.statTeal,
            AppColorUtils.shiftLightness(roles.statTeal, 0.12)
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
        iconData: Icons.camera_alt_outlined,
        gradient: LinearGradient(
          colors: [
            roles.positiveAction,
            AppColorUtils.shiftLightness(roles.positiveAction, -0.15)
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
          iconData: Icons.notifications_outlined,
          gradient: LinearGradient(
            colors: [roles.statAmber, roles.negativeAction],
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
            MaterialPageRoute(
                builder: (context) => const DesktopPermissionsScreen()),
          );
        }
      });
    }

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenHeight < 700 || screenWidth < 375;

    final pages = _pages;
    final current = pages[_currentPage.clamp(0, pages.length - 1)];
    final start = current.gradient.colors.first.withValues(alpha: 0.55);
    final end = (current.gradient.colors.length > 1
            ? current.gradient.colors[1]
            : current.gradient.colors.first)
        .withValues(alpha: 0.50);
    final mid = (Color.lerp(start, end, 0.55) ?? end).withValues(alpha: 0.52);
    final bgColors = <Color>[start, mid, end, start];

    // Show loading while checking permissions
    if (_isCheckingPermissions) {
      return AnimatedGradientBackground(
        duration: const Duration(seconds: 10),
        intensity: 0.25,
        colors: bgColors,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: InlineLoading(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                    tileSize: 6.0,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.permissionsChecking,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedGradientBackground(
      duration: const Duration(seconds: 10),
      intensity: 0.25,
      colors: bgColors,
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
      ),
    );
  }

  Widget _buildHeader([bool isSmallScreen = false]) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? KubusSpacing.lg : KubusSpacing.xl,
        isSmallScreen ? KubusSpacing.md : KubusSpacing.lg,
        isSmallScreen ? KubusSpacing.lg : KubusSpacing.xl,
        KubusSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          AppLogo(
            width: isSmallScreen ? 34 : 38,
            height: isSmallScreen ? 34 : 38,
          ),
          // Skip button
          TextButton(
            onPressed: _isCompletingOnboarding ? null : _completeOnboarding,
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

  Widget _buildPage(PermissionPage page, [bool isSmallScreen = false]) {
    final l10n = AppLocalizations.of(context)!;
    final isGranted = _isPermissionGranted(page.permissionType);

    return LayoutBuilder(
      builder: (context, constraints) {
        final scheme = Theme.of(context).colorScheme;
        final height = constraints.maxHeight;
        final compact = isSmallScreen || height < 420;
        final tight = height < 360;

        final iconCardSize = tight ? 82.0 : (compact ? 100.0 : 120.0);
        final iconSize = tight ? 40.0 : (compact ? 52.0 : 60.0);

        final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: tight ? 22 : (compact ? 24 : null),
              color: scheme.onSurface,
            );

        final message = page.subtitle.replaceAll('\n', ' ').trim().isNotEmpty
            ? page.subtitle.replaceAll('\n', ' ').trim()
            : page.description.trim();

        final messageStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.82),
              fontSize: tight ? 13 : (compact ? 14 : null),
              height: 1.35,
            );

        final helperStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
              height: 1.25,
            );

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? KubusSpacing.lg : KubusSpacing.xl,
              ),
              child: Column(
                children: [
                  const Spacer(),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      GradientIconCard(
                        start: page.gradient.colors.first,
                        end: page.gradient.colors.length > 1
                            ? page.gradient.colors[1]
                            : page.gradient.colors.first,
                        icon: page.iconData,
                        width: iconCardSize,
                        height: iconCardSize,
                        radius: KubusRadius.lg,
                        iconSize: iconSize,
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
                            child: const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: tight ? KubusSpacing.md : KubusSpacing.lg),
                  Text(
                    page.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    maxLines: tight ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: messageStyle,
                  ),
                  if (!tight) ...[
                    const SizedBox(height: KubusSpacing.sm),
                    Text(
                      l10n.permissionsPrivacyNote,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: helperStyle,
                    ),
                  ],
                  const Spacer(),
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
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final constraintSmallScreen = MediaQuery.of(context).size.height < 700;
        final effectiveSmallScreen = isSmallScreen || constraintSmallScreen;
        final primaryBg = scheme.primary;
        final primaryFg = scheme.onPrimary;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            effectiveSmallScreen ? KubusSpacing.lg : KubusSpacing.xl,
            KubusSpacing.sm,
            effectiveSmallScreen ? KubusSpacing.lg : KubusSpacing.xl,
            effectiveSmallScreen ? KubusSpacing.lg : KubusSpacing.xl,
          ),
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
              SizedBox(
                  height:
                      effectiveSmallScreen ? KubusSpacing.md : KubusSpacing.lg),
              // Grant permission button
              KubusButton(
                onPressed: _isCompletingOnboarding
                    ? null
                    : isGranted
                        ? (isLastPage ? _completeOnboarding : _nextPage)
                        : () => _requestPermission(currentPermission),
                backgroundColor: primaryBg,
                foregroundColor: primaryFg,
                label: isGranted
                    ? (isLastPage
                        ? l10n.permissionsGetStarted
                        : l10n.permissionsNextPermission)
                    : l10n.permissionsGrantPermission,
                isLoading: _isCompletingOnboarding,
                isFullWidth: true,
              ),
              SizedBox(
                  height:
                      effectiveSmallScreen ? KubusSpacing.xs : KubusSpacing.sm),
              // Skip button
              TextButton(
                onPressed: _isCompletingOnboarding
                    ? null
                    : (isLastPage ? _completeOnboarding : _nextPage),
                child: Text(
                  isLastPage
                      ? l10n.commonSkipForNow
                      : l10n.permissionsSkipThisPermission,
                  style: KubusTypography.textTheme.labelLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
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
            ? KubusColors.success
            : (isActive
                ? KubusColors.warning
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3)),
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
            'PermissionsScreen._requestPermission: notifications request failed: $e\n$st',
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
            backgroundColor: AppColorUtils.greenAccent,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
      if (mounted) {
        setState(() {
          _cameraGranted = true;
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
        throw StateError('notifications permission is handled separately');
    }

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    PermissionStatus status;
    try {
      status = await permission.request();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
            'PermissionsScreen._requestPermission: permission.request failed: $e\n$st');
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
      // Show success feedback
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            l10n.permissionsPermissionGrantedToast(
                _getPermissionName(l10n, type)),
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
    if (_isCompletingOnboarding) return;

    final navigator = Navigator.of(context);

    setState(() => _isCompletingOnboarding = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_permissions', true);
      // Legacy permissions screen now hands users into the step-based flow.
      // We persist these steps to avoid repeating the intro + permissions steps.
      final progress = await OnboardingStateService.loadFlowProgress(
        prefs: prefs,
        onboardingVersion: _onboardingFlowVersion,
      );
      final completedSteps = <String>{
        ...progress.completedSteps,
        _welcomeStepId,
        _permissionsStepId,
      };
      final deferredSteps = <String>{...progress.deferredSteps}
        ..remove(_permissionsStepId);
      await OnboardingStateService.saveFlowProgress(
        prefs: prefs,
        onboardingVersion: _onboardingFlowVersion,
        completedSteps: completedSteps,
        deferredSteps: deferredSteps,
      );
      unawaited(
        TelemetryService()
            .trackOnboardingComplete(reason: 'permissions_continue_flow'),
      );

      if (!mounted) return;
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => const OnboardingFlowScreen(initialStepId: 'account'),
          settings: const RouteSettings(name: '/onboarding/flow'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCompletingOnboarding = false);
      }
    }
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
