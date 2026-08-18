import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/kubus_node_models.dart';
import '../services/backend_api_service.dart';
import '../services/kubus_node_service.dart';
import '../services/spatial_capture_store.dart';
import '../services/spatial_library_store.dart';
import '../services/spatial_result_importer.dart';
import 'kubus_node_provider.dart';

abstract class SpatialPublicationClient {
  Future<Map<String, dynamic>> publish({
    required Map<String, dynamic> spatial,
    required String artworkId,
    String? markerId,
  });
}

class BackendSpatialPublicationClient implements SpatialPublicationClient {
  BackendSpatialPublicationClient({BackendApiService? api})
      : _api = api ?? BackendApiService();

  final BackendApiService _api;

  @override
  Future<Map<String, dynamic>> publish({
    required Map<String, dynamic> spatial,
    required String artworkId,
    String? markerId,
  }) =>
      _api.publishExistingSpatialCid(
        spatial: spatial,
        artworkId: artworkId,
        markerId: markerId,
      );
}

/// App-wide controller for private captures, processing and publication.
///
/// Capture completion itself never depends on this provider or on a Node. The
/// provider starts from already-durable records and can resume them after an
/// app restart.
class SpatialLibraryProvider extends ChangeNotifier {
  SpatialLibraryProvider({
    SpatialLibraryStore? store,
    SpatialPublicationClient? publicationClient,
    Directory? legacyCaptureRoot,
    Duration pollInterval = const Duration(seconds: 2),
  })  : store = store ?? SpatialLibraryStore(),
        _publicationClient =
            publicationClient ?? BackendSpatialPublicationClient(),
        _legacyCaptureRoot = legacyCaptureRoot,
        _pollInterval = pollInterval {
    _importer = SpatialResultImporter(store: this.store);
  }

  final SpatialLibraryStore store;
  final SpatialPublicationClient _publicationClient;
  final Directory? _legacyCaptureRoot;
  final Duration _pollInterval;
  late final SpatialResultImporter _importer;
  KubusNodeProvider? _node;
  List<SpatialLibraryRecord> _records = const <SpatialLibraryRecord>[];
  bool _initialized = false;
  bool _loading = false;
  String? _error;

  List<SpatialLibraryRecord> get records => List.unmodifiable(_records);
  bool get loading => _loading;
  String? get error => _error;

  void bindNode(KubusNodeProvider node) {
    if (identical(_node, node)) return;
    _node = node;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final legacyRoot =
        _legacyCaptureRoot ?? await SpatialCaptureStore.defaultRoot();
    await store.migrateLegacy(legacyRoot);
    await store.recoverInterruptedProcessing();
    await reload();
  }

  Future<void> reload() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _records = await store.list();
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<SpatialLibraryRecord> processWithOwnNode(
    String localSpatialId,
  ) async {
    final node = _requireNode();
    try {
      var record = await _uploadToNode(localSpatialId, node);
      if (node.snapshot?.capabilityAvailable('spatial.reconstruction') !=
          true) {
        await node.refresh();
      }
      if (node.snapshot?.capabilityAvailable('spatial.reconstruction') !=
          true) {
        throw StateError('processor_unavailable');
      }
      await store.updateProcessing(
        localSpatialId,
        SpatialLibraryProcessingState.queued,
        target: 'ownNode',
      );
      final job = await node.startReconstruction(
        captureId: record.nodeCaptureId!,
        artworkId: record.artworkId,
        markerId: record.markerId,
      );
      await store.recordJob(
        localSpatialId,
        jobId: job.id,
        state: SpatialLibraryProcessingState.queued,
      );
      while (true) {
        final current = await node.service.getJob(job.id);
        if (current.state == 'completed') {
          final spatialId = current.output?['id']?.toString() ?? '';
          if (spatialId.isEmpty) throw StateError('spatial_result_missing');
          record = await _importer.importFromNode(
            localSpatialId: localSpatialId,
            spatialId: spatialId,
            node: node.service,
          );
          await reload();
          return record;
        }
        if (current.state == 'failed' || current.state == 'cancelled') {
          throw StateError(
            current.error?['code']?.toString() ?? 'processing_failed',
          );
        }
        await store.updateProcessing(
          localSpatialId,
          current.state == 'queued'
              ? SpatialLibraryProcessingState.queued
              : SpatialLibraryProcessingState.processing,
          target: 'ownNode',
        );
        await Future<void>.delayed(_pollInterval);
      }
    } catch (error) {
      await _recordProcessingFailure(localSpatialId, error);
      rethrow;
    }
  }

  Future<SpatialLibraryRecord> processWithNetwork(
    String localSpatialId,
    KubusComputeCandidate provider,
  ) async {
    final node = _requireNode();
    try {
      final record = await _uploadToNode(localSpatialId, node);
      final job = await node.startRemoteReconstruction(
        captureId: record.nodeCaptureId!,
        provider: provider,
        requirements: <String, dynamic>{
          'frameCount': record.sampleCount,
          'inputBytes': record.sourceBytes,
          'reconstructionTier': 'standard',
          'iterationTier': 'standard',
          'outputTier': 'mobile_archive',
        },
      );
      await store.recordJob(
        localSpatialId,
        jobId: job.id,
        networkProviderNodeId: provider.nodeId,
        networkRequestId: job.id,
        state: SpatialLibraryProcessingState.queued,
      );
      while (true) {
        final current = await node.refreshRemoteJob(job.id);
        if (const <String>{
          'OUTPUT_READY',
          'VERIFYING',
          'VERIFIED',
          'COMPLETED',
        }.contains(current.state)) {
          final result = await node.retrieveRemoteResult(job.id);
          final spatialId = result['id']?.toString() ?? '';
          if (spatialId.isEmpty) throw StateError('spatial_result_missing');
          final imported = await _importer.importFromNode(
            localSpatialId: localSpatialId,
            spatialId: spatialId,
            node: node.service,
          );
          await node.acknowledgeRemoteResult(job.id, accepted: true);
          await reload();
          return imported;
        }
        if (const <String>{
          'DECLINED',
          'EXPIRED',
          'FAILED',
          'CANCELLED',
          'DISPUTED',
        }.contains(current.state)) {
          throw StateError(
            current.failure?['reason']?.toString() ?? 'network_compute_failed',
          );
        }
        await store.updateProcessing(
          localSpatialId,
          current.state == 'RUNNING'
              ? SpatialLibraryProcessingState.processing
              : SpatialLibraryProcessingState.queued,
          target: 'networkGpu',
        );
        await Future<void>.delayed(_pollInterval);
      }
    } catch (error) {
      await _recordProcessingFailure(localSpatialId, error);
      rethrow;
    }
  }

  Future<List<KubusComputeCandidate>> loadNetworkCandidates(
    SpatialLibraryRecord record,
  ) =>
      _requireNode().loadComputeCandidates(inputBytes: record.sourceBytes);

  Future<SpatialContent> loadLocalContent(String localSpatialId) async {
    final record = await store.get(localSpatialId);
    if (record == null) throw StateError('record_missing');
    return _importer.loadLocalContent(record);
  }

  Future<SpatialLibraryRecord> publish(String localSpatialId) async {
    var record = await store.get(localSpatialId);
    if (record == null || !record.hasLocalResult) {
      throw StateError('ready_private_result_required');
    }
    await store.recordPublication(
      localSpatialId,
      state: SpatialLibraryPublicationState.publishing,
    );
    try {
      final manifestFile = File(record.resultManifestPath!);
      final decoded = jsonDecode(await manifestFile.readAsString());
      if (decoded is! Map<String, dynamic> ||
          record.resultManifestCid == null) {
        throw StateError('local_manifest_invalid');
      }
      final publicManifest = sanitizePublicationManifest(decoded);
      if (!_deepJsonEquals(publicManifest, decoded)) {
        throw StateError('local_manifest_not_public_safe');
      }
      final result = await _publicationClient.publish(
        spatial: <String, dynamic>{
          'id': publicManifest['id'],
          'manifestCid': record.resultManifestCid,
          'manifestSizeBytes': await manifestFile.length(),
          'manifest': publicManifest,
        },
        artworkId: record.artworkId,
        markerId: record.markerId,
      );
      final publication = result['publication'] is Map
          ? Map<String, dynamic>.from(result['publication'] as Map)
          : result;
      final currentVersion = publication['currentVersion'] is Map
          ? Map<String, dynamic>.from(publication['currentVersion'] as Map)
          : <String, dynamic>{};
      final variants = <String, String>{};
      for (final item
          in currentVersion['cids'] as List<dynamic>? ?? const <dynamic>[]) {
        if (item is! Map) continue;
        final role =
            item['role']?.toString() ?? item['cidRole']?.toString() ?? '';
        final cid = item['cid']?.toString() ?? '';
        if (role.startsWith('spatial_') && cid.isNotEmpty) {
          variants[role] = cid;
        }
      }
      record = await store.recordPublication(
        localSpatialId,
        state: SpatialLibraryPublicationState.published,
        publicSpatialId:
            publication['id']?.toString() ?? publicManifest['id'].toString(),
        version: int.tryParse(
          (publication['latestVersion'] ?? currentVersion['version'] ?? 0)
              .toString(),
        ),
        canonicalManifestCid: publication['currentManifestCid']?.toString() ??
            currentVersion['manifestCid']?.toString(),
        canonicalRecordCid: publication['currentRecordCid']?.toString() ??
            currentVersion['recordCid']?.toString(),
        variantCids: variants.isEmpty
            ? Map<String, String>.from(record.variantCids)
            : variants,
        publishedAt: DateTime.tryParse(
          publication['lastPublishedAt']?.toString() ??
              currentVersion['publishedAt']?.toString() ??
              '',
        )?.toUtc(),
      );
      await reload();
      return record;
    } catch (error) {
      await store.recordPublication(
        localSpatialId,
        state: SpatialLibraryPublicationState.failed,
      );
      await store.recordFailure(localSpatialId, code: 'publication_failed');
      await reload();
      rethrow;
    }
  }

  @visibleForTesting
  static Map<String, dynamic> sanitizePublicationManifest(
    Map<String, dynamic> manifest,
  ) {
    final variants = (manifest['variants'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => <String, dynamic>{
            for (final key in const <String>{
              'role',
              'cid',
              'sizeBytes',
              'mimeType',
              'format',
              'storageClass',
            })
              if (item.containsKey(key)) key: item[key],
          },
        )
        .toList(growable: false);
    final provenance = manifest['captureProvenance'] is Map
        ? Map<String, dynamic>.from(manifest['captureProvenance'] as Map)
        : <String, dynamic>{};
    final processing = manifest['processing'] is Map
        ? Map<String, dynamic>.from(manifest['processing'] as Map)
        : <String, dynamic>{};
    final reconstruction = processing['reconstruction'] is Map
        ? Map<String, dynamic>.from(processing['reconstruction'] as Map)
        : <String, dynamic>{};
    final transform = manifest['transform'] is Map
        ? Map<String, dynamic>.from(manifest['transform'] as Map)
        : <String, dynamic>{};
    final viewerDefaults = manifest['viewerDefaults'] is Map
        ? Map<String, dynamic>.from(manifest['viewerDefaults'] as Map)
        : <String, dynamic>{};
    return <String, dynamic>{
      for (final key in const <String>{
        'schema',
        'type',
        'id',
        'artworkId',
        'markerId',
        'captureId',
        'capturedAt',
        'capturedBy',
        'createdAt',
      })
        if (manifest.containsKey(key)) key: manifest[key],
      if (provenance.isNotEmpty)
        'captureProvenance': <String, dynamic>{
          for (final key in const <String>{
            'source',
            'captureId',
            'remoteComputeJobId',
          })
            if (provenance.containsKey(key)) key: provenance[key],
        },
      if (transform.isNotEmpty)
        'transform': <String, dynamic>{
          for (final key in const <String>{'position', 'rotation', 'scale'})
            if (transform.containsKey(key)) key: transform[key],
        },
      if (viewerDefaults.isNotEmpty)
        'viewerDefaults': <String, dynamic>{
          for (final key in const <String>{
            'quality',
            'background',
            'camera',
          })
            if (viewerDefaults.containsKey(key)) key: viewerDefaults[key],
        },
      if (processing.isNotEmpty)
        'processing': <String, dynamic>{
          for (final key in const <String>{'protocol', 'workerVersion'})
            if (processing.containsKey(key)) key: processing[key],
          if (reconstruction.isNotEmpty)
            'reconstruction': <String, dynamic>{
              for (final key in const <String>{
                'engine',
                'method',
                'iterations',
                'outputFormat',
              })
                if (reconstruction.containsKey(key)) key: reconstruction[key],
            },
        },
      'variants': variants,
    };
  }

  Future<SpatialLibraryRecord> deleteRaw(String id) async {
    final record = await store.deleteRaw(id);
    await reload();
    return record;
  }

  Future<SpatialLibraryRecord> deleteProcessed(String id) async {
    final record = await store.deleteProcessed(id);
    await reload();
    return record;
  }

  Future<void> deleteRecord(String id) async {
    await store.deleteRecord(id);
    await reload();
  }

  Future<SpatialLibraryRecord> _uploadToNode(
    String localSpatialId,
    KubusNodeProvider node,
  ) async {
    var record = await store.get(localSpatialId);
    if (record == null || !record.rawPresent) {
      throw StateError('raw_source_required');
    }
    final source = await SpatialCaptureStore.open(Directory(record.sourcePath));
    if (source == null) throw StateError('raw_source_unreadable');
    final activeNodeId = node.service.nodeId;
    if (activeNodeId == null || activeNodeId.isEmpty) {
      throw StateError('node_identity_unavailable');
    }
    final sameNode = record.nodeId == activeNodeId;
    if ((record.nodeCaptureId ?? '').isNotEmpty && sameNode) return record;
    if (!sameNode &&
        ((record.nodeCaptureId ?? '').isNotEmpty ||
            (record.draftId ?? '').isNotEmpty)) {
      await source.recordDraftId(null);
      record = await store.recordNodeTransfer(
        localSpatialId,
        nodeId: activeNodeId,
        draftId: null,
        nodeCaptureId: null,
        uploadedFiles: 0,
        uploadedBytes: 0,
      );
    }
    await store.updateProcessing(
      localSpatialId,
      SpatialLibraryProcessingState.uploading,
      target: 'ownNode',
    );
    final entries = source.uploadEntries;
    var totalBytes = 0;
    for (final entry in entries) {
      final file = source.fileAt(entry.path);
      if (await file.exists()) totalBytes += await file.length();
    }

    var draftId = record.draftId ?? source.draftId;
    var uploaded = const <String>{};
    if (draftId != null) {
      try {
        uploaded = (await node.service.getCaptureDraft(draftId)).files.toSet();
      } on KubusNodeRequestException catch (error) {
        if (error.code != 'capture_draft_not_found') rethrow;
        draftId = null;
        await source.recordDraftId(null);
        await store.recordNodeTransfer(localSpatialId, draftId: null);
      }
    }
    if (draftId == null) {
      final draft = await node.service.beginCaptureDraft(<String, dynamic>{
        'schema': 'kubus.capture/1',
        'artworkId': record.artworkId,
        if (record.markerId != null) 'markerId': record.markerId,
        'capturedAt': record.capturedAt.toIso8601String(),
        'metadata': <String, dynamic>{
          'capturedBy': record.ownerId,
          'frameCount': record.sampleCount,
          'depthAvailable': record.hasDepth,
          'coverage': record.coverageMetadata,
          'quality': record.qualityMetadata,
          'source': 'art.kubus-mobile-tracking',
          'private': true,
          'localCaptureId': record.localSpatialId,
        },
      });
      draftId = draft.id;
      await source.recordDraftId(draftId);
      await store.recordNodeTransfer(
        localSpatialId,
        nodeId: node.service.nodeId,
        draftId: draftId,
        totalFiles: entries.length,
        totalBytes: totalBytes,
      );
    }
    var uploadedFiles = 0;
    var uploadedBytes = 0;
    for (final entry in entries) {
      final file = source.fileAt(entry.path);
      if (!await file.exists()) continue;
      final length = await file.length();
      if (!uploaded.contains(entry.path)) {
        await node.service.uploadCaptureDraftFile(
          draftId: draftId,
          path: entry.path,
          file: file,
          mimeType: entry.mimeType,
        );
      }
      uploadedFiles++;
      uploadedBytes += length;
      await store.recordNodeTransfer(
        localSpatialId,
        nodeId: node.service.nodeId,
        draftId: draftId,
        uploadedFiles: uploadedFiles,
        totalFiles: entries.length,
        uploadedBytes: uploadedBytes,
        totalBytes: totalBytes,
      );
    }
    final committed = await node.service.commitCaptureDraft(draftId);
    final nodeCaptureId = committed['id']?.toString() ?? '';
    if (nodeCaptureId.isEmpty) throw StateError('capture_id_missing');
    await source.markTransferred();
    record = await store.recordNodeTransfer(
      localSpatialId,
      nodeId: node.service.nodeId,
      draftId: null,
      nodeCaptureId: nodeCaptureId,
      uploadedFiles: entries.length,
      totalFiles: entries.length,
      uploadedBytes: totalBytes,
      totalBytes: totalBytes,
    );
    return record;
  }

  Future<void> _recordProcessingFailure(
    String localSpatialId,
    Object error,
  ) async {
    final identityMismatch = error is KubusNodeIdentityException;
    await store.recordFailure(
      localSpatialId,
      code: identityMismatch
          ? 'node_identity_mismatch'
          : error is SpatialResultValidationException
              ? error.code
              : 'processor_unavailable',
      waitingForProcessor:
          !identityMismatch && error is! SpatialResultValidationException,
    );
    await reload();
  }

  KubusNodeProvider _requireNode() {
    final node = _node;
    if (node == null || !node.isPaired) throw StateError('node_unavailable');
    return node;
  }
}

bool _deepJsonEquals(Object? left, Object? right) {
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final key in left.keys) {
      if (!right.containsKey(key) || !_deepJsonEquals(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_deepJsonEquals(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}
