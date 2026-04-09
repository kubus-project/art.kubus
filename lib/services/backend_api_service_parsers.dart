part of 'backend_api_service.dart';

CommunityLikeUser _backendApiCommunityLikeUserFromBackendJson(
  Map<String, dynamic> json,
) {
  final wallet =
      json['walletAddress'] as String? ?? json['wallet_address'] as String?;

  final username = json['username'] as String?;
  final displayName = json['displayName'] as String? ??
      json['display_name'] as String? ??
      username ??
      (wallet != null && wallet.length >= 8 ? wallet.substring(0, 8) : 'User');
  final avatarCandidate = json['avatar'] as String? ??
      json['avatarUrl'] as String? ??
      json['avatar_url'] as String?;

  DateTime? likedAt;
  final likedAtRaw = json['likedAt'] ?? json['liked_at'];
  if (likedAtRaw is String) {
    likedAt = DateTime.tryParse(likedAtRaw);
  }

  return CommunityLikeUser(
    userId: (json['userId'] ?? json['user_id'] ?? json['id'] ?? 'unknown')
        .toString(),
    walletAddress: wallet,
    displayName: displayName,
    username: username,
    avatarUrl: MediaUrlResolver.resolve(avatarCandidate),
    likedAt: likedAt,
  );
}

Map<String, dynamic> _backendApiBuildCommunityPostPayload({
  required String content,
  String category = 'post',
  List<String>? mediaUrls,
  List<String>? mediaCids,
  String? artworkId,
  String? subjectType,
  String? subjectId,
  String? postType,
  List<String>? tags,
  List<String>? mentions,
  CommunityLocation? location,
  String? locationName,
  double? locationLat,
  double? locationLng,
}) {
  final payload = <String, dynamic>{
    'content': content,
    'category': category,
    if (mediaUrls != null && mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
    if (mediaCids != null && mediaCids.isNotEmpty) 'mediaCids': mediaCids,
    if (artworkId != null) 'artworkId': artworkId,
    if (subjectType != null && subjectType.trim().isNotEmpty)
      'subjectType': subjectType.trim(),
    if (subjectId != null && subjectId.trim().isNotEmpty)
      'subjectId': subjectId.trim(),
    if (postType != null) 'postType': postType,
    if (tags != null && tags.isNotEmpty) 'tags': tags,
    if (mentions != null && mentions.isNotEmpty) 'mentions': mentions,
  };

  final hasLocationData = location != null ||
      locationLat != null ||
      locationLng != null ||
      (locationName != null && locationName.isNotEmpty);

  if (hasLocationData) {
    final effectiveLocation = location ??
        CommunityLocation(
          name: locationName,
          lat: locationLat,
          lng: locationLng,
        );

    final locPayload = <String, dynamic>{
      if (effectiveLocation.name != null && effectiveLocation.name!.isNotEmpty)
        'name': effectiveLocation.name,
      if (effectiveLocation.lat != null) 'lat': effectiveLocation.lat,
      if (effectiveLocation.lng != null) 'lng': effectiveLocation.lng,
    };
    if (locPayload.isNotEmpty) {
      payload['location'] = locPayload;
    }

    final resolvedName = (locationName != null && locationName.isNotEmpty)
        ? locationName
        : effectiveLocation.name;
    if (resolvedName != null && resolvedName.isNotEmpty) {
      payload['locationName'] = resolvedName;
    }
    final resolvedLat = locationLat ?? effectiveLocation.lat;
    if (resolvedLat != null) {
      payload['locationLat'] = resolvedLat;
    }
    final resolvedLng = locationLng ?? effectiveLocation.lng;
    if (resolvedLng != null) {
      payload['locationLng'] = resolvedLng;
    }
  }

  return payload;
}

CommunityPost _backendApiCommunityPostFromBackendJson(Map<String, dynamic> json) {
  final authorRaw = json['author'];
  final author = authorRaw is Map<String, dynamic> ? authorRaw : null;
  final normalizedAuthor = author ?? <String, dynamic>{};
  final stats = json['stats'] as Map<String, dynamic>?;
  final authorDisplayName = author?['displayName'] as String? ??
      author?['display_name'] as String? ??
      json['displayName'] as String?;
  final rawUsername = author?['username'] as String? ??
      json['authorUsername'] as String? ??
      json['username'] as String?;
  final resolvedAuthorName =
      (authorDisplayName != null && authorDisplayName.trim().isNotEmpty)
          ? authorDisplayName.trim()
          : ((rawUsername != null && rawUsername.trim().isNotEmpty)
              ? rawUsername.trim()
              : (json['authorName'] as String?) ?? 'Anonymous');
  final avatarCandidate = author?['avatar'] as String? ??
      author?['profileImage'] as String? ??
      json['authorAvatar'] as String?;

  final authorWalletCandidate = normalizedAuthor['walletAddress'] as String? ??
      normalizedAuthor['wallet_address'] as String? ??
      normalizedAuthor['wallet'] as String? ??
      json['walletAddress'] as String? ??
      json['wallet'] as String? ??
      (authorRaw is String ? authorRaw : null);

  bool authorIsArtistFlag = communityBool(
    normalizedAuthor['isArtist'] ??
        normalizedAuthor['is_artist'] ??
        json['authorIsArtist'] ??
        json['author_is_artist'],
  );
  bool authorIsInstitutionFlag = communityBool(
    normalizedAuthor['isInstitution'] ??
        normalizedAuthor['is_institution'] ??
        json['authorIsInstitution'] ??
        json['author_is_institution'],
  );
  final roleHint = (normalizedAuthor['role'] ??
          normalizedAuthor['type'] ??
          json['authorRole'] ??
          '')
      .toString()
      .toLowerCase();
  if (roleHint.contains('institution') ||
      roleHint.contains('museum') ||
      roleHint.contains('gallery')) {
    authorIsInstitutionFlag = true;
  }
  if (roleHint.contains('artist') || roleHint.contains('creator')) {
    authorIsArtistFlag = true;
  }

  final dynamic mediaPayload = json['mediaUrls'] ?? json['media_urls'];
  final List<String> mediaUrls = mediaPayload is List
      ? mediaPayload
          .map((entry) => entry?.toString())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toList()
      : <String>[];

  final mentionsPayload = json['mentions'] ?? json['mentionHandles'];
  final List<String> mentions = mentionsPayload is List
      ? mentionsPayload
          .map((entry) => entry?.toString())
          .whereType<String>()
          .toList()
      : <String>[];

  final String resolvedCategory =
      (json['category'] as String?)?.toLowerCase() ?? 'post';

  CommunityLocation? locationMeta;
  final locationJson = json['location'];
  if (locationJson is Map<String, dynamic>) {
    final latCandidate = locationJson['lat'] ?? locationJson['latitude'];
    final lngCandidate = locationJson['lng'] ?? locationJson['longitude'];
    if (locationJson['name'] != null ||
        latCandidate != null ||
        lngCandidate != null) {
      locationMeta = CommunityLocation(
        name: locationJson['name']?.toString(),
        lat: (latCandidate is num)
            ? latCandidate.toDouble()
            : double.tryParse(latCandidate?.toString() ?? ''),
        lng: (lngCandidate is num)
            ? lngCandidate.toDouble()
            : double.tryParse(lngCandidate?.toString() ?? ''),
      );
    }
  } else if (json['locationName'] != null ||
      json['location_name'] != null ||
      json['location_lat'] != null ||
      json['locationLng'] != null) {
    final latCandidate = json['locationLat'] ?? json['location_lat'];
    final lngCandidate = json['locationLng'] ?? json['location_lng'];
    locationMeta = CommunityLocation(
      name: (json['locationName'] ?? json['location_name'])?.toString(),
      lat: (latCandidate is num)
          ? latCandidate.toDouble()
          : double.tryParse(latCandidate?.toString() ?? ''),
      lng: (lngCandidate is num)
          ? lngCandidate.toDouble()
          : double.tryParse(lngCandidate?.toString() ?? ''),
    );
  }

  CommunityGroupReference? groupRef;
  final groupJson = json['group'];
  if (groupJson is Map<String, dynamic>) {
    final groupId =
        (groupJson['id'] ?? groupJson['groupId'] ?? groupJson['group_id'])
            ?.toString();
    if (groupId != null && groupId.isNotEmpty) {
      final groupName =
          (groupJson['name'] ?? groupJson['groupName'])?.toString() ??
              'Community Group';
      groupRef = CommunityGroupReference(
        id: groupId,
        name: groupName,
        slug: groupJson['slug']?.toString(),
        coverImage: groupJson['coverImage']?.toString() ??
            groupJson['cover_image']?.toString(),
        description: groupJson['description']?.toString(),
      );
    }
  } else {
    final fallbackGroupId = (json['groupId'] ?? json['group_id'])?.toString();
    if (fallbackGroupId != null && fallbackGroupId.isNotEmpty) {
      groupRef = CommunityGroupReference(
        id: fallbackGroupId,
        name: (json['groupName'] ?? json['group_name'] ?? 'Community Group')
            .toString(),
        slug: json['groupSlug']?.toString() ?? json['group_slug']?.toString(),
        coverImage:
            json['groupCover']?.toString() ?? json['group_cover']?.toString(),
        description: json['groupDescription']?.toString() ??
            json['group_description']?.toString(),
      );
    }
  }

  CommunityArtworkReference? artworkRef;
  final artworkJson = json['artwork'];
  if (artworkJson is Map<String, dynamic>) {
    final artworkId = (artworkJson['id'] ??
            artworkJson['artworkId'] ??
            artworkJson['artwork_id'])
        ?.toString();
    if (artworkId != null && artworkId.isNotEmpty) {
      final artworkImage = artworkJson['imageUrl']?.toString() ??
          artworkJson['image_url']?.toString() ??
          artworkJson['artworkImage']?.toString() ??
          artworkJson['artwork_image']?.toString() ??
          artworkJson['artworkImageUrl']?.toString() ??
          artworkJson['artwork_image_url']?.toString();
      final artworkTitle = (artworkJson['title'] ??
              artworkJson['artworkTitle'] ??
              artworkJson['artwork_title'] ??
              'Artwork')
          .toString();
      artworkRef = CommunityArtworkReference(
        id: artworkId,
        title: artworkTitle,
        imageUrl: artworkImage,
      );
    }
  } else {
    final fallbackArtworkId =
        (json['artworkId'] ?? json['artwork_id'])?.toString();
    if (fallbackArtworkId != null && fallbackArtworkId.isNotEmpty) {
      artworkRef = CommunityArtworkReference(
        id: fallbackArtworkId,
        title: (json['artworkTitle'] ?? json['artwork_title'] ?? 'Artwork')
            .toString(),
        imageUrl: json['artworkImage']?.toString() ??
            json['artwork_image']?.toString() ??
            json['artworkImageUrl']?.toString() ??
            json['artwork_image_url']?.toString(),
      );
    }
  }

  final rawSubjectType =
      (json['subjectType'] ?? json['subject_type'])?.toString();
  final rawSubjectId = (json['subjectId'] ?? json['subject_id'])?.toString();
  String? resolvedSubjectType = rawSubjectType?.trim();
  String? resolvedSubjectId = rawSubjectId?.trim();
  if ((resolvedSubjectType == null || resolvedSubjectType.isEmpty) &&
      artworkRef != null) {
    resolvedSubjectType = 'artwork';
    resolvedSubjectId = artworkRef.id;
  } else if ((resolvedSubjectType ?? '').toLowerCase().contains('artwork') &&
      (resolvedSubjectId == null || resolvedSubjectId.isEmpty)) {
    final fallbackArtworkId =
        (json['artworkId'] ?? json['artwork_id'])?.toString();
    resolvedSubjectId = fallbackArtworkId?.trim().isNotEmpty == true
        ? fallbackArtworkId?.trim()
        : artworkRef?.id;
  }

  CommunityPost? originalPost;
  final originalPostPayload = json['originalPost'] ?? json['original_post'];
  if (originalPostPayload is Map) {
    final nested = Map<String, dynamic>.from(originalPostPayload);
    nested.remove('originalPost');
    nested.remove('original_post');
    try {
      originalPost = _communityPostFromBackendJson(nested);
    } catch (e) {
      AppConfig.debugPrint(
        'BackendApiService: Failed to parse nested original post: $e',
      );
    }
  }

  final postTypeValue =
      (json['postType'] ?? json['post_type'] ?? json['type'])?.toString();
  final originalPostId =
      (json['originalPostId'] ?? json['original_post_id'])?.toString();

  return CommunityPost(
    id: json['id'] as String,
    authorId: json['authorId'] as String? ??
        json['walletAddress'] as String? ??
        json['userId'] as String? ??
        'unknown',
    authorWallet: authorWalletCandidate,
    authorName: resolvedAuthorName,
    authorAvatar: MediaUrlResolver.resolve(avatarCandidate),
    authorUsername: rawUsername,
    content: json['content'] as String,
    imageUrl: json['imageUrl'] as String? ??
        (mediaUrls.isNotEmpty ? mediaUrls.first : null),
    mediaUrls: mediaUrls,
    timestamp: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : (json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now()),
    tags: json['tags'] != null
        ? (json['tags'] as List<dynamic>).map((e) => e.toString()).toList()
        : [],
    mentions: mentions,
    category: resolvedCategory,
    location: locationMeta,
    group: groupRef,
    groupId: (json['groupId'] as String?) ??
        (json['group_id'] as String?) ??
        groupRef?.id,
    artwork: artworkRef,
    subjectType: resolvedSubjectType,
    subjectId: resolvedSubjectId,
    distanceKm: (json['distanceKm'] as num?)?.toDouble() ??
        (json['distance_km'] as num?)?.toDouble(),
    postType: postTypeValue,
    originalPostId: originalPostId,
    originalPost: originalPost,
    likeCount: stats?['likes'] as int? ??
        json['likes'] as int? ??
        json['likeCount'] as int? ??
        0,
    shareCount: stats?['shares'] as int? ??
        json['shares'] as int? ??
        json['shareCount'] as int? ??
        0,
    commentCount: stats?['comments'] as int? ??
        json['comments'] as int? ??
        json['commentCount'] as int? ??
        0,
    viewCount: stats?['views'] as int? ??
        json['views'] as int? ??
        json['viewCount'] as int? ??
        0,
    isLiked: json['isLiked'] as bool? ?? false,
    isBookmarked: json['isBookmarked'] as bool? ?? false,
    isFollowing: json['isFollowing'] as bool? ?? false,
    authorIsArtist: authorIsArtistFlag,
    authorIsInstitution: authorIsInstitutionFlag,
    promotion: PromotionMetadata.readFrom(json),
    feedPin: CommunityFeedPinMetadata.fromJson(
      json['feedPin'] is Map<String, dynamic>
          ? json['feedPin'] as Map<String, dynamic>
          : json['feedPin'] is Map
              ? Map<String, dynamic>.from(json['feedPin'] as Map)
              : json['feed_pin'] is Map
                  ? Map<String, dynamic>.from(json['feed_pin'] as Map)
                  : null,
    ),
    hybridScore: (json['hybridScore'] as num?)?.toDouble() ??
        (json['hybrid_score'] as num?)?.toDouble(),
  );
}

GroupPostPreview? _backendApiGroupPostPreviewFromJson(dynamic raw) {
  if (raw is! Map<String, dynamic>) return null;
  final id = (raw['id'] ?? raw['postId'] ?? raw['post_id'])?.toString();
  if (id == null || id.isEmpty) return null;
  DateTime? createdAt;
  final createdAtRaw = raw['createdAt'] ?? raw['created_at'];
  if (createdAtRaw is String) {
    createdAt = DateTime.tryParse(createdAtRaw);
  }
  return GroupPostPreview(
    id: id,
    content: raw['content']?.toString(),
    createdAt: createdAt,
  );
}

CommunityGroupSummary _backendApiCommunityGroupSummaryFromJson(
  Map<String, dynamic> json,
) {
  final id = (json['id'] ?? json['groupId'] ?? json['group_id'])?.toString();
  if (id == null || id.isEmpty) {
    throw Exception('Invalid group payload: missing id');
  }
  GroupPostPreview? latestPost;
  if (json['latestPost'] is Map<String, dynamic>) {
    latestPost = _groupPostPreviewFromJson(json['latestPost']);
  } else if (json['latest_post_id'] != null) {
    latestPost = _groupPostPreviewFromJson({
      'id': json['latest_post_id'],
      'content': json['latest_post_content'],
      'createdAt': json['latest_post_created_at'],
    });
  }

  return CommunityGroupSummary(
    id: id,
    name: (json['name'] ?? 'Community Group').toString(),
    slug: json['slug']?.toString(),
    description: json['description']?.toString(),
    coverImage: MediaUrlResolver.resolve(
      json['coverImage']?.toString() ?? json['cover_image']?.toString(),
    ),
    isPublic: json['isPublic'] as bool? ?? json['is_public'] as bool? ?? true,
    ownerWallet: (json['ownerWallet'] ?? json['owner_wallet'] ?? '').toString(),
    memberCount: (json['memberCount'] as num?)?.toInt() ??
        (json['member_count'] as num?)?.toInt() ??
        (json['member_count_cached'] as num?)?.toInt() ??
        0,
    isMember: json['isMember'] as bool? ?? json['is_member'] as bool? ?? false,
    isOwner: json['isOwner'] as bool? ?? json['is_owner'] as bool? ?? false,
    latestPost: latestPost,
  );
}

Comment _backendApiCommentFromBackendJson(Map<String, dynamic> json) {
  final authorRaw = json['author'];
  final author = authorRaw is Map<String, dynamic> ? authorRaw : null;
  final normalizedAuthor = author ?? <String, dynamic>{};

  final authorWallet = normalizedAuthor['walletAddress'] as String? ??
      normalizedAuthor['wallet_address'] as String? ??
      normalizedAuthor['wallet'] as String?;
  String? authorRawWalletFallback;
  if (authorRaw is String && authorRaw.isNotEmpty) {
    authorRawWalletFallback = authorRaw;
  }
  final rootAuthorWallet = json['authorWallet'] as String? ??
      json['author_wallet'] as String? ??
      json['createdByWallet'] as String? ??
      json['created_by_wallet'] as String?;
  final resolvedAuthorWallet =
      authorWallet ?? rootAuthorWallet ?? authorRawWalletFallback;

  final authorId = json['authorId'] as String? ??
      json['author_id']?.toString() ??
      normalizedAuthor['id'] as String? ??
      normalizedAuthor['walletAddress'] as String? ??
      json['walletAddress'] as String? ??
      json['wallet_address'] as String? ??
      json['wallet'] as String? ??
      json['userId'] as String? ??
      json['user_id']?.toString() ??
      resolvedAuthorWallet ??
      'unknown';

  final authorDisplayName = normalizedAuthor['displayName'] as String? ??
      normalizedAuthor['display_name'] as String? ??
      json['displayName'] as String? ??
      json['authorDisplayName'] as String?;
  final rootAuthorDisplayName = json['userDisplayName'] as String? ??
      json['display_name'] as String? ??
      json['author_name'] as String?;

  final rawUsername = normalizedAuthor['username'] as String? ??
      json['authorUsername'] as String? ??
      json['authorName'] as String? ??
      json['username'] as String?;

  final authorName =
      (authorDisplayName != null && authorDisplayName.trim().isNotEmpty)
          ? authorDisplayName.trim()
          : ((rawUsername != null && rawUsername.trim().isNotEmpty)
              ? rawUsername.trim()
              : (json['authorName'] as String?) ?? 'Anonymous');
  final resolvedAuthorName =
      (authorName != 'Anonymous' && authorName.trim().isNotEmpty)
          ? authorName
          : (rootAuthorDisplayName?.trim() ?? authorName);

  final avatarCandidate = normalizedAuthor['avatar'] as String? ??
      normalizedAuthor['avatarUrl'] as String? ??
      normalizedAuthor['avatar_url'] as String? ??
      normalizedAuthor['profile_image'] as String? ??
      normalizedAuthor['profileImage'] as String? ??
      json['authorAvatar'] as String? ??
      json['avatar'] as String?;

  final authorUsername = json['authorUsername'] as String? ??
      normalizedAuthor['username'] as String? ??
      rawUsername;

  final originalContent = (json['originalText'] ??
          json['original_content'] ??
          json['originalContent'])
      ?.toString();
  DateTime? editedAt;
  final editedRaw =
      json['editedAt'] ?? json['edited_at'] ?? json['editedAtUtc'];
  if (editedRaw != null) {
    try {
      editedAt = DateTime.parse(editedRaw.toString());
    } catch (_) {
      editedAt = null;
    }
  }

  return Comment(
    id: (json['id'] ?? '').toString(),
    authorId: authorId,
    authorName: resolvedAuthorName,
    authorAvatar: MediaUrlResolver.resolve(avatarCandidate),
    authorUsername: authorUsername,
    authorWallet: resolvedAuthorWallet ?? authorId,
    parentCommentId: json['parentCommentId'] as String? ??
        json['parent_comment_id']?.toString(),
    originalContent:
        (originalContent != null && originalContent.trim().isNotEmpty)
            ? originalContent
            : null,
    editedAt: editedAt,
    content: json['content'] as String,
    timestamp: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : (json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now()),
    likeCount: json['likes'] as int? ??
        json['likeCount'] as int? ??
        json['likesCount'] as int? ??
        0,
    isLiked: json['isLiked'] as bool? ?? false,
    replies: <Comment>[],
  );
}

List<Comment> _backendApiNestComments(List<Comment> comments) {
  if (comments.isEmpty) return <Comment>[];
  final Map<String, Comment> byId = {
    for (final comment in comments) comment.id: comment,
  };
  final List<Comment> roots = [];

  for (final comment in comments) {
    final parentId = comment.parentCommentId;
    if (parentId == null || parentId.isEmpty) {
      roots.add(comment);
      continue;
    }
    final parent = byId[parentId];
    if (parent == null) {
      roots.add(comment);
      continue;
    }
    parent.replies = [...parent.replies, comment];
  }

  return roots;
}
