import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration provider that manages app-wide settings
/// Loads settings from SharedPreferences and provides reactive updates
class ConfigProvider extends ChangeNotifier {
  static const String _serverVersionKey = 'serverVersion';
  static const String _serverVersionFetchedAtKey = 'serverVersionFetchedAtMs';

  // Default values (fallback if no preferences exist)
  bool _useRealBlockchain = true;
  bool _enableAnalytics = true;
  bool _enableCrashReporting = true;
  String? _serverVersion;
  DateTime? _serverVersionFetchedAt;

  // Getters
  bool get useRealBlockchain => _useRealBlockchain;
  bool get enableAnalytics => _enableAnalytics;
  bool get enableCrashReporting => _enableCrashReporting;
  String? get serverVersion => _serverVersion;
  DateTime? get serverVersionFetchedAt => _serverVersionFetchedAt;

  /// Initialize the provider by loading settings from SharedPreferences
  Future<void> initialize() async {
    await _loadSettings();
  }

  /// Load all settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _useRealBlockchain = prefs.getBool('useRealBlockchain') ?? true;
      final legacyAnalytics = prefs.getBool('analytics');
      final legacyCrashReporting = prefs.getBool('crashReporting');
      _enableAnalytics =
          prefs.getBool('enableAnalytics') ?? legacyAnalytics ?? true;
      _enableCrashReporting =
          prefs.getBool('enableCrashReporting') ?? legacyCrashReporting ?? true;
      // Migrate the only legacy aliases while keeping the canonical keys that
      // ConfigProvider owns. New writes never go through SettingsService.
      if (!prefs.containsKey('enableAnalytics') && legacyAnalytics != null) {
        await prefs.setBool('enableAnalytics', legacyAnalytics);
      }
      if (!prefs.containsKey('enableCrashReporting') &&
          legacyCrashReporting != null) {
        await prefs.setBool('enableCrashReporting', legacyCrashReporting);
      }
      final rawServerVersion =
          (prefs.getString(_serverVersionKey) ?? '').trim();
      _serverVersion = rawServerVersion.isEmpty ? null : rawServerVersion;
      final fetchedAtMs = prefs.getInt(_serverVersionFetchedAtKey);
      _serverVersionFetchedAt = fetchedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fetchedAtMs);

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading config settings: $e');
      }
      // Keep default values if loading fails
    }
  }

  /// Update blockchain setting
  Future<void> setUseRealBlockchain(bool value) async {
    if (_useRealBlockchain != value) {
      _useRealBlockchain = value;
      await _saveSetting('useRealBlockchain', value);
      notifyListeners();
    }
  }

  /// Update analytics setting
  Future<void> setEnableAnalytics(bool value) async {
    if (_enableAnalytics != value) {
      _enableAnalytics = value;
      notifyListeners();
      await _saveSetting('enableAnalytics', value);
    }
  }

  /// Update crash reporting setting
  Future<void> setEnableCrashReporting(bool value) async {
    if (_enableCrashReporting != value) {
      _enableCrashReporting = value;
      notifyListeners();
      await _saveSetting('enableCrashReporting', value);
    }
  }

  /// Save a single setting to SharedPreferences
  Future<void> _saveSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving config setting $key: $e');
      }
    }
  }

  Future<void> setServerVersion(String? value) async {
    final normalized = (value ?? '').trim();
    final nextValue = normalized.isEmpty ? null : normalized;
    final changed = _serverVersion != nextValue;

    _serverVersion = nextValue;
    _serverVersionFetchedAt = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_serverVersion == null) {
        await prefs.remove(_serverVersionKey);
      } else {
        await prefs.setString(_serverVersionKey, _serverVersion!);
      }
      await prefs.setInt(
        _serverVersionFetchedAtKey,
        _serverVersionFetchedAt!.millisecondsSinceEpoch,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving server version: $e');
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('useRealBlockchain');
      await prefs.remove('enableAnalytics');
      await prefs.remove('enableCrashReporting');
      await prefs.remove(_serverVersionKey);
      await prefs.remove(_serverVersionFetchedAtKey);

      _useRealBlockchain = true;
      _enableAnalytics = true;
      _enableCrashReporting = true;
      _serverVersion = null;
      _serverVersionFetchedAt = null;

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error resetting config settings: $e');
      }
    }
  }
}
