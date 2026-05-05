import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_client_factory.dart';
import 'storage_config.dart';

class IpfsMetadataResolver {
  IpfsMetadataResolver({
    http.Client? client,
    this.gatewayTimeout = const Duration(milliseconds: 3500),
    this.negativeCacheTtl = const Duration(minutes: 5),
    this.successCacheTtl = const Duration(minutes: 30),
  }) : _client = client ?? createPlatformHttpClient();

  static final IpfsMetadataResolver instance = IpfsMetadataResolver();

  final http.Client _client;
  final Duration gatewayTimeout;
  final Duration negativeCacheTtl;
  final Duration successCacheTtl;
  final Map<String, _IpfsMetadataCacheEntry> _successCache = {};
  final Map<String, DateTime> _negativeCache = {};

  Future<Map<String, dynamic>?> resolveJson(String? raw) async {
    final key = _cacheKey(raw);
    if (key == null) return null;

    final now = DateTime.now();
    final cached = _successCache[key];
    if (cached != null && now.difference(cached.timestamp) <= successCacheTtl) {
      return Map<String, dynamic>.from(cached.data);
    }

    final failedAt = _negativeCache[key];
    if (failedAt != null && now.difference(failedAt) <= negativeCacheTtl) {
      return null;
    }
    _negativeCache.remove(key);

    final candidates = StorageConfig.resolveAllUrls(key);
    if (candidates.isEmpty) {
      _negativeCache[key] = now;
      return null;
    }

    for (final candidate in candidates) {
      final uri = Uri.tryParse(candidate);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) continue;

      try {
        final response = await _client.get(uri).timeout(gatewayTimeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }

        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final data = Map<String, dynamic>.from(decoded);
          _successCache[key] = _IpfsMetadataCacheEntry(
            data: data,
            timestamp: DateTime.now(),
          );
          _negativeCache.remove(key);
          return Map<String, dynamic>.from(data);
        }
      } catch (_) {
        continue;
      }
    }

    _negativeCache[key] = DateTime.now();
    return null;
  }

  String? _cacheKey(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final ipfsIndex = uri.path.indexOf('/ipfs/');
      if (ipfsIndex >= 0) {
        final path = uri.path.substring(ipfsIndex + '/ipfs/'.length);
        return path.isEmpty ? null : 'ipfs://$path';
      }
      final ipnsIndex = uri.path.indexOf('/ipns/');
      if (ipnsIndex >= 0) {
        final path = uri.path.substring(ipnsIndex + '/ipns/'.length);
        return path.isEmpty ? null : 'ipns://$path';
      }
    }
    return trimmed;
  }
}

class _IpfsMetadataCacheEntry {
  _IpfsMetadataCacheEntry({
    required this.data,
    required this.timestamp,
  });

  final Map<String, dynamic> data;
  final DateTime timestamp;
}
