import '../models/artwork.dart';
import '../services/backend_api_service.dart';
import 'media_url_resolver.dart';
import 'wallet_utils.dart';

class ProfileArtworkShowcaseData {
  final String? id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final int likesCount;

  const ProfileArtworkShowcaseData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.likesCount,
  });

  factory ProfileArtworkShowcaseData.fromMap(
    Map<String, dynamic> data, {
    required String fallbackTitle,
    required String fallbackSubtitle,
  }) {
    Artwork? parsed;
    try {
      parsed = parseArtworkFromBackendJson(data);
    } catch (_) {
      parsed = null;
    }

    final id = _firstString(data, const ['id', 'artwork_id', 'artworkId']);
    final title = _firstNonEmpty([
      parsed?.title,
      data['title'],
      data['name'],
      fallbackTitle,
    ]);
    final subtitle = _firstNonEmpty([
      parsed?.category,
      data['category'],
      data['medium'],
      fallbackSubtitle,
    ]);
    final imageUrl = _firstNonEmptyNullable([
      parsed?.imageUrl,
      _extractImageUrl(data, const [
        'imageUrl',
        'imageURL',
        'image_url',
        'image',
        'previewUrl',
        'preview_url',
        'coverImage',
        'cover_image',
        'coverImageUrl',
        'cover_image_url',
        'coverUrl',
        'cover_url',
        'mediaUrl',
        'media_url',
      ]),
    ]);

    return ProfileArtworkShowcaseData(
      id: id,
      title: title,
      subtitle: subtitle,
      imageUrl: MediaUrlResolver.resolveDisplayUrl(imageUrl) ?? imageUrl,
      likesCount: parsed?.likesCount ??
          _readInt(data, const [
            'likesCount',
            'likes_count',
            'likeCount',
            'likes',
          ], nestedMaps: const [
            'stats',
            'statistics',
          ]),
    );
  }
}

class ProfileCollectionShowcaseData {
  final String? id;
  final String title;
  final String? imageUrl;
  final int artworkCount;
  final String? description;

  const ProfileCollectionShowcaseData({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.artworkCount,
    required this.description,
  });

  factory ProfileCollectionShowcaseData.fromMap(
    Map<String, dynamic> data, {
    required String fallbackTitle,
  }) {
    return ProfileCollectionShowcaseData(
      id: _firstString(data, const ['id', 'collection_id', 'collectionId']),
      title: _firstNonEmpty([data['name'], data['title'], fallbackTitle]),
      imageUrl:
          MediaUrlResolver.resolveDisplayUrl(_extractImageUrl(data, const [
                'thumbnailUrl',
                'thumbnail_url',
                'coverImage',
                'cover_image',
                'coverImageUrl',
                'cover_image_url',
                'coverUrl',
                'cover_url',
                'image',
                'imageUrl',
                'image_url',
              ])) ??
              _extractImageUrl(data, const [
                'thumbnailUrl',
                'thumbnail_url',
                'coverImage',
                'cover_image',
                'coverImageUrl',
                'cover_image_url',
                'coverUrl',
                'cover_url',
                'image',
                'imageUrl',
                'image_url',
              ]),
      artworkCount: _readInt(data, const [
        'artworkCount',
        'artwork_count',
        'artworksCount',
        'artworks_count',
      ]),
      description: _firstString(data, const ['description']),
    );
  }
}

class ProfileEventShowcaseData {
  final String? id;
  final String title;
  final String? imageUrl;
  final dynamic startDate;
  final String? location;

  const ProfileEventShowcaseData({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.startDate,
    required this.location,
  });

  factory ProfileEventShowcaseData.fromMap(
    Map<String, dynamic> data, {
    required String fallbackTitle,
    required String fallbackLocation,
  }) {
    return ProfileEventShowcaseData(
      id: _firstString(data, const ['id', 'event_id', 'eventId']),
      title: _firstNonEmpty([data['title'], data['name'], fallbackTitle]),
      imageUrl:
          MediaUrlResolver.resolveDisplayUrl(_extractImageUrl(data, const [
                'coverUrl',
                'cover_url',
                'coverImageUrl',
                'cover_image_url',
                'bannerUrl',
                'banner_url',
                'image',
                'imageUrl',
                'image_url',
              ])) ??
              _extractImageUrl(data, const [
                'coverUrl',
                'cover_url',
                'coverImageUrl',
                'cover_image_url',
                'bannerUrl',
                'banner_url',
                'image',
                'imageUrl',
                'image_url',
              ]),
      startDate: data['startsAt'] ??
          data['starts_at'] ??
          data['startDate'] ??
          data['start_date'],
      location: _firstNonEmptyNullable([
            data['locationName'],
            data['location_name'],
            data['location'],
          ]) ??
          fallbackLocation,
    );
  }
}

bool profileEventBelongsToWallet(
  Map<String, dynamic> event,
  String walletAddress,
) {
  final target = WalletUtils.normalize(walletAddress);
  if (target.isEmpty) return false;

  bool matches(dynamic value) {
    return WalletUtils.normalize(value?.toString()) == target;
  }

  if (matches(event['createdBy']) || matches(event['created_by'])) {
    return true;
  }

  final host = event['host'];
  if (host is Map) {
    if (matches(host['walletAddress']) ||
        matches(host['wallet_address']) ||
        matches(host['wallet'])) {
      return true;
    }
  }

  for (final key in const [
    'artistIds',
    'artist_ids',
    'artistWallets',
    'artist_wallets'
  ]) {
    final raw = event[key];
    if (raw is List && raw.any(matches)) return true;
  }

  return false;
}

String? _extractImageUrl(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  final images = data['imageUrls'] ?? data['image_urls'] ?? data['images'];
  if (images is List && images.isNotEmpty) {
    final first = images.first;
    if (first is String && first.trim().isNotEmpty) {
      return first.trim();
    }
  }
  return null;
}

String? _firstString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

String _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

String? _firstNonEmptyNullable(List<dynamic> values) {
  for (final value in values) {
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

int _readInt(
  Map<String, dynamic> data,
  List<String> keys, {
  List<String> nestedMaps = const [],
}) {
  int? parse(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  for (final key in keys) {
    final value = parse(data[key]);
    if (value != null) return value;
  }
  for (final mapKey in nestedMaps) {
    final nested = data[mapKey];
    if (nested is! Map) continue;
    for (final key in keys) {
      final value = parse(nested[key]);
      if (value != null) return value;
    }
  }
  return 0;
}
