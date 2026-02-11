import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../map_view_mode_prefs.dart';

@immutable
class MapViewPreferences {
  const MapViewPreferences({
    this.travelModeEnabled = false,
    this.isometricViewEnabled = false,
  });

  final bool travelModeEnabled;
  final bool isometricViewEnabled;

  MapViewPreferences copyWith({
    bool? travelModeEnabled,
    bool? isometricViewEnabled,
  }) {
    return MapViewPreferences(
      travelModeEnabled: travelModeEnabled ?? this.travelModeEnabled,
      isometricViewEnabled: isometricViewEnabled ?? this.isometricViewEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MapViewPreferences &&
        other.travelModeEnabled == travelModeEnabled &&
        other.isometricViewEnabled == isometricViewEnabled;
  }

  @override
  int get hashCode => Object.hash(travelModeEnabled, isometricViewEnabled);
}

/// Persists + exposes map view mode preferences shared by mobile and desktop.
///
/// Uses existing `MapViewModePrefs` helpers to preserve key and feature-flag
/// semantics.
class MapViewPreferencesController extends ChangeNotifier {
  MapViewPreferencesController({
    Future<SharedPreferences> Function()? sharedPreferencesLoader,
  }) : _sharedPreferencesLoader =
            sharedPreferencesLoader ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _sharedPreferencesLoader;

  MapViewPreferences _value = const MapViewPreferences();
  bool _hasLoaded = false;

  MapViewPreferences get value => _value;
  bool get hasLoaded => _hasLoaded;

  Future<MapViewPreferences> load() async {
    try {
      final prefs = await _sharedPreferencesLoader();
      final travelEnabled = await MapViewModePrefs.loadTravelModeEnabled(prefs);
      final isometricEnabled =
          await MapViewModePrefs.loadIsometricViewEnabled(prefs);
      final next = MapViewPreferences(
        travelModeEnabled: travelEnabled,
        isometricViewEnabled: isometricEnabled,
      );
      _hasLoaded = true;
      _setValue(next);
    } catch (_) {
      // Best-effort; keep defaults.
      _hasLoaded = true;
    }
    return _value;
  }

  Future<void> setTravelMode(bool enabled) async {
    _setValue(_value.copyWith(travelModeEnabled: enabled));
    try {
      final prefs = await _sharedPreferencesLoader();
      await MapViewModePrefs.persistTravelModeEnabled(prefs, enabled);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  Future<void> setTravelModeEnabled(bool enabled) async {
    await setTravelMode(enabled);
  }

  Future<void> setIsometric(bool enabled) async {
    _setValue(_value.copyWith(isometricViewEnabled: enabled));
    try {
      final prefs = await _sharedPreferencesLoader();
      await MapViewModePrefs.persistIsometricViewEnabled(prefs, enabled);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  Future<void> setIsometricEnabled(bool enabled) async {
    await setIsometric(enabled);
  }

  void _setValue(MapViewPreferences next) {
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }
}
