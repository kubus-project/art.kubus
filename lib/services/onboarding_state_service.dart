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

  bool get isReturningUser =>
      !isFirstLaunch || hasSeenWelcome || hasCompletedOnboarding;
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
/// - Helper methods for marking onboarding completed / reset
class OnboardingStateService {
  static const String _onboardingVersionKey = 'onboarding_version';
  static const String _onboardingCompletedStepsKey =
      'onboarding_completed_steps_v2';
  static const String _onboardingDeferredStepsKey =
      'onboarding_deferred_steps_v2';

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

    final isFirstLaunch = p.getBool(PreferenceKeys.isFirstLaunch) ?? true;
    final hasSeenWelcome = p.getBool(PreferenceKeys.hasSeenWelcome) ?? false;
    final hasCompletedOnboarding =
        p.getBool(PreferenceKeys.hasCompletedOnboarding) ?? false;

    return OnboardingState(
      isFirstLaunch: isFirstLaunch,
      hasSeenWelcome: hasSeenWelcome,
      hasCompletedOnboarding: hasCompletedOnboarding,
    );
  }

  /// Mark onboarding completed and move the app into a stable "returning" state.
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
  }

  /// Mark that the welcome has been seen (without necessarily completing the full onboarding flow).
  static Future<void> markWelcomeSeen({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setBool(PreferenceKeys.hasSeenWelcome, true);
    await p.setBool(PreferenceKeys.isFirstLaunch, false);
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
  }

  static Future<OnboardingFlowProgress> loadFlowProgress({
    SharedPreferences? prefs,
    required int onboardingVersion,
    String? flowScopeKey,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();

    // Try to load scoped progress first.
    final normalizedScope = (flowScopeKey ?? '').trim();

    final scopedProgress = await _loadFlowProgressRaw(
      prefs: p,
      onboardingVersion: onboardingVersion,
      flowScopeKey: flowScopeKey,
    );

    // If no scope requested, return scopedProgress (which in this case is unscoped raw).
    if (normalizedScope.isEmpty) {
      return scopedProgress;
    }

    // If scoped progress has real steps, prefer it.
    if (scopedProgress.completedSteps.isNotEmpty ||
        scopedProgress.deferredSteps.isNotEmpty) {
      return scopedProgress;
    }

    // Scoped progress is empty (or version mismatch). Try unscoped fallback and migrate when appropriate.
    final unscopedProgress = await _loadFlowProgressRaw(
      prefs: p,
      onboardingVersion: onboardingVersion,
      flowScopeKey: null,
    );

    if (unscopedProgress.lastSeenVersion == onboardingVersion &&
        (unscopedProgress.completedSteps.isNotEmpty ||
            unscopedProgress.deferredSteps.isNotEmpty)) {
      // Migrate unscoped progress to scoped keys and return it.
      await saveFlowProgress(
        prefs: p,
        onboardingVersion: onboardingVersion,
        completedSteps: unscopedProgress.completedSteps,
        deferredSteps: unscopedProgress.deferredSteps,
        flowScopeKey: flowScopeKey,
      );
      return unscopedProgress;
    }

    // Nothing to migrate — return the (empty) scopedProgress.
    return scopedProgress;
  }

  /// Load progress from SharedPreferences without fallback/migration logic.
  /// This is a raw loader used internally for both scoped and unscoped lookups.
  static Future<OnboardingFlowProgress> _loadFlowProgressRaw({
    required SharedPreferences prefs,
    required int onboardingVersion,
    String? flowScopeKey,
  }) async {
    final versionKey = _scopedKey(_onboardingVersionKey, flowScopeKey);
    final completedKey = _scopedKey(_onboardingCompletedStepsKey, flowScopeKey);
    final deferredKey = _scopedKey(_onboardingDeferredStepsKey, flowScopeKey);
    final seenVersion = prefs.getInt(versionKey) ?? 0;

    if (seenVersion != onboardingVersion) {
      return OnboardingFlowProgress(
        lastSeenVersion: onboardingVersion,
        completedSteps: <String>{},
        deferredSteps: <String>{},
      );
    }

    final completed = (prefs.getStringList(completedKey) ?? const <String>[])
        .where((value) => value.trim().isNotEmpty)
        .toSet();
    final deferred = (prefs.getStringList(deferredKey) ?? const <String>[])
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
    final completedKey = _scopedKey(_onboardingCompletedStepsKey, flowScopeKey);
    final deferredKey = _scopedKey(_onboardingDeferredStepsKey, flowScopeKey);
    await p.setInt(versionKey, onboardingVersion);
    await p.setStringList(
      completedKey,
      completedSteps
          .where((value) => value.trim().isNotEmpty)
          .toList(growable: false),
    );
    await p.setStringList(
      deferredKey,
      deferredSteps
          .where((value) => value.trim().isNotEmpty)
          .toList(growable: false),
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
      return prefs.getBool(scopedKey) ?? false;
    }

    final baseKey = PreferenceKeys.pendingAuthOnboarding;
    return prefs.getBool(baseKey) ?? false;
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
    await p.setBool(
        _scopedKey(PreferenceKeys.pendingAuthOnboarding, scopeKey), true);
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
