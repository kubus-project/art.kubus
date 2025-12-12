import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/themeprovider.dart';
import 'providers/wallet_provider.dart';
import 'providers/profile_provider.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/art/ar_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/community/profile_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/desktop/desktop_shell.dart';
import 'utils/app_animations.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0; // Start with map (index 0)

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

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
        
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 4 : 8, 
                vertical: isSmallScreen ? 2 : 4,
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
          setState(() {
            _currentIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: animationTheme.short,
          curve: animationTheme.defaultCurve,
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 4 : 8, 
            vertical: isSmallScreen ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: isSelected 
                ? themeProvider.accentColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
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
    final localWallet = Provider.of<WalletProvider>(context, listen: false);

    final ok = await localWallet.authenticateForAppUnlock();
    if (ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App unlocked')));
      return;
    }

    final pinController = TextEditingController();
    if (!mounted) return;
    final entered = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter PIN to unlock'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(pinController.text.trim()),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (entered == null || entered.isEmpty) return;
    final ok2 = await localWallet.authenticateForAppUnlock(pin: entered);
    if (!mounted) return;
    if (ok2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App unlocked')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication failed')));
    }
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({super.key, required this.onUnlockRequested});

  final Future<void> Function() onUnlockRequested;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'App locked',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Authenticate to unlock access to the wallet features.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onUnlockRequested,
                child: const Text('Unlock'),
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