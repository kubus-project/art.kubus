import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import 'onboarding_state_service.dart';

enum StoredSessionStatus {
  valid,
  refreshRequired,
  invalid,
}

class AuthGatingService {
  static const List<String> accessTokenKeys = <String>[
    'jwt_token',
    'token',
    'auth_token',
    'authToken',
  ];

  static const List<String> refreshTokenKeys = <String>[
    'refresh_token',
    'refreshToken',
    'auth_refresh_token',
    'authRefreshToken',
  ];

  static bool _hasNonEmptyPref(SharedPreferences prefs, String key) {
    final value = (prefs.getString(key) ?? '').trim();
    return value.isNotEmpty;
  }

  static String? _readFirstToken(SharedPreferences prefs, List<String> keys) {
    for (final key in keys) {
      final value = (prefs.getString(key) ?? '').trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static String? readStoredAccessToken(SharedPreferences prefs) {
    return _readFirstToken(prefs, accessTokenKeys);
  }

  static String? readStoredRefreshToken(SharedPreferences prefs) {
    return _readFirstToken(prefs, refreshTokenKeys);
  }

  static DateTime? extractJwtExpiryUtc(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return null;
    try {
      final parts = trimmed.split('.');
      if (parts.length < 2) return null;
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final parsed = jsonDecode(decoded);
      if (parsed is Map<String, dynamic>) {
        final exp = parsed['exp'];
        if (exp is num) {
          return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
        }
      }
    } catch (_) {
      // Ignore decoding failures; caller decides fallback behavior.
    }
    return null;
  }

  static bool isAccessTokenValid(
    String token, {
    Duration clockSkew = const Duration(seconds: 30),
    DateTime? nowUtc,
  }) {
    final expiry = extractJwtExpiryUtc(token);
    if (expiry == null) return true;
    final now = (nowUtc ?? DateTime.now()).toUtc();
    return expiry.isAfter(now.add(clockSkew));
  }

  static bool hasLocalAccountSync({
    required SharedPreferences prefs,
  }) {
    final hasAccessToken = accessTokenKeys.any((key) => _hasNonEmptyPref(prefs, key));
    final hasRefreshToken = refreshTokenKeys.any((key) => _hasNonEmptyPref(prefs, key));
    final hasAuthOnboarding =
        prefs.getBool(PreferenceKeys.hasCompletedAuthOnboarding) ?? false;
    final hasAccountRecord = (prefs.getString('user_id') ?? '').trim().isNotEmpty;
    return hasAccessToken || hasRefreshToken || (hasAuthOnboarding && hasAccountRecord);
  }

  static Future<bool> hasLocalAccount({SharedPreferences? prefs}) async {
    final resolved = prefs ?? await SharedPreferences.getInstance();
    return hasLocalAccountSync(prefs: resolved);
  }

  static Future<bool> shouldPromptReauth({SharedPreferences? prefs}) async {
    if (!AppConfig.isFeatureEnabled('rePromptLoginOnExpiry')) return false;
    return hasLocalAccount(prefs: prefs);
  }

  static StoredSessionStatus evaluateStoredSession({
    required SharedPreferences prefs,
    DateTime? nowUtc,
  }) {
    final accessToken = readStoredAccessToken(prefs);
    if (accessToken != null && accessToken.trim().isNotEmpty) {
      if (isAccessTokenValid(accessToken, nowUtc: nowUtc)) {
        return StoredSessionStatus.valid;
      }
    }

    final refreshToken = readStoredRefreshToken(prefs);
    if (refreshToken != null && refreshToken.trim().isNotEmpty) {
      return StoredSessionStatus.refreshRequired;
    }

    return StoredSessionStatus.invalid;
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

