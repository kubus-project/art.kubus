import 'package:flutter/foundation.dart' as foundation;

import '../config/api_keys.dart';
import '../config/config.dart';

/// Centralized storage configuration shared by art and AR services.
class StorageConfig {
  // IPFS Gateways (prioritized list)
  static const List<String> ipfsGateways = [
    'https://dweb.link/ipfs/',
    'https://ipfs.io/ipfs/',
    'https://gateway.pinata.cloud/ipfs/',
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
    final ordered = <String>[];
    final seen = <String>{};

    void addCandidate(String raw) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return;
      if (seen.add(trimmed)) {
        ordered.add(trimmed);
      }
    }

    final single = _envIpfsGateway.trim();
    if (single.isNotEmpty) {
      for (final value in single.split(',')) {
        addCandidate(value);
      }
    }

    final csv = _envIpfsGateways.trim();
    if (csv.isNotEmpty) {
      for (final value in csv.split(',')) {
        addCandidate(value);
      }
    }

    // Always append built-in defaults as fallback candidates.
    for (final gateway in ipfsGateways) {
      addCandidate(gateway);
    }

    return ordered;
  }

  /// Resolve storage URLs by handling IPFS CIDs and backend-relative paths.
  /// Falls back to the configured HTTP backend for relative paths.
  static String? resolveUrl(String? raw) {
    final candidates = resolveAllUrls(raw);
    if (candidates.isEmpty) return null;
    return candidates.first;
  }

  /// Resolve storage URLs and return all ordered gateway candidates.
  ///
  /// The first item is the preferred URL; following items are fallbacks.
  static List<String> resolveAllUrls(String? raw) {
    if (raw == null) return const <String>[];
    final url = raw.trim();
    if (url.isEmpty) return const <String>[];

    // Bare CID (v0 "Qm..." or v1 "bafy..."): treat as IPFS.
    if (isLikelyCid(url)) {
      return _ipfsGatewayCandidatesFor(url);
    }

    // IPFS: handle ipfs://CID, ipfs/CID, or /ipfs/CID variants
    if (url.startsWith('ipfs://')) {
      final cid =
          url.replaceFirst('ipfs://', '').replaceFirst(RegExp(r'^ipfs/'), '');
      return _ipfsGatewayCandidatesFor(cid);
    }
    if (url.startsWith('/ipfs/') || url.startsWith('ipfs/')) {
      final cid =
          url.split('/ipfs/').last.replaceFirst(RegExp(r'^ipfs/'), '');
      return _ipfsGatewayCandidatesFor(cid);
    }
    if (url.contains('/ipfs/') && !url.startsWith('http')) {
      final cid =
          url.split('/ipfs/').last.replaceFirst(RegExp(r'^ipfs/'), '');
      return _ipfsGatewayCandidatesFor(cid);
    }

    // IPNS: handle ipns://domain/path, /ipns/domain/path, or ipns/domain/path.
    if (url.startsWith('ipns://')) {
      final path =
          url.replaceFirst('ipns://', '').replaceFirst(RegExp(r'^ipns/'), '');
      return _ipnsGatewayCandidatesFor(path);
    }
    if (url.startsWith('/ipns/') || url.startsWith('ipns/')) {
      final path =
          url.split('/ipns/').last.replaceFirst(RegExp(r'^ipns/'), '');
      return _ipnsGatewayCandidatesFor(path);
    }
    if (url.contains('/ipns/') && !url.startsWith('http')) {
      final path =
          url.split('/ipns/').last.replaceFirst(RegExp(r'^ipns/'), '');
      return _ipnsGatewayCandidatesFor(path);
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
          return resolveAllUrls(relative.toString());
        }

        // On Flutter Web, mixed-content HTTP URLs are blocked on HTTPS sites.
        // Best-effort upgrade to HTTPS in secure contexts.
        if (_isWebSecureContext && uri.scheme == 'http') {
          return <String>[uri.replace(scheme: 'https').toString()];
        }
      }
      return <String>[url];
    }

    // Relative path: prefix with configured backend when available
    final backend = _effectiveHttpBackendForResolution;
    if (backend.isEmpty) return <String>[url];
    return <String>[url.startsWith('/') ? '$backend$url' : '$backend/$url'];
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

  static List<String> _ipfsGatewayCandidatesFor(String cidOrPath) {
    final normalizedPath = _normalizeIpfsPath(cidOrPath);
    if (normalizedPath.isEmpty) return const <String>[];

    final urls = <String>[];
    final seen = <String>{};
    for (final gateway in activeIpfsGateways) {
      final normalizedGateway = _normalizeGateway(gateway);
      if (normalizedGateway.isEmpty) continue;
      final candidate = '$normalizedGateway$normalizedPath';
      if (seen.add(candidate)) {
        urls.add(candidate);
      }
    }
    return urls;
  }

  static List<String> _ipnsGatewayCandidatesFor(String path) {
    final normalizedPath = _normalizeMutablePath(path);
    if (normalizedPath.isEmpty) return const <String>[];

    final urls = <String>[];
    final seen = <String>{};
    final gateways = activeIpfsGateways;

    // Prefer a direct dweb.link DNSLink subdomain candidate when possible.
    for (final gateway in gateways) {
      final candidate =
          _buildDwebIpnsSubdomainCandidate(gateway, normalizedPath);
      if (candidate == null || candidate.isEmpty) continue;
      if (seen.add(candidate)) {
        urls.add(candidate);
      }
    }

    // Then include standard /ipns/... gateway paths for all configured gateways.
    for (final gateway in gateways) {
      final normalizedGateway = _normalizeIpnsGateway(gateway);
      if (normalizedGateway.isEmpty) continue;
      final candidate = '$normalizedGateway$normalizedPath';
      if (seen.add(candidate)) {
        urls.add(candidate);
      }
    }

    return urls;
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

  static String _normalizeIpfsPath(String path) {
    var normalized = path.trim();
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    if (normalized.startsWith('ipfs/')) {
      normalized = normalized.substring('ipfs/'.length);
    }
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  static String _normalizeIpnsGateway(String gateway) {
    var g = gateway.trim();
    if (g.isEmpty) return g;
    if (!g.endsWith('/')) g = '$g/';
    if (g.contains('/ipfs/')) {
      return g.replaceFirst('/ipfs/', '/ipns/');
    }
    if (!g.contains('/ipns/')) {
      g = '${g}ipns/';
    }
    return g;
  }

  static String _normalizeMutablePath(String path) {
    var normalized = path.trim();
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    if (normalized.startsWith('ipns/')) {
      normalized = normalized.substring('ipns/'.length);
    }
    return normalized;
  }

  static String? _buildDwebIpnsSubdomainCandidate(
    String gateway,
    String normalizedPath,
  ) {
    final parsedGateway = Uri.tryParse(gateway.trim());
    if (parsedGateway == null) return null;
    if (parsedGateway.host.toLowerCase() != 'dweb.link') return null;

    final firstSlash = normalizedPath.indexOf('/');
    final mutableName =
        firstSlash >= 0 ? normalizedPath.substring(0, firstSlash) : normalizedPath;
    if (!_looksLikeDnsLinkName(mutableName)) return null;

    final encodedName = _encodeDnsLinkNameForDweb(mutableName);
    if (encodedName.isEmpty) return null;

    final remainingPath =
        firstSlash >= 0 ? normalizedPath.substring(firstSlash + 1) : '';
    final scheme = parsedGateway.scheme.isEmpty ? 'https' : parsedGateway.scheme;
    final port = parsedGateway.hasPort ? ':${parsedGateway.port}' : '';
    final suffix = remainingPath.isEmpty ? '' : '/$remainingPath';

    return '$scheme://$encodedName.ipns.dweb.link$port$suffix';
  }

  static bool _looksLikeDnsLinkName(String value) {
    final candidate = value.trim();
    return candidate.contains('.') && candidate.length >= 3;
  }

  static String _encodeDnsLinkNameForDweb(String value) {
    final lowered = value.trim().toLowerCase();
    if (lowered.isEmpty) return '';
    final replaced = lowered.replaceAll(RegExp(r'[^a-z0-9-]'), '-');
    final collapsed = replaced.replaceAll(RegExp(r'-+'), '-');
    return collapsed.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static bool isLikelyCid(String value) {
    final candidate = value.trim();
    if (candidate.isEmpty) return false;
    // CIDv0: base58btc, starts with "Qm", length 46
    if (RegExp(r'^Qm[1-9A-HJ-NP-Za-km-z]{44}$').hasMatch(candidate)) return true;
    // CIDv1: often starts with "bafy". Be permissive here to support dev/test fixtures
    // and alternative multibase encodings (some environments use non-strict samples).
    if (RegExp(r'^bafy[a-z0-9]{20,}$').hasMatch(candidate.toLowerCase())) return true;
    return false;
  }
}
