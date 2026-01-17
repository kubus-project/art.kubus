import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'providers/themeprovider.dart';
import 'providers/wallet_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/deep_link_provider.dart';
import 'providers/deferred_onboarding_provider.dart';
import 'providers/main_tab_provider.dart';
import 'core/mobile_shell_registry.dart';
import 'services/pin_hashing.dart';
import 'services/settings_service.dart';
import 'services/telemetry/telemetry_service.dart';
import 'utils/share_deep_link_navigation.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/art/ar_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/community/profile_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/desktop/desktop_shell.dart';
import 'utils/app_animations.dart';
import 'utils/design_tokens.dart';
import 'widgets/glass_components.dart';
import 'widgets/user_persona_onboarding_gate.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  MainTabProvider? _tabProvider;
  int _lastTelemetryIndex = -1;
  bool _didConsumeInitialDeepLink = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = context.read<MainTabProvider>().currentIndex;
      _syncTelemetryForIndex(index);
      _lastTelemetryIndex = index;
    });

    // If we arrived via a cold-start deep link, AppInitializer leaves the
    // target pending so the shell can open it using an in-shell context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Desktop is handled inside DesktopShell (it needs DesktopShellScope).
      if (DesktopBreakpoints.isDesktop(context)) return;
      if (_didConsumeInitialDeepLink) return;
      _didConsumeInitialDeepLink = true;

      ShareDeepLinkTarget? target;
      try {
        target = context.read<DeepLinkProvider>().consumePending();
      } catch (_) {
        target = null;
      }
      if (target == null) return;

      // ignore: discarded_futures
      ShareDeepLinkNavigation.open(context, target);
      try {
        context.read<DeferredOnboardingProvider>().markInitialDeepLinkHandled();
      } catch (_) {}
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<MainTabProvider>(context);
    if (_tabProvider == provider) return;
    _tabProvider?.removeListener(_handleTabProviderChanged);
    _tabProvider = provider;
    _tabProvider?.addListener(_handleTabProviderChanged);
  }

  void _handleTabProviderChanged() {
    if (!mounted) return;
    final index = _tabProvider?.currentIndex ?? 0;
    if (index == _lastTelemetryIndex) return;
    _lastTelemetryIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTelemetryForIndex(index);
    });
  }

  @override
  void dispose() {
    MobileShellRegistry.instance.unregister(context);
    _tabProvider?.removeListener(_handleTabProviderChanged);
    _tabProvider = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use screen-based breakpoints (not platform) so large tablets get desktop
    // UI and mobile browsers on web stay on the phone layout.
    final useDesktopLayout = DesktopBreakpoints.isDesktop(context);

    if (useDesktopLayout) {
      return const DesktopShell();
    }

    MobileShellRegistry.instance.register(context);

    final walletProvider = Provider.of<WalletProvider>(context);
    final animationTheme = context.animationTheme;
    final currentIndex = context.watch<MainTabProvider>().currentIndex;

    return UserPersonaOnboardingGate(
      child: AnimatedGradientBackground(
        // The app's base gradient needs to paint behind BOTH the app bar area
        // (status bar) and the bottom navigation bar. Screens should keep their
        // scaffolds transparent so this background remains visible.
        animate: true,
        intensity: 0.22,
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.transparent,
              extendBody: true,
              body: IndexedStack(
                index: currentIndex,
                // Keep heavy AR resources out of the tree unless the AR tab is active.
                children: _buildScreens(currentIndex),
              ),
              bottomNavigationBar: _buildBottomNavigationBar(),
            ),

            // Lock overlay with animated transitions
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !walletProvider.isLocked,
                child: AnimatedSwitcher(
                  duration: animationTheme.medium,
                  switchInCurve: animationTheme.fadeCurve,
                  switchOutCurve: animationTheme.fadeCurve,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: CurvedAnimation(parent: animation, curve: animationTheme.fadeCurve),
                    child: child,
                  ),
                  child: walletProvider.isLocked
                      ? _LockOverlay(
                          key: const ValueKey('locked'),
                          onUnlockRequested: _handleUnlock,
                        )
                      : const SizedBox(key: ValueKey('unlocked')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildScreens(int currentIndex) {
    return const [
      MapScreen(),
      // Only build AR when selected so the camera is released when not in use.
      ARScreen(),
      CommunityScreen(),
      HomeScreen(),
      ProfileScreenWrapper(),
    ].asMap().entries.map((entry) {
      if (entry.key == 1 && currentIndex != 1) {
        return const SizedBox
            .shrink(key: ValueKey('ar-placeholder')); // frees camera resources
      }
      return entry.value;
    }).toList();
  }

  Widget _buildBottomNavigationBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final glassTint = scheme.surface.withValues(alpha: isDark ? 0.18 : 0.12);
        
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: LiquidGlassPanel(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.zero,
            blurSigma: KubusGlassEffects.blurSigmaLight,
            backgroundColor: glassTint,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? KubusSpacing.xs : KubusSpacing.sm,
                  vertical: isSmallScreen ? 2 : KubusSpacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(context, 0, Icons.explore, isSmallScreen),
                    _buildNavItem(context, 1, Icons.view_in_ar, isSmallScreen),
                    _buildNavItem(context, 2, Icons.people, isSmallScreen),
                    _buildNavItem(context, 3, Icons.home, isSmallScreen),
                    _buildNavItem(context, 4, Icons.person, isSmallScreen),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    bool isSmallScreen,
  ) {
    final isSelected = context.select<MainTabProvider, bool>((p) => p.currentIndex == index);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          final tabs = context.read<MainTabProvider>();
          if (tabs.currentIndex == index) return;

          // If onboarding is deferred due to a cold-start deep link, show it
          // once the user tries to navigate away from the deep-linked surface.
          final deferredOnboarding = context.read<DeferredOnboardingProvider>();
          if (deferredOnboarding.maybeShowOnboarding(context)) return;

          tabs.setIndex(index);
        },
        child: AnimatedContainer(
          duration: animationTheme.short,
          curve: animationTheme.defaultCurve,
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? KubusSpacing.xs : KubusSpacing.sm,
            vertical: isSmallScreen ? KubusSpacing.sm : KubusSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? themeProvider.accentColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: KubusRadius.circular(KubusRadius.md),
            border: Border.all(
              color: isSelected
                  ? themeProvider.accentColor.withValues(alpha: 0.28)
                  : scheme.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          child: Center(
            child: AnimatedScale(
              scale: isSelected ? 1.0 : 0.92,
              duration: animationTheme.short,
              curve: animationTheme.emphasisCurve,
              child: AnimatedOpacity(
                duration: animationTheme.short,
                opacity: isSelected ? 1.0 : 0.65,
                curve: animationTheme.fadeCurve,
                child: Icon(
                  icon,
                  color: isSelected
                      ? themeProvider.accentColor
                      : scheme.onSurface.withValues(alpha: 0.82),
                  size: isSmallScreen ? 24 : 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleUnlock() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final localWallet = Provider.of<WalletProvider>(context, listen: false);

    var biometricEnabled = false;
    try {
      final settings = await SettingsService.loadSettings();
      biometricEnabled = settings.biometricAuth;
    } catch (_) {
      biometricEnabled = false;
    }

    if (biometricEnabled) {
      final outcome = await localWallet.unlockWithBiometrics(
        localizedReason: l10n.lockAppLockedDescription,
      );
      if (!mounted) return;
      if (outcome == BiometricAuthOutcome.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.lockAppUnlockedToast)),
        );
        return;
      }
      if (outcome == BiometricAuthOutcome.cancelled) {
        return;
      }
      if (outcome == BiometricAuthOutcome.notAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsBiometricUnavailableToast)),
        );
      }
    }

    final hasPin = await localWallet.hasPin();
    if (!mounted) return;
    if (!hasPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.lockAuthenticationFailedToast)),
      );
      return;
    }

    final remaining = await localWallet.getPinLockoutRemainingSeconds();
    if (!mounted) return;
    if (remaining > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mnemonicRevealPinLockedError(remaining))),
      );
      return;
    }

    final pinController = TextEditingController();
    if (!mounted) return;
    final entered = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.lockEnterPinTitle),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: InputDecoration(labelText: l10n.commonPinLabel),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(pinController.text.trim()),
            child: Text(l10n.commonUnlock),
          ),
        ],
      ),
    );

    if (entered == null || entered.isEmpty) return;
    final result = await localWallet.unlockWithPin(entered);
    if (!mounted) return;
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.lockAppUnlockedToast)),
      );
      return;
    }

    if (result.outcome == PinVerifyOutcome.lockedOut) {
      final seconds = result.remainingLockoutSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mnemonicRevealPinLockedError(seconds))),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.mnemonicRevealIncorrectPinError)),
    );
  }

  void _syncTelemetryForIndex(int index) {
    if (DesktopBreakpoints.isDesktop(context)) return;
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

    String name;
    String route;

    switch (index) {
      case 0:
        name = 'MainTabMap';
        route = '/main/tab/map';
        break;
      case 1:
        name = 'MainTabAR';
        route = '/main/tab/ar';
        break;
      case 2:
        name = 'MainTabCommunity';
        route = '/main/tab/community';
        break;
      case 3:
        name = 'MainTabHome';
        route = '/main/tab/home';
        break;
      case 4:
        if (!profileProvider.isSignedIn) {
          name = 'SignIn';
          route = '/sign-in';
        } else {
          name = 'MainTabProfile';
          route = '/main/tab/profile';
        }
        break;
      default:
        name = 'MainTabUnknown';
        route = '/main/tab/unknown';
    }

    TelemetryService().setActiveScreen(screenName: name, screenRoute: route);
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({super.key, required this.onUnlockRequested});

  final Future<void> Function() onUnlockRequested;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.lockAppLockedTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.lockAppLockedDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onUnlockRequested,
                child: Text(l10n.commonUnlock),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper widget that checks authentication before showing profile screen
class ProfileScreenWrapper extends StatelessWidget {
  const ProfileScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    
    if (!profileProvider.isSignedIn) {
      return const SignInScreenWrapper();
    }
    
    return const ProfileScreen();
  }
}

/// Wrapper widget for sign-in screen with proper theming
class SignInScreenWrapper extends StatelessWidget {
  const SignInScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const SignInScreen();
  }
}
