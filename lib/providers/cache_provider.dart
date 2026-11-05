import 'package:flutter/foundation.dart';
import '../services/account_cache_store.dart';
import '../services/account_identity.dart';
import '../services/user_service.dart';
import '../utils/wallet_utils.dart';

/// Centralized cache for lightweight profile data (avatars, display names, etc.).
/// Backed by account-scoped device preferences so multiple screens can reuse previously
/// resolved identities without refetching from the backend.
class CacheProvider extends ChangeNotifier {
  static const _avatarKey = 'cache_provider_avatars_v1';
  static const _displayNameKey = 'cache_provider_display_names_v1';
  static const _maxEntries = 600;

  final Map<String, String> _avatarCache = <String, String>{};
  final Map<String, String> _displayNameCache = <String, String>{};

  String _owner = AccountCacheStore.owner;
  int _generation = AccountCacheStore.generation;
  DateTime? _loadedAt;

  CacheProvider() {
    AccountIdentity.addListener(_handleIdentityChanged);
  }

  void _handleIdentityChanged() {
    _invalidate();
    notifyListeners();
  }

  void _invalidate() {
    _avatarCache.clear();
    _displayNameCache.clear();
    _initialized = false;
    _loadedAt = null;
    _owner = AccountCacheStore.owner;
    _generation = AccountCacheStore.generation;
  }

  void _syncScope() {
    if (_owner != AccountCacheStore.owner ||
        _generation != AccountCacheStore.generation ||
        (_loadedAt != null &&
            DateTime.now().difference(_loadedAt!) >=
                const Duration(hours: 24))) {
      _invalidate();
    }
  }

  @override
  void dispose() {
    AccountIdentity.removeListener(_handleIdentityChanged);
    super.dispose();
  }

  bool _initialized = false;
  bool get isInitialized {
    _syncScope();
    return _initialized;
  }

  Map<String, String> get avatarSnapshot {
    _syncScope();
    return Map.unmodifiable(_avatarCache);
  }

  Map<String, String> get displayNameSnapshot {
    _syncScope();
    return Map.unmodifiable(_displayNameCache);
  }

  Future<void> initialize() async {
    _syncScope();
    if (_initialized) return;
    final owner = _owner;
    final generation = _generation;
    final avatars = await AccountCacheStore.read(_avatarKey);
    final names = await AccountCacheStore.read(_displayNameKey);
    if (owner != AccountCacheStore.owner ||
        generation != AccountCacheStore.generation) {
      return;
    }
    _avatarCache
      ..clear()
      ..addAll(_decodeMap(avatars));
    _displayNameCache
      ..clear()
      ..addAll(_decodeMap(names));
    _loadedAt = DateTime.now();
    if (_purgeInvalidAvatarEntries()) {
      await _persist(_avatarKey, _avatarCache);
    }
    _initialized = true;
  }

  Future<void> setAvatar(String wallet, String? url) async {
    if (wallet.trim().isEmpty) return;
    final owner = AccountCacheStore.owner;
    final generation = AccountCacheStore.generation;
    await _ensureReady();
    if (owner != AccountCacheStore.owner ||
        generation != AccountCacheStore.generation) {
      return;
    }
    final key = _normalizeWallet(wallet);
    final sanitized = _sanitizeAvatar(url);
    if (sanitized == null) {
      if (_avatarCache.remove(key) != null) {
        await _persist(_avatarKey, _avatarCache);
        notifyListeners();
      }
      return;
    }
    if (_avatarCache[key] == sanitized) return;
    _avatarCache[key] = sanitized;
    _prune(_avatarCache);
    await _persist(_avatarKey, _avatarCache);
    notifyListeners();
  }

  Future<void> setDisplayName(String wallet, String? displayName) async {
    if (wallet.trim().isEmpty ||
        displayName == null ||
        displayName.trim().isEmpty) {
      return;
    }
    final owner = AccountCacheStore.owner;
    final generation = AccountCacheStore.generation;
    await _ensureReady();
    if (owner != AccountCacheStore.owner ||
        generation != AccountCacheStore.generation) {
      return;
    }
    final key = _normalizeWallet(wallet);
    final candidate = displayName.trim();
    if (_displayNameCache[key] == candidate) return;
    _displayNameCache[key] = candidate;
    _prune(_displayNameCache);
    await _persist(_displayNameKey, _displayNameCache);
    notifyListeners();
  }

  String? getAvatar(String wallet) {
    _syncScope();
    if (!_initialized) return null;
    return _avatarCache[_normalizeWallet(wallet)];
  }

  String? getDisplayName(String wallet) {
    _syncScope();
    if (!_initialized) return null;
    return _displayNameCache[_normalizeWallet(wallet)];
  }

  Future<void> mergeProfiles(
      {Map<String, String?>? avatars,
      Map<String, String?>? displayNames,
      AccountCacheScope? scope}) async {
    if ((avatars == null || avatars.isEmpty) &&
        (displayNames == null || displayNames.isEmpty)) {
      return;
    }
    final captured = scope ?? AccountCacheScope.capture();
    if (!captured.isCurrent) return;
    final owner = captured.account;
    final generation = captured.generation;
    await _ensureReady();
    if (owner != AccountCacheStore.owner ||
        generation != AccountCacheStore.generation) {
      return;
    }
    bool changed = false;
    if (avatars != null && avatars.isNotEmpty) {
      for (final entry in avatars.entries) {
        final wallet = entry.key.trim();
        final value = _sanitizeAvatar(entry.value);
        if (wallet.isEmpty || value == null || value.isEmpty) continue;
        final key = _normalizeWallet(wallet);
        if (_avatarCache[key] == value) continue;
        _avatarCache[key] = value;
        changed = true;
      }
      _prune(_avatarCache);
      if (changed) await _persist(_avatarKey, _avatarCache);
    }

    if (!captured.isCurrent) return;

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

  Map<String, String> _decodeMap(dynamic raw) {
    if (raw == null) {
      return <String, String>{};
    }
    try {
      final decoded = Map<String, dynamic>.from(raw as Map);
      return decoded.map((key, value) => MapEntry(key, value?.toString() ?? ''))
        ..removeWhere((_, value) => value.isEmpty);
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _persist(String key, Map<String, String> map) async {
    await AccountCacheStore.write(key, map,
        account: _owner, generation: _generation);
  }

  Future<void> _ensureReady() async {
    _syncScope();
    if (_initialized) return;
    await initialize();
  }

  String _normalizeWallet(String wallet) => WalletUtils.canonical(wallet);

  String? _sanitizeAvatar(String? url) {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (UserService.isPlaceholderAvatarUrl(trimmed)) return null;
    return trimmed;
  }

  void _prune(Map<String, String> map) {
    if (map.length <= _maxEntries) return;
    final overflow = map.length - _maxEntries;
    final keys = map.keys.take(overflow).toList();
    for (final key in keys) {
      map.remove(key);
    }
  }

  bool _purgeInvalidAvatarEntries() {
    if (_avatarCache.isEmpty) return false;
    final toRemove = <String>[];
    _avatarCache.forEach((key, value) {
      if (_sanitizeAvatar(value) == null) {
        toRemove.add(key);
      }
    });
    if (toRemove.isEmpty) return false;
    for (final key in toRemove) {
      _avatarCache.remove(key);
    }
    return true;
  }
}
