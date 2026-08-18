import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as image_lib;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'spatial_capture_store.dart';

const Object _notSet = Object();

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

enum SpatialLibraryIntegrityState { pending, valid, invalid }

enum SpatialLibraryPublicationState { private, publishing, published, failed }

class SpatialLibraryRecord {
  const SpatialLibraryRecord({
    this.schemaVersion = SpatialLibraryStore.schemaVersion,
    required this.localSpatialId,
    required this.artworkId,
    required this.capturedAt,
    required this.updatedAt,
    required this.sourcePath,
    required this.sampleCount,
    required this.sourceBytes,
    required this.hasDepth,
    required this.rawPresent,
    required this.processingState,
    this.ownerId,
    this.markerId,
    this.coverageMetadata = const <String, dynamic>{},
    this.qualityMetadata = const <String, dynamic>{},
    this.processingTarget,
    this.nodeId,
    this.draftId,
    this.nodeCaptureId,
    this.jobId,
    this.uploadedFiles = 0,
    this.totalFiles = 0,
    this.uploadedBytes = 0,
    this.totalUploadBytes = 0,
    this.networkProviderNodeId,
    this.networkRequestId,
    this.resultManifestPath,
    this.resultManifestCid,
    this.resultVariantPaths = const <String, String>{},
    this.thumbnailPath,
    this.resultFormat,
    this.resultBytes = 0,
    this.integrityState = SpatialLibraryIntegrityState.pending,
    this.publicationState = SpatialLibraryPublicationState.private,
    this.publicSpatialId,
    this.version,
    this.canonicalManifestCid,
    this.canonicalRecordCid,
    this.variantCids = const <String, String>{},
    this.publishedAt,
    this.lastErrorCode,
    this.lastErrorAt,
  });

  final int schemaVersion;
  final String localSpatialId;
  final String artworkId;
  final String? ownerId;
  final String? markerId;
  final DateTime capturedAt;
  final DateTime updatedAt;
  final String sourcePath;
  final int sampleCount;
  final int sourceBytes;
  final bool hasDepth;
  final bool rawPresent;
  final Map<String, dynamic> coverageMetadata;
  final Map<String, dynamic> qualityMetadata;
  final SpatialLibraryProcessingState processingState;
  final String? processingTarget;
  final String? nodeId;
  final String? draftId;
  final String? nodeCaptureId;
  final String? jobId;
  final int uploadedFiles;
  final int totalFiles;
  final int uploadedBytes;
  final int totalUploadBytes;
  final String? networkProviderNodeId;
  final String? networkRequestId;
  final String? resultManifestPath;
  final String? resultManifestCid;
  final Map<String, String> resultVariantPaths;
  final String? thumbnailPath;
  final String? resultFormat;
  final int resultBytes;
  final SpatialLibraryIntegrityState integrityState;
  final SpatialLibraryPublicationState publicationState;
  final String? publicSpatialId;
  final int? version;
  final String? canonicalManifestCid;
  final String? canonicalRecordCid;
  final Map<String, String> variantCids;
  final DateTime? publishedAt;
  final String? lastErrorCode;
  final DateTime? lastErrorAt;

  int get bytes => sourceBytes;
  int get totalBytes => sourceBytes + resultBytes;
  bool get hasLocalResult =>
      resultManifestPath != null && resultVariantPaths.isNotEmpty;

  SpatialLibraryRecord copyWith({
    int? schemaVersion,
    String? localSpatialId,
    String? artworkId,
    Object? ownerId = _notSet,
    Object? markerId = _notSet,
    DateTime? capturedAt,
    DateTime? updatedAt,
    String? sourcePath,
    int? sampleCount,
    int? sourceBytes,
    bool? hasDepth,
    bool? rawPresent,
    Map<String, dynamic>? coverageMetadata,
    Map<String, dynamic>? qualityMetadata,
    SpatialLibraryProcessingState? processingState,
    Object? processingTarget = _notSet,
    Object? nodeId = _notSet,
    Object? draftId = _notSet,
    Object? nodeCaptureId = _notSet,
    Object? jobId = _notSet,
    int? uploadedFiles,
    int? totalFiles,
    int? uploadedBytes,
    int? totalUploadBytes,
    Object? networkProviderNodeId = _notSet,
    Object? networkRequestId = _notSet,
    Object? resultManifestPath = _notSet,
    Object? resultManifestCid = _notSet,
    Map<String, String>? resultVariantPaths,
    Object? thumbnailPath = _notSet,
    Object? resultFormat = _notSet,
    int? resultBytes,
    SpatialLibraryIntegrityState? integrityState,
    SpatialLibraryPublicationState? publicationState,
    Object? publicSpatialId = _notSet,
    Object? version = _notSet,
    Object? canonicalManifestCid = _notSet,
    Object? canonicalRecordCid = _notSet,
    Map<String, String>? variantCids,
    Object? publishedAt = _notSet,
    Object? lastErrorCode = _notSet,
    Object? lastErrorAt = _notSet,
  }) =>
      SpatialLibraryRecord(
        schemaVersion: schemaVersion ?? this.schemaVersion,
        localSpatialId: localSpatialId ?? this.localSpatialId,
        ownerId:
            identical(ownerId, _notSet) ? this.ownerId : ownerId as String?,
        artworkId: artworkId ?? this.artworkId,
        markerId:
            identical(markerId, _notSet) ? this.markerId : markerId as String?,
        capturedAt: capturedAt ?? this.capturedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        sourcePath: sourcePath ?? this.sourcePath,
        sampleCount: sampleCount ?? this.sampleCount,
        sourceBytes: sourceBytes ?? this.sourceBytes,
        hasDepth: hasDepth ?? this.hasDepth,
        rawPresent: rawPresent ?? this.rawPresent,
        coverageMetadata: coverageMetadata ?? this.coverageMetadata,
        qualityMetadata: qualityMetadata ?? this.qualityMetadata,
        processingState: processingState ?? this.processingState,
        processingTarget: identical(processingTarget, _notSet)
            ? this.processingTarget
            : processingTarget as String?,
        nodeId: identical(nodeId, _notSet) ? this.nodeId : nodeId as String?,
        draftId:
            identical(draftId, _notSet) ? this.draftId : draftId as String?,
        nodeCaptureId: identical(nodeCaptureId, _notSet)
            ? this.nodeCaptureId
            : nodeCaptureId as String?,
        jobId: identical(jobId, _notSet) ? this.jobId : jobId as String?,
        uploadedFiles: uploadedFiles ?? this.uploadedFiles,
        totalFiles: totalFiles ?? this.totalFiles,
        uploadedBytes: uploadedBytes ?? this.uploadedBytes,
        totalUploadBytes: totalUploadBytes ?? this.totalUploadBytes,
        networkProviderNodeId: identical(networkProviderNodeId, _notSet)
            ? this.networkProviderNodeId
            : networkProviderNodeId as String?,
        networkRequestId: identical(networkRequestId, _notSet)
            ? this.networkRequestId
            : networkRequestId as String?,
        resultManifestPath: identical(resultManifestPath, _notSet)
            ? this.resultManifestPath
            : resultManifestPath as String?,
        resultManifestCid: identical(resultManifestCid, _notSet)
            ? this.resultManifestCid
            : resultManifestCid as String?,
        resultVariantPaths: resultVariantPaths ?? this.resultVariantPaths,
        thumbnailPath: identical(thumbnailPath, _notSet)
            ? this.thumbnailPath
            : thumbnailPath as String?,
        resultFormat: identical(resultFormat, _notSet)
            ? this.resultFormat
            : resultFormat as String?,
        resultBytes: resultBytes ?? this.resultBytes,
        integrityState: integrityState ?? this.integrityState,
        publicationState: publicationState ?? this.publicationState,
        publicSpatialId: identical(publicSpatialId, _notSet)
            ? this.publicSpatialId
            : publicSpatialId as String?,
        version: identical(version, _notSet) ? this.version : version as int?,
        canonicalManifestCid: identical(canonicalManifestCid, _notSet)
            ? this.canonicalManifestCid
            : canonicalManifestCid as String?,
        canonicalRecordCid: identical(canonicalRecordCid, _notSet)
            ? this.canonicalRecordCid
            : canonicalRecordCid as String?,
        variantCids: variantCids ?? this.variantCids,
        publishedAt: identical(publishedAt, _notSet)
            ? this.publishedAt
            : publishedAt as DateTime?,
        lastErrorCode: identical(lastErrorCode, _notSet)
            ? this.lastErrorCode
            : lastErrorCode as String?,
        lastErrorAt: identical(lastErrorAt, _notSet)
            ? this.lastErrorAt
            : lastErrorAt as DateTime?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'localSpatialId': localSpatialId,
        'ownerId': ownerId,
        'artworkId': artworkId,
        'markerId': markerId,
        'capturedAt': capturedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'source': <String, dynamic>{
          'path': sourcePath,
          'sampleCount': sampleCount,
          'bytes': sourceBytes,
          'hasDepth': hasDepth,
          'rawPresent': rawPresent,
          'coverage': coverageMetadata,
          'quality': qualityMetadata,
        },
        'processing': <String, dynamic>{
          'state': processingState.name,
          'target': processingTarget,
          'progress': <String, dynamic>{
            'uploadedFiles': uploadedFiles,
            'totalFiles': totalFiles,
            'uploadedBytes': uploadedBytes,
            'totalBytes': totalUploadBytes,
          },
        },
        'node': <String, dynamic>{
          'nodeId': nodeId,
          'draftId': draftId,
          'captureId': nodeCaptureId,
          'jobId': jobId,
        },
        'networkCompute': <String, dynamic>{
          'providerNodeId': networkProviderNodeId,
          'requestId': networkRequestId,
        },
        'result': <String, dynamic>{
          'manifestPath': resultManifestPath,
          'manifestCid': resultManifestCid,
          'variantPaths': resultVariantPaths,
          'thumbnailPath': thumbnailPath,
          'format': resultFormat,
          'bytes': resultBytes,
          'integrity': integrityState.name,
        },
        'publication': <String, dynamic>{
          'state': publicationState.name,
          'publicSpatialId': publicSpatialId,
          'version': version,
          'canonicalManifestCid': canonicalManifestCid,
          'canonicalRecordCid': canonicalRecordCid,
          'variantCids': variantCids,
          'publishedAt': publishedAt?.toIso8601String(),
        },
        if (lastErrorCode != null)
          'lastError': <String, dynamic>{
            'code': lastErrorCode,
            'timestamp': lastErrorAt?.toIso8601String(),
          },
      };

  factory SpatialLibraryRecord.fromJson(Map<String, dynamic> json) {
    final source = _map(json['source']);
    final processing = _map(json['processing']);
    final progress = _map(processing['progress']);
    final node = _map(json['node']);
    final network = _map(json['networkCompute']);
    final result = _map(json['result']);
    final publication = _map(json['publication']);
    final lastError = _map(json['lastError']);
    final legacyNode = node.isEmpty ? processing : node;
    final legacyResult = result.isEmpty ? processing : result;
    final capturedAt = DateTime.parse(json['capturedAt'].toString()).toUtc();
    return SpatialLibraryRecord(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      localSpatialId: _requiredString(json['localSpatialId']),
      ownerId: _optionalString(json['ownerId']),
      artworkId: _requiredString(json['artworkId']),
      markerId: _optionalString(json['markerId']),
      capturedAt: capturedAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toUtc() ??
              capturedAt,
      sourcePath: _optionalString(source['path']) ?? '',
      sampleCount: _int(source['sampleCount']),
      sourceBytes: _int(source['bytes']),
      hasDepth: source['hasDepth'] == true,
      rawPresent: source['rawPresent'] != false,
      coverageMetadata: _map(source['coverage']),
      qualityMetadata: _map(source['quality']),
      processingState: _enumByName(
        SpatialLibraryProcessingState.values,
        processing['state'],
        SpatialLibraryProcessingState.capturedPrivate,
      ),
      processingTarget: _optionalString(processing['target']),
      nodeId: _optionalString(legacyNode['nodeId']),
      draftId: _optionalString(legacyNode['draftId']),
      nodeCaptureId: _optionalString(
        legacyNode['captureId'] ?? legacyNode['nodeCaptureId'],
      ),
      jobId: _optionalString(legacyNode['jobId']),
      uploadedFiles: _int(progress['uploadedFiles']),
      totalFiles: _int(progress['totalFiles']),
      uploadedBytes: _int(progress['uploadedBytes']),
      totalUploadBytes: _int(progress['totalBytes']),
      networkProviderNodeId: _optionalString(network['providerNodeId']),
      networkRequestId: _optionalString(network['requestId']),
      resultManifestPath: _optionalString(
        legacyResult['manifestPath'] ?? legacyResult['resultManifestPath'],
      ),
      resultManifestCid: _optionalString(result['manifestCid']),
      resultVariantPaths: _stringMap(result['variantPaths']),
      thumbnailPath: _optionalString(result['thumbnailPath']),
      resultFormat: _optionalString(result['format']),
      resultBytes: _int(result['bytes']),
      integrityState: _enumByName(
        SpatialLibraryIntegrityState.values,
        result['integrity'],
        SpatialLibraryIntegrityState.pending,
      ),
      publicationState: _enumByName(
        SpatialLibraryPublicationState.values,
        publication['state'],
        publication['publicSpatialId'] == null
            ? SpatialLibraryPublicationState.private
            : SpatialLibraryPublicationState.published,
      ),
      publicSpatialId: _optionalString(publication['publicSpatialId']),
      version: publication['version'] is num
          ? (publication['version'] as num).toInt()
          : int.tryParse(publication['version']?.toString() ?? ''),
      canonicalManifestCid:
          _optionalString(publication['canonicalManifestCid']),
      canonicalRecordCid: _optionalString(publication['canonicalRecordCid']),
      variantCids: _stringMap(publication['variantCids']),
      publishedAt: DateTime.tryParse(
        publication['publishedAt']?.toString() ?? '',
      )?.toUtc(),
      lastErrorCode: _optionalString(lastError['code']),
      lastErrorAt: DateTime.tryParse(
        lastError['timestamp']?.toString() ?? '',
      )?.toUtc(),
    );
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static Map<String, String> _stringMap(Object? value) => value is Map
      ? value.map((key, value) => MapEntry(key.toString(), value.toString()))
      : <String, String>{};
  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
  static String _requiredString(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) throw const FormatException('Required spatial field');
    return text;
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    Object? value,
    T fallback,
  ) =>
      values.where((item) => item.name == value?.toString()).firstOrNull ??
      fallback;
}

/// The phone's durable private spatial source library.
///
/// Processing and publication only add metadata or derived results. The
/// explicit deletion methods are the only paths that remove meaningful data.
class SpatialLibraryStore {
  SpatialLibraryStore({Directory? root}) : _root = root;

  static const int schemaVersion = 2;
  static const String rootFolderName = 'spatial-library';
  static const String _recordName = 'record.json';

  final Directory? _root;
  final Map<String, Future<void>> _recordLocks = <String, Future<void>>{};

  Future<Directory> root() async {
    final base = _root ??
        Directory(
          p.join(
            (await getApplicationSupportDirectory()).path,
            rootFolderName,
          ),
        );
    await base.create(recursive: true);
    return base;
  }

  Future<Directory> recordDirectory(String localSpatialId) async => Directory(
        p.join((await root()).path, _safeId(localSpatialId)),
      );

  Future<SpatialLibraryRecord> promoteCapture(
    SpatialCaptureStore capture, {
    Map<String, dynamic> coverageMetadata = const <String, dynamic>{},
    Map<String, dynamic> qualityMetadata = const <String, dynamic>{},
  }) =>
      _withRecordLock(capture.captureId, () async {
        final existing = await _getUnlocked(capture.captureId);
        if (existing != null) return existing;
        final folder = await recordDirectory(capture.captureId);
        await folder.create(recursive: true);
        final source = Directory(p.join(folder.path, 'source'));
        if (!await source.exists()) {
          if (!await capture.directory.exists()) {
            throw StateError('Capture source disappeared before promotion.');
          }
          await capture.directory.rename(source.path);
        }
        final reopened = await SpatialCaptureStore.open(source);
        if (reopened == null || reopened.sampleCount == 0) {
          throw StateError('Capture source is not readable.');
        }
        final thumbnailPath = await _createThumbnail(folder, reopened);
        final now = DateTime.now().toUtc();
        final record = SpatialLibraryRecord(
          localSpatialId: reopened.captureId,
          ownerId: reopened.capturedBy,
          artworkId: reopened.artworkId,
          markerId: reopened.markerId,
          capturedAt: reopened.startedAt,
          updatedAt: now,
          sourcePath: source.path,
          sampleCount: reopened.sampleCount,
          sourceBytes: reopened.bytesWritten,
          hasDepth: reopened.depthObserved,
          rawPresent: true,
          coverageMetadata: coverageMetadata,
          qualityMetadata: qualityMetadata,
          processingState: SpatialLibraryProcessingState.capturedPrivate,
          draftId: reopened.draftId,
          thumbnailPath: thumbnailPath,
        );
        await _saveUnlocked(record);
        return record;
      });

  Future<List<SpatialLibraryRecord>> migrateLegacy(
    Directory captureRoot,
  ) async {
    if (!await captureRoot.exists()) return const <SpatialLibraryRecord>[];
    final migrated = <SpatialLibraryRecord>[];
    await for (final entity in captureRoot.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final capture = await SpatialCaptureStore.open(entity);
      if (capture == null || capture.sampleCount == 0) continue;
      if (await get(capture.captureId) != null) continue;
      try {
        migrated.add(await promoteCapture(capture));
      } on FileSystemException {
        // The original remains untouched after a collision/interruption.
      }
    }
    return migrated;
  }

  Future<void> save(SpatialLibraryRecord record) =>
      _withRecordLock(record.localSpatialId, () => _saveUnlocked(record));
  Future<SpatialLibraryRecord?> get(String localSpatialId) =>
      _withRecordLock(localSpatialId, () => _getUnlocked(localSpatialId));

  Future<List<SpatialLibraryRecord>> list() async {
    final entries = await (await root()).list(followLinks: false).toList();
    final records = <SpatialLibraryRecord>[];
    for (final entry in entries.whereType<Directory>()) {
      final record = await get(p.basename(entry.path));
      if (record != null) records.add(record);
    }
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  Future<SpatialLibraryRecord> updateProcessing(
    String localSpatialId,
    SpatialLibraryProcessingState state, {
    String? target,
    bool clearError = true,
  }) =>
      _mutate(
        localSpatialId,
        (record) => record.copyWith(
          processingState: state,
          processingTarget: target,
          lastErrorCode: clearError ? null : _notSet,
          lastErrorAt: clearError ? null : _notSet,
        ),
      );

  Future<SpatialLibraryRecord> recordNodeTransfer(
    String localSpatialId, {
    String? nodeId,
    Object? draftId = _notSet,
    Object? nodeCaptureId = _notSet,
    int? uploadedFiles,
    int? totalFiles,
    int? uploadedBytes,
    int? totalBytes,
  }) =>
      _mutate(
        localSpatialId,
        (record) => record.copyWith(
          nodeId: nodeId,
          draftId: draftId,
          nodeCaptureId: nodeCaptureId,
          uploadedFiles: uploadedFiles,
          totalFiles: totalFiles,
          uploadedBytes: uploadedBytes,
          totalUploadBytes: totalBytes,
        ),
      );

  Future<SpatialLibraryRecord> recordJob(
    String localSpatialId, {
    Object? jobId = _notSet,
    Object? networkProviderNodeId = _notSet,
    Object? networkRequestId = _notSet,
    SpatialLibraryProcessingState? state,
  }) =>
      _mutate(
        localSpatialId,
        (record) => record.copyWith(
          jobId: jobId,
          networkProviderNodeId: networkProviderNodeId,
          networkRequestId: networkRequestId,
          processingState: state,
        ),
      );

  Future<SpatialLibraryRecord> recordResult(
    String localSpatialId, {
    required String manifestPath,
    required String manifestCid,
    required Map<String, String> variantPaths,
    required int bytes,
    required String format,
    String? thumbnailPath,
    SpatialLibraryIntegrityState integrity = SpatialLibraryIntegrityState.valid,
  }) =>
      _mutate(
        localSpatialId,
        (record) => record.copyWith(
          processingState: SpatialLibraryProcessingState.readyPrivate,
          resultManifestPath: manifestPath,
          resultManifestCid: manifestCid,
          resultVariantPaths: variantPaths,
          resultBytes: bytes,
          resultFormat: format,
          thumbnailPath: thumbnailPath ?? record.thumbnailPath,
          integrityState: integrity,
          lastErrorCode: null,
          lastErrorAt: null,
        ),
      );

  Future<SpatialLibraryRecord> recordPublication(
    String localSpatialId, {
    required SpatialLibraryPublicationState state,
    String? publicSpatialId,
    int? version,
    String? canonicalManifestCid,
    String? canonicalRecordCid,
    Map<String, String>? variantCids,
    DateTime? publishedAt,
  }) =>
      _mutate(
        localSpatialId,
        (record) => record.copyWith(
          processingState: state == SpatialLibraryPublicationState.published
              ? SpatialLibraryProcessingState.published
              : state == SpatialLibraryPublicationState.publishing
                  ? SpatialLibraryProcessingState.publishing
                  : null,
          publicationState: state,
          publicSpatialId: publicSpatialId,
          version: version,
          canonicalManifestCid: canonicalManifestCid,
          canonicalRecordCid: canonicalRecordCid,
          variantCids: variantCids,
          publishedAt: publishedAt,
        ),
      );

  Future<SpatialLibraryRecord> recordFailure(
    String localSpatialId, {
    required String code,
    bool waitingForProcessor = false,
  }) =>
      _mutate(
        localSpatialId,
        (record) => record.copyWith(
          processingState: waitingForProcessor
              ? SpatialLibraryProcessingState.waitingForProcessor
              : SpatialLibraryProcessingState.failedRetryable,
          lastErrorCode: code,
          lastErrorAt: DateTime.now().toUtc(),
        ),
      );

  Future<SpatialLibraryRecord> deleteRaw(String localSpatialId) =>
      _withRecordLock(localSpatialId, () async {
        final record = await _requireUnlocked(localSpatialId);
        if (record.rawPresent && record.sourcePath.isNotEmpty) {
          final source = Directory(record.sourcePath);
          if (await source.exists()) await source.delete(recursive: true);
        }
        final next = record.copyWith(
          sourcePath: '',
          sourceBytes: 0,
          rawPresent: false,
          updatedAt: DateTime.now().toUtc(),
        );
        await _saveUnlocked(next);
        return next;
      });

  Future<SpatialLibraryRecord> deleteProcessed(String localSpatialId) =>
      _withRecordLock(localSpatialId, () async {
        final record = await _requireUnlocked(localSpatialId);
        final folder = await recordDirectory(localSpatialId);
        final result = Directory(p.join(folder.path, 'result'));
        if (await result.exists()) await result.delete(recursive: true);
        final next = record.copyWith(
          processingState: record.publicationState ==
                  SpatialLibraryPublicationState.published
              ? SpatialLibraryProcessingState.published
              : SpatialLibraryProcessingState.capturedPrivate,
          resultManifestPath: null,
          resultManifestCid: null,
          resultVariantPaths: const <String, String>{},
          resultBytes: 0,
          resultFormat: null,
          integrityState: SpatialLibraryIntegrityState.pending,
          updatedAt: DateTime.now().toUtc(),
        );
        await _saveUnlocked(next);
        return next;
      });

  /// Removes only the phone record. It never unpublishes a public archive.
  Future<void> deleteRecord(String localSpatialId) =>
      _withRecordLock(localSpatialId, () async {
        final folder = await recordDirectory(localSpatialId);
        if (await folder.exists()) await folder.delete(recursive: true);
      });

  Future<SpatialLibraryRecord> _mutate(
    String localSpatialId,
    SpatialLibraryRecord Function(SpatialLibraryRecord current) change,
  ) =>
      _withRecordLock(localSpatialId, () async {
        final current = await _requireUnlocked(localSpatialId);
        final next =
            change(current).copyWith(updatedAt: DateTime.now().toUtc());
        await _saveUnlocked(next);
        return next;
      });

  Future<SpatialLibraryRecord> _requireUnlocked(String localSpatialId) async {
    final record = await _getUnlocked(localSpatialId);
    if (record == null) throw StateError('Spatial Library record not found.');
    return record;
  }

  Future<SpatialLibraryRecord?> _getUnlocked(String localSpatialId) async {
    final folder = await recordDirectory(localSpatialId);
    final recovered =
        await _recoverRecord(File(p.join(folder.path, _recordName)));
    if (recovered == null) return null;
    try {
      return SpatialLibraryRecord.fromJson(
        jsonDecode(await recovered.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveUnlocked(SpatialLibraryRecord record) async {
    final folder = await recordDirectory(record.localSpatialId);
    await folder.create(recursive: true);
    await _atomicJson(File(p.join(folder.path, _recordName)), record.toJson());
  }

  Future<File?> _recoverRecord(File destination) async {
    final temporary = File('${destination.path}.tmp');
    final backup = File('${destination.path}.bak');
    if (await _isValidRecord(destination)) {
      if (await temporary.exists()) await temporary.delete();
      if (await backup.exists()) await backup.delete();
      return destination;
    }
    for (final candidate in <File>[temporary, backup]) {
      if (!await _isValidRecord(candidate)) continue;
      if (await destination.exists()) {
        await destination.rename(
          '${destination.path}.corrupt-${DateTime.now().microsecondsSinceEpoch}',
        );
      }
      await candidate.rename(destination.path);
      return destination;
    }
    return null;
  }

  Future<bool> _isValidRecord(File file) async {
    if (!await file.exists()) return false;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return false;
      SpatialLibraryRecord.fromJson(decoded);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _atomicJson(
    File destination,
    Map<String, dynamic> value,
  ) async {
    final temporary = File('${destination.path}.tmp');
    final backup = File('${destination.path}.bak');
    await destination.parent.create(recursive: true);
    await temporary.writeAsString(jsonEncode(value), flush: true);
    if (await backup.exists()) await backup.delete();
    if (await destination.exists()) await destination.rename(backup.path);
    try {
      await temporary.rename(destination.path);
    } catch (_) {
      if (!await destination.exists() && await backup.exists()) {
        await backup.rename(destination.path);
      }
      rethrow;
    }
    if (await backup.exists()) await backup.delete();
  }

  Future<String?> _createThumbnail(
    Directory recordFolder,
    SpatialCaptureStore capture,
  ) async {
    if (capture.samples.isEmpty) return null;
    final source = capture.fileAt(capture.samples.first.rgbPath);
    try {
      final decoded = image_lib.decodeImage(await source.readAsBytes());
      if (decoded == null) return null;
      final thumbnail = decoded.width > 320
          ? image_lib.copyResize(decoded, width: 320)
          : decoded;
      final target = File(p.join(recordFolder.path, 'thumbnail.jpg'));
      await target.writeAsBytes(
        image_lib.encodeJpg(thumbnail, quality: 76),
        flush: true,
      );
      return target.path;
    } catch (_) {
      return null;
    }
  }

  Future<T> _withRecordLock<T>(
    String localSpatialId,
    Future<T> Function() action,
  ) async {
    final id = _safeId(localSpatialId);
    final previous = _recordLocks[id] ?? Future<void>.value();
    final completion = Completer<void>();
    final pending = completion.future;
    _recordLocks[id] = pending;
    await previous;
    try {
      return await action();
    } finally {
      completion.complete();
      if (identical(_recordLocks[id], pending)) _recordLocks.remove(id);
    }
  }

  static String _safeId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed == '.' ||
        trimmed == '..' ||
        p.basename(trimmed) != trimmed ||
        trimmed.contains('/') ||
        trimmed.contains(r'\')) {
      throw ArgumentError.value(value, 'localSpatialId', 'invalid identifier');
    }
    return trimmed;
  }
}
