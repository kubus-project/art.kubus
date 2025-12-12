import 'dart:typed_data';

import 'tile_disk_cache_io.dart'
    if (dart.library.js_interop) 'tile_disk_cache_web.dart';

/// Platform-aware tile cache used by tile providers.
abstract class TileDiskCache {
  Future<Uint8List?> read(String key);
  Future<void> write(String key, Uint8List bytes);

  static Future<TileDiskCache?> create({int maxEntries = 4000}) {
    // The web impl clamps to a safer range; callers can still request smaller caches.
    return TileDiskCacheImpl.create(maxEntries: maxEntries);
  }
}
