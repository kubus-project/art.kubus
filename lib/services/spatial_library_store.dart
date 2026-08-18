import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'spatial_capture_store.dart';

enum SpatialLibraryProcessingState {
  capturing,
  capturedPrivate,
  waitingForProcessor,
  uploading,
  queued,
  processing,
  downloadingResult,
  readyPrivate,
  publishing,
  published,
  failedRetryable,
}

class SpatialLibraryRecord {
  const SpatialLibraryRecord({
    required this.localSpatialId,
    required this.artworkId,
    required this.capturedAt,
    required this.updatedAt,
    required this.sourcePath,
    required this.sampleCount,
    required this.bytes,
    required this.hasDepth,
    required this.rawPresent,
    required this.processingState,
    this.ownerId,
    this.markerId,
    this.nodeId,
    this.draftId,
    this.nodeCaptureId,
    this.jobId,
    this.resultManifestPath,
    this.publicSpatialId,
    this.version,
    this.canonicalManifestCid,
    this.canonicalRecordCid,
    this.lastErrorCode,
  });

  final String localSpatialId;
  final String artworkId;
  final String? ownerId;
  final String? markerId;
  final DateTime capturedAt;
  final DateTime updatedAt;
  final String sourcePath;
  final int sampleCount;
  final int bytes;
  final bool hasDepth;
  final bool rawPresent;
  final SpatialLibraryProcessingState processingState;
  final String? nodeId;
  final String? draftId;
  final String? nodeCaptureId;
  final String? jobId;
  final String? resultManifestPath;
  final String? publicSpatialId;
  final int? version;
  final String? canonicalManifestCid;
  final String? canonicalRecordCid;
  final String? lastErrorCode;

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'localSpatialId': localSpatialId,
        'ownerId': ownerId,
        'artworkId': artworkId,
        'markerId': markerId,
        'capturedAt': capturedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'source': {
          'path': sourcePath,
          'sampleCount': sampleCount,
          'bytes': bytes,
          'hasDepth': hasDepth,
          'rawPresent': rawPresent,
        },
        'processing': {
          'state': processingState.name,
          'nodeId': nodeId,
          'draftId': draftId,
          'nodeCaptureId': nodeCaptureId,
          'jobId': jobId,
          'resultManifestPath': resultManifestPath,
        },
        'publication': {
          'publicSpatialId': publicSpatialId,
          'version': version,
          'canonicalManifestCid': canonicalManifestCid,
          'canonicalRecordCid': canonicalRecordCid,
        },
        if (lastErrorCode != null) 'lastError': {'code': lastErrorCode},
      };

  factory SpatialLibraryRecord.fromJson(Map<String, dynamic> json) {
    final source =
        Map<String, dynamic>.from(json['source'] as Map? ?? const {});
    final processing =
        Map<String, dynamic>.from(json['processing'] as Map? ?? const {});
    final publication =
        Map<String, dynamic>.from(json['publication'] as Map? ?? const {});
    return SpatialLibraryRecord(
      localSpatialId: json['localSpatialId'].toString(),
      ownerId: json['ownerId']?.toString(),
      artworkId: json['artworkId'].toString(),
      markerId: json['markerId']?.toString(),
      capturedAt: DateTime.parse(json['capturedAt'].toString()).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'].toString()).toUtc(),
      sourcePath: source['path'].toString(),
      sampleCount: (source['sampleCount'] as num?)?.toInt() ?? 0,
      bytes: (source['bytes'] as num?)?.toInt() ?? 0,
      hasDepth: source['hasDepth'] == true,
      rawPresent: source['rawPresent'] != false,
      processingState: SpatialLibraryProcessingState.values.byName(
        processing['state']?.toString() ??
            SpatialLibraryProcessingState.capturedPrivate.name,
      ),
      nodeId: processing['nodeId']?.toString(),
      draftId: processing['draftId']?.toString(),
      nodeCaptureId: processing['nodeCaptureId']?.toString(),
      jobId: processing['jobId']?.toString(),
      resultManifestPath: processing['resultManifestPath']?.toString(),
      publicSpatialId: publication['publicSpatialId']?.toString(),
      version: (publication['version'] as num?)?.toInt(),
      canonicalManifestCid: publication['canonicalManifestCid']?.toString(),
      canonicalRecordCid: publication['canonicalRecordCid']?.toString(),
      lastErrorCode: (json['lastError'] as Map?)?['code']?.toString(),
    );
  }
}

/// The phone's durable private library. It stores only small record metadata
/// in its index; raw RGB/depth stays below the record's private source folder.
class SpatialLibraryStore {
  SpatialLibraryStore({Directory? root}) : _root = root;
  final Directory? _root;
  static const rootFolderName = 'spatial-library';

  Future<Directory> root() async {
    final base = _root ??
        Directory(p.join(
            (await getApplicationSupportDirectory()).path, rootFolderName));
    await base.create(recursive: true);
    return base;
  }

  Future<SpatialLibraryRecord> promoteCapture(
      SpatialCaptureStore capture) async {
    final library = await root();
    final recordDirectory = Directory(p.join(library.path, capture.captureId));
    final source = Directory(p.join(recordDirectory.path, 'source'));
    if (!await recordDirectory.exists()) {
      await recordDirectory.create(recursive: true);
    }
    if (!await source.exists()) {
      await capture.directory.rename(source.path);
    }
    final now = DateTime.now().toUtc();
    final record = SpatialLibraryRecord(
      localSpatialId: capture.captureId,
      ownerId: capture.capturedBy,
      artworkId: capture.artworkId,
      markerId: capture.markerId,
      capturedAt: capture.startedAt,
      updatedAt: now,
      sourcePath: source.path,
      sampleCount: capture.sampleCount,
      bytes: capture.bytesWritten,
      hasDepth: capture.depthObserved,
      rawPresent: true,
      processingState: SpatialLibraryProcessingState.capturedPrivate,
      draftId: capture.draftId,
    );
    await save(record);
    return record;
  }

  /// Idempotently promotes useful legacy `capture-temp` work. Empty debris is
  /// deliberately left to the capture store's grace-period cleanup; this
  /// migration never deletes user samples as a side effect of upgrading.
  Future<List<SpatialLibraryRecord>> migrateLegacy(
      Directory captureRoot) async {
    if (!await captureRoot.exists()) return const [];
    final migrated = <SpatialLibraryRecord>[];
    final entries = await captureRoot.list(followLinks: false).toList();
    for (final directory in entries.whereType<Directory>()) {
      final capture = await SpatialCaptureStore.open(directory);
      if (capture == null || capture.sampleCount == 0) continue;
      migrated.add(await promoteCapture(capture));
    }
    return migrated;
  }

  Future<void> save(SpatialLibraryRecord record) async {
    final folder =
        Directory(p.join((await root()).path, record.localSpatialId));
    await folder.create(recursive: true);
    await _atomicJson(
        File(p.join(folder.path, 'record.json')), record.toJson());
  }

  Future<List<SpatialLibraryRecord>> list() async {
    final entries = await (await root()).list(followLinks: false).toList();
    final records = <SpatialLibraryRecord>[];
    for (final entry in entries.whereType<Directory>()) {
      final file = File(p.join(entry.path, 'record.json'));
      if (!await file.exists()) continue;
      try {
        records.add(SpatialLibraryRecord.fromJson(
            jsonDecode(await file.readAsString()) as Map<String, dynamic>));
      } on FormatException {
        // A partially migrated/corrupt record is ignored; its private source is
        // retained for explicit recovery rather than silently deleted.
      }
    }
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  Future<void> _atomicJson(File destination, Map<String, dynamic> value) async {
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
  }
}
