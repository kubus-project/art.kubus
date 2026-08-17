import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../config/config.dart';

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

  /// Index-line form. Carries the fields recovery needs and nothing else.
  Map<String, dynamic> toIndexEntry() => <String, dynamic>{
        'index': index,
        'rgbPath': rgbPath,
        if (depthPath != null) 'depthPath': depthPath,
        if (confidencePath != null) 'confidencePath': confidencePath,
        'bytes': bytes,
        'metadata': metadata,
      };

  static SpatialSampleRecord? tryFromIndexEntry(Map<String, dynamic> json) {
    final rgbPath = json['rgbPath'];
    final index = json['index'];
    if (rgbPath is! String || rgbPath.isEmpty || index is! int) return null;
    return SpatialSampleRecord(
      index: index,
      rgbPath: rgbPath,
      depthPath: json['depthPath'] as String?,
      confidencePath: json['confidencePath'] as String?,
      bytes: json['bytes'] is int ? json['bytes'] as int : 0,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }
}

/// Lifecycle of a capture directory, as recorded in its manifest.
///
/// Written from the moment a capture begins, so a process killed mid-capture
/// still leaves a directory recovery can classify.
enum SpatialCaptureDirectoryState {
  /// Samples are still being written.
  capturing,

  /// Sampling finished locally; the capture has not reached a node.
  captured,

  /// Delivered to a paired node.
  transferred,
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
    required this.state,
    this.artworkId,
    this.markerId,
    this.capturedBy,
    this.byteSize = 0,
    this.draftId,
  });

  final String captureId;
  final Directory directory;
  final DateTime startedAt;
  final int sampleCount;

  /// Whether the capture already reached the node. An untransferred capture is
  /// preserved for retry rather than discarded.
  final bool transferred;

  final SpatialCaptureDirectoryState state;
  final String? artworkId;
  final String? markerId;
  final String? capturedBy;
  final int byteSize;

  /// Node-side draft the last transfer attempt opened, if any. Lets an
  /// interrupted upload resume instead of restarting.
  final String? draftId;

  /// Whether this directory holds user work worth offering back.
  bool get hasRecoverableWork => !transferred && sampleCount > 0;

  /// Whether sampling was still in progress when the process went away.
  bool get wasCapturing => state == SpatialCaptureDirectoryState.capturing;
}

/// Incremental, app-private, disk-backed storage for one spatial capture.
///
/// Replaces holding every encoded frame in a `List<Map<String, dynamic>>`:
/// capture payload is spooled to disk as it is produced, so memory stays flat
/// regardless of how long a capture runs.
///
/// Metadata is written when the capture opens and the sample index is appended
/// per sample, so a crash mid-capture leaves a directory that recovery can
/// find. Writing the manifest only at finish meant an interrupted capture was
/// invisible to `findInterrupted` and its frames were unreachable.
class SpatialCaptureStore {
  SpatialCaptureStore._(
    this.captureId,
    this.directory, {
    required String artworkId,
    required DateTime startedAt,
    String? markerId,
    String? capturedBy,
  })  : _artworkId = artworkId,
        _startedAt = startedAt,
        _markerId = markerId,
        _capturedBy = capturedBy;

  static const String rootFolderName = 'capture-temp';
  static const String _manifestFile = 'metadata.json';
  static const String _framesFile = 'frames.json';
  static const String _indexFile = 'frames.jsonl';

  /// How long a capture directory with no usable samples is kept before it is
  /// treated as debris. Long enough that a capture opened seconds ago is never
  /// swept out from under a live session.
  static const Duration emptyCaptureGrace = Duration(hours: 6);

  final String captureId;
  final Directory directory;
  final String _artworkId;
  final DateTime _startedAt;
  final String? _markerId;
  final String? _capturedBy;

  final List<SpatialSampleRecord> _samples = <SpatialSampleRecord>[];
  int _bytesWritten = 0;
  int _pendingWrites = 0;
  bool _discarded = false;
  SpatialCaptureDirectoryState _state = SpatialCaptureDirectoryState.capturing;
  String? _draftId;

  /// Extra manifest fields supplied by the caller, retained so a later write
  /// (recording a draft id, marking the capture delivered) does not drop them.
  Map<String, dynamic> _manifestExtra = const <String, dynamic>{};

  /// Serializes manifest and index writes so two concurrent updates cannot
  /// interleave a read-modify-write of the same file.
  Future<void> _metadataQueue = Future<void>.value();

  /// Samples durably written so far.
  int get sampleCount => _samples.length;

  /// Total bytes committed to disk.
  int get bytesWritten => _bytesWritten;

  /// Writes started but not yet flushed. The sampling policy uses this for
  /// backpressure instead of queueing frames in memory.
  int get pendingWrites => _pendingWrites;

  bool get isDiscarded => _discarded;

  SpatialCaptureDirectoryState get state => _state;

  String get artworkId => _artworkId;
  String? get markerId => _markerId;
  String? get capturedBy => _capturedBy;
  DateTime get startedAt => _startedAt;

  /// Node-side draft id recorded for transfer resume, if one is open.
  String? get draftId => _draftId;

  /// Sample metadata only — never image bytes.
  List<SpatialSampleRecord> get samples => List.unmodifiable(_samples);

  bool get depthObserved => _samples.any((s) => s.hasDepth);

  /// Opens a fresh capture directory and records it immediately.
  ///
  /// [root] is injectable so tests run against a temporary directory without
  /// a platform channel.
  static Future<SpatialCaptureStore> create({
    required String captureId,
    required String artworkId,
    String? markerId,
    String? capturedBy,
    DateTime? startedAt,
    Directory? root,
  }) async {
    final base = root ?? await defaultRoot();
    final dir = Directory(p.join(base.path, captureId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
    final store = SpatialCaptureStore._(
      captureId,
      dir,
      artworkId: artworkId,
      markerId: markerId,
      capturedBy: capturedBy,
      startedAt: (startedAt ?? DateTime.now()).toUtc(),
    );
    // Record the capture before the first sample. A process killed at any point
    // after this leaves a directory `findInterrupted` can classify.
    await store._persistManifest();
    return store;
  }

  /// Reopens an interrupted capture directory so it can be resumed or
  /// retransferred without losing what is already on disk.
  static Future<SpatialCaptureStore?> open(
    Directory directory, {
    Directory? root,
  }) async {
    final manifestFile = File(p.join(directory.path, _manifestFile));
    if (!await manifestFile.exists()) return null;
    Map<String, dynamic> manifest;
    try {
      manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    } catch (error) {
      if (kDebugMode) {
        AppConfig.debugPrint(
            'SpatialCaptureStore: unreadable manifest: $error');
      }
      return null;
    }
    final metadata = manifest['metadata'];
    final store = SpatialCaptureStore._(
      manifest['captureId']?.toString() ?? p.basename(directory.path),
      directory,
      artworkId: manifest['artworkId']?.toString() ?? '',
      markerId: manifest['markerId']?.toString(),
      capturedBy: metadata is Map ? metadata['capturedBy']?.toString() : null,
      startedAt: DateTime.tryParse(manifest['capturedAt']?.toString() ?? '')
              ?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
    store._state = _stateFromManifest(manifest);
    store._draftId = manifest['draftId']?.toString();
    await store._loadIndex();
    return store;
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

  /// Writes one accepted sample to disk and appends it to the sample index.
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
      // Append-only: one crash-safe line per sample. A partially written
      // trailing line is discarded on read rather than corrupting the index.
      await _appendIndexEntry(record);
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

  /// Finalizes the capture manifest and the readable frame index.
  ///
  /// The incremental index already survives a crash; this writes the canonical
  /// `frames.json` the transfer and the node consume.
  Future<void> writeManifest({
    bool transferred = false,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) async {
    if (_discarded) return;
    _state = transferred
        ? SpatialCaptureDirectoryState.transferred
        : SpatialCaptureDirectoryState.captured;
    if (extra.isNotEmpty) {
      _manifestExtra = <String, dynamic>{..._manifestExtra, ...extra};
    }
    await _enqueueMetadata(() async {
      await _writeAtomic(_framesFile, utf8.encode(jsonEncode(framesDocument)));
      await _writeManifestUnsafe();
    });
  }

  /// The canonical frame document, as uploaded to the node.
  Map<String, dynamic> get framesDocument => <String, dynamic>{
        'schema': 'kubus.capture.frames/1',
        'frames': _samples.map((s) => s.toJson()).toList(growable: false),
      };

  /// Records the node draft this capture is being streamed into, so an
  /// interrupted transfer can resume against the same draft.
  Future<void> recordDraftId(String? draftId) async {
    _draftId = draftId;
    await _enqueueMetadata(_writeManifestUnsafe);
  }

  /// Marks the capture as delivered so restart recovery stops offering it.
  Future<void> markTransferred() async {
    _state = SpatialCaptureDirectoryState.transferred;
    _draftId = null;
    await _enqueueMetadata(_writeManifestUnsafe);
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
        AppConfig.debugPrint('SpatialCaptureStore: discard failed: $error');
      }
    }
  }

  /// Absolute path of a stored file, for streaming upload.
  File fileAt(String relativePath) =>
      File(p.join(directory.path, relativePath));

  /// Every stored file, in upload order, with the MIME type the node records.
  ///
  /// Paths only: the caller streams each file's bytes one at a time rather than
  /// assembling the capture in memory.
  List<SpatialCaptureUploadEntry> get uploadEntries {
    final entries = <SpatialCaptureUploadEntry>[];
    for (final sample in _samples) {
      entries.add(
        SpatialCaptureUploadEntry(path: sample.rgbPath, mimeType: 'image/jpeg'),
      );
      final depthPath = sample.depthPath;
      if (depthPath != null) {
        entries.add(
          SpatialCaptureUploadEntry(
            path: depthPath,
            mimeType: 'application/octet-stream',
          ),
        );
      }
      final confidencePath = sample.confidencePath;
      if (confidencePath != null) {
        entries.add(
          SpatialCaptureUploadEntry(
            path: confidencePath,
            mimeType: 'application/octet-stream',
          ),
        );
      }
    }
    entries.add(
      const SpatialCaptureUploadEntry(
        path: _framesFile,
        mimeType: 'application/json',
      ),
    );
    return entries;
  }

  Map<String, dynamic> _manifestDocument() => <String, dynamic>{
        'schema': 'kubus.capture/1',
        'captureId': captureId,
        'artworkId': _artworkId,
        if (_markerId != null) 'markerId': _markerId,
        'capturedAt': _startedAt.toUtc().toIso8601String(),
        'state': _state.name,
        'transferred': _state == SpatialCaptureDirectoryState.transferred,
        if (_draftId != null) 'draftId': _draftId,
        'metadata': <String, dynamic>{
          'capturedBy': _capturedBy,
          'frameCount': _samples.length,
          'depthAvailable': depthObserved,
          'byteSize': _bytesWritten,
          'source': 'art.kubus-mobile-tracking',
          'private': true,
          ..._manifestExtra,
        },
      };

  Future<void> _persistManifest() => _enqueueMetadata(_writeManifestUnsafe);

  Future<void> _writeManifestUnsafe() async {
    if (_discarded) return;
    await _writeAtomic(
      _manifestFile,
      utf8.encode(jsonEncode(_manifestDocument())),
    );
  }

  /// Runs [action] after any queued metadata write, so concurrent updates of
  /// the manifest cannot interleave and lose each other's fields.
  Future<void> _enqueueMetadata(Future<void> Function() action) {
    final next = _metadataQueue.then((_) => action());
    // Keep the chain alive if one write fails: a failed manifest update must
    // not poison every later one.
    _metadataQueue = next.catchError((Object error) {
      if (kDebugMode) {
        AppConfig.debugPrint(
            'SpatialCaptureStore: metadata write failed: $error');
      }
    });
    return next;
  }

  /// Writes via a temporary file and an atomic rename.
  ///
  /// A crash partway through a direct overwrite would leave the only record of
  /// the capture truncated; the rename either lands whole or not at all.
  Future<void> _writeAtomic(String relativePath, List<int> bytes) async {
    final target = File(p.join(directory.path, relativePath));
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(target.path);
  }

  Future<void> _appendIndexEntry(SpatialSampleRecord record) async {
    final file = File(p.join(directory.path, _indexFile));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode(record.toIndexEntry())}\n',
      mode: FileMode.writeOnlyAppend,
      flush: true,
    );
  }

  Future<void> _loadIndex() async {
    final file = File(p.join(directory.path, _indexFile));
    if (!await file.exists()) return;
    String contents;
    try {
      contents = await file.readAsString();
    } catch (error) {
      if (kDebugMode) {
        AppConfig.debugPrint(
            'SpatialCaptureStore: unreadable sample index: $error');
      }
      return;
    }
    for (final line in const LineSplitter().convert(contents)) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map<String, dynamic>) continue;
        final record = SpatialSampleRecord.tryFromIndexEntry(decoded);
        if (record == null) continue;
        _samples.add(record);
        _bytesWritten += record.bytes;
      } catch (_) {
        // A truncated trailing line is what a crash mid-append leaves behind.
        // Everything before it is still good.
      }
    }
  }

  static SpatialCaptureDirectoryState _stateFromManifest(
    Map<String, dynamic> manifest,
  ) {
    if (manifest['transferred'] == true) {
      return SpatialCaptureDirectoryState.transferred;
    }
    return switch (manifest['state']?.toString()) {
      'transferred' => SpatialCaptureDirectoryState.transferred,
      'captured' => SpatialCaptureDirectoryState.captured,
      _ => SpatialCaptureDirectoryState.capturing,
    };
  }

  /// Finds captures left behind by an interrupted session.
  ///
  /// A capture is discoverable from the moment it opens, not only once it has
  /// been finished, because the manifest is written up front.
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
        final state = _stateFromManifest(json);
        // The manifest's frameCount is only as fresh as its last write. The
        // append-only index is authoritative for a capture killed mid-session.
        final indexed = await _countIndexEntries(entity);
        final declared = metadata is Map && metadata['frameCount'] is int
            ? metadata['frameCount'] as int
            : 0;
        found.add(InterruptedSpatialCapture(
          captureId: json['captureId']?.toString() ?? p.basename(entity.path),
          directory: entity,
          startedAt: DateTime.tryParse(json['capturedAt']?.toString() ?? '')
                  ?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          sampleCount: indexed > declared ? indexed : declared,
          transferred: state == SpatialCaptureDirectoryState.transferred,
          state: state,
          artworkId: json['artworkId']?.toString(),
          markerId: json['markerId']?.toString(),
          capturedBy:
              metadata is Map ? metadata['capturedBy']?.toString() : null,
          byteSize: metadata is Map && metadata['byteSize'] is int
              ? metadata['byteSize'] as int
              : 0,
          draftId: json['draftId']?.toString(),
        ));
      } catch (error) {
        if (kDebugMode) {
          AppConfig.debugPrint(
              'SpatialCaptureStore: unreadable manifest: $error');
        }
      }
    }
    found.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return found;
  }

  static Future<int> _countIndexEntries(Directory directory) async {
    final file = File(p.join(directory.path, _indexFile));
    if (!await file.exists()) return 0;
    try {
      return const LineSplitter()
          .convert(await file.readAsString())
          .where((line) => line.trim().isNotEmpty)
          .length;
    } catch (_) {
      return 0;
    }
  }

  /// Reclaims capture directories that are safe to remove.
  ///
  /// The policy, stated once so implementation and comment cannot drift:
  ///
  /// - A capture that reached the node is deleted once [retention] has passed.
  ///   The node holds it; the local copy is a temporary staging artifact.
  /// - A capture that never reached the node and holds at least one sample is
  ///   **never** deleted here, at any age. It is unrecoverable user work, and
  ///   only an explicit discard removes it.
  /// - A directory with no usable samples is debris — an aborted open, or a
  ///   capture killed before its first frame — and is removed once
  ///   [emptyCaptureGrace] has passed so it cannot race a live session.
  ///
  /// Returns the number of directories removed.
  static Future<int> cleanUp({
    Directory? root,
    Duration retention = const Duration(days: 7),
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now().toUtc();
    var removed = 0;
    for (final capture in await findInterrupted(root: root)) {
      final age = at.difference(capture.startedAt);
      final bool deletable;
      if (capture.transferred) {
        deletable = age > retention;
      } else if (capture.sampleCount > 0) {
        // Untransferred user work is never reclaimed by age.
        deletable = false;
      } else {
        deletable = age > emptyCaptureGrace;
      }
      if (!deletable) continue;
      try {
        await capture.directory.delete(recursive: true);
        removed++;
      } catch (error) {
        if (kDebugMode) {
          AppConfig.debugPrint('SpatialCaptureStore: cleanup failed: $error');
        }
      }
    }
    return removed;
  }
}

/// One file to stream to the node, identified by its path within the capture.
@immutable
class SpatialCaptureUploadEntry {
  const SpatialCaptureUploadEntry({required this.path, required this.mimeType});

  final String path;
  final String mimeType;

  @override
  bool operator ==(Object other) =>
      other is SpatialCaptureUploadEntry &&
      other.path == path &&
      other.mimeType == mimeType;

  @override
  int get hashCode => Object.hash(path, mimeType);
}
