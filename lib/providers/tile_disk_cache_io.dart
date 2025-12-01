import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tile_disk_cache.dart';

class TileDiskCacheImpl implements TileDiskCache {
  static const int _defaultMaxEntries = 0; // unlimited; rely on OS cleanup
  final Directory directory;
  final int maxEntries;

  TileDiskCacheImpl._(this.directory, this.maxEntries);

  static Future<TileDiskCache?> create({int maxEntries = _defaultMaxEntries}) async {
    if (kIsWeb) return null;
    try {
      final Directory baseDir = await getTemporaryDirectory();
      final Directory dir = Directory(p.join(baseDir.path, 'tile_cache'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return TileDiskCacheImpl._(dir, maxEntries);
    } catch (_) {
      return null;
    }
  }

  String _pathFor(String key) {
    final String hash = sha1.convert(utf8.encode(key)).toString();
    return p.join(directory.path, '$hash.bin');
  }

  @override
  Future<Uint8List?> read(String key) async {
    final file = File(_pathFor(key));
    try {
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        await file.setLastModified(DateTime.now());
        return bytes;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    final file = File(_pathFor(key));
    try {
      await file.writeAsBytes(bytes, flush: false);
      await _trimIfNeeded();
    } catch (_) {}
  }

  Future<void> _trimIfNeeded() async {
    if (maxEntries <= 0) return;
    try {
      final entries = await directory
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      if (entries.length <= maxEntries) return;

      entries.sort((a, b) => (a.statSync().modified).compareTo(b.statSync().modified));

      final int removeCount = entries.length - maxEntries;
      for (int i = 0; i < removeCount; i++) {
        await entries[i].delete();
      }
    } catch (_) {}
  }
}
