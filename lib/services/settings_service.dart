import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import '../providers/notification_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/wallet_provider.dart';
import 'backend_api_service.dart';
import 'onboarding_state_service.dart';
import 'push_notification_service.dart';

/// Centralized storage and side-effect helpers for settings.
class SettingsService {
  static const Set<String> _criticalWalletKeys = {
    'has_wallet',
    'wallet_address',
    'wallet',
    'walletAddress',
    'private_key',
    'mnemonic',
    'cached_mnemonic',
    'cached_mnemonic_ts',
  };

  /// Load settings from SharedPreferences with safe defaults.
  static Future<SettingsState> loadSettings({String? fallbackNetwork}) async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsState.fromPrefs(prefs, fallbackNetwork: fallbackNetwork);
  }

  /// Persist the provided settings snapshot.
  static Future<void> saveSettings(SettingsState state) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('pushNotifications', state.pushNotifications);
    await prefs.setBool('emailNotifications', state.emailNotifications);
    await prefs.setBool('marketingEmails', state.marketingEmails);
    await prefs.setBool('loginNotifications', state.loginNotifications);

    await prefs.setBool('dataCollection', state.dataCollection);
    await prefs.setBool('personalizedAds', state.personalizedAds);
    await prefs.setBool('locationTracking', state.locationTracking);
    await prefs.setString('dataRetention', state.dataRetention);

    await prefs.setBool('twoFactorAuth', state.twoFactorAuth);
    await prefs.setBool('sessionTimeout', state.sessionTimeout);
    await prefs.setString('autoLockTime', state.autoLockTime);
    await prefs.setInt('autoLockSeconds', state.autoLockSeconds);
    await prefs.setBool('loginNotifications', state.loginNotifications);
    await prefs.setBool('requirePin', state.requirePin);
    await prefs.setBool('biometricAuth', state.biometricAuth);
    await prefs.setBool('biometricsDeclined', state.biometricsDeclined);
    await prefs.setBool('useBiometricsOnUnlock', state.useBiometricsOnUnlock);
    await prefs.setBool('privacyMode', state.privacyMode);

    await prefs.setBool('enableAnalytics', state.analytics);
    await prefs.setBool('enableCrashReporting', state.crashReporting);
    await prefs.setBool('skipOnboardingForReturningUsers', state.skipOnboarding);

    await prefs.setString('networkSelection', state.networkSelection);
    await prefs.setBool('autoBackup', state.autoBackup);

    await prefs.setString('profileVisibility', state.profileVisibility);
    await prefs.setBool('showAchievements', state.showAchievements);
    await prefs.setBool('showFriends', state.showFriends);
    await prefs.setBool('allowMessages', state.allowMessages);

    await prefs.setString('accountType', state.accountType);
    await prefs.setBool('publicProfile', state.publicProfile);

    // Legacy/compatibility keys (desktop used underscores previously)
    await prefs.setBool('email_notifications', state.emailNotifications);
    await prefs.setBool('push_notifications', state.pushNotifications);
    await prefs.setBool('marketing_emails', state.marketingEmails);
  }

  static Future<void> saveProfileVisibility(String visibility) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileVisibility', visibility);
    await prefs.setString('profile_visibility', visibility); // legacy key
  }

  /// Clear non-critical caches while preserving wallet credentials.
  static Future<void> clearNonCriticalCaches({Set<String> preserveKeys = const {}}) async {
    final prefs = await SharedPreferences.getInstance();
    final keep = {..._criticalWalletKeys, ...preserveKeys};
    for (final key in prefs.getKeys()) {
      if (!keep.contains(key)) {
        await prefs.remove(key);
      }
    }
  }

  /// Reset stored permission/service flags (location, camera, notifications, etc.).
  static Future<void> resetPermissionFlags() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      final normalized = key.toLowerCase();
      if (_criticalWalletKeys.contains(key)) continue;
      if (normalized.contains('permission') ||
          normalized.contains('service') ||
          normalized.contains('location') ||
          normalized.contains('camera') ||
          normalized.contains('_requested') ||
          normalized.contains('gps')) {
        await prefs.remove(key);
      }
    }
  }

  /// Clear all local session/auth data and disconnect wallet.
  static Future<void> logout({
    required WalletProvider walletProvider,
    required BackendApiService backendApi,
    NotificationProvider? notificationProvider,
    ProfileProvider? profileProvider,
  }) async {
    await backendApi.clearAuth();
    notificationProvider?.reset();
    profileProvider?.signOut();
    try {
      await PushNotificationService().cancelAllNotifications();
    } catch (_) {}

    walletProvider.disconnectWallet();

    final prefs = await SharedPreferences.getInstance();
    const removeKeys = {
      'jwt_token',
      'token',
      'auth_token',
      'authToken',
      'wallet_address',
      'wallet',
      'walletAddress',
      'has_wallet',
      'user_id',
      PreferenceKeys.hasCompletedAuthOnboarding,
      'completed_onboarding',
      'notification_permission_granted',
      'last_inactive_ts',
      'lock_timeout_seconds',
    };
    for (final key in removeKeys) {
      await prefs.remove(key);
    }

    // Reset onboarding flags so the app restarts into onboarding
    await OnboardingStateService.reset(prefs: prefs);
    await prefs.remove('skipOnboardingForReturningUsers');
  }

  /// Clear as much local state as possible while preserving secure wallet storage.
  static Future<void> resetApp({
    required WalletProvider walletProvider,
    required BackendApiService backendApi,
    NotificationProvider? notificationProvider,
    ProfileProvider? profileProvider,
  }) async {
    await logout(
      walletProvider: walletProvider,
      backendApi: backendApi,
      notificationProvider: notificationProvider,
      profileProvider: profileProvider,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await OnboardingStateService.reset(prefs: prefs);
  }
}

class SettingsState {
  final bool pushNotifications;
  final bool emailNotifications;
  final bool marketingEmails;
  final bool loginNotifications;

  final bool dataCollection;
  final bool personalizedAds;
  final bool locationTracking;
  final String dataRetention;

  final bool twoFactorAuth;
  final bool sessionTimeout;
  final String autoLockTime;
  final int autoLockSeconds;
  final bool requirePin;
  final bool biometricAuth;
  final bool biometricsDeclined;
  final bool useBiometricsOnUnlock;
  final bool privacyMode;

  final bool analytics;
  final bool crashReporting;
  final bool skipOnboarding;

  final String networkSelection;
  final bool autoBackup;

  final String profileVisibility;
  final bool showAchievements;
  final bool showFriends;
  final bool allowMessages;

  final String accountType;
  final bool publicProfile;

  const SettingsState({
    required this.pushNotifications,
    required this.emailNotifications,
    required this.marketingEmails,
    required this.loginNotifications,
    required this.dataCollection,
    required this.personalizedAds,
    required this.locationTracking,
    required this.dataRetention,
    required this.twoFactorAuth,
    required this.sessionTimeout,
    required this.autoLockTime,
    required this.autoLockSeconds,
    required this.requirePin,
    required this.biometricAuth,
    required this.biometricsDeclined,
    required this.useBiometricsOnUnlock,
    required this.privacyMode,
    required this.analytics,
    required this.crashReporting,
    required this.skipOnboarding,
    required this.networkSelection,
    required this.autoBackup,
    required this.profileVisibility,
    required this.showAchievements,
    required this.showFriends,
    required this.allowMessages,
    required this.accountType,
    required this.publicProfile,
  });

  factory SettingsState.defaults({String? fallbackNetwork}) {
    return SettingsState(
      pushNotifications: true,
      emailNotifications: true,
      marketingEmails: false,
      loginNotifications: true,
      dataCollection: true,
      personalizedAds: true,
      locationTracking: true,
      dataRetention: '1 Year',
      twoFactorAuth: false,
      sessionTimeout: true,
      autoLockTime: '5 minutes',
      autoLockSeconds: _autoLockSecondsForLabel('5 minutes'),
      requirePin: false,
      biometricAuth: false,
      biometricsDeclined: false,
      useBiometricsOnUnlock: true,
      privacyMode: false,
      analytics: true,
      crashReporting: true,
      skipOnboarding: AppConfig.skipOnboardingForReturningUsers,
      networkSelection: fallbackNetwork ?? 'Mainnet',
      autoBackup: true,
      profileVisibility: 'Public',
      showAchievements: true,
      showFriends: true,
      allowMessages: true,
      accountType: 'Standard',
      publicProfile: true,
    );
  }

  factory SettingsState.fromPrefs(SharedPreferences prefs, {String? fallbackNetwork}) {
    final defaults = SettingsState.defaults(fallbackNetwork: fallbackNetwork);

    final storedAutoLockLabel = prefs.getString('autoLockTime') ?? defaults.autoLockTime;
    final storedAutoLockSeconds =
        prefs.getInt('autoLockSeconds') ?? _autoLockSecondsForLabel(storedAutoLockLabel);

    return SettingsState(
      pushNotifications: prefs.getBool('pushNotifications') ??
          prefs.getBool('push_notifications') ??
          defaults.pushNotifications,
      emailNotifications: prefs.getBool('emailNotifications') ??
          prefs.getBool('email_notifications') ??
          defaults.emailNotifications,
      marketingEmails: prefs.getBool('marketingEmails') ??
          prefs.getBool('marketing_emails') ??
          defaults.marketingEmails,
      loginNotifications: prefs.getBool('loginNotifications') ?? defaults.loginNotifications,
      dataCollection: prefs.getBool('dataCollection') ?? defaults.dataCollection,
      personalizedAds: prefs.getBool('personalizedAds') ?? defaults.personalizedAds,
      locationTracking: prefs.getBool('locationTracking') ?? defaults.locationTracking,
      dataRetention: prefs.getString('dataRetention') ?? defaults.dataRetention,
      twoFactorAuth: prefs.getBool('twoFactorAuth') ?? defaults.twoFactorAuth,
      sessionTimeout: prefs.getBool('sessionTimeout') ?? defaults.sessionTimeout,
      autoLockTime: storedAutoLockLabel,
      autoLockSeconds: storedAutoLockSeconds,
      requirePin: prefs.getBool('requirePin') ?? defaults.requirePin,
      biometricAuth: prefs.getBool('biometricAuth') ?? defaults.biometricAuth,
      biometricsDeclined: prefs.getBool('biometricsDeclined') ?? defaults.biometricsDeclined,
      useBiometricsOnUnlock: prefs.getBool('useBiometricsOnUnlock') ?? defaults.useBiometricsOnUnlock,
      privacyMode: prefs.getBool('privacyMode') ?? defaults.privacyMode,
      analytics: prefs.getBool('enableAnalytics') ??
          prefs.getBool('analytics') ??
          defaults.analytics,
      crashReporting: prefs.getBool('enableCrashReporting') ??
          prefs.getBool('crashReporting') ??
          defaults.crashReporting,
      skipOnboarding: prefs.getBool('skipOnboardingForReturningUsers') ?? defaults.skipOnboarding,
      networkSelection: prefs.getString('networkSelection') ??
          prefs.getString('selected_network') ??
          defaults.networkSelection,
      autoBackup: prefs.getBool('autoBackup') ?? defaults.autoBackup,
      profileVisibility: prefs.getString('profileVisibility') ??
          prefs.getString('profile_visibility') ??
          defaults.profileVisibility,
      showAchievements: prefs.getBool('showAchievements') ?? defaults.showAchievements,
      showFriends: prefs.getBool('showFriends') ?? defaults.showFriends,
      allowMessages: prefs.getBool('allowMessages') ?? defaults.allowMessages,
      accountType: prefs.getString('accountType') ?? defaults.accountType,
      publicProfile: prefs.getBool('publicProfile') ?? defaults.publicProfile,
    );
  }

  SettingsState copyWith({
    bool? pushNotifications,
    bool? emailNotifications,
    bool? marketingEmails,
    bool? loginNotifications,
    bool? dataCollection,
    bool? personalizedAds,
    bool? locationTracking,
    String? dataRetention,
    bool? twoFactorAuth,
    bool? sessionTimeout,
    String? autoLockTime,
    int? autoLockSeconds,
    bool? requirePin,
    bool? biometricAuth,
    bool? biometricsDeclined,
    bool? useBiometricsOnUnlock,
    bool? privacyMode,
    bool? analytics,
    bool? crashReporting,
    bool? skipOnboarding,
    String? networkSelection,
    bool? autoBackup,
    String? profileVisibility,
    bool? showAchievements,
    bool? showFriends,
    bool? allowMessages,
    String? accountType,
    bool? publicProfile,
  }) {
    return SettingsState(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      marketingEmails: marketingEmails ?? this.marketingEmails,
      loginNotifications: loginNotifications ?? this.loginNotifications,
      dataCollection: dataCollection ?? this.dataCollection,
      personalizedAds: personalizedAds ?? this.personalizedAds,
      locationTracking: locationTracking ?? this.locationTracking,
      dataRetention: dataRetention ?? this.dataRetention,
      twoFactorAuth: twoFactorAuth ?? this.twoFactorAuth,
      sessionTimeout: sessionTimeout ?? this.sessionTimeout,
      autoLockTime: autoLockTime ?? this.autoLockTime,
      autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
      requirePin: requirePin ?? this.requirePin,
      biometricAuth: biometricAuth ?? this.biometricAuth,
      biometricsDeclined: biometricsDeclined ?? this.biometricsDeclined,
      useBiometricsOnUnlock: useBiometricsOnUnlock ?? this.useBiometricsOnUnlock,
      privacyMode: privacyMode ?? this.privacyMode,
      analytics: analytics ?? this.analytics,
      crashReporting: crashReporting ?? this.crashReporting,
      skipOnboarding: skipOnboarding ?? this.skipOnboarding,
      networkSelection: networkSelection ?? this.networkSelection,
      autoBackup: autoBackup ?? this.autoBackup,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      showAchievements: showAchievements ?? this.showAchievements,
      showFriends: showFriends ?? this.showFriends,
      allowMessages: allowMessages ?? this.allowMessages,
      accountType: accountType ?? this.accountType,
      publicProfile: publicProfile ?? this.publicProfile,
    );
  }
}

int _autoLockSecondsForLabel(String label) {
  switch (label.toLowerCase()) {
    case 'immediately':
      return -1;
    case '10 seconds':
      return 10;
    case '30 seconds':
      return 30;
    case '1 minute':
      return 60;
    case '5 minutes':
      return 5 * 60;
    case '15 minutes':
      return 15 * 60;
    case '30 minutes':
      return 30 * 60;
    case '1 hour':
      return 60 * 60;
    case '3 hours':
      return 3 * 60 * 60;
    case '6 hours':
      return 6 * 60 * 60;
    case '12 hours':
      return 12 * 60 * 60;
    case '1 day':
      return 24 * 60 * 60;
    case 'never':
      return 0;
    default:
      return 5 * 60;
  }
}
