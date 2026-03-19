import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import '../utils/wallet_utils.dart';

class OnboardingState {
  final bool isFirstLaunch;
  final bool hasSeenWelcome;
  final bool hasCompletedOnboarding;

  const OnboardingState({
    required this.isFirstLaunch,
    required this.hasSeenWelcome,
    required this.hasCompletedOnboarding,
  });

  bool get isReturningUser => !isFirstLaunch || hasSeenWelcome || hasCompletedOnboarding;
}

class OnboardingFlowProgress {
  final int lastSeenVersion;
  final Set<String> completedSteps;
  final Set<String> deferredSteps;

  const OnboardingFlowProgress({
    required this.lastSeenVersion,
    required this.completedSteps,
    required this.deferredSteps,
  });
}

/// Single source-of-truth for onboarding-related SharedPreferences.
///
/// This centralizes:
/// - Canonical keys (`PreferenceKeys.*`)
/// - One-time migration from legacy keys used in older builds
/// - Helper methods for marking onboarding completed / reset
class OnboardingStateService {
  static const String _legacyFirstTime = 'first_time';
  static const String _legacyCompletedOnboarding = 'completed_onboarding';
  static const String _legacyHasCompletedOnboarding = 'has_completed_onboarding';
  static const String _legacyHasSeenOnboarding = 'has_seen_onboarding';
  static const String _legacyHasSeenPermissions = 'has_seen_permissions';
  static const String _onboardingVersionKey = 'onboarding_version';
  static const String _onboardingCompletedStepsKey = 'onboarding_completed_steps_v2';
  static const String _onboardingDeferredStepsKey = 'onboarding_deferred_steps_v2';

  static String _scopedKey(String key, String? flowScopeKey) {
    final scope = (flowScopeKey ?? '').trim();
    if (scope.isEmpty) return key;
    return '$key:$scope';
  }

  static Future<void> _clearPendingAuthOnboardingKeys(
      SharedPreferences prefs) async {
    final baseKey = PreferenceKeys.pendingAuthOnboarding;
    final keys = prefs
        .getKeys()
        .where(
          (key) => key == baseKey || key.startsWith('$baseKey:'),
        )
        .toList(growable: false);
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  static Future<void> _clearPendingAuthOnboardingForScope(
    SharedPreferences prefs, {
    String? scopeKey,
  }) async {
    final normalizedScope = (scopeKey ?? '').trim();
    if (normalizedScope.isEmpty) {
      await prefs.remove(PreferenceKeys.pendingAuthOnboarding);
      return;
    }
    await prefs.remove(
      _scopedKey(PreferenceKeys.pendingAuthOnboarding, normalizedScope),
    );
    // Clear the unscoped legacy flag too so scoped reads don't get overridden.
    await prefs.remove(PreferenceKeys.pendingAuthOnboarding);
  }

  static String? buildAuthOnboardingScopeKey({
    String? walletAddress,
    String? userId,
  }) {
    final canonicalWallet = WalletUtils.canonical(walletAddress);
    if (canonicalWallet.isNotEmpty) {
      return 'wallet:$canonicalWallet';
    }
    final normalizedUserId = (userId ?? '').trim();
    if (normalizedUserId.isNotEmpty) {
      return 'user:$normalizedUserId';
    }
    return null;
  }

  static Future<OnboardingState> load({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await _migrateLegacyKeys(p);

    final isFirstLaunch = p.getBool(PreferenceKeys.isFirstLaunch) ?? true;
    final hasSeenWelcome = p.getBool(PreferenceKeys.hasSeenWelcome) ?? false;
    final hasCompletedOnboarding = p.getBool(PreferenceKeys.hasCompletedOnboarding) ?? false;

    return OnboardingState(
      isFirstLaunch: isFirstLaunch,
      hasSeenWelcome: hasSeenWelcome,
      hasCompletedOnboarding: hasCompletedOnboarding,
    );
  }

  /// Mark onboarding completed and move the app into a stable "returning" state.
  ///
  /// Also writes legacy keys for backward compatibility with any remaining
  /// surfaces that might still read them.
  static Future<void> markCompleted({
    SharedPreferences? prefs,
    String? authOnboardingScopeKey,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setBool(PreferenceKeys.hasCompletedOnboarding, true);
    await p.setBool(PreferenceKeys.hasSeenWelcome, true);
    await p.setBool(PreferenceKeys.isFirstLaunch, false);
    await _clearPendingAuthOnboardingForScope(
      p,
      scopeKey: authOnboardingScopeKey,
    );

    // Legacy keys (compat)
    await p.setBool(_legacyCompletedOnboarding, true);
    await p.setBool(_legacyHasCompletedOnboarding, true);
    await p.setBool(_legacyHasSeenOnboarding, true);
    await p.setBool(_legacyFirstTime, false);
  }

  /// Mark that the welcome has been seen (without necessarily completing the full onboarding flow).
  static Future<void> markWelcomeSeen({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setBool(PreferenceKeys.hasSeenWelcome, true);
    await p.setBool(PreferenceKeys.isFirstLaunch, false);

    // Legacy
    await p.setBool(_legacyFirstTime, false);
  }

  /// Reset onboarding-related flags so the app starts from a clean first-launch state.
  ///
  /// Does not touch wallet credentials.
  static Future<void> reset({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();

    await p.setBool(PreferenceKeys.hasCompletedOnboarding, false);
    await p.setBool(PreferenceKeys.hasSeenWelcome, false);
    await p.setBool(PreferenceKeys.isFirstLaunch, true);
    await _clearPendingAuthOnboardingKeys(p);

    // Legacy
    await p.setBool(_legacyFirstTime, true);
    await p.remove(_legacyCompletedOnboarding);
    await p.remove(_legacyHasCompletedOnboarding);
    await p.remove(_legacyHasSeenOnboarding);
    await p.remove(_legacyHasSeenPermissions);
  }

  static Future<void> _migrateLegacyKeys(SharedPreferences prefs) async {
    // completed_onboarding -> PreferenceKeys.hasCompletedOnboarding
    if (!prefs.containsKey(PreferenceKeys.hasCompletedOnboarding)) {
      final legacyCompleted = (prefs.getBool(_legacyCompletedOnboarding) ?? false) ||
          (prefs.getBool(_legacyHasCompletedOnboarding) ?? false);
      if (legacyCompleted) {
        await prefs.setBool(PreferenceKeys.hasCompletedOnboarding, true);
      }
    }

    // first_time / has_seen_onboarding -> hasSeenWelcome
    if (!prefs.containsKey(PreferenceKeys.hasSeenWelcome)) {
      final legacyFirstTime = prefs.getBool(_legacyFirstTime);
      final inferredSeenWelcome = (legacyFirstTime == false) ||
          (prefs.getBool(_legacyHasSeenOnboarding) ?? false) ||
          (prefs.getBool(_legacyCompletedOnboarding) ?? false);
      if (inferredSeenWelcome) {
        await prefs.setBool(PreferenceKeys.hasSeenWelcome, true);
      }
    }

    // If first_time indicates returning user, also migrate isFirstLaunch.
    if (!prefs.containsKey(PreferenceKeys.isFirstLaunch)) {
      final legacyFirstTime = prefs.getBool(_legacyFirstTime);
      if (legacyFirstTime == false) {
        await prefs.setBool(PreferenceKeys.isFirstLaunch, false);
      }
    }

    // Keep legacy in sync if canonical says completed.
    final canonicalCompleted = prefs.getBool(PreferenceKeys.hasCompletedOnboarding) ?? false;
    if (canonicalCompleted) {
      if (prefs.getBool(_legacyCompletedOnboarding) != true) {
        await prefs.setBool(_legacyCompletedOnboarding, true);
      }
      if (prefs.getBool(_legacyHasCompletedOnboarding) != true) {
        await prefs.setBool(_legacyHasCompletedOnboarding, true);
      }
      if (prefs.getBool(_legacyHasSeenOnboarding) != true) {
        await prefs.setBool(_legacyHasSeenOnboarding, true);
      }
      if (prefs.getBool(_legacyFirstTime) != false) {
        await prefs.setBool(_legacyFirstTime, false);
      }
    }
  }

  static Future<OnboardingFlowProgress> loadFlowProgress({
    SharedPreferences? prefs,
    required int onboardingVersion,
    String? flowScopeKey,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final versionKey = _scopedKey(_onboardingVersionKey, flowScopeKey);
    final completedKey =
        _scopedKey(_onboardingCompletedStepsKey, flowScopeKey);
    final deferredKey = _scopedKey(_onboardingDeferredStepsKey, flowScopeKey);
    final seenVersion = p.getInt(versionKey) ?? 0;

    if (seenVersion != onboardingVersion) {
      return OnboardingFlowProgress(
        lastSeenVersion: onboardingVersion,
        completedSteps: <String>{},
        deferredSteps: <String>{},
      );
    }

    final completed = (p.getStringList(completedKey) ?? const <String>[])
        .where((value) => value.trim().isNotEmpty)
        .toSet();
    final deferred = (p.getStringList(deferredKey) ?? const <String>[])
        .where((value) => value.trim().isNotEmpty)
        .toSet();

    return OnboardingFlowProgress(
      lastSeenVersion: seenVersion,
      completedSteps: completed,
      deferredSteps: deferred,
    );
  }

  static Future<void> saveFlowProgress({
    SharedPreferences? prefs,
    required int onboardingVersion,
    required Set<String> completedSteps,
    required Set<String> deferredSteps,
    String? flowScopeKey,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final versionKey = _scopedKey(_onboardingVersionKey, flowScopeKey);
    final completedKey =
        _scopedKey(_onboardingCompletedStepsKey, flowScopeKey);
    final deferredKey = _scopedKey(_onboardingDeferredStepsKey, flowScopeKey);
    await p.setInt(versionKey, onboardingVersion);
    await p.setStringList(
      completedKey,
      completedSteps.where((value) => value.trim().isNotEmpty).toList(growable: false),
    );
    await p.setStringList(
      deferredKey,
      deferredSteps.where((value) => value.trim().isNotEmpty).toList(growable: false),
    );
  }

  static bool hasPendingAuthOnboardingSync(
    SharedPreferences prefs, {
    String? scopeKey,
  }) {
    final normalizedScope = (scopeKey ?? '').trim();
    if (normalizedScope.isNotEmpty) {
      final scopedKey =
          _scopedKey(PreferenceKeys.pendingAuthOnboarding, normalizedScope);
      if (prefs.getBool(scopedKey) ?? false) return true;
      final hasScopedEntries = prefs
          .getKeys()
          .any((key) => key.startsWith('${PreferenceKeys.pendingAuthOnboarding}:'));
      if (!hasScopedEntries) {
        // Legacy migration path: if scoped keys were never written, honor the
        // old global key once for backward compatibility.
        return prefs.getBool(PreferenceKeys.pendingAuthOnboarding) ?? false;
      }
      return false;
    }

    final baseKey = PreferenceKeys.pendingAuthOnboarding;
    if (prefs.getBool(baseKey) ?? false) return true;
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('$baseKey:')) continue;
      if (prefs.getBool(key) ?? false) return true;
    }
    return false;
  }

  static Future<bool> hasPendingAuthOnboarding({
    SharedPreferences? prefs,
    String? scopeKey,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return hasPendingAuthOnboardingSync(p, scopeKey: scopeKey);
  }

  static Future<void> markAuthOnboardingPending({
    SharedPreferences? prefs,
    String? scopeKey,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final normalizedScope = (scopeKey ?? '').trim();
    await p.setBool(_scopedKey(PreferenceKeys.pendingAuthOnboarding, scopeKey), true);
    if (normalizedScope.isNotEmpty) {
      await p.remove(PreferenceKeys.pendingAuthOnboarding);
    }
    await p.setBool(PreferenceKeys.hasSeenWelcome, true);
    await p.setBool(PreferenceKeys.isFirstLaunch, false);
  }

  static Future<void> clearPendingAuthOnboarding({
    SharedPreferences? prefs,
    String? scopeKey,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final normalizedScope = (scopeKey ?? '').trim();
    if (normalizedScope.isEmpty) {
      await _clearPendingAuthOnboardingKeys(p);
      return;
    }
    await _clearPendingAuthOnboardingForScope(p, scopeKey: normalizedScope);
  }
}
