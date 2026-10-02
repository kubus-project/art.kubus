import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/kubus_node_models.dart';
import 'kubus_node_service.dart';
import 'spatial_library_store.dart';
import 'storage_config.dart';

class SpatialResultValidationException implements Exception {
  const SpatialResultValidationException(this.code);

  final String code;

  @override
  String toString() => 'SpatialResultValidationException($code)';
}

/// Imports a processed Node result into the phone's private library.
///
/// Each large variant is streamed to a staging directory, validated, and only
/// then promoted as a complete result. A killed or failed download can leave a
/// staging directory, but can never make the record `readyPrivate`.
class SpatialResultImporter {
  const SpatialResultImporter({required this.store});

  final SpatialLibraryStore store;

  Future<SpatialLibraryRecord> importFromNode({
    required String localSpatialId,
    required String spatialId,
    required KubusNodeService node,
  }) async {
    final libraryRecord = await store.get(localSpatialId);
    if (libraryRecord == null) {
      throw const SpatialResultValidationException('record_missing');
    }
    await store.updateProcessing(
      localSpatialId,
      SpatialLibraryProcessingState.downloadingResult,
      target: libraryRecord.processingTarget,
    );

    Directory? staging;
    try {
      final nodeRecord = await node.getSpatial(spatialId);
      final manifestCid = nodeRecord['manifestCid']?.toString();
      if (manifestCid == null || !StorageConfig.isLikelyCid(manifestCid)) {
        throw const SpatialResultValidationException('manifest_cid_invalid');
      }

      final recordDirectory = await store.recordDirectory(localSpatialId);
      staging = Directory(
        p.join(
          recordDirectory.path,
          'result.staging-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      await staging.create(recursive: true);
      final manifestPartial = File(p.join(staging.path, 'manifest.partial'));
      await node.downloadContentToFile(manifestCid, manifestPartial);
      final decodedManifest = jsonDecode(await manifestPartial.readAsString());
      if (decodedManifest is! Map) {
        throw const SpatialResultValidationException('manifest_missing');
      }
      final manifest = Map<String, dynamic>.from(decodedManifest);
      final rawManifest = nodeRecord['manifest'];
      if (rawManifest is! Map || !_deepJsonEquals(rawManifest, manifest)) {
        throw const SpatialResultValidationException(
          'manifest_response_mismatch',
        );
      }
      final content = _validateManifest(manifest, libraryRecord);
      final variantDirectory = Directory(p.join(staging.path, 'variants'));
      await variantDirectory.create(recursive: true);

      final paths = <String, String>{};
      var totalBytes = 0;
      for (var index = 0; index < content.variants.length; index++) {
        final variant = content.variants[index];
        final rawVariant = (manifest['variants'] as List<dynamic>)[index];
        final metadata = Map<String, dynamic>.from(rawVariant as Map);
        final extension = _safeExtension(variant.format);
        final name = '${_safeName(variant.role)}.$extension';
        final partial = File(p.join(variantDirectory.path, '$name.partial'));
        final complete = File(p.join(variantDirectory.path, name));
        await node.downloadContentToFile(variant.cid, partial);
        final length = await partial.length();
        if (length != variant.sizeBytes) {
          throw const SpatialResultValidationException('variant_size_mismatch');
        }
        await _validateHash(partial, metadata);
        await partial.rename(complete.path);
        paths[variant.role] = p.join('variants', name);
        totalBytes += length;
      }

      final manifestFile = await manifestPartial.rename(
        p.join(staging.path, 'manifest.json'),
      );
      totalBytes += await manifestFile.length();

      final finalDirectory = Directory(p.join(recordDirectory.path, 'result'));
      final backup = Directory('${finalDirectory.path}.bak');
      if (await backup.exists()) await backup.delete(recursive: true);
      if (await finalDirectory.exists()) {
        await finalDirectory.rename(backup.path);
      }
      try {
        await staging.rename(finalDirectory.path);
      } catch (_) {
        if (!await finalDirectory.exists() && await backup.exists()) {
          await backup.rename(finalDirectory.path);
        }
        rethrow;
      }
      staging = null;
      if (await backup.exists()) await backup.delete(recursive: true);

      final absolutePaths = paths.map(
        (role, relative) =>
            MapEntry(role, p.join(finalDirectory.path, relative)),
      );
      return store.recordResult(
        localSpatialId,
        manifestPath: p.join(finalDirectory.path, 'manifest.json'),
        manifestCid: manifestCid,
        variantPaths: absolutePaths,
        bytes: totalBytes,
        format: content.type,
      );
    } catch (error) {
      if (staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
      await store.recordFailure(
        localSpatialId,
        code: error is SpatialResultValidationException
            ? error.code
            : 'result_download_failed',
      );
      rethrow;
    }
  }

  Future<SpatialContent> loadLocalContent(SpatialLibraryRecord record) async {
    final manifestPath = record.resultManifestPath;
    if (manifestPath == null ||
        record.integrityState != SpatialLibraryIntegrityState.valid) {
      throw const SpatialResultValidationException('local_result_unavailable');
    }
    final decoded = jsonDecode(await File(manifestPath).readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const SpatialResultValidationException('manifest_invalid');
    }
    final content = SpatialContent.fromJson(decoded);
    return SpatialContent(
      id: content.id,
      type: content.type,
      artworkId: content.artworkId,
      markerId: content.markerId,
      captureId: content.captureId,
      capturedAt: content.capturedAt,
      variants: content.variants
          .map(
            (variant) => variant.copyWith(
              localPath: record.resultVariantPaths[variant.role],
            ),
          )
          .toList(growable: false),
      transform: content.transform,
      viewerDefaults: content.viewerDefaults,
    );
  }

  static SpatialContent _validateManifest(
    Map<String, dynamic> manifest,
    SpatialLibraryRecord record,
  ) {
    final content = SpatialContent.fromJson(manifest);
    if (content.id.isEmpty || content.artworkId != record.artworkId) {
      throw const SpatialResultValidationException('artwork_mismatch');
    }
    final expectedCapture = record.nodeCaptureId;
    if (expectedCapture == null || content.captureId != expectedCapture) {
      throw const SpatialResultValidationException('capture_mismatch');
    }
    if (content.type != 'gaussianSplat' && content.type != 'model3d') {
      throw const SpatialResultValidationException('format_unsupported');
    }
    if (content.variants.isEmpty) {
      throw const SpatialResultValidationException('variants_missing');
    }
    final roles = <String>{};
    for (final variant in content.variants) {
      if (!roles.add(variant.role) ||
          !_allowedRoles.contains(variant.role) ||
          variant.sizeBytes <= 0 ||
          variant.format.trim().isEmpty ||
          !StorageConfig.isLikelyCid(variant.cid)) {
        throw const SpatialResultValidationException('variant_invalid');
      }
    }
    return content;
  }

  static Future<void> _validateHash(
    File file,
    Map<String, dynamic> metadata,
  ) async {
    var expected = (metadata['sha256'] ?? metadata['hash'])?.toString().trim();
    if (expected == null || expected.isEmpty) return;
    if (expected.startsWith('sha256:')) expected = expected.substring(7);
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(expected)) {
      throw const SpatialResultValidationException('variant_hash_invalid');
    }
    final actual = (await sha256.bind(file.openRead()).first).toString();
    if (actual.toLowerCase() != expected.toLowerCase()) {
      throw const SpatialResultValidationException('variant_hash_mismatch');
    }
  }

  static const Set<String> _allowedRoles = <String>{
    'spatial_preview',
    'spatial_mobile',
    'spatial_archive',
    'model3d',
  };

  static String _safeName(String value) =>
      value.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');

  static String _safeExtension(String value) {
    final normalized = value.toLowerCase().replaceFirst('.', '');
    return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(normalized) ? normalized : 'bin';
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
