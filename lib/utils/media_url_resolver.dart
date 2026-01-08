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

  /// Resolves a raw media reference into an absolute URL when possible.
  ///
  /// - Passes through `data:`, `blob:`, and `asset:` URIs unchanged.
  /// - Supports `ipfs://`, `ipfs/`, `/ipfs/` and backend-relative paths via `StorageConfig`.
  /// - Normalizes protocol-relative URLs (`//...`) to `https://`.
  static String? resolve(String? raw) {
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

    // Flutter Web (CanvasKit) loads images via fetch/wasm decode and therefore
    // requires upstream CORS headers. For third-party hosts that don't set CORS,
    // route through our backend proxy (which is same-origin to the app's API).
    if (foundation.kIsWeb && AppConfig.isFeatureEnabled('externalImageProxy')) {
      final lowerResolved = resolved.toLowerCase();
      final isHttp = lowerResolved.startsWith('http://') || lowerResolved.startsWith('https://');
      if (
          isHttp &&
          _looksLikeImageUrl(resolved) &&
          !_isSameHostAsBackend(resolved) &&
          !lowerResolved.contains('/api/media/proxy')
      ) {
        return _proxyImageUrl(resolved);
      }
    }

    return resolved;
  }
}
