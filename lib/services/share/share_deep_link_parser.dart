import 'package:flutter/foundation.dart';

import 'share_types.dart';

@immutable
class ShareDeepLinkTarget {
  final ShareEntityType type;
  final String id;

  const ShareDeepLinkTarget({required this.type, required this.id});
}

class ShareDeepLinkParser {
  const ShareDeepLinkParser();

  ShareDeepLinkTarget? parse(Uri uri) {
    final segments = uri.pathSegments
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (segments.length < 2) return null;

    // Links may include prefixes (e.g. /en/marker/:id, /share/marker/:id).
    // Scan for the first recognizable "entity" segment and treat the following
    // segment as the id.
    for (var i = 0; i < segments.length - 1; i++) {
      final head = segments[i].toLowerCase();
      final type = _typeForHead(head);
      if (type == null) continue;

      final rawId = segments[i + 1];
      if (rawId.isEmpty) continue;

      final id = Uri.decodeComponent(rawId).trim();
      if (id.isEmpty) continue;

      return ShareDeepLinkTarget(type: type, id: id);
    }

    return null;
  }

  ShareEntityType? _typeForHead(String head) {
    switch (head) {
      case 'post':
      case 'posts':
      case 'p':
        return ShareEntityType.post;
      case 'artwork':
      case 'artworks':
      case 'a':
        return ShareEntityType.artwork;
      case 'marker':
      case 'markers':
      case 'm':
      case 'art-marker':
      case 'art-markers':
        return ShareEntityType.marker;
      case 'collection':
      case 'collections':
      case 'c':
        return ShareEntityType.collection;
      case 'event':
      case 'events':
        return ShareEntityType.event;
      case 'exhibition':
      case 'exhibitions':
        return ShareEntityType.exhibition;
      case 'profile':
      case 'profiles':
      case 'user':
      case 'users':
      case 'u':
        return ShareEntityType.profile;
      case 'nft':
      case 'nfts':
        return ShareEntityType.nft;
      default:
        return null;
    }
  }
}
