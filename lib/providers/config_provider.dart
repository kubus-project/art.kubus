import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration provider that manages app-wide settings
/// Loads settings from SharedPreferences and provides reactive updates
class ConfigProvider extends ChangeNotifier {
  // Default values (fallback if no preferences exist)
  bool _useMockData = false;
  bool _useRealBlockchain = true;
  bool _enableAnalytics = true;
  bool _enableCrashReporting = true;

  // Getters
  bool get useMockData => _useMockData;
  bool get useRealBlockchain => _useRealBlockchain;
  bool get enableAnalytics => _enableAnalytics;
  bool get enableCrashReporting => _enableCrashReporting;

  /// Initialize the provider by loading settings from SharedPreferences
  Future<void> initialize() async {
    await _loadSettings();
  }

  /// Load all settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _useMockData = prefs.getBool('useMockData') ?? false;
      _useRealBlockchain = prefs.getBool('useRealBlockchain') ?? true;
      _enableAnalytics = prefs.getBool('enableAnalytics') ?? true;
      _enableCrashReporting = prefs.getBool('enableCrashReporting') ?? true;
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading config settings: $e');
      }
      // Keep default values if loading fails
    }
  }

  /// Update mock data setting
  Future<void> setUseMockData(bool value) async {
    if (_useMockData != value) {
      _useMockData = value;
      await _saveSetting('useMockData', value);
      notifyListeners();
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
      await _saveSetting('enableAnalytics', value);
      notifyListeners();
    }
  }

  /// Update crash reporting setting
  Future<void> setEnableCrashReporting(bool value) async {
    if (_enableCrashReporting != value) {
      _enableCrashReporting = value;
      await _saveSetting('enableCrashReporting', value);
      notifyListeners();
    }
  }

  /// Save a single setting to SharedPreferences
  Future<void> _saveSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving config setting $key: $e');
      }
    }
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('useMockData');
      await prefs.remove('useRealBlockchain');
      await prefs.remove('enableAnalytics');
      await prefs.remove('enableCrashReporting');
      
      _useMockData = false;
      _useRealBlockchain = true;
      _enableAnalytics = true;
      _enableCrashReporting = true;
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting config settings: $e');
      }
    }
  }
}
