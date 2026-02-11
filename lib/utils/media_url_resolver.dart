import 'package:flutter/foundation.dart' as foundation;

import '../config/config.dart';
import '../services/storage_config.dart';

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

  // Rate limit tracking for media proxy
  static DateTime? _proxyRateLimitUntil;
  static int _proxyFailureCount = 0;

  /// Call this when a media proxy request fails with 429 or similar rate limit error.
  static void markProxyRateLimited() {
    _proxyFailureCount++;
    // Exponential backoff: 5min, 10min, 20min based on failure count (capped at 3 failures)
    final backoff = Duration(minutes: 5 * (1 << (_proxyFailureCount - 1).clamp(0, 2)));
    _proxyRateLimitUntil = DateTime.now().add(backoff);
    if (foundation.kDebugMode) {
      foundation.debugPrint('MediaUrlResolver: proxy rate-limited until $_proxyRateLimitUntil (failures: $_proxyFailureCount)');
    }
  }

  /// Call this when a media proxy request succeeds to reset the failure counter.
  static void markProxySuccess() {
    _proxyFailureCount = 0;
    _proxyRateLimitUntil = null;
  }

  /// Check if we should skip proxying due to rate limiting.
  static bool get _isProxyRateLimited {
    if (_proxyRateLimitUntil == null) return false;
    if (DateTime.now().isAfter(_proxyRateLimitUntil!)) {
      // Rate limit window expired, allow retry but keep failure count for backoff
      _proxyRateLimitUntil = null;
      return false;
    }
    return true;
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
    // Known permissive media hosts.
    'upload.wikimedia.org',
    'wikimedia.org',
    'wikipedia.org',
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
    return uri.toString();
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

  static bool _looksLikeImageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      final dot = path.lastIndexOf('.');
      if (dot == -1 || dot == path.length - 1) return false;
      final ext = path.substring(dot + 1);
      return _imageExtensions.contains(ext);
    } catch (_) {
      return false;
    }
  }

  static String _proxyImageUrl(String absoluteUrl) {
    final encoded = Uri.encodeQueryComponent(absoluteUrl);
    final proxyPath = '/api/media/proxy?url=$encoded';
    return StorageConfig.resolveUrl(proxyPath) ?? proxyPath;
  }

  static bool _isSameHostAsBackend(String absoluteUrl) {
    try {
      final backend = Uri.parse(StorageConfig.httpBackend);
      final uri = Uri.parse(absoluteUrl);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) return true;
      return backend.host.isNotEmpty && backend.host.toLowerCase() == uri.host.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  static bool _isSameHostAsCurrentOrigin(String absoluteUrl) {
    if (!foundation.kIsWeb) return false;
    try {
      final uri = Uri.parse(absoluteUrl);
      final current = Uri.base;
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) return true;
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
    if (_isSameHostAsBackend(canonical)) return false;
    if (_isSameHostAsCurrentOrigin(canonical)) return false;
    return !_isAllowedDirectDisplayHost(canonical);
  }

  /// Resolves a raw media reference into an absolute URL when possible.
  ///
  /// - Passes through `data:`, `blob:`, and `asset:` URIs unchanged.
  /// - Supports `ipfs://`, `ipfs/`, `/ipfs/` and backend-relative paths via `StorageConfig`.
  /// - Normalizes protocol-relative URLs (`//...`) to `https://`.
  static String? resolve(String? raw) {
    return _resolveInternal(raw, forDisplay: false);
  }

  /// Resolves an image/display URL.
  ///
  /// For Flutter Web, this routes non-allowlisted external hosts through the
  /// backend media proxy to avoid CORS/image decode failures in CanvasKit.
  static String? resolveDisplayUrl(String? raw) {
    return _resolveInternal(raw, forDisplay: true);
  }

  static String? _resolveInternal(String? raw, {required bool forDisplay}) {
    if (raw == null) return null;
    final candidate = raw.trim();
    if (candidate.isEmpty) return null;

    final lower = candidate.toLowerCase();
    if (lower.startsWith('placeholder://')) return null;
    if (lower.startsWith('data:') ||
        lower.startsWith('blob:') ||
        lower.startsWith('asset:')) {
      return candidate;
    }

    if (candidate.startsWith('//')) {
      return StorageConfig.resolveUrl('https:$candidate');
    }

    final resolved = StorageConfig.resolveUrl(candidate);
    if (resolved == null) return null;
    final normalized = _canonicalizeHttpUrl(resolved);

    // Flutter Web (CanvasKit) loads images via fetch/wasm decode and therefore
    // requires upstream CORS headers. Route external display media through
    // backend proxy unless the host is explicitly allowlisted.
    if (foundation.kIsWeb && AppConfig.isFeatureEnabled('externalImageProxy')) {
      // Skip proxying if rate-limited
      if (_isProxyRateLimited) {
        return normalized;
      }

      if (_isHttpUrl(normalized)) {
        if (forDisplay) {
          if (shouldProxyDisplayUrl(normalized)) {
            return _proxyImageUrl(normalized);
          }
        } else if (_looksLikeImageUrl(normalized) &&
            shouldProxyDisplayUrl(normalized)) {
          return _proxyImageUrl(normalized);
        }
      }
    }

    return normalized;
  }
}
