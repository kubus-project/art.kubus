import '../models/artwork.dart';
import 'media_url_resolver.dart';

/// Artwork and marker cover chain shared by every surface that shows a cover.
///
/// Order (first safe URL wins):
/// 1. `artwork.imageUrl` (the backend's `image_url`, already resolved at parse)
/// 2. cover-like metadata keys (see [coverMetadataKeys])
/// 3. image CID metadata keys (see [imageCidMetadataKeys]), resolved through the
///    configured IPFS gateways
/// 4. [fallbackUrl], then [additionalUrls]
///
/// Metadata keys are the only place legacy spellings are read: they sit at the
/// metadata boundary, and typed fields always take precedence over them.
class ArtworkMediaResolver {
  /// Metadata keys that can carry a cover, in preference order.
  static const List<String> coverMetadataKeys = <String>[
    'coverImageUrl',
    'cover_image_url',
    'coverUrl',
    'cover_url',
    'coverImage',
    'cover_image',
    'imageUrl',
    'image_url',
    'image',
    'thumbnailUrl',
    'thumbnail_url',
    'thumbnail',
    'preview',
    'previewUrl',
    'hero',
    'banner',
  ];

  /// Metadata keys that can carry an IPFS CID for the image.
  static const List<String> imageCidMetadataKeys = <String>[
    'imageCid',
    'image_cid',
    'imageCID',
  ];

  /// Resolve the primary cover for an artwork or marker.
  ///
  /// [maxWidth] asks the media resolver for a size-clamped URL (thumbnail
  /// rewriting and width query clamping). Cards and map thumbnails pass it so a
  /// marker never downloads archival media.
  static String? resolveCover({
    Artwork? artwork,
    Map<String, dynamic>? metadata,
    String? fallbackUrl,
    Iterable<String?> additionalUrls = const [],
    int? maxWidth,
  }) {
    return MediaUrlResolver.firstDisplayUrl(
      <String?>[
        artwork?.imageUrl,
        ...coverRefsFromMetadata(artwork?.metadata),
        ...coverRefsFromMetadata(metadata),
        fallbackUrl,
        ...additionalUrls,
      ],
      maxWidth: maxWidth,
    );
  }

  /// Raw cover references carried by a metadata bag, in chain order.
  ///
  /// Only string values count: a nested object or list under a cover key is
  /// never stringified into a URL.
  static List<String> coverRefsFromMetadata(Map<String, dynamic>? meta) {
    if (meta == null || meta.isEmpty) return const <String>[];
    final refs = <String>[];
    for (final key in <String>[...coverMetadataKeys, ...imageCidMetadataKeys]) {
      final value = meta[key];
      if (value is! String) continue;
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) refs.add(trimmed);
    }
    return refs;
  }
}
