import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'search_suggestions.dart';

class MapSearchSuggestion {
  final String label;
  final String type;
  final String? subtitle;
  final String? id;
  final LatLng? position;

  const MapSearchSuggestion({
    required this.label,
    required this.type,
    this.subtitle,
    this.id,
    this.position,
  });

  IconData get icon {
    switch (type) {
      case 'profile':
        return Icons.account_circle_outlined;
      case 'institution':
        return Icons.museum_outlined;
      case 'event':
        return Icons.event_available;
      case 'marker':
        return Icons.location_on_outlined;
      case 'artwork':
      default:
        return Icons.auto_awesome;
    }
  }

  factory MapSearchSuggestion.fromMap(Map<String, dynamic> map) {
    final lat = map['lat'] ?? map['latitude'];
    final lng = map['lng'] ?? map['longitude'];
    LatLng? position;
    if (lat is num && lng is num) {
      position = LatLng(lat.toDouble(), lng.toDouble());
    }

    final label = (map['label'] ??
            map['displayName'] ??
            map['display_name'] ??
            map['title'] ??
            '')
        .toString();

    String? subtitle = map['subtitle']?.toString();
    if (subtitle == null || subtitle.isEmpty) {
      final username = (map['username'] ?? map['handle'])?.toString();
      final wallet = (map['wallet'] ?? map['walletAddress'] ?? map['wallet_address'])?.toString();
      if (username != null && username.isNotEmpty) {
        subtitle = '@$username';
      } else if (wallet != null && wallet.isNotEmpty) {
        subtitle = maskWallet(wallet);
      }
    }

    return MapSearchSuggestion(
      label: label,
      type: map['type']?.toString() ?? 'artwork',
      subtitle: subtitle,
      id: map['id']?.toString() ?? (map['wallet']?.toString()),
      position: position,
    );
  }
}
