import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';

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
  static Future<void> markCompleted({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setBool(PreferenceKeys.hasCompletedOnboarding, true);
    await p.setBool(PreferenceKeys.hasSeenWelcome, true);
    await p.setBool(PreferenceKeys.isFirstLaunch, false);

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
}
