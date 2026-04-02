import 'package:flutter/foundation.dart';

import 'creator_display_format.dart';
import 'wallet_utils.dart';

/// Utilities for normalizing search suggestion payloads and small helpers
/// used across UI screens.

List<Map<String, dynamic>> normalizeSearchSuggestionsPayload(dynamic raw) {
  final List<Map<String, dynamic>> out = [];
  try {
    if (raw == null) return out;

    Map<String, dynamic>? asMap(dynamic value) {
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return null;
    }

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

      final rawDisplayName = (m['displayName'] ??
              m['display_name'] ??
              m['name'] ??
              m['label'] ??
              m['text'])?.toString();
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
                m['text'] ??
                m['name'] ??
                '')
            .toString();
        id = (m['id'] ?? m['walletAddress'] ?? m['wallet'] ?? m['wallet_address'])?.toString();

        // Prefer domain-specific subtitles so map search feels relevant.
        if (m['subtitle'] != null && m['subtitle'].toString().trim().isNotEmpty) {
          subtitle = m['subtitle'].toString();
        } else if (m['secondaryText'] != null &&
            m['secondaryText'].toString().trim().isNotEmpty) {
          subtitle = m['secondaryText'].toString();
        } else if (m['secondary_text'] != null &&
            m['secondary_text'].toString().trim().isNotEmpty) {
          subtitle = m['secondary_text'].toString();
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
      final authorMap = m['author'] is Map
          ? Map<String, dynamic>.from(m['author'] as Map)
          : null;
      final artworkMap = m['artwork'] is Map
          ? Map<String, dynamic>.from(m['artwork'] as Map)
          : null;
      final institutionMap = m['institution'] is Map
          ? Map<String, dynamic>.from(m['institution'] as Map)
          : null;
      final eventMap = m['event'] is Map
          ? Map<String, dynamic>.from(m['event'] as Map)
          : null;
      final metadataMap = m['metadata'] is Map
          ? Map<String, dynamic>.from(m['metadata'] as Map)
          : (m['meta'] is Map
              ? Map<String, dynamic>.from(m['meta'] as Map)
              : null);
      final artworkMetadataMap =
          asMap(artworkMap?['metadata']) ?? asMap(artworkMap?['meta']);
      final institutionMetadataMap =
          asMap(institutionMap?['metadata']) ?? asMap(institutionMap?['meta']);
      final eventMetadataMap =
          asMap(eventMap?['metadata']) ?? asMap(eventMap?['meta']);
      final rootLatLngMap = asMap(m['latlng']);
      final artworkLatLngMap = asMap(artworkMap?['latlng']);
      final institutionLatLngMap = asMap(institutionMap?['latlng']);
      final eventLatLngMap = asMap(eventMap?['latlng']);
      final latRaw = m['lat'] ??
          m['latitude'] ??
          rootLatLngMap?['lat'] ??
          artworkMap?['lat'] ??
          artworkMap?['latitude'] ??
          artworkLatLngMap?['lat'] ??
          institutionMap?['lat'] ??
          institutionMap?['latitude'] ??
          institutionLatLngMap?['lat'] ??
          eventMap?['lat'] ??
          eventMap?['latitude'] ??
          eventLatLngMap?['lat'];
      final lngRaw = m['lng'] ??
          m['longitude'] ??
          rootLatLngMap?['lng'] ??
          artworkMap?['lng'] ??
          artworkMap?['longitude'] ??
          artworkLatLngMap?['lng'] ??
          institutionMap?['lng'] ??
          institutionMap?['longitude'] ??
          institutionLatLngMap?['lng'] ??
          eventMap?['lng'] ??
          eventMap?['longitude'] ??
          eventLatLngMap?['lng'];
      if (latRaw is num) lat = latRaw.toDouble();
      if (lngRaw is num) lng = lngRaw.toDouble();
      final markerCandidate = (m['markerId'] ??
              m['marker_id'] ??
              metadataMap?['markerId'] ??
              metadataMap?['marker_id'] ??
              artworkMap?['markerId'] ??
              artworkMap?['marker_id'] ??
              artworkMetadataMap?['markerId'] ??
              artworkMetadataMap?['marker_id'] ??
              institutionMap?['markerId'] ??
              institutionMap?['marker_id'] ??
              institutionMetadataMap?['markerId'] ??
              institutionMetadataMap?['marker_id'] ??
              eventMap?['markerId'] ??
              eventMap?['marker_id'] ??
              eventMetadataMap?['markerId'] ??
              eventMetadataMap?['marker_id'])
          ?.toString()
          .trim();
      final subjectTypeCandidate = (m['subjectType'] ??
              m['subject_type'] ??
              metadataMap?['subjectType'] ??
              metadataMap?['subject_type'] ??
              artworkMap?['subjectType'] ??
              artworkMap?['subject_type'] ??
              artworkMetadataMap?['subjectType'] ??
              artworkMetadataMap?['subject_type'] ??
              institutionMap?['subjectType'] ??
              institutionMap?['subject_type'] ??
              institutionMetadataMap?['subjectType'] ??
              institutionMetadataMap?['subject_type'] ??
              eventMap?['subjectType'] ??
              eventMap?['subject_type'] ??
              eventMetadataMap?['subjectType'] ??
              eventMetadataMap?['subject_type'])
          ?.toString()
          .trim();
      final subjectIdCandidate = (m['subjectId'] ??
              m['subject_id'] ??
              metadataMap?['subjectId'] ??
              metadataMap?['subject_id'] ??
              artworkMap?['subjectId'] ??
              artworkMap?['subject_id'] ??
              artworkMetadataMap?['subjectId'] ??
              artworkMetadataMap?['subject_id'] ??
              institutionMap?['subjectId'] ??
              institutionMap?['subject_id'] ??
              institutionMetadataMap?['subjectId'] ??
              institutionMetadataMap?['subject_id'] ??
              eventMap?['subjectId'] ??
              eventMap?['subject_id'] ??
              eventMetadataMap?['subjectId'] ??
              eventMetadataMap?['subject_id'])
          ?.toString()
          .trim();
      final artworkIdCandidate = (m['artworkId'] ??
              m['artwork_id'] ??
              metadataMap?['artworkId'] ??
              metadataMap?['artwork_id'] ??
              artworkMap?['id'] ??
              artworkMap?['artworkId'] ??
              artworkMap?['artwork_id'] ??
              artworkMetadataMap?['artworkId'] ??
              artworkMetadataMap?['artwork_id'])
          ?.toString()
          .trim();
      final avatarCandidate = (m['avatarUrl'] ??
              m['avatar_url'] ??
              m['avatar'] ??
              m['profileImageUrl'] ??
              m['profile_image_url'] ??
              m['profileImage'] ??
              m['profile_image'] ??
              m['authorAvatar'] ??
              m['author_avatar'] ??
              authorMap?['avatarUrl'] ??
              authorMap?['avatar_url'] ??
              authorMap?['avatar'] ??
              authorMap?['profileImageUrl'] ??
              authorMap?['profile_image_url'] ??
              artworkMap?['authorAvatar'] ??
              artworkMap?['author_avatar'])
          ?.toString()
          .trim();
      final imageCandidate = (m['imageUrl'] ??
              m['image_url'] ??
              m['image'] ??
              m['coverImageUrl'] ??
              m['cover_image_url'] ??
              m['coverImage'] ??
              m['cover_image'] ??
              m['coverUrl'] ??
              m['cover_url'] ??
              m['thumbnailUrl'] ??
              m['thumbnail_url'] ??
              m['thumbnail'] ??
              m['previewUrl'] ??
              m['preview_url'] ??
              m['preview'] ??
              m['hero'] ??
              m['banner'] ??
              m['mediaUrl'] ??
              m['media_url'] ??
              m['artworkImage'] ??
              m['artwork_image'] ??
              m['artworkImageUrl'] ??
              m['artwork_image_url'] ??
              artworkMap?['imageUrl'] ??
              artworkMap?['image_url'] ??
              artworkMap?['coverImageUrl'] ??
              artworkMap?['cover_image_url'] ??
              artworkMap?['coverUrl'] ??
              artworkMap?['cover_url'] ??
              institutionMap?['imageUrl'] ??
              institutionMap?['image_url'] ??
              eventMap?['imageUrl'] ??
              eventMap?['image_url'])
          ?.toString()
          .trim();
      final rawImageList = m['imageUrls'] ??
          m['image_urls'] ??
          m['images'] ??
          artworkMap?['imageUrls'] ??
          artworkMap?['image_urls'] ??
          artworkMap?['images'] ??
          institutionMap?['imageUrls'] ??
          institutionMap?['image_urls'] ??
          institutionMap?['images'] ??
          eventMap?['imageUrls'] ??
          eventMap?['image_urls'] ??
          eventMap?['images'];
      final imageListCandidate = rawImageList is List
          ? rawImageList
              .map((item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
          : const <String>[];

      id = (id?.trim().isNotEmpty ?? false)
          ? id
          : ((type.toLowerCase() == 'artwork')
                  ? artworkIdCandidate
                  : (type.toLowerCase() == 'institution')
                      ? (m['institutionId'] ??
                              m['institution_id'] ??
                              institutionMap?['id'] ??
                              institutionMap?['institutionId'] ??
                              institutionMap?['institution_id'])
                          ?.toString()
                          .trim()
                      : (type.toLowerCase() == 'event')
                          ? (m['eventId'] ??
                                  m['event_id'] ??
                                  eventMap?['id'] ??
                                  eventMap?['eventId'] ??
                                  eventMap?['event_id'])
                              ?.toString()
                              .trim()
                          : (type.toLowerCase() == 'marker')
                              ? markerCandidate
                              : id);

      final normalized = <String, dynamic>{
        'label': label,
        'subtitle': subtitle,
        'id': id,
        'type': type,
        if (rawDisplayName != null) 'displayName': rawDisplayName,
        if (rawUsername != null) 'username': rawUsername,
        if (wallet != null) 'wallet': wallet,
        if (markerCandidate != null && markerCandidate.isNotEmpty)
          'markerId': markerCandidate,
        if (subjectTypeCandidate != null && subjectTypeCandidate.isNotEmpty)
          'subjectType': subjectTypeCandidate,
        if (subjectIdCandidate != null && subjectIdCandidate.isNotEmpty)
          'subjectId': subjectIdCandidate,
        if (artworkIdCandidate != null && artworkIdCandidate.isNotEmpty)
          'artworkId': artworkIdCandidate,
        if (avatarCandidate != null && avatarCandidate.isNotEmpty)
          'avatarUrl': avatarCandidate,
        if (imageCandidate != null && imageCandidate.isNotEmpty)
          'imageUrl': imageCandidate,
        if (imageListCandidate.isNotEmpty) 'imageUrls': imageListCandidate,
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
