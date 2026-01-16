import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'providers/themeprovider.dart';
import 'providers/wallet_provider.dart';
import 'providers/profile_provider.dart';
import 'services/telemetry/telemetry_service.dart';
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
  int _currentIndex = 0; // Start with map (index 0)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTelemetryForIndex(_currentIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);
    final animationTheme = context.animationTheme;
    
    // Use screen-based breakpoints (not platform) so large tablets get desktop
    // UI and mobile browsers on web stay on the phone layout.
    final useDesktopLayout = DesktopBreakpoints.isDesktop(context);

    if (useDesktopLayout) {
      return const DesktopShell();
    }

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
                index: _currentIndex,
                // Keep heavy AR resources out of the tree unless the AR tab is active.
                children: _buildScreens(),
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

  List<Widget> _buildScreens() {
    return const [
      MapScreen(),
      // Only build AR when selected so the camera is released when not in use.
      ARScreen(),
      CommunityScreen(),
      HomeScreen(),
      ProfileScreenWrapper(),
    ].asMap().entries.map((entry) {
      if (entry.key == 1 && _currentIndex != 1) {
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
                    _buildNavItem(0, Icons.explore, isSmallScreen),
                    _buildNavItem(1, Icons.view_in_ar, isSmallScreen),
                    _buildNavItem(2, Icons.people, isSmallScreen),
                    _buildNavItem(3, Icons.home, isSmallScreen),
                    _buildNavItem(4, Icons.person, isSmallScreen),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, bool isSmallScreen) {
    final isSelected = _currentIndex == index;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_currentIndex == index) return;
          setState(() {
            _currentIndex = index;
          });
          _syncTelemetryForIndex(index);
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
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
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
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    size: isSmallScreen ? 24 : 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUnlock() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final localWallet = Provider.of<WalletProvider>(context, listen: false);

    final ok = await localWallet.authenticateForAppUnlock();
    if (ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.lockAppUnlockedToast)));
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
    final ok2 = await localWallet.authenticateForAppUnlock(pin: entered);
    if (!mounted) return;
    if (ok2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.lockAppUnlockedToast)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.lockAuthenticationFailedToast)));
    }
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
