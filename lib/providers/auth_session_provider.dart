import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import '../core/app_navigator.dart';
import '../l10n/app_localizations.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/session_reauth_prompt.dart';
import '../services/backend_api_service.dart';
import '../services/auth_session_coordinator.dart';
import '../services/pin_hashing.dart';
import '../services/settings_service.dart';
import '../providers/profile_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/glass_components.dart';

class AuthSessionProvider extends ChangeNotifier implements AuthSessionCoordinator {
  AuthSessionProvider({Duration? promptCooldown})
      : _promptCooldown = promptCooldown ?? const Duration(seconds: 20);

  final Duration _promptCooldown;

  Completer<AuthReauthResult>? _inFlight;
  DateTime? _cooldownUntil;
  Future<void> Function()? _onSessionRestored;
  ProfileProvider? _profileProvider;
  WalletProvider? _walletProvider;

  void bindOnSessionRestored(Future<void> Function() callback) {
    _onSessionRestored = callback;
  }

  void bindDependencies({
    required ProfileProvider profileProvider,
    required WalletProvider walletProvider,
  }) {
    _profileProvider = profileProvider;
    _walletProvider = walletProvider;
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
    final inflight = _inFlight;
    _inFlight = null;
    if (inflight != null && !inflight.isCompleted) {
      inflight.complete(const AuthReauthResult(AuthReauthOutcome.cancelled));
    }
    notifyListeners();
  }

  @override
  Future<AuthReauthResult> handleAuthFailure(AuthFailureContext context) async {
    if (!AppConfig.isFeatureEnabled('rePromptLoginOnExpiry')) {
      return const AuthReauthResult(AuthReauthOutcome.notEnabled);
    }

    final existing = _inFlight;
    if (existing != null) {
      return existing.future;
    }

    final now = DateTime.now();
    final cooldownUntil = _cooldownUntil;
    if (cooldownUntil != null && now.isBefore(cooldownUntil)) {
      return const AuthReauthResult(AuthReauthOutcome.cooldown);
    }

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return const AuthReauthResult(AuthReauthOutcome.failed, message: 'Navigator unavailable');
    }

    final completer = Completer<AuthReauthResult>();
    _inFlight = completer;
    notifyListeners();

    try {
      final resolvedL10n = AppLocalizations.of(navigator.context);
      if (resolvedL10n == null || !navigator.mounted) {
        _cooldownUntil = DateTime.now().add(_promptCooldown);
        completer.complete(const AuthReauthResult(AuthReauthOutcome.failed, message: 'Localizations unavailable'));
        return completer.future;
      }

      final walletProvider = _walletProvider;
      final showPin = walletProvider != null && await walletProvider.hasPin();

      var biometricEnabled = false;
      if (walletProvider != null) {
        try {
          final settings = await SettingsService.loadSettings();
          biometricEnabled = settings.biometricAuth;
        } catch (_) {
          biometricEnabled = false;
        }
      }

      final showBiometrics = walletProvider != null &&
          biometricEnabled &&
          await walletProvider.canUseBiometrics();

      if (!navigator.mounted) {
        _cooldownUntil = DateTime.now().add(_promptCooldown);
        completer.complete(const AuthReauthResult(AuthReauthOutcome.cancelled));
        return completer.future;
      }

      // Avoid triggering navigation during a build/layout phase.
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
        await SchedulerBinding.instance.endOfFrame;
        if (!navigator.mounted) {
          _cooldownUntil = DateTime.now().add(_promptCooldown);
          completer.complete(const AuthReauthResult(AuthReauthOutcome.cancelled));
          return completer.future;
        }
      }

      final decision = await showKubusDialog<SessionReauthDecision>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) {
          if (walletProvider == null) {
            return SessionReauthPrompt(
              title: resolvedL10n.authReauthDialogTitle,
              message: resolvedL10n.authReauthDialogMessage,
              showBiometrics: false,
              showPin: false,
              onBiometric: () async => BiometricAuthOutcome.notAvailable,
              onVerifyPin: (_) async => const PinVerifyResult(PinVerifyOutcome.notSet),
              getPinLockoutSeconds: () async => 0,
              biometricButtonLabel: resolvedL10n.settingsBiometricTileTitle,
              pinLabel: resolvedL10n.commonPinLabel,
              pinSubmitLabel: resolvedL10n.commonUnlock,
              cancelLabel: resolvedL10n.commonCancel,
              signInLabel: resolvedL10n.commonSignIn,
              pinIncorrectMessage: resolvedL10n.mnemonicRevealIncorrectPinError,
              pinLockedMessage: resolvedL10n.mnemonicRevealPinLockedError,
              biometricUnavailableMessage: resolvedL10n.settingsBiometricUnavailableToast,
              biometricFailedMessage: resolvedL10n.settingsBiometricFailedToast,
            );
          }

          return SessionReauthPrompt(
            title: resolvedL10n.authReauthDialogTitle,
            message: resolvedL10n.authReauthDialogMessage,
            showBiometrics: showBiometrics,
            showPin: showPin,
            onBiometric: () => walletProvider.unlockWithBiometrics(
              localizedReason: resolvedL10n.authReauthDialogMessage,
            ),
            onVerifyPin: (pin) => walletProvider.unlockWithPin(pin),
            getPinLockoutSeconds: () => walletProvider.getPinLockoutRemainingSeconds(),
            biometricButtonLabel: resolvedL10n.settingsBiometricTileTitle,
            pinLabel: resolvedL10n.commonPinLabel,
            pinSubmitLabel: resolvedL10n.commonUnlock,
            cancelLabel: resolvedL10n.commonCancel,
            signInLabel: resolvedL10n.commonSignIn,
            pinIncorrectMessage: resolvedL10n.mnemonicRevealIncorrectPinError,
            pinLockedMessage: resolvedL10n.mnemonicRevealPinLockedError,
            biometricUnavailableMessage: resolvedL10n.settingsBiometricUnavailableToast,
            biometricFailedMessage: resolvedL10n.settingsBiometricFailedToast,
          );
        },
      );

      if (!navigator.mounted) {
        _cooldownUntil = DateTime.now().add(_promptCooldown);
        completer.complete(const AuthReauthResult(AuthReauthOutcome.cancelled));
        return completer.future;
      }

      final resolved = decision ?? SessionReauthDecision.cancelled;
      if (resolved == SessionReauthDecision.cancelled) {
        _cooldownUntil = DateTime.now().add(_promptCooldown);
        completer.complete(const AuthReauthResult(AuthReauthOutcome.cancelled));
        return completer.future;
      }

      var ok = false;
      if (resolved == SessionReauthDecision.verified) {
        final walletAddress = await _resolveWalletAddress();
        if (walletAddress != null && walletAddress.trim().isNotEmpty) {
          ok = await _renewWalletSession(walletAddress.trim());
        }
      }

      if (!ok && resolved == SessionReauthDecision.signIn) {
        ok = await _runSignInFlow(navigator);
      }

      if (!ok && resolved == SessionReauthDecision.verified) {
        // Local verification succeeded but we couldn't renew the backend session
        // (no wallet or backend rejected). Offer sign-in as a fallback.
        ok = await _runSignInFlow(navigator);
      }

      if (ok) {
        completer.complete(const AuthReauthResult(AuthReauthOutcome.success));
        unawaited(() async {
          try {
            await _onSessionRestored?.call();
          } catch (e) {
            AppConfig.debugPrint('AuthSessionProvider: onSessionRestored failed: $e');
          }
        }());
        return completer.future;
      }

      _cooldownUntil = DateTime.now().add(_promptCooldown);
      completer.complete(const AuthReauthResult(AuthReauthOutcome.cancelled));
    } catch (e) {
      _cooldownUntil = DateTime.now().add(_promptCooldown);
      completer.complete(AuthReauthResult(AuthReauthOutcome.failed, message: e.toString()));
    } finally {
      _inFlight = null;
      notifyListeners();
    }

    return completer.future;
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

  Future<bool> _renewWalletSession(String walletAddress) async {
    try {
      await BackendApiService().registerWallet(walletAddress: walletAddress);
      await BackendApiService().loadAuthToken();
      return (BackendApiService().getAuthToken() ?? '').isNotEmpty;
    } catch (e) {
      AppConfig.debugPrint('AuthSessionProvider: wallet session renewal failed: $e');
      return false;
    }
  }

  Future<bool> _runSignInFlow(NavigatorState navigator) async {
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      await SchedulerBinding.instance.endOfFrame;
      if (!navigator.mounted) return false;
    }
    final result = await navigator.push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SignInScreen(onAuthSuccess: (_) async {}),
      ),
    );
    if (result == true) {
      try {
        await BackendApiService().loadAuthToken();
      } catch (_) {}
      return true;
    }
    return false;
  }
}
