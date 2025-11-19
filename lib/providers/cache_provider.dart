import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized cache for lightweight profile data (avatars, display names, etc.).
/// Backed by [SharedPreferences] so multiple screens can reuse previously
/// resolved identities without refetching from the backend.
class CacheProvider extends ChangeNotifier {
  static const _avatarKey = 'cache_provider_avatars_v1';
  static const _displayNameKey = 'cache_provider_display_names_v1';
  static const _maxEntries = 600;

  final Map<String, String> _avatarCache = <String, String>{};
  final Map<String, String> _displayNameCache = <String, String>{};

  SharedPreferences? _prefs;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  Map<String, String> get avatarSnapshot => Map.unmodifiable(_avatarCache);
  Map<String, String> get displayNameSnapshot => Map.unmodifiable(_displayNameCache);

  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _avatarCache
      ..clear()
      ..addAll(_decodeMap(_prefs?.getString(_avatarKey)));
    _displayNameCache
      ..clear()
      ..addAll(_decodeMap(_prefs?.getString(_displayNameKey)));
    _initialized = true;
  }

  Future<void> setAvatar(String wallet, String? url) async {
    if (wallet.trim().isEmpty) return;
    await _ensureReady();
    final key = _normalizeWallet(wallet);
    if (url == null || url.trim().isEmpty) {
      if (_avatarCache.remove(key) != null) {
        await _persist(_avatarKey, _avatarCache);
        notifyListeners();
      }
      return;
    }
    final candidate = url.trim();
    if (_avatarCache[key] == candidate) return;
    _avatarCache[key] = candidate;
    _prune(_avatarCache);
    await _persist(_avatarKey, _avatarCache);
    notifyListeners();
  }

  Future<void> setDisplayName(String wallet, String? displayName) async {
    if (wallet.trim().isEmpty || displayName == null || displayName.trim().isEmpty) return;
    await _ensureReady();
    final key = _normalizeWallet(wallet);
    final candidate = displayName.trim();
    if (_displayNameCache[key] == candidate) return;
    _displayNameCache[key] = candidate;
    _prune(_displayNameCache);
    await _persist(_displayNameKey, _displayNameCache);
    notifyListeners();
  }

  String? getAvatar(String wallet) {
    if (!_initialized) return null;
    return _avatarCache[_normalizeWallet(wallet)];
  }

  String? getDisplayName(String wallet) {
    if (!_initialized) return null;
    return _displayNameCache[_normalizeWallet(wallet)];
  }

  Future<void> mergeProfiles({Map<String, String?>? avatars, Map<String, String?>? displayNames}) async {
    if ((avatars == null || avatars.isEmpty) && (displayNames == null || displayNames.isEmpty)) return;
    await _ensureReady();
    bool changed = false;
    if (avatars != null && avatars.isNotEmpty) {
      for (final entry in avatars.entries) {
        final wallet = entry.key.trim();
        final value = entry.value?.trim();
        if (wallet.isEmpty || value == null || value.isEmpty) continue;
        final key = _normalizeWallet(wallet);
        if (_avatarCache[key] == value) continue;
        _avatarCache[key] = value;
        changed = true;
      }
      _prune(_avatarCache);
      if (changed) await _persist(_avatarKey, _avatarCache);
    }

    bool displayChanged = false;
    if (displayNames != null && displayNames.isNotEmpty) {
      for (final entry in displayNames.entries) {
        final wallet = entry.key.trim();
        final value = entry.value?.trim();
        if (wallet.isEmpty || value == null || value.isEmpty) continue;
        final key = _normalizeWallet(wallet);
        if (_displayNameCache[key] == value) continue;
        _displayNameCache[key] = value;
        displayChanged = true;
      }
      _prune(_displayNameCache);
      if (displayChanged) await _persist(_displayNameKey, _displayNameCache);
      changed = changed || displayChanged;
    }

    if (changed || displayChanged) notifyListeners();
  }

  Map<String, String> _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value?.toString() ?? ''))
        ..removeWhere((_, value) => value.isEmpty);
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _persist(String key, Map<String, String> map) async {
    if (_prefs == null) return;
    await _prefs!.setString(key, jsonEncode(map));
  }

  Future<void> _ensureReady() async {
    if (_initialized) return;
    await initialize();
  }

  String _normalizeWallet(String wallet) => wallet.trim().toLowerCase();

  void _prune(Map<String, String> map) {
    if (map.length <= _maxEntries) return;
    final overflow = map.length - _maxEntries;
    final keys = map.keys.take(overflow).toList();
    for (final key in keys) {
      map.remove(key);
    }
  }
}
