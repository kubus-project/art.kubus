import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'search_suggestions.dart';
import 'creator_display_format.dart';
import 'wallet_utils.dart';

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

    final type = map['type']?.toString() ?? 'artwork';
    final rawDisplayName = (map['displayName'] ?? map['display_name'] ?? map['label'])?.toString();
    final rawUsername = (map['username'] ?? map['handle'])?.toString();
    final wallet = (map['wallet'] ?? map['walletAddress'] ?? map['wallet_address'] ?? map['id'])?.toString();

    String label;
    String? subtitle = map['subtitle']?.toString();

    if (type == 'profile' || type == 'institution') {
      final formatted = CreatorDisplayFormat.format(
        fallbackLabel: 'Unknown creator',
        displayName: rawDisplayName,
        username: rawUsername,
        wallet: wallet,
      );
      label = formatted.primary;
      subtitle = formatted.secondary;
    } else {
      label = (map['label'] ??
              map['displayName'] ??
              map['display_name'] ??
              map['title'] ??
              '')
          .toString();
      if (subtitle == null || subtitle.isEmpty) {
        var username = rawUsername;
        if (username != null) {
          username = username.trim();
          if (username.startsWith('@')) username = username.substring(1).trim();
        }
        final hasSafeUsername =
            username != null && username.isNotEmpty && !WalletUtils.looksLikeWallet(username);
        if (hasSafeUsername) {
          subtitle = '@$username';
        } else if (wallet != null && wallet.isNotEmpty) {
          subtitle = maskWallet(wallet);
        }
      }
    }

    return MapSearchSuggestion(
      label: label,
      type: type,
      subtitle: subtitle,
      id: map['id']?.toString() ?? (map['wallet']?.toString()),
      position: position,
    );
  }
}
