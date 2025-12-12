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

  // Allow overriding the upload backend via --dart-define to keep dev/staging builds off prod.
  static final String _envHttpBackend =
      const String.fromEnvironment('STORAGE_HTTP_BACKEND', defaultValue: '');

  // Default HTTP backend resolved from env → ApiKeys → AppConfig fallback.
  static final String defaultHttpBackend = _normalizeBaseUrl(
    _envHttpBackend.isNotEmpty
        ? _envHttpBackend
        : (ApiKeys.backendUrl.isNotEmpty
            ? ApiKeys.backendUrl
            : AppConfig.baseApiUrl),
  );

  // Custom backend URL (can be overridden at runtime)
  static String? customHttpBackend;

  // IPFS pin service configuration - values come from ApiKeys
  static String get pinataApiUrl => ApiKeys.ipfsApiUrl;
  static String get pinataApiKey => ApiKeys.pinataApiKey;
  static String get pinataSecretKey => ApiKeys.pinataSecretKey;
  static String get ipfsGateway => ApiKeys.ipfsGateway;

  /// Resolve storage URLs by handling IPFS CIDs and backend-relative paths.
  /// Falls back to the configured HTTP backend for relative paths.
  static String? resolveUrl(String? raw) {
    if (raw == null) return null;
    final url = raw.trim();
    if (url.isEmpty) return null;

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
    if (url.startsWith('http://') || url.startsWith('https://')) return url;

    // Relative path: prefix with configured backend when available
    final backend = httpBackend;
    if (backend.isEmpty) return url;
    return url.startsWith('/') ? '$backend$url' : '$backend/$url';
  }

  /// Get active HTTP backend URL
  static String get httpBackend =>
      _normalizeBaseUrl(customHttpBackend ?? defaultHttpBackend);

  /// Override HTTP backend (useful for QA environments)
  static void setHttpBackend(String url) {
    customHttpBackend = _normalizeBaseUrl(url);
  }

  static String _ipfsGatewayFor(String cid) {
    final gateway = ipfsGateway.isNotEmpty
        ? ipfsGateway
        : (ipfsGateways.isNotEmpty ? ipfsGateways.first : 'https://ipfs.io/ipfs/');
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
}
