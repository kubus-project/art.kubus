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

  /// Byte routes the viewer tries in order (the backend's gated route only).
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
/// single-route delivery below cannot provide. `sog` is absent until a SOG
/// fixture has been loaded through the browser smoke: it is a zip container
/// that Spark opens as `pcsogszip`, the bytes route carries no file extension
/// to detect it from, and nothing here has proven the detection by content.
const Set<String> kSpatialWebFormats = <String>{
  'splat',
  'ply',
  'spz',
  'ksplat',
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

  /// A CID as the backend and the public registry spell it: letters, digits,
  /// `-` and `_` only, bounded. Anything else (`..`, a path, a query, an
  /// encoded separator) is never turned into a URL.
  static final RegExp _cidShape = RegExp(r'^[A-Za-z0-9_-]{4,128}$');

  static bool isPlausibleCid(String? cid) =>
      cid != null && _cidShape.hasMatch(cid);

  /// The anonymous, registry-authorised byte route of the backend.
  ///
  /// Only CIDs of a currently public publication resolve here (withdrawn or
  /// private content answers 404, and an unavailable withdrawal lookup answers
  /// 503: it fails closed). The legacy `/uploads/<cid>` path is a different
  /// store and does not serve published spatial variants.
  ///
  /// Returns null for a CID that is not a plausible CID.
  static String? backendUrl(String backendBase, String cid) {
    if (!isPlausibleCid(cid)) return null;
    final base = backendBase.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base/api/upload/file/$cid';
  }

  /// The byte routes the public viewer may use for [cid]: the backend route
  /// and nothing else.
  ///
  /// Public IPFS gateways are deliberately not a fallback. The backend route
  /// is the publication gate: it answers 404 for withdrawn or unregistered
  /// content and 503 when the withdrawal lookup fails. A gateway has no such
  /// gate and would keep serving pinned bytes of withdrawn content (and learn
  /// the visitor's address), so falling through to one after a backend refusal
  /// would defeat the gate. The URL is https (or the backend's own loopback
  /// origin in a local build), so a secure page never issues mixed content and
  /// none points at a LAN node.
  static List<String> candidateUrls(String cid, {String? backendBase}) {
    final base = (backendBase ?? StorageConfig.httpBackend).trim();
    if (base.isEmpty) return const <String>[];
    final url = backendUrl(base, cid);
    if (url == null || !_isSecureOrLoopback(url)) return const <String>[];
    return <String>[url];
  }

  static bool _isSecureOrLoopback(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme == 'https') return true;
    return uri.scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1');
  }

  static bool isViewable(SpatialVariant variant) {
    if (!isPlausibleCid(variant.cid)) return false;
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
  static SpatialVariant? defaultVariant(SpatialContent content) =>
      defaultTiers(content).firstOrNull;

  /// The tiers that may open without the visitor asking, best first:
  /// optimised, then preview. When one cannot be loaded (a format the viewer
  /// rejects, a failed route) the next is tried; the archive is never in this
  /// list.
  static List<SpatialVariant> defaultTiers(SpatialContent content) {
    final viewable = content.variants.where(isViewable).toList();
    return <SpatialVariant>[
      for (final role in const <String>['spatial_mobile', 'spatial_preview'])
        ...viewable.where((v) => v.role == role).take(1),
    ];
  }

  /// The tier to try after [failed] failed, or null when none is left. The
  /// archive tier never falls back: it was an explicit request.
  static SpatialVariant? nextTier(
    SpatialContent content,
    SpatialVariant failed,
  ) {
    final tiers = defaultTiers(content);
    final at = tiers.indexWhere(
      (v) => v.role == failed.role && v.cid == failed.cid,
    );
    if (at < 0 || at + 1 >= tiers.length) return null;
    return tiers[at + 1];
  }

  /// Largest archive the visitor may start without an explicit confirmation.
  static const int archiveConfirmBytes = 50 * 1024 * 1024;

  /// True when the archive is large or of unknown size. The archive is the
  /// large tier by definition, so a record that omits `sizeBytes` (0) is asked
  /// about too instead of being downloaded on the strength of a missing field.
  static bool archiveNeedsConfirmation(SpatialVariant variant) =>
      variant.sizeBytes <= 0 || variant.sizeBytes >= archiveConfirmBytes;

  /// How long one load may take before it is reported as failed. The archive
  /// tier is far larger than the other tiers, so it gets a longer budget
  /// instead of being declared dead while it is still downloading.
  static Duration loadTimeout(SpatialVariant variant) =>
      variant.role == 'spatial_archive'
          ? const Duration(minutes: 10)
          : const Duration(seconds: 120);

  static SpatialVariant? archiveVariant(SpatialContent content) =>
      content.variants
          .where(isViewable)
          .where((v) => v.role == 'spatial_archive')
          .firstOrNull;

  static SpatialWebLoadPlan plan(
    SpatialContent content,
    SpatialVariant variant, {
    String? backendBase,
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
      urls: candidateUrls(variant.cid, backendBase: backendBase),
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

  /// Largest manifest document read for its transform.
  static const int manifestMaxBytes = 262144;

  /// Best-effort read of the manifest transform. Never throws. The size cap
  /// bounds the download, not just the parsing: a declared length above it is
  /// refused before any body is read, and the body stream is abandoned as soon
  /// as it passes the cap.
  static Future<Map<String, dynamic>?> fetchTransform(
    String? manifestUrl, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (manifestUrl == null) return null;
    final http.Client active = client ?? http.Client();
    try {
      final response = await active
          .send(http.Request('GET', Uri.parse(manifestUrl)))
          .timeout(timeout);
      final declared = response.contentLength;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          (declared != null && declared > manifestMaxBytes)) {
        return null;
      }
      final body = <int>[];
      await for (final chunk in response.stream.timeout(timeout)) {
        body.addAll(chunk);
        if (body.length > manifestMaxBytes) return null;
      }
      return transformFromManifest(jsonDecode(utf8.decode(body)));
    } catch (_) {
      return null;
    } finally {
      if (client == null) active.close();
    }
  }
}
