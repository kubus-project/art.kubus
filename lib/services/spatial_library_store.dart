import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

/// Durable lifecycle of a request for network (non-owned) compute.
///
/// Network compute is asynchronous and may outlive the process, so the request
/// is persisted rather than derived from whichever providers happen to answer
/// a discovery call at the moment a sheet is opened.
enum SpatialNetworkRequestState {
  /// The user asked for network processing. No provider has been contacted.
  networkRequested,

  /// Actively looking for a provider that can take the job.
  searchingProvider,

  /// A provider has been matched and its terms are known.
  providerOffered,

  /// The provider accepted the job.
  providerAccepted,

  /// Waiting in the provider's queue.
  queued,

  /// The provider is reconstructing.
  processing,

  /// The result is being verified against its manifest.
  verifying,

  /// The verified result is being pulled back to the phone.
  downloading,

  /// The result landed and was imported.
  complete,

  /// The provider or the transport failed. Retryable.
  failed,

  /// The request aged out before a provider took it.
  expired,

  /// The user withdrew the request.
  cancelled,
}

extension SpatialNetworkRequestStateX on SpatialNetworkRequestState {
  /// Whether the request is still live and should be resumed after a restart.
  bool get isActive => const <SpatialNetworkRequestState>{
        SpatialNetworkRequestState.networkRequested,
        SpatialNetworkRequestState.searchingProvider,
        SpatialNetworkRequestState.providerOffered,
        SpatialNetworkRequestState.providerAccepted,
        SpatialNetworkRequestState.queued,
        SpatialNetworkRequestState.processing,
        SpatialNetworkRequestState.verifying,
        SpatialNetworkRequestState.downloading,
      }.contains(this);

  /// Whether the user may still withdraw the request. Once the verified bytes
  /// are moving back to the phone there is nothing useful left to cancel.
  bool get isCancellable => const <SpatialNetworkRequestState>{
        SpatialNetworkRequestState.networkRequested,
        SpatialNetworkRequestState.searchingProvider,
        SpatialNetworkRequestState.providerOffered,
        SpatialNetworkRequestState.providerAccepted,
        SpatialNetworkRequestState.queued,
        SpatialNetworkRequestState.processing,
      }.contains(this);
}

/// A persisted request for network compute, carrying only what the protocol
/// has actually reported about the provider. Nothing here is estimated
/// locally: a null estimate means the protocol did not offer one.
@immutable
class SpatialNetworkRequest {
  const SpatialNetworkRequest({
    required this.state,
    required this.requestedAt,
    this.updatedAt,
    this.requestId,
    this.jobId,
    this.providerNodeId,
    this.providerLabel,
    this.providerTier,
    this.estimatedDurationSeconds,
    this.estimatedCostKub8,
    this.queuedAhead,
    this.failureCode,
  });

  final SpatialNetworkRequestState state;
  final DateTime requestedAt;
  final DateTime? updatedAt;

  /// Local correlation id, stable across restarts and provider changes.
  final String? requestId;

  /// Remote compute job id, once a provider has accepted.
  final String? jobId;

  final String? providerNodeId;
  final String? providerLabel;
  final String? providerTier;

  final int? estimatedDurationSeconds;
  final double? estimatedCostKub8;
  final int? queuedAhead;

  final String? failureCode;

  bool get isActive => state.isActive;
  bool get isCancellable => state.isCancellable;

  SpatialNetworkRequest copyWith({
    SpatialNetworkRequestState? state,
    DateTime? requestedAt,
    Object? updatedAt = _notSet,
    Object? requestId = _notSet,
    Object? jobId = _notSet,
    Object? providerNodeId = _notSet,
    Object? providerLabel = _notSet,
    Object? providerTier = _notSet,
    Object? estimatedDurationSeconds = _notSet,
    Object? estimatedCostKub8 = _notSet,
    Object? queuedAhead = _notSet,
    Object? failureCode = _notSet,
  }) =>
      SpatialNetworkRequest(
        state: state ?? this.state,
        requestedAt: requestedAt ?? this.requestedAt,
        updatedAt: identical(updatedAt, _notSet)
            ? this.updatedAt
            : updatedAt as DateTime?,
        requestId: identical(requestId, _notSet)
            ? this.requestId
            : requestId as String?,
        jobId: identical(jobId, _notSet) ? this.jobId : jobId as String?,
        providerNodeId: identical(providerNodeId, _notSet)
            ? this.providerNodeId
            : providerNodeId as String?,
        providerLabel: identical(providerLabel, _notSet)
            ? this.providerLabel
            : providerLabel as String?,
        providerTier: identical(providerTier, _notSet)
            ? this.providerTier
            : providerTier as String?,
        estimatedDurationSeconds: identical(estimatedDurationSeconds, _notSet)
            ? this.estimatedDurationSeconds
            : estimatedDurationSeconds as int?,
        estimatedCostKub8: identical(estimatedCostKub8, _notSet)
            ? this.estimatedCostKub8
            : estimatedCostKub8 as double?,
        queuedAhead: identical(queuedAhead, _notSet)
            ? this.queuedAhead
            : queuedAhead as int?,
        failureCode: identical(failureCode, _notSet)
            ? this.failureCode
            : failureCode as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'state': state.name,
        'requestedAt': requestedAt.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        if (requestId != null) 'requestId': requestId,
        if (jobId != null) 'jobId': jobId,
        if (providerNodeId != null) 'providerNodeId': providerNodeId,
        if (providerLabel != null) 'providerLabel': providerLabel,
        if (providerTier != null) 'providerTier': providerTier,
        if (estimatedDurationSeconds != null)
          'estimatedDurationSeconds': estimatedDurationSeconds,
        if (estimatedCostKub8 != null) 'estimatedCostKub8': estimatedCostKub8,
        if (queuedAhead != null) 'queuedAhead': queuedAhead,
        if (failureCode != null) 'failureCode': failureCode,
      };

  /// Returns null for a payload with no recognizable state, so an unreadable
  /// request degrades to "no request" instead of a fabricated one.
  static SpatialNetworkRequest? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final rawState = value['state']?.toString();
    final state = SpatialNetworkRequestState.values
        .where((item) => item.name == rawState)
        .firstOrNull;
    if (state == null) return null;
    return SpatialNetworkRequest(
      state: state,
      requestedAt:
          DateTime.tryParse(value['requestedAt']?.toString() ?? '')?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt:
          DateTime.tryParse(value['updatedAt']?.toString() ?? '')?.toUtc(),
      requestId: SpatialLibraryRecord._optionalString(value['requestId']),
      jobId: SpatialLibraryRecord._optionalString(value['jobId']),
      providerNodeId:
          SpatialLibraryRecord._optionalString(value['providerNodeId']),
      providerLabel:
          SpatialLibraryRecord._optionalString(value['providerLabel']),
      providerTier: SpatialLibraryRecord._optionalString(value['providerTier']),
      estimatedDurationSeconds: _optionalInt(value['estimatedDurationSeconds']),
      estimatedCostKub8: _optionalDouble(value['estimatedCostKub8']),
      queuedAhead: _optionalInt(value['queuedAhead']),
      failureCode: SpatialLibraryRecord._optionalString(value['failureCode']),
    );
  }

  static int? _optionalInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  static double? _optionalDouble(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
}

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
    this.displayName,
    this.note,
    this.artworkTitleSnapshot,
    this.artistNameSnapshot,
    this.markerLabelSnapshot,
    this.revision = 1,
    this.parentLocalSpatialId,
    this.parentPublicVersion,
    this.resultStale = false,
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
    this.networkRequest,
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

  /// Optional user-chosen local name. Identity never depends on it and it is
  /// never pushed into the public archive.
  final String? displayName;

  /// Optional private note.
  final String? note;

  /// Display-only association snapshots, for offline and broken-reference
  /// rendering. Never used to resolve, match, or relink a record.
  final String? artworkTitleSnapshot;
  final String? artistNameSnapshot;
  final String? markerLabelSnapshot;

  /// Local revision number within this capture lineage. Starts at 1.
  final int revision;

  /// The record this revision was branched from, if any.
  final String? parentLocalSpatialId;

  /// The public version the branch was taken from, if any.
  final int? parentPublicVersion;

  /// True once more capture data landed after the processed result, so the
  /// result no longer describes the source it claims to.
  final bool resultStale;

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

  /// Durable network-compute request, independent of whether a provider
  /// happens to be discoverable right now.
  final SpatialNetworkRequest? networkRequest;

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

  /// A result exists but no longer matches the source it was built from.
  bool get hasStaleResult => hasLocalResult && resultStale;

  /// A result exists and still describes the current source.
  bool get hasCurrentResult => hasLocalResult && !resultStale;

  bool get isPublished =>
      publicationState == SpatialLibraryPublicationState.published;

  /// True while a processing or publication step owns the record.
  bool get isBusy => const <SpatialLibraryProcessingState>{
        SpatialLibraryProcessingState.uploading,
        SpatialLibraryProcessingState.queued,
        SpatialLibraryProcessingState.processing,
        SpatialLibraryProcessingState.downloadingResult,
        SpatialLibraryProcessingState.publishing,
      }.contains(processingState);

  /// True while a persisted network request is still live, even when nothing
  /// is running locally and no provider has been matched yet.
  bool get hasActiveNetworkRequest => networkRequest?.isActive == true;

  /// Whether the raw source can still be reopened for more sampling.
  bool get canContinueCapture =>
      rawPresent &&
      sourcePath.isNotEmpty &&
      !isBusy &&
      !hasActiveNetworkRequest;

  SpatialLibraryRecord copyWith({
    int? schemaVersion,
    String? localSpatialId,
    String? artworkId,
    Object? ownerId = _notSet,
    Object? markerId = _notSet,
    Object? displayName = _notSet,
    Object? note = _notSet,
    Object? artworkTitleSnapshot = _notSet,
    Object? artistNameSnapshot = _notSet,
    Object? markerLabelSnapshot = _notSet,
    int? revision,
    Object? parentLocalSpatialId = _notSet,
    Object? parentPublicVersion = _notSet,
    bool? resultStale,
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
    Object? networkRequest = _notSet,
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
        displayName: identical(displayName, _notSet)
            ? this.displayName
            : displayName as String?,
        note: identical(note, _notSet) ? this.note : note as String?,
        artworkTitleSnapshot: identical(artworkTitleSnapshot, _notSet)
            ? this.artworkTitleSnapshot
            : artworkTitleSnapshot as String?,
        artistNameSnapshot: identical(artistNameSnapshot, _notSet)
            ? this.artistNameSnapshot
            : artistNameSnapshot as String?,
        markerLabelSnapshot: identical(markerLabelSnapshot, _notSet)
            ? this.markerLabelSnapshot
            : markerLabelSnapshot as String?,
        revision: revision ?? this.revision,
        parentLocalSpatialId: identical(parentLocalSpatialId, _notSet)
            ? this.parentLocalSpatialId
            : parentLocalSpatialId as String?,
        parentPublicVersion: identical(parentPublicVersion, _notSet)
            ? this.parentPublicVersion
            : parentPublicVersion as int?,
        resultStale: resultStale ?? this.resultStale,
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
        networkRequest: identical(networkRequest, _notSet)
            ? this.networkRequest
            : networkRequest as SpatialNetworkRequest?,
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
        'local': <String, dynamic>{
          'displayName': displayName,
          'note': note,
        },
        'association': <String, dynamic>{
          'artworkTitle': artworkTitleSnapshot,
          'artistName': artistNameSnapshot,
          'markerLabel': markerLabelSnapshot,
        },
        'lineage': <String, dynamic>{
          'revision': revision,
          'parentLocalSpatialId': parentLocalSpatialId,
          'parentPublicVersion': parentPublicVersion,
        },
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
          if (networkRequest != null) 'request': networkRequest!.toJson(),
        },
        'result': <String, dynamic>{
          'manifestPath': resultManifestPath,
          'manifestCid': resultManifestCid,
          'variantPaths': resultVariantPaths,
          'thumbnailPath': thumbnailPath,
          'format': resultFormat,
          'bytes': resultBytes,
          'integrity': integrityState.name,
          'stale': resultStale,
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
    final local = _map(json['local']);
    final association = _map(json['association']);
    final lineage = _map(json['lineage']);
    final legacyNode = node.isEmpty ? processing : node;
    final legacyResult = result.isEmpty ? processing : result;
    final capturedAt = DateTime.parse(json['capturedAt'].toString()).toUtc();
    return SpatialLibraryRecord(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      localSpatialId: _requiredString(json['localSpatialId']),
      ownerId: _optionalString(json['ownerId']),
      artworkId: _requiredString(json['artworkId']),
      markerId: _optionalString(json['markerId']),
      displayName: _optionalString(local['displayName']),
      note: _optionalString(local['note']),
      artworkTitleSnapshot: _optionalString(association['artworkTitle']),
      artistNameSnapshot: _optionalString(association['artistName']),
      markerLabelSnapshot: _optionalString(association['markerLabel']),
      revision: _positiveInt(lineage['revision'], fallback: 1),
      parentLocalSpatialId: _optionalString(lineage['parentLocalSpatialId']),
      parentPublicVersion: lineage['parentPublicVersion'] is num
          ? (lineage['parentPublicVersion'] as num).toInt()
          : int.tryParse(lineage['parentPublicVersion']?.toString() ?? ''),
      resultStale: result['stale'] == true,
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
      networkRequest: SpatialNetworkRequest.tryFromJson(network['request']),
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

  static int _positiveInt(Object? value, {required int fallback}) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? fallback;
    return parsed < 1 ? fallback : parsed;
  }

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
  SpatialLibraryStore({
    Directory? root,
    @visibleForTesting
    Future<void> Function(SpatialLibraryRecord record)? beforeRecordCommit,
  })  : _root = root,
        _beforeRecordCommit = beforeRecordCommit;

  /// 3 adds the local display name/note, the association snapshots, the
  /// revision lineage, the stale-result flag, and the durable network compute
  /// request. Every added field is optional with a safe default, so a v1/v2
  /// record upgrades in place and no capture is ever discarded.
  static const int schemaVersion = 3;
  static const String rootFolderName = 'spatial-library';
  static const String _recordName = 'record.json';

  final Directory? _root;
  final Future<void> Function(SpatialLibraryRecord record)? _beforeRecordCommit;
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
    String? artworkTitleSnapshot,
    String? artistNameSnapshot,
    String? markerLabelSnapshot,
    int revision = 1,
    String? parentLocalSpatialId,
    int? parentPublicVersion,
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
          final staging = Directory('${source.path}.tmp');
          if (await staging.exists()) await staging.delete(recursive: true);
          await _copyDirectory(capture.directory, staging);
          final stagedCapture = await SpatialCaptureStore.open(staging);
          if (stagedCapture == null || stagedCapture.sampleCount == 0) {
            throw StateError('Copied capture source is not readable.');
          }
          await staging.rename(source.path);
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
          artworkTitleSnapshot: artworkTitleSnapshot,
          artistNameSnapshot: artistNameSnapshot,
          markerLabelSnapshot: markerLabelSnapshot,
          revision: revision < 1 ? 1 : revision,
          parentLocalSpatialId: parentLocalSpatialId,
          parentPublicVersion: parentPublicVersion,
        );
        await _beforeRecordCommit?.call(record);
        await _saveUnlocked(record);
        if (p.normalize(capture.directory.path) != p.normalize(source.path) &&
            await capture.directory.exists()) {
          await capture.directory.delete(recursive: true);
        }
        return record;
      });

  Future<List<SpatialLibraryRecord>> recoverInterruptedProcessing() async {
    final recovered = <SpatialLibraryRecord>[];
    for (final record in await list()) {
      final (state, code, publicationState) = switch (record.processingState) {
        SpatialLibraryProcessingState.uploading => (
            SpatialLibraryProcessingState.waitingForProcessor,
            'upload_interrupted',
            record.publicationState,
          ),
        SpatialLibraryProcessingState.queued ||
        SpatialLibraryProcessingState.processing =>
          (
            SpatialLibraryProcessingState.failedRetryable,
            'processing_interrupted',
            record.publicationState,
          ),
        SpatialLibraryProcessingState.downloadingResult => (
            SpatialLibraryProcessingState.failedRetryable,
            'result_download_interrupted',
            record.publicationState,
          ),
        SpatialLibraryProcessingState.publishing => (
            SpatialLibraryProcessingState.readyPrivate,
            'publication_interrupted',
            SpatialLibraryPublicationState.failed,
          ),
        _ => (record.processingState, null, record.publicationState),
      };
      if (code == null) continue;
      recovered.add(await _mutate(
        record.localSpatialId,
        (current) => current.copyWith(
          processingState: state,
          publicationState: publicationState,
          lastErrorCode: code,
          lastErrorAt: DateTime.now().toUtc(),
        ),
      ));
    }
    return recovered;
  }

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

  /// Repoints a record at a different artwork and/or marker.
  ///
  /// The stored ids are the authority, so this is the only way an association
  /// changes — nothing else in the app may relink a record, and a published
  /// record is never repointed in place (the caller branches a revision).
  Future<SpatialLibraryRecord> updateAssociation(
    String localSpatialId, {
    required String artworkId,
    Object? markerId = _notSet,
    Object? artworkTitleSnapshot = _notSet,
    Object? artistNameSnapshot = _notSet,
    Object? markerLabelSnapshot = _notSet,
  }) {
    final target = artworkId.trim();
    if (target.isEmpty) {
      throw ArgumentError.value(artworkId, 'artworkId', 'must not be empty');
    }
    return _mutate(
      localSpatialId,
      (record) {
        if (record.isPublished) {
          // Rewriting a published record's association would silently change
          // what the public archive claims to depict.
          throw StateError('published_association_immutable');
        }
        return record.copyWith(
          artworkId: target,
          markerId: markerId,
          artworkTitleSnapshot: artworkTitleSnapshot,
          artistNameSnapshot: artistNameSnapshot,
          markerLabelSnapshot: markerLabelSnapshot,
        );
      },
    );
  }

  /// Updates only device-local, user-authored metadata.
  ///
  /// Technical facts (sample counts, capture time, byte totals, CIDs) are not
  /// reachable from here: they describe what happened, not what the user
  /// wants it called.
  Future<SpatialLibraryRecord> updateLocalMetadata(
    String localSpatialId, {
    Object? displayName = _notSet,
    Object? note = _notSet,
  }) =>
      _mutate(
        localSpatialId,
        (record) => record.copyWith(
          displayName: _normalizeOptional(displayName),
          note: _normalizeOptional(note),
        ),
      );

  /// Folds additional capture data back into an existing record.
  ///
  /// A processed result that predates the new samples is kept — it may still
  /// be the only thing the user can look at — but is marked stale so nothing
  /// presents or publishes it as current.
  Future<SpatialLibraryRecord> applyContinuedCapture(
    String localSpatialId, {
    required int sampleCount,
    required int sourceBytes,
    required bool hasDepth,
    Map<String, dynamic> coverageMetadata = const <String, dynamic>{},
    Map<String, dynamic> qualityMetadata = const <String, dynamic>{},
  }) =>
      _mutate(
        localSpatialId,
        (record) {
          final gainedSamples = sampleCount > record.sampleCount;
          return record.copyWith(
            sampleCount: sampleCount,
            sourceBytes: sourceBytes,
            hasDepth: hasDepth || record.hasDepth,
            rawPresent: true,
            coverageMetadata: coverageMetadata.isEmpty
                ? record.coverageMetadata
                : coverageMetadata,
            qualityMetadata: qualityMetadata.isEmpty
                ? record.qualityMetadata
                : qualityMetadata,
            resultStale: record.hasLocalResult
                ? record.resultStale || gainedSamples
                : false,
            processingState: record.hasLocalResult && gainedSamples
                ? (record.isPublished
                    ? SpatialLibraryProcessingState.published
                    : SpatialLibraryProcessingState.capturedPrivate)
                : record.processingState,
            // New source means the node-side copy no longer matches.
            nodeCaptureId: gainedSamples ? null : _notSet,
            draftId: gainedSamples ? null : _notSet,
            uploadedFiles: gainedSamples ? 0 : null,
            uploadedBytes: gainedSamples ? 0 : null,
            lastErrorCode: null,
            lastErrorAt: null,
          );
        },
      );

  /// Branches a new private draft from an existing record.
  ///
  /// The parent is never touched: a published archive stays published and
  /// immutable, and the branch starts with a private copy of the parent's raw
  /// source so the user extends the capture rather than starting over.
  Future<SpatialLibraryRecord> createRevision(
    String parentLocalSpatialId, {
    required String newLocalSpatialId,
  }) async {
    final parent = await get(parentLocalSpatialId);
    if (parent == null) throw StateError('record_missing');
    if (!parent.rawPresent || parent.sourcePath.isEmpty) {
      throw StateError('raw_source_required');
    }
    return _withRecordLock(newLocalSpatialId, () async {
      final existing = await _getUnlocked(newLocalSpatialId);
      if (existing != null) return existing;
      final folder = await recordDirectory(newLocalSpatialId);
      await folder.create(recursive: true);
      final source = Directory(p.join(folder.path, 'source'));
      final staging = Directory('${source.path}.tmp');
      if (await staging.exists()) await staging.delete(recursive: true);
      await _copyDirectory(Directory(parent.sourcePath), staging);
      final staged = await SpatialCaptureStore.open(staging);
      if (staged == null || staged.sampleCount == 0) {
        await staging.delete(recursive: true);
        throw StateError('raw_source_unreadable');
      }
      // The branch is a fresh capture identity: it must never resume the
      // parent's node draft or claim the parent's committed capture.
      await staged.recordDraftId(null);
      if (await source.exists()) await source.delete(recursive: true);
      await staging.rename(source.path);
      final reopened = await SpatialCaptureStore.open(source);
      if (reopened == null) throw StateError('raw_source_unreadable');
      final now = DateTime.now().toUtc();
      final record = SpatialLibraryRecord(
        localSpatialId: newLocalSpatialId,
        ownerId: parent.ownerId,
        artworkId: parent.artworkId,
        markerId: parent.markerId,
        displayName: parent.displayName,
        artworkTitleSnapshot: parent.artworkTitleSnapshot,
        artistNameSnapshot: parent.artistNameSnapshot,
        markerLabelSnapshot: parent.markerLabelSnapshot,
        revision: parent.revision + 1,
        parentLocalSpatialId: parent.localSpatialId,
        parentPublicVersion: parent.version,
        capturedAt: now,
        updatedAt: now,
        sourcePath: source.path,
        sampleCount: reopened.sampleCount,
        sourceBytes: reopened.bytesWritten,
        hasDepth: reopened.depthObserved,
        rawPresent: true,
        coverageMetadata: parent.coverageMetadata,
        qualityMetadata: parent.qualityMetadata,
        processingState: SpatialLibraryProcessingState.capturedPrivate,
        thumbnailPath: await _createThumbnail(folder, reopened),
      );
      await _beforeRecordCommit?.call(record);
      await _saveUnlocked(record);
      return record;
    });
  }

  /// Persists a network compute request so it survives an app restart.
  Future<SpatialLibraryRecord> recordNetworkRequest(
    String localSpatialId,
    SpatialNetworkRequest request, {
    SpatialLibraryProcessingState? processingState,
  }) =>
      _mutate(
        localSpatialId,
        (record) => record.copyWith(
          networkRequest: request,
          networkProviderNodeId: request.providerNodeId,
          // The flat field keeps its long-standing meaning: the remote compute
          // job id. The local correlation id lives inside the request.
          networkRequestId: request.jobId ?? record.networkRequestId,
          jobId: request.jobId ?? record.jobId,
          processingState: processingState,
          processingTarget: 'networkGpu',
        ),
      );

  /// Drops the persisted network request without touching capture data.
  Future<SpatialLibraryRecord> clearNetworkRequest(String localSpatialId) =>
      _mutate(
        localSpatialId,
        (record) => record.copyWith(
          networkRequest: null,
          networkProviderNodeId: null,
          networkRequestId: null,
        ),
      );

  static Object? _normalizeOptional(Object? value) {
    if (identical(value, _notSet)) return _notSet;
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
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
    Object? nodeId = _notSet,
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

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final targetPath = p.join(destination.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      }
    }
  }

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
          // A fresh result describes the source as it stands now.
          resultStale: false,
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
          resultStale: false,
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
    SpatialLibraryRecord record;
    try {
      record = SpatialLibraryRecord.fromJson(
        jsonDecode(await recovered.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
    return _migrate(record);
  }

  /// Upgrades an older record in place.
  ///
  /// Every field added since v1 is optional with a safe default, so the
  /// migration is a version stamp rather than a rewrite. Nothing is dropped
  /// and nothing is guessed: an old record that predates the association
  /// snapshots simply has none, and the UI resolves the live artwork instead.
  ///
  /// A failed write is not fatal — the in-memory record is already correct, so
  /// the library stays usable and the stamp is retried on the next read.
  Future<SpatialLibraryRecord> _migrate(SpatialLibraryRecord record) async {
    if (record.schemaVersion >= schemaVersion) return record;
    final upgraded = record.copyWith(schemaVersion: schemaVersion);
    try {
      await _saveUnlocked(upgraded);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SpatialLibraryStore: schema stamp deferred: $error');
      }
    }
    return upgraded;
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
