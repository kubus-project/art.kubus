import 'package:art_kubus/widgets/glass_components.dart';
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
import '../l10n/app_localizations.dart';
import '../services/backend_api_service.dart';
import '../services/app_bootstrap_service.dart';
import '../services/auth_onboarding_service.dart';
import '../services/onboarding_state_service.dart';
import '../services/auth_gating_service.dart';
import '../services/guest_session_service.dart';
import '../services/telemetry/telemetry_service.dart';
import '../services/auth/auth_deep_link_parser.dart';
import '../services/share/share_deep_link_parser.dart';
import '../screens/onboarding/onboarding_flow_screen.dart';
import '../screens/desktop/desktop_shell.dart';
import '../widgets/app_loading.dart';
import 'app_navigator.dart';
import 'app_initializer_helper.dart';
import 'startup_trace.dart';
import 'deep_link_startup_routing.dart';
import '../main_app.dart';
import 'shell_entry_screen.dart';
import 'shell_routes.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({
    super.key,
    this.preferredShellRoute,
    this.initialUri,
  });

  final String? preferredShellRoute;
  final Uri? initialUri;

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

  ShareDeepLinkTarget? get _pendingShareTarget {
    try {
      return Provider.of<DeepLinkProvider>(context, listen: false).pending;
    } catch (_) {
      return null;
    }
  }

  bool _openPendingPublicTarget(NavigatorState navigator) {
    final pending = _pendingShareTarget;
    if (pending == null) return false;
    final routing = const DeepLinkStartupRouting();
    if (routing.accessPolicyFor(pending) != DeepLinkAccessPolicy.publicRead) {
      return false;
    }
    final decision = routing.decide(
      pending: pending,
      hasValidSession: false,
      initialUri: widget.initialUri,
    );
    if (decision == null) return false;
    final destination = decision.preferredShellRoute == ShellRoutes.map
        ? const ShellEntryScreen.map()
        : const MainApp();
    _didNavigate = true;
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => destination,
        settings: RouteSettings(name: decision.browserRoutePath),
      ),
    );
    return true;
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
      if (_openPendingPublicTarget(navigator)) return;
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
      StartupTrace.mark('critical bootstrap start');
      // Load JWT token for backend authentication (do not block indefinitely on startup).
      await _safeStep<void>(
        'loadAuthToken',
        BackendApiService().loadAuthToken,
        timeout: const Duration(seconds: 3),
      );
      StartupTrace.mark('auth token loaded');
      if (!mounted) return;

      final localeProvider =
          Provider.of<LocaleProvider>(context, listen: false);
      await _safeStep<void>('locale.initialize', localeProvider.initialize,
          timeout: const Duration(seconds: 4));
      final deepLinkLocale = _pendingShareTarget?.localeCode;
      final launchLocale = widget.initialUri?.queryParameters['lang'] ??
          widget.initialUri?.queryParameters['locale'];
      final requestedLocale = deepLinkLocale ?? launchLocale;
      if (requestedLocale != null &&
          LocaleProvider.supportedLanguageCodes.contains(
            requestedLocale.trim().toLowerCase(),
          )) {
        await _safeStep<void>(
          'locale.applyDeepLink',
          () => localeProvider.setLanguageCode(requestedLocale),
          timeout: const Duration(seconds: 4),
        );
      }
      if (!mounted) return;

      // Initialize ConfigProvider first
      final configProvider =
          Provider.of<ConfigProvider>(context, listen: false);
      await _safeStep<void>('config.initialize', configProvider.initialize,
          timeout: const Duration(seconds: 6));
      StartupTrace.mark('config ready');
      if (!mounted) return;

      // AppModeProvider.initialize() probes backend /health/writable on BOTH the
      // primary and fallback hosts to decide live vs standby vs IPFS-fallback
      // mode. The [BOOT] trace showed those probes dominating the critical path
      // (~350ms between "config ready" and "wallet restore start"). The default
      // mode is `live` (no UI degradation banner), warm-up re-runs
      // initialize()/refreshMode() after the shell mounts, and initialize() is
      // de-duped, so this is fallback/decentralized sync that must not block the
      // first paint. Kick it off without awaiting; the mode self-corrects (and
      // notifies listeners) in the background if the backend is actually
      // degraded.
      final appModeProvider =
          Provider.of<AppModeProvider>(context, listen: false);
      unawaited(_safeStep<void>(
        'app_mode.initialize',
        appModeProvider.initialize,
        timeout: const Duration(seconds: 8),
      ));
      StartupTrace.mark('app_mode init kicked off (deferred)');
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
      StartupTrace.mark('cache ready');
      if (!mounted) return;

      // Initialize WalletProvider early to restore cached wallet (safe for fresh starts).
      StartupTrace.mark('wallet restore start');
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
      StartupTrace.mark('wallet restore end');
      String? walletAddress = walletProvider.currentWalletAddress;
      walletAddress = walletAddress?.trim().isNotEmpty == true
          ? walletAddress!.trim()
          : null;
      if (!mounted) return;

      // Initialize ProfileProvider and load profile if wallet exists
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final pendingBeforeAccountHydration = _pendingShareTarget;
      final signedOutPublicRead = pendingBeforeAccountHydration != null &&
          const DeepLinkStartupRouting()
                  .accessPolicyFor(pendingBeforeAccountHydration) ==
              DeepLinkAccessPolicy.publicRead &&
          !BackendApiService().hasAuthSession;
      if (!signedOutPublicRead) {
        await _safeStep<void>('profile.initialize', profileProvider.initialize,
            timeout: const Duration(seconds: 8));
      }
      if (!signedOutPublicRead &&
          walletAddress != null &&
          walletAddress.isNotEmpty) {
        // profileProvider.initialize() already performs a backend loadProfile()
        // + stats fetch for the persisted wallet. When that already hydrated the
        // SAME wallet we're routing for, repeating the network load here only
        // duplicates a round-trip on the critical (pre-shell) path without
        // changing the route decision: the only profile fields routing consumes
        // (hasHydratedProfile / nextStructuredOnboardingStepId / userPersona)
        // are identical. Skip the duplicate so the splash clears sooner; the
        // hydrated state and freshness from initialize() are fully preserved.
        // If initialize() did not hydrate (cache miss, different wallet, or
        // failure), fall back to the synchronous load exactly as before.
        final alreadyHydratedForWallet = canSkipRedundantCriticalProfileLoad(
          hasHydratedProfile: profileProvider.hasHydratedProfile,
          hydratedWalletAddress: profileProvider.currentUser?.walletAddress,
          routeWalletAddress: walletAddress,
        );
        if (alreadyHydratedForWallet) {
          StartupTrace.mark(
              'profile already hydrated by initialize (skip duplicate load)');
        } else {
          StartupTrace.mark('profile load start');
          try {
            await profileProvider
                .loadProfile(walletAddress)
                .timeout(const Duration(seconds: 6));
          } catch (e) {
            AppConfig.debugPrint(
                'AppInitializer: ProfileProvider load failed: $e');
          }
          StartupTrace.mark('profile load end');
        }
      }
      if (!mounted) return;

      // Initialize SavedItemsProvider. Saved items are NOT consumed by the
      // route decision, and warm-up re-initializes this provider after the
      // shell mounts. The [BOOT] trace showed its backend round-trip
      // (/api/saved) sitting on the critical, pre-shell path — so start it here
      // but don't block the shell route on it. Saved-state simply hydrates a
      // moment later (unchanged from the warm-up path), with no routing impact.
      final savedItemsProvider =
          Provider.of<SavedItemsProvider>(context, listen: false);
      unawaited(_safeStep<void>(
        'saved_items.initialize',
        () => savedItemsProvider.initialize(syncBackend: !signedOutPublicRead),
        timeout: const Duration(seconds: 6),
      ));
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
          hasValidSession = await BackendApiService()
              .restoreExistingSession(allowRefresh: false);
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

      // Guest-first entry from the marketing funnel (e.g.
      // app.kubus.site/?mode=guest&intent=discover). Cold visitors who clicked
      // an ad are not ready for the account/wallet/tutorial onboarding flow, so
      // we capture their campaign attribution and send them straight to the
      // map/discovery shell. Only the new guest-entry case is affected; all
      // existing returning-user / sign-in / onboarding flows are untouched.
      await GuestSessionService.captureFromLaunchUrl(prefs: prefs);
      final guestEntry = GuestSessionService.isGuestActiveSync(prefs);
      if (guestEntry) {
        unawaited(TelemetryService().trackGuestAppLoaded());
      }
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
      final hasActiveGoogleOnboardingGuard =
          OnboardingStateService.hasActiveGoogleOnboardingRegistrationGuardSync(
        prefs,
      );
      final hasActiveAccountLinkGuard =
          OnboardingStateService.hasActiveAccountLinkGuardSync(prefs);
      // Either guard means an account already exists (or is being created):
      // startup must never fall back to /sign-in while one is active.
      final hasActiveOnboardingGuard =
          hasActiveGoogleOnboardingGuard || hasActiveAccountLinkGuard;

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

      StartupTrace.mark('route decision ready');

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
      Future<void> maybeStartWarmUp({bool publicRead = false}) {
        if ((shouldShowSignIn && !publicRead) ||
            (publicRead && !hasValidSession)) {
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
      final pendingDeepLink = _pendingShareTarget;
      if (pendingDeepLink != null) {
        // For first-run deep-link cold starts, defer onboarding until users
        // leave the deep-linked destination (handled in shell navigation).
        try {
          if (shouldShowFirstRunOnboarding ||
              hasPendingAuthOnboarding ||
              hasActiveOnboardingGuard) {
            Provider.of<DeferredOnboardingProvider>(context, listen: false)
                .enableForDeepLinkColdStart(
              initialStepId: pendingAuthOnboardingStepId,
            );
          }
        } catch (_) {}

        final decision = const DeepLinkStartupRouting().decide(
          pending: pendingDeepLink,
          hasValidSession: hasValidSession,
          initialUri: widget.initialUri,
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

        // Do not block the deep-link cold-start shell on warm-up. The
        // destination shell consumes the pending target itself and loads its
        // own data; warm-up (markers/artworks/web3/profile refresh) runs in the
        // background after the first frame instead of holding the splash for up
        // to 15s.
        unawaited(maybeStartWarmUp(
          publicRead: decision.accessPolicy == DeepLinkAccessPolicy.publicRead,
        ));
        if (!mounted) return;
        _didNavigate = true;

        final destination = decision.preferredShellRoute == ShellRoutes.map
            ? const ShellEntryScreen.map()
            : const MainApp();
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => destination,
            settings: RouteSettings(name: decision.browserRoutePath),
          ),
        );
        return;
      }

      if (hasPendingAuthOnboarding) {
        // Use the helper to decide if this is a no-session pending-auth case.
        // The helper returns 'none' for valid-session cases (deferred to resolver below).
        final hasPendingVerificationEmail =
            prefs.getBool('onboarding_pending_email_verification_v1') ?? false;
        final pendingVerificationEmail =
            prefs.getString('onboarding_verification_email_v3');

        if (hasActiveOnboardingGuard && hasValidSession) {
          final hydratedProfileWallet =
              (profileProvider.currentUser?.walletAddress ?? '').trim();
          final hasResolvedWallet = hydratedProfileWallet.isNotEmpty ||
              (walletAddress ?? '').trim().isNotEmpty;
          if (!hasResolvedWallet) {
            if (kDebugMode) {
              debugPrint(
                'AppInitializer: route -> OnboardingFlowScreen (onboarding guard, walletConnect)',
              );
            }
            _didNavigate = true;
            navigator.pushReplacement(
              MaterialPageRoute(
                builder: (context) => OnboardingFlowScreen(
                  forceDesktop: isDesktop,
                  initialStepId: 'walletConnect',
                ),
                settings: const RouteSettings(name: '/onboarding'),
              ),
            );
            return;
          }
        }

        final startupDecision = decideStartupRoute(
          hasPendingAuthOnboarding: hasPendingAuthOnboarding,
          hasValidSession: hasValidSession,
          hasPendingVerificationEmailFlag: hasPendingVerificationEmail,
          pendingVerificationEmail: pendingVerificationEmail,
          shouldSkipOnboarding:
              false, // This branch runs before shouldSkipOnboarding
          shouldShowSignIn: false,
        );

        if (startupDecision.route == StartupRouteType.onboarding) {
          // Pending auth onboarding without valid session -> onboarding
          if (kDebugMode) {
            debugPrint(
                'AppInitializer: route -> OnboardingFlowScreen (pending auth, no session, initialStep=${startupDecision.onboardingInitialStepId})');
          }
          _didNavigate = true;
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => OnboardingFlowScreen(
                forceDesktop: isDesktop,
                initialStepId: startupDecision.onboardingInitialStepId,
              ),
              settings: const RouteSettings(name: '/onboarding'),
            ),
          );
          return;
        }

        // Helper returned 'none', meaning hasValidSession=true.
        // Continue to structured resume logic below.
        if (!pendingAuthOnboardingResume.requiresStructuredOnboarding ||
            pendingAuthOnboardingStepId == null ||
            pendingAuthOnboardingStepId.isEmpty) {
          await OnboardingStateService.clearPendingAuthOnboarding(
            prefs: prefs,
            scopeKey: authOnboardingScopeKey,
          );
        } else {
          if (kDebugMode) {
            debugPrint(
                'AppInitializer: route -> OnboardingFlowScreen (pending auth onboarding resume)');
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

      if (hasActiveOnboardingGuard) {
        final hydratedProfileWallet =
            (profileProvider.currentUser?.walletAddress ?? '').trim();
        final hasResolvedWallet = hydratedProfileWallet.isNotEmpty ||
            (walletAddress ?? '').trim().isNotEmpty;
        if (!hasValidSession || !hasResolvedWallet) {
          final initialStepId = hasValidSession && !hasResolvedWallet
              ? 'walletConnect'
              : 'account';
          if (kDebugMode) {
            debugPrint(
              'AppInitializer: route -> OnboardingFlowScreen (onboarding guard, initialStep=$initialStepId)',
            );
          }
          _didNavigate = true;
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => OnboardingFlowScreen(
                forceDesktop: isDesktop,
                initialStepId: initialStepId,
              ),
              settings: const RouteSettings(name: '/onboarding'),
            ),
          );
          return;
        }

        if (pendingAuthOnboardingResume.requiresStructuredOnboarding &&
            pendingAuthOnboardingStepId != null &&
            pendingAuthOnboardingStepId.isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
              'AppInitializer: route -> OnboardingFlowScreen (Google onboarding guard resume)',
            );
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
      } else if (shouldShowFirstRunOnboarding && !guestEntry) {
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
      if (_openPendingPublicTarget(navigator)) return;
      final isDesktop = DesktopBreakpoints.isDesktop(context);
      _didNavigate = true;
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => OnboardingFlowScreen(forceDesktop: isDesktop),
          settings: const RouteSettings(name: '/onboarding'),
        ),
      );
    } finally {
      StartupTrace.mark('critical bootstrap end (shell route pushed)');
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.exploreOnlyAppTitle),
        actions: [
          TextButton(
            onPressed: () => _showWalletPrompt(context),
            child: Text(l10n.exploreOnlyConnectWalletAction),
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
              l10n.exploreOnlyModeBanner,
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
                    l10n.exploreOnlyDiscoverTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureCard(
                    context,
                    l10n.exploreOnlyCollectionsTitle,
                    l10n.exploreOnlyCollectionsDescription,
                    Icons.collections,
                    () => _showWalletPrompt(context),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureCard(
                    context,
                    l10n.exploreOnlyArTitle,
                    l10n.exploreOnlyArDescription,
                    Icons.view_in_ar,
                    () => _showWalletPrompt(context),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureCard(
                    context,
                    l10n.exploreOnlyCommunityTitle,
                    l10n.exploreOnlyCommunityDescription,
                    Icons.people,
                    () => _showWalletPrompt(context),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureCard(
                    context,
                    l10n.exploreOnlyArtifactsTitle,
                    l10n.exploreOnlyArtifactsDescription,
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
        label: Text(l10n.exploreOnlyConnectWalletAction),
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
    final l10n = AppLocalizations.of(context)!;

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
          Text(l10n.walletPromptTitle),
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
          Text(
            l10n.walletPromptBody,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.walletPromptIntro,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(l10n.walletPromptFeatureArchiveObjects),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(l10n.walletPromptFeatureCreateArtworks),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(l10n.walletPromptFeatureCommunity),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.walletPromptMaybeLater),
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
          label: Text(l10n.walletPromptSetUpAction),
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
