import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_navigator.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_gating_service.dart';
import '../services/auth_session_coordinator.dart';
import '../services/backend_api_service.dart';
import '../services/onboarding_state_service.dart';
import '../services/pin_hashing.dart';
import '../services/settings_service.dart';
import '../providers/notification_provider.dart';
import '../providers/artwork_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/saved_items_provider.dart';
import '../providers/wallet_provider.dart';
import '../screens/auth/sign_in_screen.dart';
import '../widgets/glass_components.dart';

enum SecurityLockReason {
  autoLock,
  tokenExpired,
  sensitiveAction,
}

class SecurityGateProvider extends ChangeNotifier
    implements AuthSessionCoordinator {
  /// Upper bound for one cold-start or resume lock decision. Past it the
  /// decision locks fail-closed so the opaque cover cannot stay up forever.
  static const Duration defaultLockDecisionTimeout = Duration(seconds: 5);

  SecurityGateProvider({
    Duration promptCooldown = const Duration(seconds: 8),
    Duration lockDecisionTimeout = defaultLockDecisionTimeout,
  })  : _promptCooldown = promptCooldown,
        _lockDecisionTimeout = lockDecisionTimeout;

  final Duration _promptCooldown;
  final Duration _lockDecisionTimeout;

  ProfileProvider? _profileProvider;
  WalletProvider? _walletProvider;
  NotificationProvider? _notificationProvider;
  SavedItemsProvider? _savedItemsProvider;
  ArtworkProvider? _artworkProvider;

  SettingsState? _settings;

  bool _locked = false;
  SecurityLockReason? _lockReason;
  AuthFailureContext? _authFailureContext;

  Completer<AuthReauthResult>? _inFlight;
  Future<AuthReauthResult>? _inactiveSessionEnd;
  DateTime? _cooldownUntil;
  bool _busy = false;

  Timer? _inactivityTimer;
  DateTime _lastInteractionAt = DateTime.now();

  Completer<void>? _initializeCompleter;
  bool _hasLocalAccount = false;
  bool _accountStateUnknown = false;

  /// Lock decisions still running. Starts at one: the cold-start decision
  /// stays pending until [initialize] settles it. Each resume adds one.
  int _pendingLockDecisions = 1;

  /// Identifies the newest lock decision. A decision whose body outlives its
  /// timeout is retired by bumping this, so the orphaned body sees it is stale
  /// and stops before every mutation.
  int _lockDecisionGeneration = 0;

  /// True until the cold-start or resume decision has finished. The UI must
  /// cover the app while this holds so no restored route is interactive.
  bool get isLockDecisionPending => _pendingLockDecisions > 0;

  bool get isLocked => _locked;
  SecurityLockReason? get lockReason => _lockReason;
  AuthFailureContext? get authFailureContext => _authFailureContext;
  bool get isBusy => _busy;
  bool get hasLocalAccount => _hasLocalAccount;

  SettingsState get settings => _settings ?? SettingsState.defaults();

  bool get requirePin => settings.requirePin;
  bool get biometricsEnabled => settings.biometricAuth;
  bool get useBiometricsOnUnlock => settings.useBiometricsOnUnlock;
  int get autoLockSeconds => settings.autoLockSeconds;

  void bindDependencies({
    required ProfileProvider profileProvider,
    required WalletProvider walletProvider,
    required NotificationProvider notificationProvider,
    SavedItemsProvider? savedItemsProvider,
    ArtworkProvider? artworkProvider,
  }) {
    _profileProvider = profileProvider;
    _walletProvider = walletProvider;
    _notificationProvider = notificationProvider;
    _savedItemsProvider = savedItemsProvider;
    _artworkProvider = artworkProvider;
  }

  Future<void> initialize() {
    final existing = _initializeCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _initializeCompleter = completer;

    () async {
      try {
        // The cold-start decision (its settings read included) is bounded and
        // ends the pending count it started with, exactly once.
        await _enqueueLifecycle(() => _runLockDecision(_enforceColdStartLock));
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    }();

    return completer.future;
  }

  Future<void> reloadSettings() => _reloadSettings(_alwaysCurrent);

  /// The settings read used by lock decisions. Overridable so tests can hold
  /// the read open and release it after a decision has timed out.
  @protected
  Future<SettingsState> readSettingsForDecision() =>
      SettingsService.loadSettings();

  static bool _alwaysCurrent() => true;

  /// Applies freshly read settings only while [isCurrent] holds, so an orphaned
  /// decision cannot overwrite settings applied by a newer one.
  Future<void> _reloadSettings(bool Function() isCurrent) async {
    final loaded = await readSettingsForDecision();
    if (!isCurrent()) return;
    _settings = loaded;
    await _refreshLocalAccountState(isCurrent: isCurrent);
    if (!isCurrent()) return;
    _resetInactivityTimer();
    notifyListeners();
  }

  Future<void> refreshLocalAccountState({SharedPreferences? prefs}) =>
      _refreshLocalAccountState(isCurrent: _alwaysCurrent, prefs: prefs);

  Future<void> _refreshLocalAccountState({
    required bool Function() isCurrent,
    SharedPreferences? prefs,
  }) async {
    try {
      final resolved = prefs ?? await SharedPreferences.getInstance();
      if (!isCurrent()) return;
      _hasLocalAccount = AuthGatingService.hasLocalAccountSync(prefs: resolved);
      _accountStateUnknown = false;
    } catch (_) {
      if (!isCurrent()) return;
      _hasLocalAccount = false;
      _accountStateUnknown = true;
    }
  }

  void _beginLockDecision() {
    _pendingLockDecisions++;
    notifyListeners();
  }

  void _endLockDecision() {
    if (_pendingLockDecisions > 0) _pendingLockDecisions--;
    notifyListeners();
  }

  void onUserInteraction() {
    _lastInteractionAt = DateTime.now();
    _resetInactivityTimer();
  }

  /// Lifecycle work is serialised so the departure timestamp is written,
  /// read and cleared in the order the engine delivered the events.
  Future<void> _lifecycleChain = Future<void>.value();

  Future<void> _enqueueLifecycle(Future<void> Function() task) {
    final next = _lifecycleChain.then((_) => task()).catchError((Object e) {
      if (kDebugMode) debugPrint('SecurityGateProvider lifecycle task: $e');
    });
    _lifecycleChain = next;
    return next;
  }

  @visibleForTesting
  Future<void> get lifecycleIdleForTesting => _lifecycleChain;

  void onAppLifecycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // The app really left the foreground. `inactive` is also delivered on
        // the way back, so it is never used to record the departure.
        unawaited(_enqueueLifecycle(_recordDeparture));
        return;
      case AppLifecycleState.resumed:
        // Covered synchronously, before any awaited read can let the restored
        // route be interactive.
        _beginLockDecision();
        unawaited(_enqueueLifecycle(_runResumeDecision));
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        return;
    }
  }

  /// Records when the app was left. The first departure wins: the `hidden`
  /// event that precedes `resumed` on the return transition must not move it.
  Future<void> _recordDeparture() async {
    try {
      await _writeDeparture().timeout(_lockDecisionTimeout);
    } catch (_) {
      // Best-effort only, and bounded: a hung write must not stall the
      // lifecycle chain. The departure is then lost, which the resume decision
      // treats as "no timestamp".
    }
  }

  Future<void> _writeDeparture() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_departureKey) != null) return;
    await prefs.setInt(_departureKey, DateTime.now().millisecondsSinceEpoch);
  }

  static const String _departureKey = 'last_inactive_ts';

  /// Reads and clears the persisted departure time. A stale decision leaves
  /// the departure for the decision that replaced it.
  Future<int?> _takeDeparture(bool Function() isCurrent) async {
    final prefs = await SharedPreferences.getInstance();
    if (!isCurrent()) return null;
    final value = prefs.getInt(_departureKey);
    await prefs.remove(_departureKey);
    return value;
  }

  /// Whether the time away from the app calls for a lock. A missing, future or
  /// unreadable departure time counts as "unknown", which locks.
  bool _awayLongEnough(int? departureMs) {
    final seconds = autoLockSeconds;
    if (seconds < 0) return true;
    if (departureMs == null) return true;
    final elapsed = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(departureMs));
    if (elapsed.isNegative) return true;
    return elapsed.inSeconds >= seconds;
  }

  Future<void> _runResumeDecision() => _runLockDecision(_handleResumed);

  /// Runs one lock decision under [_lockDecisionTimeout]. The decision's
  /// pending count is ended here, once, in `finally`. The body never ends it,
  /// so an orphaned body that finishes after a timeout cannot decrement the
  /// counter or clear a newer decision's cover.
  ///
  /// The body receives an `isCurrent` check for its generation and must test it
  /// after every await before it mutates gate state. On timeout or error the
  /// generation is retired before the fail-closed lock, so the orphan stops.
  Future<void> _runLockDecision(
      Future<void> Function(bool Function() isCurrent) body) async {
    final generation = ++_lockDecisionGeneration;
    bool isCurrent() => generation == _lockDecisionGeneration;
    try {
      await body(isCurrent).timeout(_lockDecisionTimeout);
    } catch (e) {
      _lockDecisionGeneration++;
      if (kDebugMode) {
        debugPrint('SecurityGateProvider lock decision bounded: $e');
      }
      await _lockAfterUnreadableDecision(SecurityLockReason.autoLock);
    } finally {
      _endLockDecision();
    }
  }

  /// Applies the app lock when the process starts. A process that was
  /// reclaimed in the background must not come back unlocked.
  Future<void> _enforceColdStartLock(bool Function() isCurrent) async {
    try {
      await _reloadSettings(isCurrent);
      if (!isCurrent()) return;
      _resetInactivityTimer();
      final departureMs = await _takeDeparture(isCurrent);
      if (!isCurrent()) return;
      if (_accountStateUnknown) {
        throw StateError('local account state is unreadable');
      }
      if (!_shouldAutoLock()) return;
      if (_awayLongEnough(departureMs)) {
        await _lock(SecurityLockReason.autoLock, isCurrent: isCurrent);
      }
    } catch (e) {
      if (!isCurrent()) return;
      if (kDebugMode) {
        debugPrint('SecurityGateProvider._enforceColdStartLock failed: $e');
      }
      await _lockAfterUnreadableDecision(SecurityLockReason.autoLock);
    }
  }

  /// A decision that could not be read must fail closed. Locks when the last
  /// known settings required a PIN, or, with no settings loaded, when the
  /// persisted flag says so or cannot be read. Ignores [_hasLocalAccount]:
  /// that flag is exactly what may be unreadable here.
  Future<void> _lockAfterUnreadableDecision(SecurityLockReason reason) async {
    try {
      await _lockAfterUnreadableDecisionUnbounded(reason)
          .timeout(_lockDecisionTimeout);
    } catch (_) {
      // The fallback itself hung (its prefs read or PIN check). Lock directly,
      // without awaiting anything, unless loaded settings say no PIN is needed.
      final loaded = _settings;
      if (loaded == null || _appLockRequired(loaded)) {
        _engageLockDirectly(reason);
      }
    }
  }

  /// Sets the locked state without awaiting the wallet. Only the fail-closed
  /// fallback uses it, when the PIN check itself cannot complete.
  void _engageLockDirectly(SecurityLockReason reason) {
    if (_locked) return;
    _locked = true;
    _lockReason = reason;
    _authFailureContext = null;
    _inFlight ??= Completer<AuthReauthResult>();
    notifyListeners();
  }

  Future<void> _lockAfterUnreadableDecisionUnbounded(
      SecurityLockReason reason) async {
    try {
      final loaded = _settings;
      final bool wantLock;
      if (loaded != null) {
        wantLock = _appLockRequired(loaded);
      } else {
        try {
          final prefs = await SharedPreferences.getInstance();
          wantLock = prefs.getBool('requirePin') ??
              SettingsState.defaults().requirePin;
        } catch (_) {
          // Unreadable flag: a PIN is presumed to exist, so lock.
          await _applyLock(reason);
          return;
        }
      }
      if (!wantLock) return;
      await _applyLock(reason);
    } catch (_) {
      // The lock itself could not be applied; nothing further to do here.
    }
  }

  Future<void> _handleResumed(bool Function() isCurrent) async {
    try {
      final departureMs = await _takeDeparture(isCurrent);
      if (!isCurrent()) return;

      // Check if we're on an auth-related route that shouldn't trigger auto-lock
      final navigator = appNavigatorKey.currentState;
      if (navigator != null && navigator.mounted) {
        final currentRoute = ModalRoute.of(navigator.context);
        if (currentRoute != null) {
          final routeName = currentRoute.settings.name ?? '';
          // Skip auto-lock on auth routes
          if (routeName.contains('/verify-email') ||
              routeName.contains('/sign-in') ||
              routeName.contains('/register') ||
              routeName.contains('/signup')) {
            if (kDebugMode) {
              debugPrint(
                  'SecurityGateProvider._handleResumed: Skipping auto-lock on auth route: $routeName');
            }
            return;
          }
        }
      }

      await _reloadSettings(isCurrent);
      if (!isCurrent()) return;
      if (_accountStateUnknown) {
        throw StateError('local account state is unreadable');
      }

      if (!_shouldAutoLock()) return;
      // No recorded departure on a warm resume means the app never left the
      // foreground (the first `resumed` of a launch); cold start handles that.
      if (departureMs == null) return;
      if (_awayLongEnough(departureMs)) {
        await _lock(SecurityLockReason.autoLock, isCurrent: isCurrent);
      }
    } catch (e) {
      if (!isCurrent()) return;
      if (kDebugMode) {
        debugPrint('SecurityGateProvider._handleResumed failed: $e');
      }
      await _lockAfterUnreadableDecision(SecurityLockReason.autoLock);
    }
  }

  bool _shouldAutoLock() {
    if (!_hasLocalAccount) return false;
    return _appLockRequired(settings);
  }

  /// Whether the settings call for the app lock. Shared by [_shouldAutoLock]
  /// and the fail-closed fallback, so both decide the same way.
  static bool _appLockRequired(SettingsState s) =>
      (s.requirePin || s.biometricAuth) && s.autoLockSeconds != 0;

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!_shouldAutoLock()) return;
    if (autoLockSeconds <= 0) {
      return; // Never or Immediate handled via lifecycle.
    }
    if (_locked) return;

    final deadline = _lastInteractionAt.add(Duration(seconds: autoLockSeconds));
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) {
      unawaited(lock(SecurityLockReason.autoLock));
      return;
    }

    _inactivityTimer = Timer(remaining, () {
      unawaited(lock(SecurityLockReason.autoLock));
    });
  }

  Future<void> lock(SecurityLockReason reason, {AuthFailureContext? context}) =>
      _lock(reason, context: context, isCurrent: _alwaysCurrent);

  /// [lock] for a lock decision body: applies nothing once [isCurrent] fails.
  Future<void> _lock(
    SecurityLockReason reason, {
    AuthFailureContext? context,
    required bool Function() isCurrent,
  }) async {
    if ((reason == SecurityLockReason.autoLock ||
            reason == SecurityLockReason.tokenExpired) &&
        !_hasLocalAccount) {
      return;
    }
    await _applyLock(reason, context: context, isCurrent: isCurrent);
  }

  Future<void> _applyLock(
    SecurityLockReason reason, {
    AuthFailureContext? context,
    bool Function()? isCurrent,
  }) async {
    final wallet = _walletProvider;
    bool hasPin;
    try {
      hasPin = await wallet?.hasPinOrThrow() ?? false;
    } catch (_) {
      // An unreadable PIN store is not "no PIN": lock rather than skip.
      hasPin = true;
    }
    if (isCurrent != null && !isCurrent()) return;
    final canUseBiometrics =
        biometricsEnabled && (await wallet?.canUseBiometrics() ?? false);
    if (isCurrent != null && !isCurrent()) return;
    if (reason == SecurityLockReason.autoLock &&
        !(hasPin || canUseBiometrics)) {
      return;
    }
    if (reason == SecurityLockReason.sensitiveAction &&
        !(hasPin || canUseBiometrics)) {
      return;
    }

    if (_locked && _inFlight != null) {
      if (_lockReason == SecurityLockReason.sensitiveAction &&
          reason != SecurityLockReason.sensitiveAction) {
        // An auto-lock or expired session outranks a pending sensitive prompt:
        // that prompt may be cancelled, this lock may not. The waiting action
        // is refused and must be retried after unlocking.
        final sensitive = _inFlight;
        _inFlight = Completer<AuthReauthResult>();
        _lockReason = reason;
        _authFailureContext = context;
        if (sensitive != null && !sensitive.isCompleted) {
          sensitive
              .complete(const AuthReauthResult(AuthReauthOutcome.cancelled));
        }
        notifyListeners();
        return;
      }
      _lockReason ??= reason;
      _authFailureContext ??= context;
      notifyListeners();
      return;
    }

    _locked = true;
    _lockReason = reason;
    _authFailureContext = context;
    _inFlight ??= Completer<AuthReauthResult>();
    notifyListeners();
  }

  /// Cancels a [SecurityLockReason.sensitiveAction] prompt without logging out.
  /// For auto-lock and token-expiry locks, cancellation would weaken security,
  /// so it is ignored.
  void cancel() {
    if (!_locked) return;
    if (_lockReason != SecurityLockReason.sensitiveAction) return;
    _completeAndReset(const AuthReauthResult(AuthReauthOutcome.cancelled));
  }

  /// Signs out. With [preserveWallet] the account session ends in full but the
  /// local wallet is untouched (the backend ended the session, not the user).
  Future<void> logout({bool preserveWallet = false}) async {
    final wallet = _walletProvider;
    if (wallet == null) return;

    try {
      await SettingsService.logout(
        walletProvider: wallet,
        backendApi: BackendApiService(),
        notificationProvider: _notificationProvider,
        profileProvider: _profileProvider,
        savedItemsProvider: _savedItemsProvider,
        artworkProvider: _artworkProvider,
        preserveWallet: preserveWallet,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecurityGateProvider.logout failed: $e');
      }
    } finally {
      _hasLocalAccount = false;
      _completeAndReset(const AuthReauthResult(AuthReauthOutcome.cancelled));
      final navigator = appNavigatorKey.currentState;
      if (navigator != null && navigator.mounted) {
        navigator.pushNamedAndRemoveUntil('/sign-in', (_) => false);
      }
    }
  }

  @override
  bool get isResolving => _inFlight != null;

  @override
  Future<AuthReauthResult?> waitForResolution() async {
    return _inFlight?.future;
  }

  @override
  void reset() {
    _cooldownUntil = null;
    final reason = _lockReason;
    if (_locked &&
        (reason == SecurityLockReason.autoLock ||
            reason == SecurityLockReason.tokenExpired)) {
      // Clearing the HTTP session must not open a locked app. Only a local
      // unlock or logout() releases these locks.
      notifyListeners();
      return;
    }
    _busy = false;
    _locked = false;
    _lockReason = null;
    _authFailureContext = null;
    _inactivityTimer?.cancel();

    final inflight = _inFlight;
    _inFlight = null;
    if (inflight != null && !inflight.isCompleted) {
      inflight.complete(const AuthReauthResult(AuthReauthOutcome.cancelled));
    }
    notifyListeners();
  }

  @override
  Future<AuthReauthResult> handleAuthFailure(AuthFailureContext context) async {
    // A suspended account cannot be repaired by signing in again, and its
    // still-valid token must not be mistaken for a live session below.
    if (context.isAccountInactive) return _endSessionForInactiveAccount();

    final existing = _inFlight;
    if (existing != null) {
      if (_lockReason != SecurityLockReason.sensitiveAction) {
        return existing.future;
      }
      // An expired session outranks a pending sensitive prompt.
      await lock(SecurityLockReason.tokenExpired, context: context);
      return _inFlight?.future ??
          const AuthReauthResult(AuthReauthOutcome.failed);
    }

    final now = DateTime.now();
    final cooldownUntil = _cooldownUntil;
    if (cooldownUntil != null && now.isBefore(cooldownUntil)) {
      return const AuthReauthResult(AuthReauthOutcome.cooldown);
    }

    // Don't prompt for re-auth on auth endpoints (signup, email verification, etc).
    // These are endpoints that don't require an existing session; their 401s
    // belong to the calling screen, which surfaces them inline.
    final path = (context.path).toLowerCase();
    final isAuthEndpoint = path.contains('/auth/') &&
        (path.contains('/auth/login') ||
            path.contains('/auth/register') ||
            path.contains('/auth/google') ||
            path.contains('/auth/email-status') ||
            path.contains('/auth/verify-email') ||
            path.contains('/auth/resend-verification') ||
            path.contains('/auth/forgot-password') ||
            path.contains('/auth/reset-password') ||
            path.contains('/auth/signup'));

    // Also skip re-auth on email verification routes (user waiting for verification)
    final isEmailVerificationRoute = path.contains('/verify-email');

    if (isAuthEndpoint || isEmailVerificationRoute) {
      _cooldownUntil = DateTime.now().add(_promptCooldown);
      return const AuthReauthResult(AuthReauthOutcome.notEnabled,
          message: 'Auth endpoint does not require re-auth');
    }

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      _hasLocalAccount = AuthGatingService.hasLocalAccountSync(prefs: prefs);
      _settings ??= SettingsState.fromPrefs(prefs);
    } catch (_) {}

    // While a registration/account-link transaction is in flight the
    // onboarding flow owns auth-error UX (inline retry, guards, recovery).
    // Hijacking navigation here is what used to eject fresh Google/email
    // signups to /sign-in mid-onboarding.
    if (prefs != null &&
        (OnboardingStateService.hasActiveGoogleOnboardingRegistrationGuardSync(
              prefs,
            ) ||
            OnboardingStateService.hasActiveAccountLinkGuardSync(prefs))) {
      _cooldownUntil = DateTime.now().add(_promptCooldown);
      return const AuthReauthResult(AuthReauthOutcome.notEnabled,
          message: 'Onboarding transaction in flight; caller handles errors');
    }

    // A still-valid session token means this 401/403 was a route-level
    // rejection (permissions, race, endpoint contract) — not session expiry.
    // Never bounce a valid Google/email session back to /sign-in.
    // Require an actual JWT with a verifiable future exp claim — opaque strings
    // that cannot be decoded (e.g. test stubs without dots) must not satisfy
    // this check, so we use extractJwtExpiryUtc rather than isAccessTokenValid
    // (which returns true when no exp claim is present).
    final inMemoryToken = (BackendApiService().getAuthToken() ?? '').trim();
    final hasValidInMemorySession = _tokenHasFutureExpiry(inMemoryToken);
    final storedToken = prefs != null
        ? (AuthGatingService.readStoredAccessToken(prefs) ?? '').trim()
        : '';
    final hasValidStoredSession = _tokenHasFutureExpiry(storedToken);
    if (hasValidInMemorySession || hasValidStoredSession) {
      _cooldownUntil = DateTime.now().add(_promptCooldown);
      return const AuthReauthResult(AuthReauthOutcome.notEnabled,
          message: 'Session still valid; not an expiry');
    }

    if (prefs != null) {
      final sessionStatus =
          AuthGatingService.evaluateStoredSession(prefs: prefs);
      if (sessionStatus == StoredSessionStatus.refreshRequired) {
        final restored = await BackendApiService().restoreExistingSession(
          allowRefresh: false,
        );
        if (restored) {
          _cooldownUntil = DateTime.now().add(_promptCooldown);
          return const AuthReauthResult(AuthReauthOutcome.success);
        }
      }
    }

    // Only prompt for re-auth if:
    // 1. Feature is enabled AND
    // 2. User has a local account/session
    // 3. User has app lock configured (PIN or biometrics)
    final shouldPrompt =
        await AuthGatingService.shouldPromptReauth(prefs: prefs);
    final hasAppLock = requirePin || biometricsEnabled;

    if (!shouldPrompt) {
      if (_hasLocalAccount) {
        _cooldownUntil = DateTime.now().add(_promptCooldown);
        _forceSignInRedirect();
      }
      _cooldownUntil = DateTime.now().add(_promptCooldown);
      return const AuthReauthResult(AuthReauthOutcome.notEnabled,
          message: 'Re-auth not enabled for non-session users');
    }

    if (!hasAppLock) {
      // Token expired but no app lock configured: force sign-in to restore session.
      _cooldownUntil = DateTime.now().add(_promptCooldown);
      _forceSignInRedirect();
      return const AuthReauthResult(AuthReauthOutcome.notEnabled,
          message: 'App lock not configured; sign-in required');
    }

    await lock(SecurityLockReason.tokenExpired, context: context);
    final inflight = _inFlight;
    if (inflight == null) {
      _cooldownUntil = DateTime.now().add(_promptCooldown);
      return const AuthReauthResult(AuthReauthOutcome.failed,
          message: 'Unable to start re-auth flow');
    }
    return inflight.future;
  }

  /// The backend suspended this account: end the authenticated session through
  /// the ordinary sign-out (tokens, account state, navigation to /sign-in) and
  /// say why. The wallet stays on the device untouched. Concurrent reports
  /// share one run, and a report that arrives once the session is already gone
  /// is ignored, so nothing loops and the notice is shown once.
  Future<AuthReauthResult> _endSessionForInactiveAccount() {
    final running = _inactiveSessionEnd;
    if (running != null) return running;

    final hasSession = _hasLocalAccount ||
        (BackendApiService().getAuthToken() ?? '').trim().isNotEmpty;
    if (!hasSession) {
      return Future.value(const AuthReauthResult(
        AuthReauthOutcome.failed,
        message: 'Account suspended; no session left to end',
      ));
    }

    final run = () async {
      await logout(preserveWallet: true);
      _showAccountSuspendedNotice();
      return const AuthReauthResult(
        AuthReauthOutcome.failed,
        message: 'Account suspended; session ended',
      );
    }();
    _inactiveSessionEnd = run;
    return run.whenComplete(() => _inactiveSessionEnd = null);
  }

  void _showAccountSuspendedNotice() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The overlay sits below the navigator, so the dialog finds its route
      // stack; the navigator's own context has no navigator above it.
      final context = appNavigatorKey.currentState?.overlay?.context;
      if (context == null || !context.mounted) return;
      final l10n = AppLocalizations.of(context);
      if (l10n == null) return;
      unawaited(showKubusDialog<void>(
        context: context,
        builder: (dialogContext) => KubusAlertDialog(
          title: Text(l10n.authAccountSuspendedTitle),
          content: Text(l10n.authAccountSuspendedMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      ));
    });
  }

  /// Returns true only when [token] is a parseable JWT with an `exp` claim
  /// that lies in the future (with a 30-second clock-skew grace period).
  /// Opaque strings without a dot-separated JWT structure return false so that
  /// test stubs and malformed values never satisfy the valid-session check.
  static bool _tokenHasFutureExpiry(String token) {
    if (token.isEmpty) return false;
    final expiry = AuthGatingService.extractJwtExpiryUtc(token);
    if (expiry == null) return false;
    return expiry
        .isAfter(DateTime.now().toUtc().add(const Duration(seconds: 30)));
  }

  /// Forces the app to /sign-in for a session that truly cannot be restored.
  /// Never hijacks auth/onboarding surfaces — those flows own their own
  /// recovery UX and an automatic stack wipe there loses in-progress state.
  void _forceSignInRedirect() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;
    String? currentRouteName;
    navigator.popUntil((route) {
      currentRouteName = route.settings.name;
      return true;
    });
    final routeName = (currentRouteName ?? '').toLowerCase();
    if (routeName.contains('/onboarding') ||
        routeName.contains('/sign-in') ||
        routeName.contains('/register') ||
        routeName.contains('/verify-email') ||
        routeName.contains('/reset-password')) {
      return;
    }
    navigator.pushNamedAndRemoveUntil('/sign-in', (_) => false);
  }

  Future<bool> unlockWithSignIn() async {
    if (!_locked) return true;
    if (_busy) return false;

    _busy = true;
    notifyListeners();
    try {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null || !navigator.mounted) return false;

      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
        await SchedulerBinding.instance.endOfFrame;
      }
      if (!navigator.mounted) return false;

      final result = await navigator.push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const SignInScreen(onAuthSuccess: _noOpAuthCallback),
        ),
      );

      if (result == true) {
        try {
          await BackendApiService().loadAuthToken();
        } catch (_) {}
        _lastResolutionWasLocal = false;
        _completeAndReset(const AuthReauthResult(AuthReauthOutcome.success));
        return true;
      }

      _cooldownUntil = DateTime.now().add(_promptCooldown);
      return false;
    } catch (e) {
      _cooldownUntil = DateTime.now().add(_promptCooldown);
      if (kDebugMode) {
        debugPrint('SecurityGateProvider.unlockWithSignIn failed: $e');
      }
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  static FutureOr<void> _noOpAuthCallback(Map<String, dynamic> _) {}

  Future<BiometricAuthOutcome> unlockWithBiometrics(
      {String? localizedReason}) async {
    if (!_locked) return BiometricAuthOutcome.success;
    if (_busy) return BiometricAuthOutcome.failed;

    final wallet = _walletProvider;
    if (wallet == null) return BiometricAuthOutcome.error;

    _busy = true;
    notifyListeners();
    try {
      final outcome = await wallet.authenticateWithBiometricsDetailed(
        localizedReason: localizedReason,
      );
      if (outcome != BiometricAuthOutcome.success) return outcome;

      final ok = await _finalizeUnlockAfterLocalVerification();
      return ok ? BiometricAuthOutcome.success : BiometricAuthOutcome.error;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecurityGateProvider.unlockWithBiometrics failed: $e');
      }
      return BiometricAuthOutcome.error;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<PinVerifyResult> unlockWithPin(String pin) async {
    if (!_locked) return const PinVerifyResult(PinVerifyOutcome.success);
    if (_busy) return const PinVerifyResult(PinVerifyOutcome.error);

    final wallet = _walletProvider;
    if (wallet == null) return const PinVerifyResult(PinVerifyOutcome.error);

    _busy = true;
    notifyListeners();
    try {
      final result = await wallet.verifyPinDetailed(pin);
      if (!result.isSuccess) return result;

      final ok = await _finalizeUnlockAfterLocalVerification();
      return ok ? result : const PinVerifyResult(PinVerifyOutcome.error);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Whether the last lock was resolved by local authentication (PIN or
  /// biometric). Signing in again renews the session but proves nothing about
  /// the person holding the device, so it never satisfies a sensitive action.
  bool _lastResolutionWasLocal = false;

  Future<bool> requireSensitiveActionVerification() async {
    final wallet = _walletProvider;
    bool hasPin;
    try {
      hasPin = await wallet?.hasPinOrThrow() ?? false;
    } catch (_) {
      // The PIN store could not be read: fail closed. "Unknown" is not "none".
      return false;
    }
    final canUseBiometrics =
        biometricsEnabled && (await wallet?.canUseBiometrics() ?? false);

    await lock(SecurityLockReason.sensitiveAction);
    if (!(hasPin || canUseBiometrics)) {
      return true;
    }

    final settled = await _inFlight?.future;
    return (settled?.isSuccess ?? false) && _lastResolutionWasLocal;
  }

  Future<bool> _finalizeUnlockAfterLocalVerification() async {
    final reason = _lockReason;
    if (reason == SecurityLockReason.tokenExpired) {
      final ok = await _renewBackendSession();
      if (!ok) {
        // Keep locked so the user can choose "Sign in" or "Logout".
        _cooldownUntil = DateTime.now().add(_promptCooldown);
        notifyListeners();
        return false;
      }
    } else if (reason == SecurityLockReason.autoLock) {
      await _attemptManagedWalletReconnect(refreshBackendSession: false);
    }

    _lastResolutionWasLocal = true;
    _completeAndReset(const AuthReauthResult(AuthReauthOutcome.success));
    return true;
  }

  Future<void> _attemptManagedWalletReconnect({
    required bool refreshBackendSession,
  }) async {
    final wallet = _walletProvider;
    if (wallet == null || !wallet.isReadOnlySession) return;
    try {
      final managedEligible = await wallet.isManagedReconnectEligible();
      if (!managedEligible) return;
      final walletAddress = await _resolveWalletAddress();
      await wallet.recoverManagedWalletSession(
        walletAddress: walletAddress?.trim(),
        refreshBackendSession: refreshBackendSession,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecurityGateProvider: managed reconnect failed: $e');
      }
    }
  }

  Future<bool> _renewBackendSession() async {
    try {
      final walletAddress = await _resolveWalletAddress();
      if (walletAddress == null || walletAddress.trim().isEmpty) return false;

      final wallet = _walletProvider;
      if (wallet != null) {
        final managedEligible = await wallet.isManagedReconnectEligible();
        if (managedEligible) {
          await wallet.recoverManagedWalletSession(
            walletAddress: walletAddress.trim(),
            refreshBackendSession: true,
          );
        } else if (await wallet.ensureBackendSessionForActiveSigner(
          walletAddress: walletAddress.trim(),
        )) {
          return true;
        } else {
          await BackendApiService().restoreExistingSession(allowRefresh: false);
        }
      } else {
        await BackendApiService().restoreExistingSession(allowRefresh: false);
      }
      return (BackendApiService().getAuthToken() ?? '').trim().isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecurityGateProvider: backend session renewal failed: $e');
      }
      return false;
    }
  }

  Future<String?> _resolveWalletAddress() async {
    final fromProfile = _profileProvider?.currentUser?.walletAddress;
    if (fromProfile != null && fromProfile.trim().isNotEmpty) {
      return fromProfile;
    }
    final fromWallet = _walletProvider?.currentWalletAddress;
    if (fromWallet != null && fromWallet.trim().isNotEmpty) return fromWallet;

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('wallet_address') ??
          prefs.getString('wallet') ??
          prefs.getString('walletAddress');
      if (stored != null && stored.trim().isNotEmpty) return stored.trim();
    } catch (_) {}
    return null;
  }

  /// Resolves the pending lock as the overlay would after a successful unlock
  /// ([localAuthentication] true: PIN or biometric) or after signing in again.
  @visibleForTesting
  void completeForTesting({required bool localAuthentication}) {
    _lastResolutionWasLocal = localAuthentication;
    _completeAndReset(const AuthReauthResult(AuthReauthOutcome.success));
  }

  void _completeAndReset(AuthReauthResult result) {
    final completer = _inFlight;
    _inFlight = null;
    _locked = false;
    _lockReason = null;
    _authFailureContext = null;
    _busy = false;
    _resetInactivityTimer();

    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
    notifyListeners();
  }
}
