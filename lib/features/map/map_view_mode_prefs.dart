import 'package:shared_preferences/shared_preferences.dart';

import '../../config/config.dart';

/// Shared persistence helpers for map view modes.
///
/// These preferences must remain stable across platforms so desktop/mobile
/// behave consistently and don't drift.
class MapViewModePrefs {
  const MapViewModePrefs._();

  static Future<bool> loadIsometricViewEnabled(SharedPreferences prefs) async {
    if (!AppConfig.isFeatureEnabled('mapIsometricView')) return false;
    return prefs.getBool(PreferenceKeys.mapIsometricViewEnabledV1) ?? false;
  }

  static Future<void> persistIsometricViewEnabled(
    SharedPreferences prefs,
    bool enabled,
  ) async {
    await prefs.setBool(PreferenceKeys.mapIsometricViewEnabledV1, enabled);
  }
}
