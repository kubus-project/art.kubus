import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_navigator.dart';
import '../services/auth_gating_service.dart';
import '../services/auth_session_coordinator.dart';
import '../services/backend_api_service.dart';
import '../services/pin_hashing.dart';
import '../services/settings_service.dart';
import '../services/onboarding_state_service.dart';
import '../providers/notification_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/wallet_provider.dart';
import '../screens/auth/sign_in_screen.dart';

enum SecurityLockReason {
  autoLock,
  tokenExpired,
  sensitiveAction,
}

class SecurityGateProvider extends ChangeNotifier implements AuthSessionCoordinator {
  SecurityGateProvider({
    Duration promptCooldown = const Duration(seconds: 8),
  }) : _promptCooldown = promptCooldown;

  final Duration _promptCooldown;

  ProfileProvider? _profileProvider;
  WalletProvider? _walletProvider;
  NotificationProvider? _notificationProvider;

  SettingsState? _settings;

  bool _locked = false;
  SecurityLockReason? _lockReason;
  AuthFailureContext? _authFailureContext;

  Completer<AuthReauthResult>? _inFlight;
  DateTime? _cooldownUntil;
  bool _busy = false;

  Timer? _inactivityTimer;
  DateTime _lastInteractionAt = DateTime.now();

  Completer<void>? _initializeCompleter;
  bool _hasLocalAccount = false;

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
  }) {
    _profileProvider = profileProvider;
    _walletProvider = walletProvider;
    _notificationProvider = notificationProvider;
  }

  Future<void> initialize() {
    final existing = _initializeCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _initializeCompleter = completer;

    () async {
      try {
        await reloadSettings();
        _resetInactivityTimer();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('SecurityGateProvider.initialize failed: $e');
        }
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    }();

    return completer.future;
  }

  Future<void> reloadSettings() async {
    _settings = await SettingsService.loadSettings();
    await refreshLocalAccountState();
    _resetInactivityTimer();
    notifyListeners();
  }

  Future<void> refreshLocalAccountState({SharedPreferences? prefs}) async {
    try {
      final resolved = prefs ?? await SharedPreferences.getInstance();
      _hasLocalAccount = AuthGatingService.hasLocalAccountSync(prefs: resolved);
    } catch (_) {
      _hasLocalAccount = false;
    }
  }

  void onUserInteraction() {
    _lastInteractionAt = DateTime.now();
    _resetInactivityTimer();
  }

  void onAppLifecycleChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      unawaited(_persistInactiveTimestamp());
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleResumed());
    }
  }

  Future<void> _persistInactiveTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_inactive_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> _handleResumed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastInactiveMs = prefs.getInt('last_inactive_ts');
      await prefs.remove('last_inactive_ts');

      await reloadSettings();

      if (!_shouldAutoLock()) return;
      if (lastInactiveMs == null) return;

      final elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastInactiveMs));
      if (autoLockSeconds < 0) {
        // Immediate: any backgrounding locks.
        await lock(SecurityLockReason.autoLock);
        return;
      }
      if (autoLockSeconds == 0) return;
      if (elapsed.inSeconds >= autoLockSeconds) {
        await lock(SecurityLockReason.autoLock);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecurityGateProvider._handleResumed failed: $e');
      }
    }
  }

  bool _shouldAutoLock() {
    if (!_hasLocalAccount) return false;
    if (!requirePin) return false;
    final seconds = autoLockSeconds;
    if (seconds == 0) return false;
    return true;
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!_shouldAutoLock()) return;
    if (autoLockSeconds <= 0) return; // Never or Immediate handled via lifecycle.
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

  Future<void> lock(SecurityLockReason reason, {AuthFailureContext? context}) async {
    if ((reason == SecurityLockReason.autoLock || reason == SecurityLockReason.tokenExpired) && !_hasLocalAccount) {
      return;
    }
    final wallet = _walletProvider;
    final hasPin = await wallet?.hasPin() ?? false;
    if (reason == SecurityLockReason.autoLock && (!requirePin || !hasPin)) return;
    if (reason == SecurityLockReason.sensitiveAction && !hasPin) return;

    if (_locked && _inFlight != null) {
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

  Future<void> logout() async {
    final wallet = _walletProvider;
    if (wallet == null) return;

    try {
      await SettingsService.logout(
        walletProvider: wallet,
        backendApi: BackendApiService(),
        notificationProvider: _notificationProvider,
        profileProvider: _profileProvider,
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
    final existing = _inFlight;
    if (existing != null) return existing.future;

    final now = DateTime.now();
    final cooldownUntil = _cooldownUntil;
    if (cooldownUntil != null && now.isBefore(cooldownUntil)) {
      return const AuthReauthResult(AuthReauthOutcome.cooldown);
    }

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      _hasLocalAccount = AuthGatingService.hasLocalAccountSync(prefs: prefs);
    } catch (_) {}

    if (!await AuthGatingService.shouldPromptReauth(prefs: prefs)) {
      // Fresh installs (no stored session) must never show the "sign in again"
      // lock. In that case, either let onboarding proceed or route to sign-in.
      final showOnboarding = await AuthGatingService.shouldShowFirstRunOnboarding(
        prefs: prefs,
        onboardingState: prefs == null ? null : await OnboardingStateService.load(prefs: prefs),
      );

      if (!showOnboarding) {
        _cooldownUntil = DateTime.now().add(_promptCooldown);
        final navigator = appNavigatorKey.currentState;
        if (navigator != null && navigator.mounted) {
          navigator.pushNamedAndRemoveUntil('/sign-in', (_) => false);
        }
      }

      return const AuthReauthResult(AuthReauthOutcome.notEnabled);
    }

    await lock(SecurityLockReason.tokenExpired, context: context);
    final inflight = _inFlight;
    if (inflight == null) {
      _cooldownUntil = DateTime.now().add(_promptCooldown);
      return const AuthReauthResult(AuthReauthOutcome.failed, message: 'Unable to start re-auth flow');
    }
    return inflight.future;
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

  Future<BiometricAuthOutcome> unlockWithBiometrics({String? localizedReason}) async {
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

  Future<void> requireSensitiveActionVerification() async {
    await lock(SecurityLockReason.sensitiveAction);
    await _inFlight?.future;
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
    }

    _completeAndReset(const AuthReauthResult(AuthReauthOutcome.success));
    return true;
  }

  Future<bool> _renewBackendSession() async {
    try {
      final walletAddress = await _resolveWalletAddress();
      if (walletAddress == null || walletAddress.trim().isEmpty) return false;

      await BackendApiService().registerWallet(walletAddress: walletAddress.trim());
      await BackendApiService().loadAuthToken();
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
    if (fromProfile != null && fromProfile.trim().isNotEmpty) return fromProfile;
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
