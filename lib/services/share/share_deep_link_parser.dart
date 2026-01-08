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
    final segments = uri.pathSegments.where((s) => s.trim().isNotEmpty).toList(growable: false);
    if (segments.length < 2) return null;

    final head = segments[0].toLowerCase();
    final id = segments[1].trim();
    if (id.isEmpty) return null;

    switch (head) {
      case 'post':
        return ShareDeepLinkTarget(type: ShareEntityType.post, id: id);
      case 'artwork':
        return ShareDeepLinkTarget(type: ShareEntityType.artwork, id: id);
      case 'marker':
      case 'markers':
      case 'art-marker':
      case 'art-markers':
        return ShareDeepLinkTarget(type: ShareEntityType.marker, id: id);
      case 'collection':
        return ShareDeepLinkTarget(type: ShareEntityType.collection, id: id);
      case 'event':
      case 'events':
        return ShareDeepLinkTarget(type: ShareEntityType.event, id: id);
      case 'exhibition':
      case 'exhibitions':
        return ShareDeepLinkTarget(type: ShareEntityType.exhibition, id: id);
      case 'profile':
      case 'user':
      case 'u':
        return ShareDeepLinkTarget(type: ShareEntityType.profile, id: id);
      case 'nft':
      case 'nfts':
        return ShareDeepLinkTarget(type: ShareEntityType.nft, id: id);
      default:
        return null;
    }
  }
}

