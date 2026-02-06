// NOTE: use_build_context_synchronously lint handled per-instance; avoid file-level ignore

import 'package:art_kubus/widgets/glass_components.dart';
// NOTE: use_build_context_synchronously lint handled per-instance; avoid file-level ignore
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';
import '../providers/config_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/artwork_provider.dart';
import '../providers/saved_items_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/web3provider.dart';
import '../providers/cache_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/deep_link_provider.dart';
import '../providers/auth_deep_link_provider.dart';
import '../providers/deferred_onboarding_provider.dart';
import '../services/backend_api_service.dart';
import '../services/app_bootstrap_service.dart';
import '../services/onboarding_state_service.dart';
import '../services/auth_gating_service.dart';
import '../services/auth/auth_deep_link_parser.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/desktop/onboarding/desktop_onboarding_screen.dart';
import '../screens/desktop/desktop_shell.dart';
import '../widgets/app_loading.dart';
import 'app_navigator.dart';
import 'deep_link_startup_routing.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  String? initializationError;
  Completer<void>? _initCompleter;
  Timer? _startupWatchdog;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeApp());
    });

    // Safety net: never stay on AppLoading forever (e.g. due to a plugin hang on web/desktop).
    _startupWatchdog?.cancel();
    _startupWatchdog = Timer(const Duration(seconds: 20), () {
      if (!mounted || _didNavigate) return;
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;
      final isDesktop = DesktopBreakpoints.isDesktop(navigator.context);
      _didNavigate = true;
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => isDesktop ? const DesktopOnboardingScreen() : const OnboardingScreen(),
          settings: RouteSettings(name: isDesktop ? '/onboarding/desktop' : '/onboarding'),
        ),
      );
    });
  }

  @override
  void dispose() {
    _startupWatchdog?.cancel();
    _startupWatchdog = null;
    super.dispose();
  }

  Future<T?> _safeStep<T>(
    String label,
    Future<T> Function() step, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      return await step().timeout(timeout);
    } catch (e) {
      AppConfig.debugPrint('AppInitializer: $label failed: $e');
      return null;
    }
  }

  Future<void> _initializeApp() async {
    final existing = _initCompleter;
    if (existing != null) return existing.future;
    final completer = Completer<void>();
    _initCompleter = completer;

    NavigatorState? navigator = appNavigatorKey.currentState;
    try {
      navigator ??= Navigator.of(context);
    } catch (e) {
      AppConfig.debugPrint('AppInitializer: navigator unavailable: $e');
    }
    if (navigator == null) {
      // If the navigator isn't ready yet (rare on web refresh), retry next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_initializeApp());
      });
      if (!completer.isCompleted) completer.complete();
      _initCompleter = null;
      return completer.future;
    }

    try {
      // Load JWT token for backend authentication (do not block indefinitely on startup).
      await _safeStep<void>(
        'loadAuthToken',
        BackendApiService().loadAuthToken,
        timeout: const Duration(seconds: 3),
      );
      if (!mounted) return;

      final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      await _safeStep<void>('locale.initialize', localeProvider.initialize, timeout: const Duration(seconds: 4));
      if (!mounted) return;

      // Initialize ConfigProvider first
      final configProvider = Provider.of<ConfigProvider>(context, listen: false);
      await _safeStep<void>('config.initialize', configProvider.initialize, timeout: const Duration(seconds: 6));
      if (!mounted) return;

      // Ensure cache provider is hydrated before any screen depends on it.
      final cacheProvider = Provider.of<CacheProvider>(context, listen: false);
      await _safeStep<void>('cache.initialize', cacheProvider.initialize, timeout: const Duration(seconds: 6));
      if (!mounted) return;

      // Initialize WalletProvider early to restore cached wallet (safe for fresh starts).
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      await _safeStep<void>('wallet.initialize', walletProvider.initialize, timeout: const Duration(seconds: 8));
      final walletAddress = walletProvider.currentWalletAddress;
      if (!mounted) return;

      // Sync Web3Provider with WalletProvider if wallet was restored
      if (walletAddress != null && walletAddress.isNotEmpty) {
        final web3Provider = Provider.of<Web3Provider>(context, listen: false);
        try {
          await web3Provider.connectExistingWallet(walletAddress).timeout(const Duration(seconds: 6));
        } catch (e) {
          AppConfig.debugPrint('AppInitializer: Web3Provider sync failed: $e');
        }
      }
      if (!mounted) return;

      // Initialize ProfileProvider and load profile if wallet exists
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      await _safeStep<void>('profile.initialize', profileProvider.initialize, timeout: const Duration(seconds: 8));
      if (walletAddress != null && walletAddress.isNotEmpty) {
        try {
          await profileProvider.loadProfile(walletAddress).timeout(const Duration(seconds: 6));
        } catch (e) {
          AppConfig.debugPrint('AppInitializer: ProfileProvider load failed: $e');
        }
      }
      if (!mounted) return;

      // Initialize SavedItemsProvider
      final savedItemsProvider = Provider.of<SavedItemsProvider>(context, listen: false);
      await _safeStep<void>('saved_items.initialize', savedItemsProvider.initialize, timeout: const Duration(seconds: 6));
      if (!mounted) return;
    
    // Initialize ArtworkProvider (no mock data needed)
    final artworkProvider = Provider.of<ArtworkProvider>(context, listen: false);
    artworkProvider.setUseMockData(false); // Always use backend data
    
    // ProfileProvider always uses backend data (no setUseMockData method)
    
    final prefs = await _safeStep<SharedPreferences>(
          'SharedPreferences.getInstance',
          SharedPreferences.getInstance,
          timeout: const Duration(seconds: 5),
        ) ??
        (throw Exception('SharedPreferences unavailable'));

    final onboardingState = await _safeStep<OnboardingState>(
          'OnboardingStateService.load',
          () => OnboardingStateService.load(prefs: prefs),
          timeout: const Duration(seconds: 5),
        ) ??
        (throw Exception('OnboardingState unavailable'));
    
    // Check user preference for skipping onboarding (defaults to config setting)
    final userSkipOnboarding = prefs.getBool('skipOnboardingForReturningUsers') ?? AppConfig.skipOnboardingForReturningUsers;
    
    // Check wallet connection status
    final hasWallet = prefs.getBool('has_wallet') ?? false;
    final hasCompletedOnboarding = onboardingState.hasCompletedOnboarding;
    final inMemoryToken = BackendApiService().getAuthToken();
    final sessionStatus = (inMemoryToken != null &&
        inMemoryToken.trim().isNotEmpty &&
        AuthGatingService.isAccessTokenValid(inMemoryToken))
      ? StoredSessionStatus.valid
      : AuthGatingService.evaluateStoredSession(prefs: prefs);
    bool hasValidSession = sessionStatus == StoredSessionStatus.valid;
    if (sessionStatus == StoredSessionStatus.refreshRequired) {
      try {
        final refreshed = await BackendApiService().refreshAuthTokenFromStorage();
        hasValidSession = refreshed;
      } catch (e) {
        AppConfig.debugPrint('AppInitializer: refreshAuthTokenFromStorage failed: $e');
      }
    }
    final hasLocalAccount = AuthGatingService.hasLocalAccountSync(prefs: prefs);
    final shouldShowFirstRunOnboarding = await AuthGatingService.shouldShowFirstRunOnboarding(
      prefs: prefs,
      onboardingState: onboardingState,
    );
    final shouldShowSignIn = !hasValidSession &&
      hasLocalAccount &&
      AppConfig.enableMultiAuthEntry &&
      (AppConfig.enableEmailAuth || AppConfig.enableGoogleAuth || AppConfig.enableWalletConnect);
    
    if (kDebugMode) {
      debugPrint('AppInitializer: flags');
      debugPrint('  isFirstLaunch: ${onboardingState.isFirstLaunch}');
      debugPrint('  hasSeenWelcome: ${onboardingState.hasSeenWelcome}');
      debugPrint('  userSkipOnboarding: $userSkipOnboarding');
      debugPrint('  hasWallet: $hasWallet');
      debugPrint('  hasCompletedOnboarding: $hasCompletedOnboarding');
      debugPrint('  hasLocalAccount: $hasLocalAccount');
      debugPrint('  sessionStatus: $sessionStatus');
      debugPrint('  shouldShowFirstRunOnboarding: $shouldShowFirstRunOnboarding');
      debugPrint('  showWelcomeScreen: ${AppConfig.showWelcomeScreen}');
      debugPrint('  enforceWalletOnboarding: ${AppConfig.enforceWalletOnboarding}');
    }
    
    if (!mounted) return;
    
    // Navigate based on user state and configuration
    final shouldSkipOnboarding = userSkipOnboarding &&
      hasCompletedOnboarding;
    
    if (kDebugMode) {
      debugPrint('AppInitializer: shouldSkipOnboarding=$shouldSkipOnboarding');
    }

    // Detect desktop layout for responsive onboarding
    final isDesktop = DesktopBreakpoints.isDesktop(context);
    if (kDebugMode) {
      debugPrint('AppInitializer: isDesktop=$isDesktop');
    }

    // Prime all data providers before the main UI renders so users see fresh
    // content without needing manual refreshes on first interaction.
    //
    // IMPORTANT: Do not start warm-up during first-run onboarding. It can
    // trigger expensive polling / socket setup while the user isn't in the
    // shell yet (and increases perceived startup jank).
    final bootstrapper = AppBootstrapService();
    Future<void> startWarmUp() => bootstrapper.warmUp(
          context: context,
          walletAddress: walletAddress,
        );

    final pendingAuthLink = (() {
      try {
        return Provider.of<AuthDeepLinkProvider>(context, listen: false).consumePending();
      } catch (_) {
        return null;
      }
    })();
    if (pendingAuthLink != null) {
      if (!mounted) return;
      _didNavigate = true;
      switch (pendingAuthLink.type) {
        case AuthDeepLinkType.verifyEmail:
          navigator.pushReplacementNamed(
            '/verify-email',
            arguments: {
              'token': pendingAuthLink.token,
              if (pendingAuthLink.email != null) 'email': pendingAuthLink.email,
            },
          );
          break;
        case AuthDeepLinkType.resetPassword:
          navigator.pushReplacementNamed(
            '/reset-password',
            arguments: {'token': pendingAuthLink.token},
          );
          break;
      }
      return;
    }

    // If a share/deep link landed the user on this initializer, route into the
    // shell first. The shell (MainApp/DesktopShell) will consume & open the
    // pending target using an in-shell context so sidebars/tabs remain visible.
    //
    // NOTE: We intentionally do NOT consume the pending target here because
    // AppInitializer's navigator context does not have DesktopShellScope.
    final pendingDeepLink = (() {
      try {
        return Provider.of<DeepLinkProvider>(context, listen: false).pending;
      } catch (_) {
        return null;
      }
    })();
    if (pendingDeepLink != null) {
      // If a signed-out user opens the app via a deep link on first launch,
      // let them see the deep-linked content first and defer onboarding until
      // they navigate elsewhere.
      try {
        if (!hasCompletedOnboarding && !profileProvider.isSignedIn) {
          Provider.of<DeferredOnboardingProvider>(context, listen: false)
              .enableForDeepLinkColdStart();
        }
      } catch (_) {}

      try {
        await startWarmUp().timeout(const Duration(seconds: 15));
      } catch (_) {}
      if (!mounted) return;
      _didNavigate = true;
      final decision = const DeepLinkStartupRouting().decide(
        pending: pendingDeepLink,
        shouldShowSignIn: shouldShowSignIn,
      );
      if (decision == null) return;
      navigator.pushReplacementNamed(decision.route, arguments: decision.arguments);
      return;
    }
    
    if (shouldSkipOnboarding) {
      // Returning user - skip onboarding and go directly to main app
      if (kDebugMode) {
        debugPrint('AppInitializer: route -> MainApp (skip onboarding)');
      }
      // Ensure welcome/first-launch flags are consistent for returning users.
      await OnboardingStateService.markWelcomeSeen(prefs: prefs);

      unawaited(startWarmUp());
      if (!mounted) return;
      if (shouldShowSignIn) {
        _didNavigate = true;
        navigator.pushReplacementNamed('/sign-in');
      } else {
        _didNavigate = true;
        navigator.pushReplacementNamed('/main');
      }
    } else if (shouldShowFirstRunOnboarding) {
      // First-time user - show onboarding (no wallet required)
      // Use desktop onboarding for desktop layouts
      if (isDesktop) {
        if (kDebugMode) {
          debugPrint('AppInitializer: route -> DesktopOnboardingScreen');
        }
        _didNavigate = true;
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => const DesktopOnboardingScreen(),
            settings: const RouteSettings(name: '/onboarding/desktop'),
          ),
        );
      } else {
        if (kDebugMode) {
          debugPrint('AppInitializer: route -> OnboardingScreen');
        }
        _didNavigate = true;
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => const OnboardingScreen(),
            settings: const RouteSettings(name: '/onboarding'),
          ),
        );
      }
    } else {
      // Returning user who completed onboarding - go to main app (wallet optional)
      if (kDebugMode) {
        debugPrint('AppInitializer: route -> MainApp');
      }
      unawaited(startWarmUp());
      if (!mounted) return;
      _didNavigate = true;
      navigator.pushReplacementNamed(shouldShowSignIn ? '/sign-in' : '/main');
    }
    } catch (e, st) {
      AppConfig.debugPrint('AppInitializer: initialization failed: $e');
      AppConfig.debugPrint('AppInitializer: init stack: $st');
      if (!mounted) return;
      final isDesktop = DesktopBreakpoints.isDesktop(context);
      _didNavigate = true;
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => isDesktop ? const DesktopOnboardingScreen() : const OnboardingScreen(),
          settings: RouteSettings(name: isDesktop ? '/onboarding/desktop' : '/onboarding'),
        ),
      );
    } finally {
      _startupWatchdog?.cancel();
      _startupWatchdog = null;
      if (!completer.isCompleted) completer.complete();
      _initCompleter = null;
    }

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const AppLoading(),
    );
  }
}

// Explore-only mode for users without wallets
class ExploreOnlyApp extends StatelessWidget {
  const ExploreOnlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('art.kubus - Explore'),
        actions: [
          TextButton(
            onPressed: () => _showWalletPrompt(context),
            child: const Text('Connect Wallet'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Text(
              'You\'re in explore-only mode. Connect a wallet to access all features.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover Art',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureCard(
                    context,
                    'Browse Collections',
                    'Explore amazing art collections from around the world',
                    Icons.collections,
                    () => _showWalletPrompt(context),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureCard(
                    context,
                    'AR Experience',
                    'View artworks in augmented reality',
                    Icons.view_in_ar,
                    () => _showWalletPrompt(context),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureCard(
                    context,
                    'Community',
                    'Join the art community discussions',
                    Icons.people,
                    () => _showWalletPrompt(context),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureCard(
                    context,
                    'Marketplace',
                    'Discover and trade NFT artworks',
                    Icons.store,
                    () => _showWalletPrompt(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWalletPrompt(context),
        icon: const Icon(Icons.account_balance_wallet),
        label: const Text('Connect Wallet'),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.lock_outline),
        onTap: onTap,
      ),
    );
  }

  void _showWalletPrompt(BuildContext context) {
    if (kDebugMode) {
      if (kDebugMode) {
        debugPrint('AppInitializer: wallet prompt triggered');
      }
    }
    showKubusDialog(
      context: context,
      builder: (context) => const WalletPromptScreen(),
    );
  }
}

// Wallet connection prompt dialog
class WalletPromptScreen extends StatelessWidget {
  const WalletPromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KubusAlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.account_balance_wallet,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          const Text('Connect Wallet'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.security,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'To access this feature, you need to connect a Web3 wallet.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Set up your secure wallet to unlock:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Features list
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text('• Buy and sell NFTs'),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text('• Create your own artworks'),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text('• Community interactions'),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (kDebugMode) {
              if (kDebugMode) {
                debugPrint('WalletPromptScreen: Set Up Wallet pressed');
              }
            }
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
          },
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Set Up Wallet'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}

/// Utility functions for managing user onboarding state
class OnboardingManager {
  /// Mark user as a returning user to skip onboarding screens
  static Future<void> markAsReturningUser() async {
    final prefs = await SharedPreferences.getInstance();
    await OnboardingStateService.markWelcomeSeen(prefs: prefs);
  }
  
  /// Reset user state to trigger onboarding again (useful for testing)
  static Future<void> resetOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('has_wallet');
    await OnboardingStateService.reset(prefs: prefs);
    
    // Reset all Web3 feature onboarding
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.endsWith('_onboarding_completed')) {
        await prefs.remove(key);
      }
    }
  }
  
  /// Check if user should skip onboarding
  static Future<bool> shouldSkipOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check user preference (defaults to config setting)
    final userSkipOnboarding = prefs.getBool('skipOnboardingForReturningUsers') ?? AppConfig.skipOnboardingForReturningUsers;
    if (!userSkipOnboarding) return false;

    final onboardingState = await OnboardingStateService.load(prefs: prefs);
    return onboardingState.isReturningUser;
  }
}
