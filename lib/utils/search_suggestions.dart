import 'package:flutter/foundation.dart';

/// Utilities for normalizing search suggestion payloads and small helpers
/// used across UI screens.

List<Map<String, dynamic>> normalizeSearchSuggestionsPayload(dynamic raw) {
  final List<Map<String, dynamic>> out = [];
  try {
    if (raw == null) return out;

    List<dynamic> items = [];
    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      final m = raw;
      if (m.containsKey('results')) {
        final results = m['results'];
        if (results is Map && results.containsKey('profiles') && results['profiles'] is List) {
          items = results['profiles'] as List<dynamic>;
        } else if (results is List) {
          items = results;
        }
      } else if (m.containsKey('profiles') && m['profiles'] is List) {
        items = m['profiles'] as List<dynamic>;
      } else if (m.containsKey('data') && m['data'] is List) {
        items = m['data'] as List<dynamic>;
      } else if (m.containsKey('items') && m['items'] is List) {
        items = m['items'] as List<dynamic>;
      } else {
        items = [m];
      }
    } else {
      try {
        items = List<dynamic>.from(raw as List);
      } catch (_) {
        return out;
      }
    }

    for (final e in items) {
      if (e is! Map) continue;
      final Map<String, dynamic> m = Map<String, dynamic>.from(e);

      final label = (m['displayName'] ?? m['display_name'] ?? m['title'] ?? m['label'] ?? m['name'] ?? m['username'] ?? m['wallet'] ?? '').toString();

      final id = (m['username'] ?? m['id'] ?? m['walletAddress'] ?? m['wallet'] ?? m['wallet_address'])?.toString();

      String? subtitle;
      final username = (m['username'] ?? m['handle'])?.toString();
      final wallet = (m['wallet'] ?? m['walletAddress'] ?? m['wallet_address'])?.toString();
      if (username != null && username.isNotEmpty) {
        subtitle = '@$username';
      } else if (wallet != null && wallet.isNotEmpty) {
        subtitle = maskWallet(wallet);
      } else if (m['subtitle'] != null) {
        subtitle = m['subtitle'].toString();
      }

      double? lat;
      double? lng;
      final latRaw = m['lat'] ?? m['latitude'] ?? (m['latlng'] is Map ? (m['latlng']['lat']) : null);
      final lngRaw = m['lng'] ?? m['longitude'] ?? (m['latlng'] is Map ? (m['latlng']['lng']) : null);
      if (latRaw is num) lat = latRaw.toDouble();
      if (lngRaw is num) lng = lngRaw.toDouble();

      final type = (m['type'] ?? (m.containsKey('username') ? 'profile' : 'artwork')).toString();

      final normalized = <String, dynamic>{
        'label': label,
        'subtitle': subtitle,
        'id': id,
        'type': type,
      };
      if (lat != null && lng != null) {
        normalized['lat'] = lat;
        normalized['lng'] = lng;
      }

      out.add(normalized);
    }
  } catch (e) {
    debugPrint('search_suggestions.normalizeSearchSuggestions error: $e');
    return out;
  }
  return out;
}

String maskWallet(String wallet) {
  if (wallet.isEmpty) return wallet;
  return wallet.length > 10 ? '${wallet.substring(0,4)}...${wallet.substring(wallet.length-4)}' : wallet;
}
