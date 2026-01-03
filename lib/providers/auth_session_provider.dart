import 'dart:async';

import 'package:flutter/material.dart';

import '../config/config.dart';
import '../core/app_navigator.dart';
import '../screens/auth/sign_in_screen.dart';
import '../services/auth_session_coordinator.dart';

class AuthSessionProvider extends ChangeNotifier implements AuthSessionCoordinator {
  AuthSessionProvider({Duration? promptCooldown})
      : _promptCooldown = promptCooldown ?? const Duration(seconds: 20);

  final Duration _promptCooldown;

  Completer<AuthReauthResult>? _inFlight;
  DateTime? _cooldownUntil;
  Future<void> Function()? _onSessionRestored;

  void bindOnSessionRestored(Future<void> Function() callback) {
    _onSessionRestored = callback;
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
      final result = await navigator.push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => SignInScreen(
            onAuthSuccess: (_) async {},
          ),
        ),
      );

      final ok = result == true;
      if (ok) {
        try {
          await _onSessionRestored?.call();
        } catch (e) {
          AppConfig.debugPrint('AuthSessionProvider: onSessionRestored failed: $e');
        }
        completer.complete(const AuthReauthResult(AuthReauthOutcome.success));
      } else {
        _cooldownUntil = DateTime.now().add(_promptCooldown);
        completer.complete(const AuthReauthResult(AuthReauthOutcome.cancelled));
      }
    } catch (e) {
      _cooldownUntil = DateTime.now().add(_promptCooldown);
      completer.complete(AuthReauthResult(AuthReauthOutcome.failed, message: e.toString()));
    } finally {
      _inFlight = null;
      notifyListeners();
    }

    return completer.future;
  }
}
