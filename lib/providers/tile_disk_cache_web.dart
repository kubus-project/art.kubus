import 'dart:convert';
import 'dart:typed_data';

import 'dart:html' as html;

import 'tile_disk_cache.dart';

/// Lightweight browser cache using localStorage for persistence across reloads.
/// Keeps an optional LRU index with guardrails to avoid blowing past browser quota.
class TileDiskCacheImpl implements TileDiskCache {
  // Keep the footprint small on web; tiles are often 20–60kb each.
  static const int _defaultMaxEntries = 400;
  static const int _maxEntryBytes = 200 * 1024; // Skip anything larger than ~200kb
  static const String _indexKey = '__tile_cache_keys__';
  final int maxEntries;

  TileDiskCacheImpl._(this.maxEntries);

  static Future<TileDiskCache?> create({int maxEntries = _defaultMaxEntries}) async {
    // Cap the requested entries to keep localStorage reasonable.
    final effective = maxEntries <= 0 ? _defaultMaxEntries : maxEntries.clamp(50, 5000);
    return TileDiskCacheImpl._(effective);
  }

  String _keyFor(String url) => 'tile_${_hash(url)}';

  // Simple string hash to avoid very long storage keys
  String _hash(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = 0x1fffffff & (hash + input.codeUnitAt(i));
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= (hash >> 6);
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= (hash >> 11);
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash.toRadixString(16);
  }

  List<String> _readIndex() {
    try {
      final raw = html.window.localStorage[_indexKey];
      if (raw == null || raw.isEmpty) return <String>[];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.cast<String>();
      }
    } catch (_) {}
    return <String>[];
  }

  void _writeIndex(List<String> keys) {
    try {
      html.window.localStorage[_indexKey] = jsonEncode(keys);
    } catch (_) {}
  }

  void _evictOldest(int count) {
    if (count <= 0) return;
    final keys = _readIndex();
    if (keys.isEmpty) return;
    for (var i = 0; i < count && keys.isNotEmpty; i++) {
      final removeKey = keys.removeAt(0);
      html.window.localStorage.remove(removeKey);
    }
    _writeIndex(keys);
  }

  @override
  Future<Uint8List?> read(String key) async {
    final storageKey = _keyFor(key);
    try {
      final encoded = html.window.localStorage[storageKey];
      if (encoded == null) return null;
      final bytes = base64Decode(encoded);
      // Move key to end for LRU behavior when eviction is enabled
      final keys = _readIndex();
      keys.remove(storageKey);
      keys.add(storageKey);
      _writeIndex(keys);
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    final storageKey = _keyFor(key);
    if (bytes.lengthInBytes > _maxEntryBytes) {
      // Don't attempt to store very large tiles; they will overflow quota quickly.
      return;
    }
    try {
      final encoded = base64Encode(bytes);
      html.window.localStorage[storageKey] = encoded;
      final keys = _readIndex();
      keys.remove(storageKey);
      keys.add(storageKey);
      if (maxEntries > 0) {
        while (keys.length > maxEntries) {
          final removeKey = keys.removeAt(0);
          html.window.localStorage.remove(removeKey);
        }
      }
      _writeIndex(keys);
    } catch (_) {
      // Best-effort: evict a few old entries and retry once
      _evictOldest(5);
      try {
        final encoded = base64Encode(bytes);
        html.window.localStorage[storageKey] = encoded;
        final keys = _readIndex();
        keys.remove(storageKey);
        keys.add(storageKey);
        if (maxEntries > 0) {
          while (keys.length > maxEntries) {
            final removeKey = keys.removeAt(0);
            html.window.localStorage.remove(removeKey);
          }
        }
        _writeIndex(keys);
      } catch (_) {
        // Ignore quota or serialization errors
      }
    }
  }
}
