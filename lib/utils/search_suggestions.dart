import 'package:flutter/foundation.dart';

import 'creator_display_format.dart';
import 'wallet_utils.dart';

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

      String inferType() {
        final rawType = (m['type'] ?? '').toString().trim();
        if (rawType.isNotEmpty) return rawType;

        // Heuristics: avoid treating embedded creator usernames on artworks as
        // a profile suggestion.
        final hasArtworkShape = m.containsKey('artworkId') ||
            m.containsKey('artwork_id') ||
            m.containsKey('arMarkerId') ||
            m.containsKey('ar_marker_id') ||
            m.containsKey('rewards') ||
            m.containsKey('modelCID') ||
            m.containsKey('model3DCID') ||
            m.containsKey('model3dCID') ||
            m.containsKey('category') ||
            m.containsKey('tags');

        final hasEventShape = m.containsKey('eventId') ||
            m.containsKey('event_id') ||
            m.containsKey('startsAt') ||
            m.containsKey('endsAt') ||
            m.containsKey('starts_at') ||
            m.containsKey('ends_at');

        final hasExhibitionShape = m.containsKey('exhibitionId') ||
            m.containsKey('exhibition_id') ||
            m.containsKey('exhibition');

        final hasInstitutionShape = m.containsKey('institutionId') ||
            m.containsKey('institution_id') ||
            m.containsKey('institution');

        final hasProfileShape = m.containsKey('walletAddress') ||
            m.containsKey('wallet_address') ||
            m.containsKey('wallet') ||
            m.containsKey('displayName') ||
            m.containsKey('display_name') ||
            m.containsKey('bio');

        if (hasArtworkShape) return 'artwork';
        if (hasEventShape || hasExhibitionShape) return 'event';
        if (hasInstitutionShape) return 'institution';
        if (hasProfileShape || m.containsKey('username') || m.containsKey('handle')) {
          return 'profile';
        }

        // If it has a title/name and coordinates, it's usually map content.
        if ((m['title'] ?? m['name']) != null) return 'artwork';
        return 'artwork';
      }

      final type = inferType();

      final rawDisplayName = (m['displayName'] ?? m['display_name'] ?? m['name'] ?? m['label'])?.toString();
      final rawUsername = (m['username'] ?? m['handle'])?.toString();
      final wallet = (m['wallet'] ?? m['walletAddress'] ?? m['wallet_address'] ?? m['id'])?.toString();

      String label;
      String? subtitle;
      String? id;

      if (type == 'profile' || type == 'institution') {
        final walletFallback = (wallet != null && wallet.trim().isNotEmpty)
            ? maskWallet(wallet.trim())
            : 'Unknown artist';
        final formatted = CreatorDisplayFormat.format(
          fallbackLabel: walletFallback,
          displayName: rawDisplayName,
          username: rawUsername,
          wallet: wallet,
        );
        label = formatted.primary;
        subtitle = formatted.secondary;
        id = wallet ?? (m['id']?.toString() ?? m['username']?.toString());
      } else {
        label = (m['displayName'] ??
                m['display_name'] ??
                m['title'] ??
                m['label'] ??
                m['name'] ??
                '')
            .toString();
        id = (m['id'] ?? m['walletAddress'] ?? m['wallet'] ?? m['wallet_address'])?.toString();

        // Prefer domain-specific subtitles so map search feels relevant.
        if (m['subtitle'] != null && m['subtitle'].toString().trim().isNotEmpty) {
          subtitle = m['subtitle'].toString();
        } else if (type.toLowerCase() == 'artwork') {
          final rawArtist = (m['artist'] ??
                  m['artistName'] ??
                  m['artist_name'] ??
                  m['creatorName'] ??
                  m['creator_name'] ??
                  m['creator'] ??
                  m['authorName'] ??
                  m['author_name'])
              ?.toString()
              .trim();
          if (rawArtist != null && rawArtist.isNotEmpty && !WalletUtils.looksLikeWallet(rawArtist)) {
            subtitle = rawArtist;
          }
        } else if (type.toLowerCase() == 'event') {
          final rawLocation = (m['locationName'] ??
                  m['location_name'] ??
                  m['venue'] ??
                  m['city'])
              ?.toString()
              .trim();
          if (rawLocation != null && rawLocation.isNotEmpty) {
            subtitle = rawLocation;
          }
        } else if (type.toLowerCase() == 'marker') {
          final rawMarkerType = (m['markerType'] ??
                  m['marker_type'] ??
                  m['subjectType'] ??
                  m['subject_type'])
              ?.toString()
              .trim();
          if (rawMarkerType != null && rawMarkerType.isNotEmpty) {
            subtitle = rawMarkerType;
          }
        }

        var username = rawUsername;
        if (username != null) {
          username = username.trim();
          if (username.startsWith('@')) username = username.substring(1).trim();
        }
        final hasSafeUsername =
            username != null && username.isNotEmpty && !WalletUtils.looksLikeWallet(username);

        // Only fall back to @username/wallet if we still have no useful subtitle.
        if ((subtitle ?? '').trim().isEmpty) {
          if (hasSafeUsername) {
            subtitle = '@$username';
          } else if (wallet != null && wallet.trim().isNotEmpty) {
            subtitle = maskWallet(wallet.trim());
          }
        }
      }

      double? lat;
      double? lng;
      final latRaw = m['lat'] ?? m['latitude'] ?? (m['latlng'] is Map ? (m['latlng']['lat']) : null);
      final lngRaw = m['lng'] ?? m['longitude'] ?? (m['latlng'] is Map ? (m['latlng']['lng']) : null);
      if (latRaw is num) lat = latRaw.toDouble();
      if (lngRaw is num) lng = lngRaw.toDouble();

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
