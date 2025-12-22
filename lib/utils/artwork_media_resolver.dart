import '../models/artwork.dart';
import '../services/storage_config.dart';

/// Centralizes artwork media URL resolution so every screen shows the same
/// cover image with IPFS/HTTP fallbacks applied consistently.
class ArtworkMediaResolver {
  /// Resolve the primary cover for an artwork.
  /// Mirrors the working logic used in Featured Artworks cards:
  /// prefer the artwork's own `imageUrl`, then a provided fallback list.
  static String? resolveCover({
    Artwork? artwork,
    Map<String, dynamic>? metadata,
    String? fallbackUrl,
    Iterable<String?> additionalUrls = const [],
  }) {
    final candidates = <String?>[
      artwork?.imageUrl,
      ..._metadataCandidates(artwork?.metadata),
      ..._metadataCandidates(metadata),
      fallbackUrl,
      ...additionalUrls,
    ];

    for (final raw in candidates) {
      final resolved = StorageConfig.resolveUrl(_asString(raw));
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
    }
    return null;
  }

  static List<String?> _metadataCandidates(Map<String, dynamic>? meta) {
    if (meta == null || meta.isEmpty) return const <String?>[];
    return [
      meta['coverImage']?.toString(),
      meta['coverImageUrl']?.toString(),
      meta['cover_image_url']?.toString(),
      meta['coverUrl']?.toString(),
      meta['cover_url']?.toString(),
      meta['imageUrl']?.toString(),
      meta['image']?.toString(),
      meta['thumbnailUrl']?.toString(),
      meta['thumbnail_url']?.toString(),
      meta['thumbnail']?.toString(),
      meta['preview']?.toString(),
      meta['previewUrl']?.toString(),
      meta['hero']?.toString(),
      meta['banner']?.toString(),
    ];
  }

  static String? _asString(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
