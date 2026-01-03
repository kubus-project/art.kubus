/// Share target types used by sharing helpers and analytics.
///
/// Keep this file dependency-light so it can be used by services without
/// importing UI code.
enum ShareEntityType {
  post,
  artwork,
  marker,
  event,
  exhibition,
  profile,
  nft,
  collection,
}

extension ShareEntityTypeX on ShareEntityType {
  /// Stable string sent to backend/analytics.
  String get analyticsTargetType {
    switch (this) {
      case ShareEntityType.post:
        return 'post';
      case ShareEntityType.artwork:
        return 'artwork';
      case ShareEntityType.marker:
        return 'marker';
      case ShareEntityType.event:
        return 'event';
      case ShareEntityType.exhibition:
        return 'exhibition';
      case ShareEntityType.profile:
        return 'profile';
      case ShareEntityType.nft:
        return 'nft';
      case ShareEntityType.collection:
        return 'collection';
    }
  }

  static ShareEntityType? tryParse(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty) return null;
    for (final type in ShareEntityType.values) {
      if (type.analyticsTargetType == value) return type;
    }
    return null;
  }
}

/// Minimal description of what is being shared.
class ShareTarget {
  const ShareTarget({
    required this.type,
    required this.shareId,
    this.title,
  });

  final ShareEntityType type;
  final String shareId;
  final String? title;

  factory ShareTarget.post({required String postId, String? title}) {
    return ShareTarget(type: ShareEntityType.post, shareId: postId, title: title);
  }

  factory ShareTarget.artwork({required String artworkId, String? title}) {
    return ShareTarget(type: ShareEntityType.artwork, shareId: artworkId, title: title);
  }

  factory ShareTarget.marker({required String markerId, String? title}) {
    return ShareTarget(type: ShareEntityType.marker, shareId: markerId, title: title);
  }

  factory ShareTarget.event({required String eventId, String? title}) {
    return ShareTarget(type: ShareEntityType.event, shareId: eventId, title: title);
  }

  factory ShareTarget.exhibition({required String exhibitionId, String? title}) {
    return ShareTarget(type: ShareEntityType.exhibition, shareId: exhibitionId, title: title);
  }

  factory ShareTarget.profile({required String walletAddress, String? title}) {
    return ShareTarget(type: ShareEntityType.profile, shareId: walletAddress, title: title);
  }

  factory ShareTarget.nft({required String mintAddress, String? title}) {
    return ShareTarget(type: ShareEntityType.nft, shareId: mintAddress, title: title);
  }

  factory ShareTarget.collection({required String collectionId, String? title}) {
    return ShareTarget(type: ShareEntityType.collection, shareId: collectionId, title: title);
  }
}

