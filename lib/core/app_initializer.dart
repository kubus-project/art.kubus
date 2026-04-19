// NOTE: use_build_context_synchronously lint handled per-instance; avoid file-level ignore

import 'package:art_kubus/widgets/glass_components.dart';
// NOTE: use_build_context_synchronously lint handled per-instance; avoid file-level ignore
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_persona.dart';
import '../config/config.dart';
import '../providers/config_provider.dart';
import '../providers/app_mode_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/saved_items_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/cache_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/deep_link_provider.dart';
import '../providers/auth_deep_link_provider.dart';
import '../providers/deferred_onboarding_provider.dart';
import '../services/backend_api_service.dart';
import '../services/app_bootstrap_service.dart';
import '../services/auth_onboarding_service.dart';
import '../services/onboarding_state_service.dart';
import '../services/auth_gating_service.dart';
import '../services/auth/auth_deep_link_parser.dart';
import '../screens/onboarding/onboarding_flow_screen.dart';
import '../screens/desktop/desktop_shell.dart';
import '../widgets/app_loading.dart';
import 'app_navigator.dart';
import 'deep_link_startup_routing.dart';
import '../main_app.dart';
import 'shell_entry_screen.dart';
import 'shell_routes.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({
    super.key,
    this.preferredShellRoute,
  });

  final String? preferredShellRoute;

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  static const String _serverVersionOfflineLabel = 'offline';
  String? initializationError;
  Completer<void>? _initCompleter;
  Timer? _startupWatchdog;
  bool _didNavigate = false;
  String? _serverVersion;

  String get _resolvedShellRoute {
    return ShellRoutes.resolvePreferredShellRoute(widget.preferredShellRoute);
  }

  Future<void> _refreshServerVersion(ConfigProvider configProvider) async {
    final fetched = await BackendApiService().fetchServerVersion(
      timeout: const Duration(seconds: 3),
    );
    final normalized = (fetched ?? '').trim();
    final nextVersion = normalized.isEmpty ? null : normalized;

    await configProvider.setServerVersion(nextVersion);
    if (!mounted) return;
    setState(() {
      _serverVersion = nextVersion;
    });
  }

  Map<String, String>? get _signInRedirectArguments {
    return ShellRoutes.signInRedirectArguments(widget.preferredShellRoute);
  }

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
          builder: (_) => OnboardingFlowScreen(forceDesktop: isDesktop),
          settings: const RouteSettings(name: '/onboarding'),
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

      final localeProvider =
          Provider.of<LocaleProvider>(context, listen: false);
      await _safeStep<void>('locale.initialize', localeProvider.initialize,
          timeout: const Duration(seconds: 4));
      if (!mounted) return;

      // Initialize ConfigProvider first
      final configProvider =
          Provider.of<ConfigProvider>(context, listen: false);
      await _safeStep<void>('config.initialize', configProvider.initialize,
          timeout: const Duration(seconds: 6));
      if (!mounted) return;

      final appModeProvider =
          Provider.of<AppModeProvider>(context, listen: false);
      await _safeStep<void>('app_mode.initialize', appModeProvider.initialize,
          timeout: const Duration(seconds: 8));
      if (!mounted) return;

      final cachedServerVersion = (configProvider.serverVersion ?? '').trim();
      setState(() {
        _serverVersion =
            cachedServerVersion.isEmpty ? null : cachedServerVersion;
      });
      unawaited(_refreshServerVersion(configProvider));

      // Ensure cache provider is hydrated before any screen depends on it.
      final cacheProvider = Provider.of<CacheProvider>(context, listen: false);
      await _safeStep<void>('cache.initialize', cacheProvider.initialize,
          timeout: const Duration(seconds: 6));
      if (!mounted) return;

      // Initialize WalletProvider early to restore cached wallet (safe for fresh starts).
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      await _safeStep<void>('wallet.initialize', walletProvider.initialize,
          timeout: const Duration(seconds: 8));
      await _safeStep<void>(
        'wallet.restoreAccountShell',
        () => walletProvider.restoreAccountShellFromBackend(
          allowRefresh: false,
        ),
        timeout: const Duration(seconds: 8),
      );
      String? walletAddress = walletProvider.currentWalletAddress;
      walletAddress = walletAddress?.trim().isNotEmpty == true
          ? walletAddress!.trim()
          : null;
      if (!mounted) return;

      // Initialize ProfileProvider and load profile if wallet exists
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      await _safeStep<void>('profile.initialize', profileProvider.initialize,
          timeout: const Duration(seconds: 8));
      if (walletAddress != null && walletAddress.isNotEmpty) {
        try {
          await profileProvider
              .loadProfile(walletAddress)
              .timeout(const Duration(seconds: 6));
        } catch (e) {
          AppConfig.debugPrint(
              'AppInitializer: ProfileProvider load failed: $e');
        }
      }
      if (!mounted) return;

      // Initialize SavedItemsProvider
      final savedItemsProvider =
          Provider.of<SavedItemsProvider>(context, listen: false);
      await _safeStep<void>(
          'saved_items.initialize', savedItemsProvider.initialize,
          timeout: const Duration(seconds: 6));
      if (!mounted) return;

      // ProfileProvider always uses backend data.

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
      final userSkipOnboarding =
          prefs.getBool('skipOnboardingForReturningUsers') ??
              AppConfig.skipOnboardingForReturningUsers;

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
          hasValidSession =
              await BackendApiService().restoreExistingSession(allowRefresh: false);
        } catch (e) {
          AppConfig.debugPrint(
              'AppInitializer: restoreExistingSession failed: $e');
        }
      }
      if (hasValidSession &&
          walletProvider.hasWalletIdentity &&
          walletProvider.isReadOnlySession) {
        try {
          final managedEligible =
              await walletProvider.isManagedReconnectEligible();
          if (managedEligible) {
            await walletProvider
                .recoverManagedWalletSession(
                  walletAddress: walletAddress,
                  refreshBackendSession: true,
                )
                .timeout(const Duration(seconds: 10));
            walletAddress = walletProvider.currentWalletAddress;
          }
        } catch (e) {
          AppConfig.debugPrint(
              'AppInitializer: managed wallet reconnect failed: $e');
        }
      }
      final hasLocalAccount =
          AuthGatingService.hasLocalAccountSync(prefs: prefs);
      final shouldShowFirstRunOnboarding =
          await AuthGatingService.shouldShowFirstRunOnboarding(
        prefs: prefs,
        onboardingState: onboardingState,
      );
      final shouldShowSignIn = !hasValidSession &&
          hasLocalAccount &&
          AppConfig.enableMultiAuthEntry &&
          (AppConfig.enableEmailAuth ||
              AppConfig.enableGoogleAuth ||
              AppConfig.enableWalletConnect);
      final hasPendingAuthOnboarding =
          OnboardingStateService.hasPendingAuthOnboardingSync(
        prefs,
        scopeKey: OnboardingStateService.buildAuthOnboardingScopeKey(
          walletAddress: walletAddress,
          userId: (prefs.getString('user_id') ?? '').trim(),
        ),
      );
      final requiresWalletBackup =
          AppConfig.isFeatureEnabled('walletBackupOnboarding')
              ? await walletProvider.isMnemonicBackupRequired(
                  walletAddress: walletAddress,
                )
              : false;
      final authOnboardingScopeKey =
          OnboardingStateService.buildAuthOnboardingScopeKey(
        walletAddress: walletAddress,
        userId: (prefs.getString('user_id') ?? '').trim(),
      );
      final pendingAuthOnboardingResume = hasValidSession
          ? await AuthOnboardingService.resolveStructuredOnboardingResume(
              prefs: prefs,
              hasPendingAuthOnboarding: hasPendingAuthOnboarding,
              hasAuthenticatedSession: hasValidSession,
              hasHydratedProfile: profileProvider.hasHydratedProfile,
              requiresWalletBackup: requiresWalletBackup,
              heuristicNextStepId:
                  profileProvider.nextStructuredOnboardingStepId,
              persona: profileProvider.userPersona?.storageValue,
              flowScopeKey: authOnboardingScopeKey,
            )
          : const StructuredOnboardingResumeState(
              requiresStructuredOnboarding: false,
            );
      final pendingAuthOnboardingStepId =
          pendingAuthOnboardingResume.nextStepId;

      if (kDebugMode) {
        debugPrint('AppInitializer: flags');
        debugPrint('  isFirstLaunch: ${onboardingState.isFirstLaunch}');
        debugPrint('  hasSeenWelcome: ${onboardingState.hasSeenWelcome}');
        debugPrint('  userSkipOnboarding: $userSkipOnboarding');
        debugPrint('  hasWallet: $hasWallet');
        debugPrint('  hasCompletedOnboarding: $hasCompletedOnboarding');
        debugPrint('  hasLocalAccount: $hasLocalAccount');
        debugPrint('  sessionStatus: $sessionStatus');
        debugPrint('  hasPendingAuthOnboarding: $hasPendingAuthOnboarding');
        debugPrint(
            '  pendingAuthOnboardingStepId: ${pendingAuthOnboardingStepId ?? 'none'}');
        debugPrint(
            '  shouldShowFirstRunOnboarding: $shouldShowFirstRunOnboarding');
        debugPrint('  showWelcomeScreen: ${AppConfig.showWelcomeScreen}');
        debugPrint(
            '  enforceWalletOnboarding: ${AppConfig.enforceWalletOnboarding}');
      }

      if (!mounted) return;

      // Navigate based on user state and configuration
      final shouldSkipOnboarding = userSkipOnboarding && hasCompletedOnboarding;

      if (kDebugMode) {
        debugPrint(
            'AppInitializer: shouldSkipOnboarding=$shouldSkipOnboarding');
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
      Future<void> maybeStartWarmUp() {
        if (shouldShowSignIn) {
          return Future<void>.value();
        }
        return startWarmUp();
      }

      final pendingAuthLink = (() {
        try {
          return Provider.of<AuthDeepLinkProvider>(context, listen: false)
              .consumePending();
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
                if (pendingAuthLink.email != null)
                  'email': pendingAuthLink.email,
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
        // For first-run deep-link cold starts, defer onboarding until users
        // leave the deep-linked destination (handled in shell navigation).
        try {
          if (shouldShowFirstRunOnboarding && !profileProvider.isSignedIn) {
            Provider.of<DeferredOnboardingProvider>(context, listen: false)
                .enableForDeepLinkColdStart();
          }
        } catch (_) {}

        final decision = const DeepLinkStartupRouting().decide(
          pending: pendingDeepLink,
          shouldShowSignIn: shouldShowSignIn,
        );
        if (decision == null) return;

        if (decision.requiresSignIn) {
          if (!mounted) return;
          _didNavigate = true;
          navigator.pushReplacementNamed(
            '/sign-in',
            arguments: decision.signInArguments,
          );
          return;
        }

        try {
          await maybeStartWarmUp().timeout(const Duration(seconds: 15));
        } catch (_) {}
        if (!mounted) return;
        _didNavigate = true;

        final destination = decision.preferredShellRoute == ShellRoutes.map
            ? const ShellEntryScreen.map()
            : const MainApp();
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => destination,
            settings: RouteSettings(name: decision.canonicalPath),
          ),
        );
        return;
      }

      if (hasPendingAuthOnboarding) {
        if (!hasValidSession) {
          // Keep the pending flag until the user completes auth again.
        } else if (!pendingAuthOnboardingResume.requiresStructuredOnboarding ||
            pendingAuthOnboardingStepId == null ||
            pendingAuthOnboardingStepId.isEmpty) {
          await OnboardingStateService.clearPendingAuthOnboarding(
            prefs: prefs,
            scopeKey: authOnboardingScopeKey,
          );
        } else {
          if (kDebugMode) {
            debugPrint(
                'AppInitializer: route -> OnboardingFlowScreen (pending auth onboarding)');
          }
          _didNavigate = true;
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => OnboardingFlowScreen(
                forceDesktop: isDesktop,
                initialStepId: pendingAuthOnboardingStepId,
              ),
              settings: const RouteSettings(name: '/onboarding'),
            ),
          );
          return;
        }
      }

      if (shouldSkipOnboarding) {
        // Returning user - skip onboarding and go directly to main app
        if (kDebugMode) {
          debugPrint('AppInitializer: route -> MainApp (skip onboarding)');
        }
        // Ensure welcome/first-launch flags are consistent for returning users.
        await OnboardingStateService.markWelcomeSeen(prefs: prefs);

        unawaited(maybeStartWarmUp());
        if (!mounted) return;
        if (shouldShowSignIn) {
          _didNavigate = true;
          navigator.pushReplacementNamed(
            '/sign-in',
            arguments: _signInRedirectArguments,
          );
        } else {
          _didNavigate = true;
          navigator.pushReplacementNamed(_resolvedShellRoute);
        }
      } else if (shouldShowFirstRunOnboarding) {
        // First-time user - show onboarding (no wallet required)
        await OnboardingStateService.markWelcomeSeen(prefs: prefs);
        if (kDebugMode) {
          debugPrint('AppInitializer: route -> OnboardingFlowScreen');
        }
        _didNavigate = true;
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => OnboardingFlowScreen(forceDesktop: isDesktop),
            settings: const RouteSettings(name: '/onboarding'),
          ),
        );
      } else {
        // Returning user who completed onboarding - go to main app (wallet optional)
        if (kDebugMode) {
          debugPrint('AppInitializer: route -> MainApp');
        }
        unawaited(maybeStartWarmUp());
        if (!mounted) return;
        _didNavigate = true;
        navigator.pushReplacementNamed(
          shouldShowSignIn ? '/sign-in' : _resolvedShellRoute,
          arguments: shouldShowSignIn ? _signInRedirectArguments : null,
        );
      }
    } catch (e, st) {
      AppConfig.debugPrint('AppInitializer: initialization failed: $e');
      AppConfig.debugPrint('AppInitializer: init stack: $st');
      if (!mounted) return;
      final isDesktop = DesktopBreakpoints.isDesktop(context);
      _didNavigate = true;
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => OnboardingFlowScreen(forceDesktop: isDesktop),
          settings: const RouteSettings(name: '/onboarding'),
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
    final serverVersion = (_serverVersion ?? '').trim().isEmpty
        ? _serverVersionOfflineLabel
        : _serverVersion!.trim();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppLoading(
        appVersion: AppInfo.fullVersion,
        serverVersion: serverVersion,
      ),
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
              MaterialPageRoute(
                  builder: (context) => const OnboardingFlowScreen()),
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
    final userSkipOnboarding =
        prefs.getBool('skipOnboardingForReturningUsers') ??
            AppConfig.skipOnboardingForReturningUsers;
    if (!userSkipOnboarding) return false;

    final onboardingState = await OnboardingStateService.load(prefs: prefs);
    return onboardingState.isReturningUser;
  }
}
