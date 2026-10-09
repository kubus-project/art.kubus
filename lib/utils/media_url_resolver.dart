import 'package:flutter/foundation.dart' as foundation;

import '../config/config.dart';
import '../services/storage_config.dart';
import '../services/telemetry/telemetry_service.dart';

/// Shared media URL resolver for images, models, and other assets.
///
/// Centralizes IPFS and backend-relative path handling so widgets and providers
/// don't re‑implement gateway logic or base URL fallbacks.
class MediaUrlResolver {
  static const Set<String> _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'svg',
    'avif',
  };

  /// Call this when a media proxy request fails with 429 or similar rate limit error.
  static void markProxyRateLimited() {
    // Intentionally a no-op for routing decisions.
    // We never fall back to direct cross-origin fetches for hosts that require
    // proxying, because that reintroduces CORS failures on web.
    if (foundation.kDebugMode) {
      foundation.debugPrint(
        'MediaUrlResolver: proxy rate-limited (routing unchanged)',
      );
    }
  }

  /// Call this when a media proxy request succeeds to reset the failure counter.
  static void markProxySuccess() {
    // Intentionally a no-op; kept for compatibility with existing callers.
  }

  // Hosts that are allowed to be fetched directly by web clients for display
  // images. Any other cross-origin image host is routed through media proxy.
  static const Set<String> _directDisplayDomains = {
    'app.kubus.site',
    'api.kubus.site',
    'art.kubus.site',
    'kubus.site',
    'localhost',
    '127.0.0.1',
    '[::1]',
    // Wikimedia's upload CDN is generally CORS-safe for direct image fetches.
    'upload.wikimedia.org',
  };

  static const int _defaultMaxDisplayWidth = 1600;

  /// Width cap for list rows, cards and thumbnails. Heroes and detail headers
  /// use the default display cap.
  static const int cardMaxWidth = 960;

  // Wikimedia originals are frequently multi-megabyte scans; always request a
  // server-side thumbnail for display so 4G clients don't download 5MB+ per
  // card. Formats that Wikimedia can thumbnail with the same file extension.
  static const Set<String> _wikimediaThumbnailableExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  };
  // Wikimedia's thumbor only serves a fixed set of thumbnail widths and
  // returns 400 for anything else (see https://w.wiki/GHai). Requested widths
  // are snapped up to the nearest allowed bucket.
  static const List<int> _wikimediaThumbWidthBuckets = [
    120,
    250,
    330,
    500,
    960,
    1280,
    1920,
  ];
  static const int _defaultWikimediaThumbWidth = 960;

  static const Set<String> _indirectImageNoiseParams = {
    'v',
    'cb',
    'cachebust',
    'cache_bust',
    '_',
    '_t',
    'ts',
    'timestamp',
  };

  static bool _isHttpUrl(String url) {
    final lower = url.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  static bool _isProxiedUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('/api/media/proxy?url=');
  }

  static String _canonicalizeHttpUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (!uri.hasScheme) return url;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return url;
    return _canonicalizeIndirectImageUrl(uri).toString();
  }

  static Uri _canonicalizeIndirectImageUrl(Uri uri) {
    final isDirectImagePath = _pathLooksLikeImageAsset(uri.path);
    final isKnownRedirector = _isKnownCorsHostileRedirector(uri.toString());
    final params = Map<String, String>.from(uri.queryParameters);

    if (!isDirectImagePath) {
      // Keep indirect resolver URLs cache-stable across small client-side
      // variants (e.g. `width`, `v`, `cb`) that usually don't alter the final
      // origin file selected by upstream redirectors.
      if (!isKnownRedirector) {
        params.remove('width');
        params.remove('w');
      }
      for (final key in _indirectImageNoiseParams) {
        params.remove(key);
      }
    }

    return uri.replace(queryParameters: params.isEmpty ? null : params);
  }

  static bool _pathLooksLikeImageAsset(String path) {
    final lowerPath = path.toLowerCase();
    final dot = lowerPath.lastIndexOf('.');
    if (dot == -1 || dot == lowerPath.length - 1) return false;
    final ext = lowerPath.substring(dot + 1);
    return _imageExtensions.contains(ext);
  }

  static bool _hostMatches(String host, String candidateDomain) {
    final d = candidateDomain.trim().toLowerCase();
    if (d.isEmpty) return false;
    return host == d || host.endsWith('.$d');
  }

  static bool _isAllowedDirectDisplayHost(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      return _directDisplayDomains.any((d) => _hostMatches(host, d));
    } catch (_) {
      return false;
    }
  }

  static bool _isKnownCorsHostileRedirector(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      final path = uri.path.toLowerCase();
      // commons.wikimedia.org/wiki/Special:FilePath/* commonly redirects with
      // non-image + CORS-restricted responses. Route through backend proxy.
      if (_hostMatches(host, 'commons.wikimedia.org') &&
          path.startsWith('/wiki/special:filepath/')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String _clampDisplayWidthQuery(String url, {int? maxWidth}) {
    final targetMaxWidth =
        (maxWidth ?? _defaultMaxDisplayWidth).clamp(64, 4096);
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme) return url;
      final scheme = uri.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https') return url;

      final existing = uri.queryParameters['width'];
      if (existing == null || existing.trim().isEmpty) return url;
      final parsedWidth = int.tryParse(existing.trim());
      if (parsedWidth == null || parsedWidth <= 0) return url;
      if (parsedWidth <= targetMaxWidth) return url;

      final params = Map<String, String>.from(uri.queryParameters);
      params['width'] = '$targetMaxWidth';
      return uri.replace(queryParameters: params).toString();
    } catch (_) {
      return url;
    }
  }

  /// Rewrites a Wikimedia Commons original-file URL to a server-side
  /// thumbnail URL, e.g.
  /// `upload.wikimedia.org/wikipedia/commons/a/ab/File.jpg`
  /// → `upload.wikimedia.org/wikipedia/commons/thumb/a/ab/File.jpg/1024px-File.jpg`.
  ///
  /// Returns the input unchanged for non-Wikimedia hosts, already-thumbnailed
  /// URLs, and formats that don't thumbnail cleanly (SVG/TIFF/PDF).
  @foundation.visibleForTesting
  static String rewriteWikimediaThumb(String url, {int? maxWidth}) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (!_hostMatches(uri.host.toLowerCase(), 'upload.wikimedia.org')) {
      return url;
    }

    // Work on the raw (still percent-encoded) URL string so the filename
    // keeps its original encoding in the rebuilt thumb URL. Uri.path would
    // decode `%2C` etc.
    final withoutQuery = url.split('?').first.split('#').first;
    final pathStart = withoutQuery.indexOf('/wikipedia/');
    if (pathStart == -1) return url;
    final parts = withoutQuery.substring(pathStart).split('/');
    // Expected: ['', 'wikipedia', '<project>', '<h1>', '<h2>', '<File.ext>'].
    // Thumb URLs have more segments: they are left untouched unless the caller
    // asked for a specific width (see [_rebucketWikimediaThumb]).
    if (parts.length == 8 && maxWidth != null) {
      return _rebucketWikimediaThumb(withoutQuery, pathStart, parts, maxWidth);
    }
    if (parts.length != 6) return url;

    final fileName = parts.last;
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return url;
    final ext = fileName.substring(dot + 1).toLowerCase();
    if (!_wikimediaThumbnailableExtensions.contains(ext)) return url;

    final requestedWidth = maxWidth ?? _defaultWikimediaThumbWidth;
    final width = _wikimediaThumbWidthBuckets.firstWhere(
      (bucket) => bucket >= requestedWidth,
      orElse: () => _wikimediaThumbWidthBuckets.last,
    );
    final thumbPath = '/wikipedia/${parts[2]}/thumb/${parts[3]}/${parts[4]}'
        '/$fileName/${width}px-$fileName';
    // Cache-buster queries are dropped; thumbs are immutable per name+width.
    return '${withoutQuery.substring(0, pathStart)}$thumbPath';
  }

  /// Snaps an existing Wikimedia thumbnail URL
  /// (`.../thumb/a/ab/File.jpg/960px-File.jpg`) down to the bucket for
  /// [maxWidth].
  ///
  /// Records often store a thumb URL that is far larger than the surface that
  /// shows it (a map marker face is ~44 logical px). A thumb is only ever
  /// replaced by a *smaller* one; a URL that is not a plain `NNNpx-` thumb, or
  /// is already small enough, is returned as it was given.
  static String _rebucketWikimediaThumb(
    String withoutQuery,
    int pathStart,
    List<String> parts,
    int maxWidth,
  ) {
    // ['', 'wikipedia', project, 'thumb', h1, h2, File, 'NNNpx-File'].
    if (parts[3] != 'thumb') return withoutQuery;
    final thumbName = parts.last;
    final match = RegExp(r'^(\d+)px-(.+)$').firstMatch(thumbName);
    if (match == null) return withoutQuery;
    final currentWidth = int.parse(match.group(1)!);
    final width = _wikimediaThumbWidthBuckets.firstWhere(
      (bucket) => bucket >= maxWidth,
      orElse: () => _wikimediaThumbWidthBuckets.last,
    );
    if (width >= currentWidth) return withoutQuery;
    final rebuilt = <String>[...parts]..[parts.length - 1] =
        '${width}px-${match.group(2)}';
    return '${withoutQuery.substring(0, pathStart)}${rebuilt.join('/')}';
  }

  static bool _looksLikeImageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return _pathLooksLikeImageAsset(uri.path);
    } catch (_) {
      return false;
    }
  }

  static String _proxyImageUrl(String absoluteUrl) {
    final queryParams = <String, String>{
      'url': absoluteUrl,
    };
    final sessionId = TelemetryService().currentSessionId;
    if (sessionId != null && sessionId.isNotEmpty) {
      queryParams['sid'] = sessionId;
    }
    final proxyPath = Uri(
      path: '/api/media/proxy',
      queryParameters: queryParams,
    ).toString();
    return StorageConfig.resolveUrl(proxyPath) ?? proxyPath;
  }

  static bool _isSameHostAsBackend(String absoluteUrl) {
    try {
      final backend = Uri.parse(StorageConfig.httpBackend);
      final uri = Uri.parse(absoluteUrl);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return true;
      }
      return backend.host.isNotEmpty &&
          backend.host.toLowerCase() == uri.host.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  static bool _isSameHostAsCurrentOrigin(String absoluteUrl) {
    if (!foundation.kIsWeb) return false;
    try {
      final uri = Uri.parse(absoluteUrl);
      final current = Uri.base;
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return true;
      }
      return current.host.isNotEmpty &&
          current.host.toLowerCase() == uri.host.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  /// Returns whether a fully-qualified URL should be routed via media proxy
  /// when used for display images on web.
  static bool shouldProxyDisplayUrl(String absoluteUrl) {
    final canonical = _canonicalizeHttpUrl(absoluteUrl);
    if (!_isHttpUrl(canonical)) return false;
    if (_isProxiedUrl(canonical)) return false;
    if (_isKnownCorsHostileRedirector(canonical)) return true;
    if (_isSameHostAsBackend(canonical)) return false;
    if (_isSameHostAsCurrentOrigin(canonical)) return false;
    return !_isAllowedDirectDisplayHost(canonical);
  }

  /// Resolves a raw media reference into an absolute URL when possible.
  ///
  /// Non-display variant: used for models, files and any reference that is not
  /// rendered as a size-clamped image. See [_resolveCandidates] for the rules.
  static String? resolve(String? raw) {
    return _firstCandidate(_resolveCandidates(raw, forDisplay: false));
  }

  /// Resolves an image/display URL.
  ///
  /// For Flutter Web, this routes non-allowlisted external hosts through the
  /// backend media proxy to avoid CORS/image decode failures in CanvasKit.
  static String? resolveDisplayUrl(String? raw, {int? maxWidth}) {
    return _firstCandidate(
      _resolveCandidates(raw, forDisplay: true, maxWidth: maxWidth),
    );
  }

  /// Every display URL for [raw], in preference order.
  ///
  /// IPFS references resolve to one candidate per configured gateway so an
  /// image widget can step to the next gateway when the first one fails. All
  /// other references yield at most one candidate.
  static List<String> resolveDisplayCandidates(String? raw, {int? maxWidth}) {
    return _resolveCandidates(raw, forDisplay: true, maxWidth: maxWidth);
  }

  /// The single fallback walker for entity media fields.
  ///
  /// Callers pass their field chain in preference order (for example an
  /// artwork's `imageUrl`, then its CID, then fallbacks). The first reference
  /// that resolves to a safe URL wins. Unsafe, empty and placeholder entries
  /// are skipped, never passed through.
  static String? firstDisplayUrl(
    Iterable<String?> refs, {
    int? maxWidth,
  }) {
    for (final raw in refs) {
      final resolved = resolveDisplayUrl(raw, maxWidth: maxWidth);
      if (resolved != null) return resolved;
    }
    return null;
  }

  static String? _firstCandidate(List<String> candidates) {
    return candidates.isEmpty ? null : candidates.first;
  }

  /// URL safety and normalization shared by every media consumer.
  ///
  /// Accepted: absolute `https:` and `http:` (upgraded by [StorageConfig] on
  /// secure web), `ipfs://`, `ipns://`, bare CIDs and `ipfs/` paths (expanded
  /// through the configured gateways), protocol-relative `//host/...`, and
  /// backend-relative paths (prefixed with the storage backend).
  ///
  /// Rejected (returns no candidates): `javascript:`, `data:`, `file:`,
  /// `blob:`, `asset:`, `vbscript:` and every other scheme, `placeholder://`,
  /// empty and null input.
  static List<String> _resolveCandidates(
    String? raw, {
    required bool forDisplay,
    int? maxWidth,
  }) {
    if (raw == null) return const <String>[];
    var candidate = raw.trim();
    if (candidate.isEmpty) return const <String>[];

    final lower = candidate.toLowerCase();
    if (lower.startsWith('placeholder://')) return const <String>[];

    final scheme = _schemeOf(candidate);
    if (scheme != null) {
      if (scheme == 'ipfs' || scheme == 'ipns') {
        // `ipfs:<cid>` and `ipfs:/<cid>` are accepted as `ipfs://<cid>`; the
        // same for `ipns:`.
        if (!lower.startsWith('$scheme://')) {
          final rest = candidate.substring(scheme.length + 1);
          candidate = '$scheme://${rest.replaceFirst(RegExp(r'^/+'), '')}';
        }
      } else if (!_allowedSchemes.contains(scheme)) {
        return const <String>[];
      }
    }

    if (candidate.startsWith('//')) {
      candidate = 'https:$candidate';
    }

    final resolvedCandidates = StorageConfig.resolveAllUrls(candidate);
    final out = <String>[];
    for (final resolved in resolvedCandidates) {
      var normalized = _canonicalizeHttpUrl(resolved);
      if (forDisplay && _isHttpUrl(normalized)) {
        normalized = _clampDisplayWidthQuery(normalized, maxWidth: maxWidth);
        normalized = rewriteWikimediaThumb(normalized, maxWidth: maxWidth);
      }

      // Flutter Web (CanvasKit) loads images via fetch/wasm decode and therefore
      // requires upstream CORS headers. Route external display media through
      // backend proxy unless the host is explicitly allowlisted.
      if (foundation.kIsWeb &&
          AppConfig.isFeatureEnabled('externalImageProxy') &&
          _isHttpUrl(normalized)) {
        if (forDisplay) {
          if (shouldProxyDisplayUrl(normalized)) {
            normalized = _proxyImageUrl(normalized);
          }
        } else if (_looksLikeImageUrl(normalized) &&
            shouldProxyDisplayUrl(normalized)) {
          normalized = _proxyImageUrl(normalized);
        }
      }

      if (normalized.isNotEmpty && !out.contains(normalized)) {
        out.add(normalized);
      }
    }
    return out;
  }

  static const Set<String> _allowedSchemes = {'http', 'https', 'ipfs', 'ipns'};

  static final RegExp _schemePattern = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.\-]*):');

  /// Lower-cased scheme of [candidate] when it carries one (`javascript`,
  /// `data`, `https`, ...), otherwise null. Relative paths and CIDs have none.
  static String? _schemeOf(String candidate) {
    final match = _schemePattern.firstMatch(candidate);
    return match?.group(1)!.toLowerCase();
  }
}
