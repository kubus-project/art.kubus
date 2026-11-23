import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
      loadTimeoutOverride ??
      (variant.role == 'spatial_archive'
          ? const Duration(minutes: 10)
          : const Duration(seconds: 120));

  /// Replaces every load budget. Set only by the browser QA harness
  /// (tool/qa/spatial_viewer_web_harness_main.dart), so a timeout followed by a
  /// late response can be exercised in seconds; always null in the app.
  static Duration? loadTimeoutOverride;

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
        : (_kExplicitFileTypes
                .where((t) => variant.mimeType.toLowerCase().contains(t))
                .toList()
              ..sort((a, b) => b.length.compareTo(a.length)))
            .firstOrNull;
    final manifestCid = content.manifestCid;
    final base = (backendBase ?? StorageConfig.httpBackend).trim();
    // The manifest route follows the same rule as the byte route: https, or
    // the backend's own loopback origin in a local build, never plain http.
    final manifestUrl =
        manifestCid == null || manifestCid.isEmpty || base.isEmpty
            ? null
            : backendUrl(base, manifestCid);
    return SpatialWebLoadPlan(
      variant: variant,
      urls: candidateUrls(variant.cid, backendBase: backendBase),
      fileType: fileType,
      manifestUrl: manifestUrl != null && _isSecureOrLoopback(manifestUrl)
          ? manifestUrl
          : null,
    );
  }

  /// Largest translation component accepted from a manifest.
  static const double maxTransformPosition = 1e6;

  /// Smallest and largest per-axis scale accepted from a manifest.
  static const double minTransformScale = 1e-6;
  static const double maxTransformScale = 1e4;

  static bool _acceptedPosition(List<Object?> position) =>
      position.length == 3 &&
      position.every(
        (v) => v is num && v.isFinite && v.abs() <= maxTransformPosition,
      );

  static bool _acceptedScale(Object? v) =>
      v is num &&
      v.isFinite &&
      v >= minTransformScale &&
      v <= maxTransformScale;

  /// A column-major 4x4 that is a proper affine placement: bottom row
  /// (0, 0, 0, 1), bounded translation, axis lengths inside the scale bounds,
  /// perpendicular axes (no shear) and a right-handed basis (no mirror). The
  /// viewer page applies the same rules again (manifest_transform.mjs).
  static bool _acceptedMatrix(List<double> m) {
    const eps = 1e-6;
    const shear = 1e-3;
    if (m[3].abs() > eps || m[7].abs() > eps || m[11].abs() > eps) return false;
    if ((m[15] - 1).abs() > eps) return false;
    if ([m[12], m[13], m[14]].any((v) => v.abs() > maxTransformPosition)) {
      return false;
    }
    final axes = [m.sublist(0, 3), m.sublist(4, 7), m.sublist(8, 11)];
    double dot(List<double> a, List<double> b) =>
        a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
    final lengths = [for (final a in axes) math.sqrt(dot(a, a))];
    if (!lengths.every(
      (l) => l >= minTransformScale && l <= maxTransformScale,
    )) {
      return false;
    }
    for (final pair in const [
      [0, 1],
      [0, 2],
      [1, 2],
    ]) {
      final i = pair[0];
      final j = pair[1];
      if (dot(axes[i], axes[j]).abs() > shear * lengths[i] * lengths[j]) {
        return false;
      }
    }
    final b = axes[1];
    final c = axes[2];
    final cross = [
      b[1] * c[2] - b[2] * c[1],
      b[2] * c[0] - b[0] * c[2],
      b[0] * c[1] - b[1] * c[0],
    ];
    return dot(axes[0], cross) > 0;
  }

  /// Splits an accepted column-major placement matrix into the
  /// `{position, rotation, scale}` form the public manifest contract carries
  /// (position 3, rotation as a quaternion x y z w, scale as a 3-vector).
  ///
  /// Composing translation * rotation * scale from the result gives the same
  /// placement the viewer builds from the matrix itself. Returns null for a
  /// matrix the viewer would refuse (wrong length, non-finite, non-affine,
  /// sheared, mirrored, out of bounds), so nothing the viewer rejects reaches
  /// a publication.
  static Map<String, dynamic>? decomposePlacementMatrix(Object? matrix) {
    if (matrix is! List || matrix.length != 16) return null;
    if (!matrix.every((v) => v is num && v.isFinite)) return null;
    final m = matrix.map((v) => (v as num).toDouble()).toList(growable: false);
    if (!_acceptedMatrix(m)) return null;
    double length(int o) =>
        math.sqrt(m[o] * m[o] + m[o + 1] * m[o + 1] + m[o + 2] * m[o + 2]);
    final sx = length(0);
    final sy = length(4);
    final sz = length(8);
    // Rotation matrix entries r<row><col>, from the normalised basis columns.
    final r00 = m[0] / sx, r10 = m[1] / sx, r20 = m[2] / sx;
    final r01 = m[4] / sy, r11 = m[5] / sy, r21 = m[6] / sy;
    final r02 = m[8] / sz, r12 = m[9] / sz, r22 = m[10] / sz;
    final trace = r00 + r11 + r22;
    double qx, qy, qz, qw;
    if (trace > 0) {
      final s = 0.5 / math.sqrt(trace + 1.0);
      qw = 0.25 / s;
      qx = (r21 - r12) * s;
      qy = (r02 - r20) * s;
      qz = (r10 - r01) * s;
    } else if (r00 > r11 && r00 > r22) {
      final s = 2.0 * math.sqrt(1.0 + r00 - r11 - r22);
      qw = (r21 - r12) / s;
      qx = 0.25 * s;
      qy = (r01 + r10) / s;
      qz = (r02 + r20) / s;
    } else if (r11 > r22) {
      final s = 2.0 * math.sqrt(1.0 + r11 - r00 - r22);
      qw = (r02 - r20) / s;
      qx = (r01 + r10) / s;
      qy = 0.25 * s;
      qz = (r12 + r21) / s;
    } else {
      final s = 2.0 * math.sqrt(1.0 + r22 - r00 - r11);
      qw = (r10 - r01) / s;
      qx = (r02 + r20) / s;
      qy = (r12 + r21) / s;
      qz = 0.25 * s;
    }
    final norm = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw);
    return <String, dynamic>{
      'position': <double>[m[12], m[13], m[14]],
      'rotation': <double>[qx / norm, qy / norm, qz / norm, qw / norm],
      'scale': <double>[sx, sy, sz],
    };
  }

  /// Extracts the viewer transform from a published manifest document.
  ///
  /// Accepts the Node's `{matrix: [16 numbers, column-major]}` and the
  /// `{position, rotation, scale}` form. Anything malformed yields null, which
  /// makes the viewer open the piece untransformed instead of failing. A
  /// matrix that is not a plain placement (non-affine, sheared, mirrored,
  /// out of bounds) is refused whole, as are out-of-bounds position and scale.
  static Map<String, dynamic>? transformFromManifest(Object? manifest) {
    if (manifest is! Map) return null;
    final raw = manifest['transform'];
    if (raw is! Map) return null;
    bool finite(Object? v) => v is num && v.isFinite;
    final result = <String, dynamic>{};
    final matrix = raw['matrix'];
    final order = raw['matrixOrder'];
    if (matrix is List && (order == null || order == 'column-major')) {
      if (matrix.length != 16 || !matrix.every(finite)) return null;
      final values = matrix.map((v) => (v as num).toDouble()).toList();
      if (!_acceptedMatrix(values)) return null;
      result['matrix'] = values;
      result['matrixOrder'] = 'column-major';
      return result;
    }
    final position = raw['position'];
    if (position is List && _acceptedPosition(position)) {
      result['position'] = position.map((v) => (v as num).toDouble()).toList();
    }
    final rotation = raw['rotation'];
    if (rotation is List &&
        (rotation.length == 3 || rotation.length == 4) &&
        rotation.every(finite)) {
      result['rotation'] = rotation.map((v) => (v as num).toDouble()).toList();
    }
    final scale = raw['scale'];
    if (_acceptedScale(scale)) {
      result['scale'] = (scale as num).toDouble();
    } else if (scale is List &&
        scale.length == 3 &&
        scale.every(_acceptedScale)) {
      result['scale'] = scale.map((v) => (v as num).toDouble()).toList();
    }
    return result.isEmpty ? null : result;
  }

  /// The placement a viewer applies to [content], by the same validation either
  /// way: the published manifest read from [plan]'s manifest URL when there is
  /// one, otherwise the placement the content already carries (a local manifest
  /// from the Node, whose `matrix` form exists nowhere else). Local content
  /// never causes a request, so no private CID leaves the device. Never throws.
  static Future<Map<String, dynamic>?> resolveTransform(
    SpatialContent content,
    SpatialWebLoadPlan plan, {
    http.Client? client,
  }) async {
    final published = await fetchTransform(plan.manifestUrl, client: client);
    if (published != null) return published;
    return transformFromManifest(<String, dynamic>{
      'transform': content.transform,
    });
  }

  /// Largest manifest document read for its transform.
  static const int manifestMaxBytes = 262144;

  /// Best-effort read of the manifest transform. Never throws. The size cap
  /// bounds the download, not just the parsing: a declared length above it is
  /// refused before any body is read, and the body stream is abandoned as soon
  /// as it passes the cap. [timeout] is one total deadline for the request and
  /// the whole body, so a server that drips a chunk every few seconds cannot
  /// hold the viewer load.
  static Future<Map<String, dynamic>?> fetchTransform(
    String? manifestUrl, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (manifestUrl == null) return null;
    final http.Client active = client ?? http.Client();
    final clock = Stopwatch()..start();
    StreamIterator<List<int>>? chunks;
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
      final iterator = chunks = StreamIterator<List<int>>(response.stream);
      while (true) {
        final remaining = timeout - clock.elapsed;
        if (remaining <= Duration.zero) return null;
        if (!await iterator.moveNext().timeout(remaining)) break;
        body.addAll(iterator.current);
        if (body.length > manifestMaxBytes) return null;
      }
      return transformFromManifest(jsonDecode(utf8.decode(body)));
    } catch (_) {
      return null;
    } finally {
      final open = chunks;
      if (open != null) unawaited(open.cancel().catchError((Object _) {}));
      if (client == null) active.close();
    }
  }
}
