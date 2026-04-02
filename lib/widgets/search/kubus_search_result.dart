import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/app_localizations.dart';

enum KubusSearchResultKind {
  artwork,
  profile,
  institution,
  event,
  marker,
  post,
  screen,
}

@immutable
class KubusSearchResult {
  const KubusSearchResult({
    required this.label,
    required this.kind,
    this.detail,
    this.id,
    this.position,
    this.iconOverride,
    this.data = const <String, dynamic>{},
  });

  final String label;
  final KubusSearchResultKind kind;
  final String? detail;
  final String? id;
  final LatLng? position;
  final IconData? iconOverride;
  final Map<String, dynamic> data;

  String? dataString(Iterable<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      if (value is Iterable) {
        for (final item in value) {
          if (item == null) continue;
          final nestedText = item.toString().trim();
          if (nestedText.isNotEmpty) return nestedText;
        }
        continue;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String? get walletSeed => dataString(const <String>[
        'wallet',
        'walletAddress',
        'wallet_address',
        'authorWallet',
        'author_wallet',
        'creatorWallet',
        'creator_wallet',
      ]) ??
      (kind == KubusSearchResultKind.profile ? id : null);

  String? get markerId => dataString(const <String>[
        'markerId',
        'marker_id',
      ]) ??
      (kind == KubusSearchResultKind.marker ? id : null);

  String? get artworkId => dataString(const <String>[
        'artworkId',
        'artwork_id',
        'linkedArtworkId',
        'linked_artwork_id',
      ]) ??
      (kind == KubusSearchResultKind.artwork ? id : null);

  String? get subjectId => dataString(const <String>[
        'subjectId',
        'subject_id',
      ]) ??
      switch (kind) {
        KubusSearchResultKind.institution => id,
        KubusSearchResultKind.event => id,
        KubusSearchResultKind.artwork => artworkId,
        _ => null,
      };

  String? get subjectType => dataString(const <String>[
        'subjectType',
        'subject_type',
      ]) ??
      switch (kind) {
        KubusSearchResultKind.artwork => 'artwork',
        KubusSearchResultKind.institution => 'institution',
        KubusSearchResultKind.event => 'event',
        _ => null,
      };

  String? get avatarUrl => dataString(const <String>[
        'avatarUrl',
        'avatar_url',
        'avatar',
        'profileImageUrl',
        'profile_image_url',
        'profileImage',
        'profile_image',
        'authorAvatar',
        'author_avatar',
      ]);

  String? get previewImageUrl => dataString(const <String>[
        'imageUrl',
        'image_url',
        'image',
        'coverImageUrl',
        'cover_image_url',
        'coverImage',
        'cover_image',
        'coverUrl',
        'cover_url',
        'thumbnailUrl',
        'thumbnail_url',
        'thumbnail',
        'previewUrl',
        'preview_url',
        'preview',
        'hero',
        'banner',
        'mediaUrl',
        'media_url',
        'artworkImage',
        'artwork_image',
        'artworkImageUrl',
        'artwork_image_url',
        'imageUrls',
        'image_urls',
        'images',
        'coverImages',
        'cover_images',
      ]);

  String get stableKey {
    final lat = position?.latitude.toStringAsFixed(5) ?? '';
    final lng = position?.longitude.toStringAsFixed(5) ?? '';
    return [
      kind.name,
      (id ?? '').trim().toLowerCase(),
      label.trim().toLowerCase(),
      lat,
      lng,
    ].join('|');
  }

  IconData get icon {
    if (iconOverride != null) return iconOverride!;
    switch (kind) {
      case KubusSearchResultKind.artwork:
        return Icons.auto_awesome;
      case KubusSearchResultKind.profile:
        return Icons.account_circle_outlined;
      case KubusSearchResultKind.institution:
        return Icons.museum_outlined;
      case KubusSearchResultKind.event:
        return Icons.event_available;
      case KubusSearchResultKind.marker:
        return Icons.location_on_outlined;
      case KubusSearchResultKind.post:
        return Icons.article_outlined;
      case KubusSearchResultKind.screen:
        return Icons.open_in_new;
    }
  }

  String subtitleText(AppLocalizations l10n) {
    final kindLabel = switch (kind) {
      KubusSearchResultKind.artwork => l10n.commonArtwork,
      KubusSearchResultKind.profile => l10n.navigationScreenProfile,
      KubusSearchResultKind.institution => l10n.commonInstitution,
      KubusSearchResultKind.event => l10n.mapMarkerSubjectTypeEvent,
      KubusSearchResultKind.marker => l10n.mapMarkerLayerOther,
      KubusSearchResultKind.post => l10n.commonPost,
      KubusSearchResultKind.screen => l10n.communitySearchTypeScreens,
    };
    final resolvedDetail = detail?.trim() ?? '';
    if (resolvedDetail.isEmpty) return kindLabel;
    return '$kindLabel \u2022 $resolvedDetail';
  }

  factory KubusSearchResult.fromMap(Map<String, dynamic> map) {
    final lat = map['lat'] ?? map['latitude'];
    final lng = map['lng'] ?? map['longitude'];
    LatLng? position;
    if (lat is num && lng is num) {
      position = LatLng(lat.toDouble(), lng.toDouble());
    }

    final rawKind = (map['type'] ?? map['kind'])?.toString();
    final kind = KubusSearchResultKindX.fromRaw(rawKind) ??
        KubusSearchResultKind.artwork;

    final label = (map['label'] ??
            map['text'] ??
            map['displayName'] ??
            map['display_name'] ??
            map['title'] ??
            map['name'] ??
            '')
        .toString()
        .trim();

    final detail = (map['detail'] ??
            map['subtitle'] ??
            map['secondaryText'] ??
            map['secondary_text'])
        ?.toString()
        .trim();

    final id = (map['id'] ??
            map['wallet'] ??
            map['walletAddress'] ??
            map['wallet_address'])
        ?.toString()
        .trim();

    return KubusSearchResult(
      label: label,
      kind: kind,
      detail: (detail?.isEmpty ?? true) ? null : detail,
      id: (id?.isEmpty ?? true) ? null : id,
      position: position,
      data: Map<String, dynamic>.from(map),
    );
  }
}

extension KubusSearchResultKindX on KubusSearchResultKind {
  String get wireName {
    switch (this) {
      case KubusSearchResultKind.artwork:
        return 'artwork';
      case KubusSearchResultKind.profile:
        return 'profile';
      case KubusSearchResultKind.institution:
        return 'institution';
      case KubusSearchResultKind.event:
        return 'event';
      case KubusSearchResultKind.marker:
        return 'marker';
      case KubusSearchResultKind.post:
        return 'post';
      case KubusSearchResultKind.screen:
        return 'screen';
    }
  }

  static KubusSearchResultKind? fromRaw(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'artwork':
        return KubusSearchResultKind.artwork;
      case 'profile':
      case 'user':
        return KubusSearchResultKind.profile;
      case 'institution':
        return KubusSearchResultKind.institution;
      case 'event':
      case 'exhibition':
        return KubusSearchResultKind.event;
      case 'marker':
        return KubusSearchResultKind.marker;
      case 'post':
      case 'community':
        return KubusSearchResultKind.post;
      case 'screen':
        return KubusSearchResultKind.screen;
      default:
        return null;
    }
  }
}
