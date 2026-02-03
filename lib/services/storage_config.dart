import 'package:flutter/foundation.dart' as foundation;

import '../config/api_keys.dart';
import '../config/config.dart';

/// Centralized storage configuration shared by art and AR services.
class StorageConfig {
  // IPFS Gateways (prioritized list)
  static const List<String> ipfsGateways = [
    'https://ipfs.io/ipfs/',
    'https://gateway.pinata.cloud/ipfs/',
    'https://cloudflare-ipfs.com/ipfs/',
    'https://dweb.link/ipfs/',
  ];

  // Optional overrides via --dart-define for dev/staging builds.
  // - IPFS_GATEWAY: single gateway base URL
  // - IPFS_GATEWAYS: comma-separated list of gateway base URLs
  static final String _envIpfsGateway =
      const String.fromEnvironment('IPFS_GATEWAY', defaultValue: '');
  static final String _envIpfsGateways =
      const String.fromEnvironment('IPFS_GATEWAYS', defaultValue: '');

  // Allow overriding the upload backend via --dart-define to keep dev/staging builds off prod.
  static final String _envHttpBackend =
      const String.fromEnvironment('STORAGE_HTTP_BACKEND', defaultValue: '');

  // Default HTTP backend resolved from env → ApiKeys → AppConfig fallback.
  static final String defaultHttpBackend = _normalizeBaseUrl(
    _envHttpBackend.isNotEmpty
        ? _envHttpBackend
      : (AppConfig.baseApiUrl.isNotEmpty
        ? AppConfig.baseApiUrl
        : ApiKeys.backendUrl),
  );

  // Custom backend URL (can be overridden at runtime)
  static String? customHttpBackend;

  // IPFS pin service configuration - values come from ApiKeys
  static String get pinataApiUrl => ApiKeys.ipfsApiUrl;
  static String get pinataApiKey => ApiKeys.pinataApiKey;
  static String get pinataSecretKey => ApiKeys.pinataSecretKey;

  static List<String> get activeIpfsGateways {
    final single = _selectGateway(_envIpfsGateway);
    if (single.trim().isNotEmpty) return [single.trim()];

    final csv = _envIpfsGateways.trim();
    if (csv.isNotEmpty) {
      return csv
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    return ipfsGateways;
  }

  /// Resolve storage URLs by handling IPFS CIDs and backend-relative paths.
  /// Falls back to the configured HTTP backend for relative paths.
  static String? resolveUrl(String? raw) {
    if (raw == null) return null;
    final url = raw.trim();
    if (url.isEmpty) return null;

    // Bare CID (v0 "Qm..." or v1 "bafy..."): treat as IPFS.
    if (isLikelyCid(url)) {
      return _ipfsGatewayFor(url);
    }

    // IPFS: handle ipfs://CID, ipfs/CID, or /ipfs/CID variants
    if (url.startsWith('ipfs://')) {
      final cid = url.replaceFirst('ipfs://', '').replaceFirst(RegExp(r'^ipfs/'), '');
      return _ipfsGatewayFor(cid);
    }
    if (url.startsWith('/ipfs/') || url.startsWith('ipfs/')) {
      final cid = url.split('/ipfs/').last.replaceFirst(RegExp(r'^ipfs/'), '');
      return _ipfsGatewayFor(cid);
    }
    if (url.contains('/ipfs/') && !url.startsWith('http')) {
      final cid = url.split('/ipfs/').last.replaceFirst(RegExp(r'^ipfs/'), '');
      return _ipfsGatewayFor(cid);
    }

    // Already absolute HTTP(S)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final path = uri.path;

        // If the URL points to a backend-managed upload path, canonicalize it
        // to the configured storage backend. This avoids stale or unreachable
        // absolute URLs being persisted (e.g. http://localhost/...).
        if (path.startsWith('/uploads/') || path.startsWith('/profiles/') || path.startsWith('/avatars/')) {
          final relative = StringBuffer(path);
          if (uri.hasQuery) relative.write('?${uri.query}');
          if (uri.hasFragment) relative.write('#${uri.fragment}');
          return resolveUrl(relative.toString());
        }

        // On Flutter Web, mixed-content HTTP URLs are blocked on HTTPS sites.
        // Best-effort upgrade to HTTPS in secure contexts.
        if (_isWebSecureContext && uri.scheme == 'http') {
          return uri.replace(scheme: 'https').toString();
        }
      }
      return url;
    }

    // Relative path: prefix with configured backend when available
    final backend = _effectiveHttpBackendForResolution;
    if (backend.isEmpty) return url;
    return url.startsWith('/') ? '$backend$url' : '$backend/$url';
  }

  /// Get active HTTP backend URL
  static String get httpBackend =>
      _normalizeBaseUrl(customHttpBackend ?? defaultHttpBackend);

  static bool get _isWebSecureContext =>
      foundation.kIsWeb && Uri.base.scheme.toLowerCase() == 'https';

  static String get _effectiveHttpBackendForResolution {
    final backend = httpBackend;
    if (!_isWebSecureContext) return backend;
    if (backend.startsWith('http://')) {
      return 'https://${backend.substring('http://'.length)}';
    }
    return backend;
  }

  /// Override HTTP backend (useful for QA environments)
  static void setHttpBackend(String url) {
    customHttpBackend = _normalizeBaseUrl(url);
  }

  static String _ipfsGatewayFor(String cid) {
    final gateways = activeIpfsGateways;
    final gateway = gateways.isNotEmpty ? gateways.first : '';
    final normalizedGateway = _normalizeGateway(gateway);
    return '$normalizedGateway$cid';
  }

  static String _normalizeBaseUrl(String url) {
    if (url.isEmpty) return url;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String _normalizeGateway(String gateway) {
    var g = gateway.trim();
    if (g.isEmpty) return g;
    if (!g.endsWith('/')) g = '$g/';
    if (!g.contains('/ipfs/')) g = '${g}ipfs/';
    return g;
  }

  static String _selectGateway(String rawGateway) {
    final trimmed = rawGateway.trim();
    if (!trimmed.contains(',')) return trimmed;
    final parts = trimmed.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.first : trimmed;
  }

  static bool isLikelyCid(String value) {
    final candidate = value.trim();
    if (candidate.isEmpty) return false;
    // CIDv0: base58btc, starts with "Qm", length 46
    if (RegExp(r'^Qm[1-9A-HJ-NP-Za-km-z]{44}$').hasMatch(candidate)) return true;
    // CIDv1: base32, commonly starts with "bafy"
    if (RegExp(r'^bafy[a-z2-7]{20,}$').hasMatch(candidate.toLowerCase())) return true;
    return false;
  }
}
