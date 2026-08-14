import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-disk record of one accepted capture sample.
///
/// Holds paths and sizes only. The encoded bytes live on disk and are never
/// retained in Dart memory once written.
@immutable
class SpatialSampleRecord {
  const SpatialSampleRecord({
    required this.index,
    required this.rgbPath,
    required this.bytes,
    this.depthPath,
    this.confidencePath,
    this.metadata = const <String, dynamic>{},
  });

  final int index;
  final String rgbPath;
  final String? depthPath;
  final String? confidencePath;

  /// Total bytes this sample contributed to the capture.
  final int bytes;

  /// Pose, intrinsics and timestamps — small scalars only.
  final Map<String, dynamic> metadata;

  bool get hasDepth => depthPath != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...metadata,
        'rgbPath': rgbPath,
        if (depthPath != null) 'depthPath': depthPath,
        if (confidencePath != null) 'depthConfidencePath': confidencePath,
      };
}

/// A capture directory left behind by an interrupted session.
@immutable
class InterruptedSpatialCapture {
  const InterruptedSpatialCapture({
    required this.captureId,
    required this.directory,
    required this.startedAt,
    required this.sampleCount,
    required this.transferred,
  });

  final String captureId;
  final Directory directory;
  final DateTime startedAt;
  final int sampleCount;

  /// Whether the capture already reached the node. An untransferred capture is
  /// preserved for retry rather than discarded.
  final bool transferred;
}

/// Incremental, app-private, disk-backed storage for one spatial capture.
///
/// Replaces holding every encoded frame in a `List<Map<String, dynamic>>`:
/// capture payload is spooled to disk as it is produced, so memory stays flat
/// regardless of how long a capture runs.
class SpatialCaptureStore {
  SpatialCaptureStore._(this.captureId, this.directory);

  static const String rootFolderName = 'capture-temp';
  static const String _manifestFile = 'metadata.json';
  static const String _framesFile = 'frames.json';

  final String captureId;
  final Directory directory;

  final List<SpatialSampleRecord> _samples = <SpatialSampleRecord>[];
  int _bytesWritten = 0;
  int _pendingWrites = 0;
  bool _discarded = false;

  /// Samples durably written so far.
  int get sampleCount => _samples.length;

  /// Total bytes committed to disk.
  int get bytesWritten => _bytesWritten;

  /// Writes started but not yet flushed. The sampling policy uses this for
  /// backpressure instead of queueing frames in memory.
  int get pendingWrites => _pendingWrites;

  bool get isDiscarded => _discarded;

  /// Sample metadata only — never image bytes.
  List<SpatialSampleRecord> get samples => List.unmodifiable(_samples);

  bool get depthObserved => _samples.any((s) => s.hasDepth);

  /// Opens a fresh capture directory.
  ///
  /// [root] is injectable so tests run against a temporary directory without
  /// a platform channel.
  static Future<SpatialCaptureStore> create({
    required String captureId,
    Directory? root,
  }) async {
    final base = root ?? await defaultRoot();
    final dir = Directory(p.join(base.path, captureId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
    return SpatialCaptureStore._(captureId, dir);
  }

  /// App-private capture root. Not the shared media store: raw capture stays
  /// private to the app until the user explicitly publishes a processed
  /// variant.
  static Future<Directory> defaultRoot() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, rootFolderName));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  /// Writes one accepted sample to disk.
  ///
  /// The caller's byte buffers are released as soon as this completes; nothing
  /// is cached in memory.
  Future<SpatialSampleRecord> writeSample({
    required Uint8List rgb,
    Uint8List? depth,
    Uint8List? confidence,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    if (_discarded) {
      throw StateError('Capture $captureId has been discarded.');
    }
    _pendingWrites++;
    try {
      final index = _samples.length;
      final stem = index.toString().padLeft(5, '0');

      final rgbPath = 'rgb/$stem.jpg';
      await _write(rgbPath, rgb);
      var bytes = rgb.length;

      String? depthPath;
      if (depth != null && depth.isNotEmpty) {
        depthPath = 'depth/$stem.bin';
        await _write(depthPath, depth);
        bytes += depth.length;
      }

      String? confidencePath;
      if (confidence != null && confidence.isNotEmpty) {
        confidencePath = 'confidence/$stem.bin';
        await _write(confidencePath, confidence);
        bytes += confidence.length;
      }

      final record = SpatialSampleRecord(
        index: index,
        rgbPath: rgbPath,
        depthPath: depthPath,
        confidencePath: confidencePath,
        bytes: bytes,
        metadata: metadata,
      );
      _samples.add(record);
      _bytesWritten += bytes;
      return record;
    } finally {
      _pendingWrites--;
    }
  }

  Future<void> _write(String relativePath, Uint8List bytes) async {
    final file = File(p.join(directory.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: false);
  }

  /// Persists the sample index and capture metadata so an interrupted capture
  /// can be recovered after an app restart.
  Future<void> writeManifest({
    required String artworkId,
    String? markerId,
    String? capturedBy,
    required DateTime startedAt,
    bool transferred = false,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) async {
    if (_discarded) return;
    final manifest = <String, dynamic>{
      'schema': 'kubus.capture/1',
      'captureId': captureId,
      'artworkId': artworkId,
      if (markerId != null) 'markerId': markerId,
      'capturedAt': startedAt.toUtc().toIso8601String(),
      'transferred': transferred,
      'metadata': <String, dynamic>{
        'capturedBy': capturedBy,
        'frameCount': _samples.length,
        'depthAvailable': depthObserved,
        'byteSize': _bytesWritten,
        'source': 'art.kubus-mobile-tracking',
        'private': true,
        ...extra,
      },
    };
    await File(p.join(directory.path, _manifestFile))
        .writeAsString(jsonEncode(manifest), flush: true);
    await File(p.join(directory.path, _framesFile)).writeAsString(
      jsonEncode(<String, dynamic>{
        'schema': 'kubus.capture.frames/1',
        'frames': _samples.map((s) => s.toJson()).toList(growable: false),
      }),
      flush: true,
    );
  }

  /// Marks the capture as delivered so restart recovery stops offering it.
  Future<void> markTransferred() async {
    final file = File(p.join(directory.path, _manifestFile));
    if (!await file.exists()) return;
    try {
      final manifest =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      manifest['transferred'] = true;
      await file.writeAsString(jsonEncode(manifest), flush: true);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SpatialCaptureStore: manifest rewrite failed: $error');
      }
    }
  }

  /// Deletes the capture. Only ever called on explicit user intent or for a
  /// capture that has already been delivered.
  Future<void> discard() async {
    _discarded = true;
    _samples.clear();
    _bytesWritten = 0;
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SpatialCaptureStore: discard failed: $error');
      }
    }
  }

  /// Absolute path of a stored file, for streaming upload.
  File fileAt(String relativePath) =>
      File(p.join(directory.path, relativePath));

  /// Finds captures left behind by an interrupted session.
  static Future<List<InterruptedSpatialCapture>> findInterrupted({
    Directory? root,
  }) async {
    final base = root ?? await defaultRoot();
    if (!await base.exists()) return const <InterruptedSpatialCapture>[];

    final found = <InterruptedSpatialCapture>[];
    await for (final entity in base.list()) {
      if (entity is! Directory) continue;
      final manifest = File(p.join(entity.path, _manifestFile));
      if (!await manifest.exists()) continue;
      try {
        final json =
            jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
        final metadata = json['metadata'];
        found.add(InterruptedSpatialCapture(
          captureId: json['captureId']?.toString() ?? p.basename(entity.path),
          directory: entity,
          startedAt: DateTime.tryParse(json['capturedAt']?.toString() ?? '')
                  ?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          sampleCount: metadata is Map && metadata['frameCount'] is int
              ? metadata['frameCount'] as int
              : 0,
          transferred: json['transferred'] == true,
        ));
      } catch (error) {
        if (kDebugMode) {
          debugPrint('SpatialCaptureStore: unreadable manifest: $error');
        }
      }
    }
    found.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return found;
  }

  /// Removes delivered or expired captures. A capture that never reached the
  /// node is preserved regardless of age so a valuable scan is not silently
  /// deleted.
  static Future<int> cleanUp({
    Directory? root,
    Duration retention = const Duration(days: 7),
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now().toUtc();
    var removed = 0;
    for (final capture in await findInterrupted(root: root)) {
      final expired = at.difference(capture.startedAt) > retention;
      if (!capture.transferred && !expired) continue;
      try {
        await capture.directory.delete(recursive: true);
        removed++;
      } catch (error) {
        if (kDebugMode) {
          debugPrint('SpatialCaptureStore: cleanup failed: $error');
        }
      }
    }
    return removed;
  }
}
