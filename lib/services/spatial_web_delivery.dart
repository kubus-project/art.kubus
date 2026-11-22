import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/kubus_node_models.dart';
import 'storage_config.dart';

/// What the Flutter web viewer needs to show one published spatial variant.
///
/// Pure Dart on purpose: the browser-only widget stays a thin shell around
/// this, and the choices that matter (which tier opens by default, which URLs
/// are tried, how the manifest transform is read) are unit-testable.
class SpatialWebLoadPlan {
  const SpatialWebLoadPlan({
    required this.variant,
    required this.urls,
    this.fileType,
    this.manifestUrl,
  });

  final SpatialVariant variant;

  /// Public byte routes in the order the viewer tries them.
  final List<String> urls;

  /// Spark file type when the bytes carry no magic number (a raw `.splat`).
  final String? fileType;

  /// Public route of the published manifest, when its CID is known.
  final String? manifestUrl;

  bool get isArchiveTier => variant.role == 'spatial_archive';
}

/// Formats the bundled Spark viewer is offered on the web.
///
/// `rad` is deliberately absent: a paged RAD needs sibling chunk URLs that the
/// single-route delivery below cannot provide.
const Set<String> kSpatialWebFormats = <String>{
  'splat',
  'ply',
  'spz',
  'ksplat',
  'sog',
};

/// Formats whose bytes cannot be recognised by content, so Spark is told.
const Set<String> _kExplicitFileTypes = <String>{
  'splat',
  'ply',
  'spz',
  'ksplat',
};

class SpatialWebDelivery {
  const SpatialWebDelivery._();

  /// The anonymous, registry-authorised byte route of the backend.
  ///
  /// Only CIDs of a currently public publication resolve here (withdrawn or
  /// private content answers 404), which is what makes it the right first
  /// route for a visitor. The legacy `/uploads/<cid>` path is a different
  /// store and does not serve published spatial variants.
  static String backendUrl(String backendBase, String cid) {
    final base = backendBase.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base/api/upload/file/${Uri.encodeComponent(cid)}';
  }

  /// Ordered byte routes for [cid]: the backend proxy, then public gateways.
  ///
  /// Every URL is https (or the backend's own origin in a local build), so a
  /// secure page never issues mixed content, and none points at a LAN node.
  static List<String> candidateUrls(
    String cid, {
    String? backendBase,
    List<String>? gateways,
  }) {
    final base = (backendBase ?? StorageConfig.httpBackend).trim();
    final urls = <String>[];
    if (base.isNotEmpty) urls.add(backendUrl(base, cid));
    for (final gateway in gateways ?? StorageConfig.activeIpfsGateways) {
      final trimmed = gateway.trim();
      if (trimmed.isEmpty) continue;
      final withSlash = trimmed.endsWith('/') ? trimmed : '$trimmed/';
      urls.add('$withSlash${Uri.encodeComponent(cid)}');
    }
    return urls.where(_isSecureOrLoopback).toList(growable: false);
  }

  static bool _isSecureOrLoopback(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme == 'https') return true;
    return uri.scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1');
  }

  static bool isViewable(SpatialVariant variant) {
    if (variant.cid.isEmpty) return false;
    final format = variant.format.toLowerCase();
    final mimeType = variant.mimeType.toLowerCase();
    return kSpatialWebFormats.any(
      (supported) =>
          format == supported ||
          format.endsWith('.$supported') ||
          mimeType.contains(supported),
    );
  }

  /// The tier that opens by default: optimised, then preview. The archive tier
  /// is never chosen here; it is large, so the visitor asks for it.
  static SpatialVariant? defaultVariant(SpatialContent content) {
    final viewable = content.variants.where(isViewable).toList();
    return viewable.where((v) => v.role == 'spatial_mobile').firstOrNull ??
        viewable.where((v) => v.role == 'spatial_preview').firstOrNull;
  }

  static SpatialVariant? archiveVariant(SpatialContent content) =>
      content.variants
          .where(isViewable)
          .where((v) => v.role == 'spatial_archive')
          .firstOrNull;

  static SpatialWebLoadPlan plan(
    SpatialContent content,
    SpatialVariant variant, {
    String? backendBase,
    List<String>? gateways,
  }) {
    final format = variant.format.toLowerCase();
    final fileType = _kExplicitFileTypes.contains(format)
        ? format
        : _kExplicitFileTypes
            .where((t) => variant.mimeType.toLowerCase().contains(t))
            .firstOrNull;
    final manifestCid = content.manifestCid;
    final base = (backendBase ?? StorageConfig.httpBackend).trim();
    return SpatialWebLoadPlan(
      variant: variant,
      urls: candidateUrls(variant.cid,
          backendBase: backendBase, gateways: gateways),
      fileType: fileType,
      manifestUrl: manifestCid == null || manifestCid.isEmpty || base.isEmpty
          ? null
          : backendUrl(base, manifestCid),
    );
  }

  /// Extracts the viewer transform from a published manifest document.
  ///
  /// Accepts the Node's `{matrix: [16 numbers, column-major]}` and the
  /// `{position, rotation, scale}` form. Anything malformed yields null, which
  /// makes the viewer open the piece untransformed instead of failing.
  static Map<String, dynamic>? transformFromManifest(Object? manifest) {
    if (manifest is! Map) return null;
    final raw = manifest['transform'];
    if (raw is! Map) return null;
    bool finite(Object? v) => v is num && v.isFinite;
    final result = <String, dynamic>{};
    final matrix = raw['matrix'];
    final order = raw['matrixOrder'];
    if (matrix is List &&
        matrix.length == 16 &&
        matrix.every(finite) &&
        (order == null || order == 'column-major')) {
      result['matrix'] = matrix.map((v) => (v as num).toDouble()).toList();
      result['matrixOrder'] = 'column-major';
      return result;
    }
    final position = raw['position'];
    if (position is List && position.length == 3 && position.every(finite)) {
      result['position'] = position.map((v) => (v as num).toDouble()).toList();
    }
    final rotation = raw['rotation'];
    if (rotation is List &&
        (rotation.length == 3 || rotation.length == 4) &&
        rotation.every(finite)) {
      result['rotation'] = rotation.map((v) => (v as num).toDouble()).toList();
    }
    final scale = raw['scale'];
    if (scale is num && scale.isFinite && scale > 0) {
      result['scale'] = scale.toDouble();
    } else if (scale is List &&
        scale.length == 3 &&
        scale.every((v) => finite(v) && (v as num) > 0)) {
      result['scale'] = scale.map((v) => (v as num).toDouble()).toList();
    }
    return result.isEmpty ? null : result;
  }

  /// Best-effort read of the manifest transform. Never throws.
  static Future<Map<String, dynamic>?> fetchTransform(
    String? manifestUrl, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (manifestUrl == null) return null;
    final http.Client active = client ?? http.Client();
    try {
      final response =
          await active.get(Uri.parse(manifestUrl)).timeout(timeout);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.length > 262144) {
        return null;
      }
      return transformFromManifest(jsonDecode(utf8.decode(response.bodyBytes)));
    } catch (_) {
      return null;
    } finally {
      if (client == null) active.close();
    }
  }
}
