import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import 'onboarding_state_service.dart';

class AuthGatingService {
  static const List<String> _tokenKeys = <String>[
    'jwt_token',
    'token',
    'auth_token',
    'authToken',
  ];

  static const List<String> _walletKeys = <String>[
    'wallet_address',
    'wallet',
    'walletAddress',
  ];

  static bool _hasNonEmptyPref(SharedPreferences prefs, String key) {
    final value = (prefs.getString(key) ?? '').trim();
    return value.isNotEmpty;
  }

  static bool hasLocalAccountSync({
    required SharedPreferences prefs,
  }) {
    final hasToken = _tokenKeys.any((key) => _hasNonEmptyPref(prefs, key));
    final hasWallet = (prefs.getBool('has_wallet') ?? false) ||
        _walletKeys.any((key) => _hasNonEmptyPref(prefs, key));
    final hasUserId = _hasNonEmptyPref(prefs, 'user_id');
    return hasToken || hasWallet || hasUserId;
  }

  static Future<bool> hasLocalAccount({SharedPreferences? prefs}) async {
    final resolved = prefs ?? await SharedPreferences.getInstance();
    return hasLocalAccountSync(prefs: resolved);
  }

  static Future<bool> shouldPromptReauth({SharedPreferences? prefs}) async {
    if (!AppConfig.isFeatureEnabled('rePromptLoginOnExpiry')) return false;
    return hasLocalAccount(prefs: prefs);
  }

  static Future<bool> shouldShowFirstRunOnboarding({
    SharedPreferences? prefs,
    OnboardingState? onboardingState,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final localAccount = hasLocalAccountSync(prefs: resolvedPrefs);
    if (localAccount) return false;

    final state = onboardingState ?? await OnboardingStateService.load(prefs: resolvedPrefs);
    return !state.hasCompletedOnboarding;
  }
}

