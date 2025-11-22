import 'dart:convert';

/// Activity categories supported by the unified recent activity feed.
enum ActivityCategory {
  like,
  comment,
  discovery,
  reward,
  follow,
  share,
  mention,
  nft,
  ar,
  save,
  achievement,
  system,
}

ActivityCategory activityCategoryFromString(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'like':
      return ActivityCategory.like;
    case 'comment':
      return ActivityCategory.comment;
    case 'discovery':
    case 'artwork_discovery':
    case 'art_discovered':
      return ActivityCategory.discovery;
    case 'reward':
    case 'token':
    case 'kub8':
    case 'airdrop':
      return ActivityCategory.reward;
    case 'follow':
    case 'follower':
    case 'followed':
      return ActivityCategory.follow;
    case 'share':
      return ActivityCategory.share;
    case 'mention':
      return ActivityCategory.mention;
    case 'nft':
    case 'nft_minting':
    case 'mint':
      return ActivityCategory.nft;
    case 'ar':
    case 'ar_event':
    case 'ar_proximity':
    case 'ar_experience':
      return ActivityCategory.ar;
    case 'save':
    case 'saved':
    case 'bookmark':
    case 'bookmarked':
      return ActivityCategory.save;
    case 'achievement':
    case 'achievement_unlocked':
    case 'badge':
      return ActivityCategory.achievement;
    default:
      return ActivityCategory.system;
  }
}

/// Immutable data model for items shown in the recent activity feed.
class RecentActivity {
  final String id;
  final ActivityCategory category;
  final String title;
  final String description;
  final DateTime timestamp;
  final bool isRead;
  final String? actorName;
  final String? actorAvatar;
  final String? actionUrl;
  final Map<String, dynamic> metadata;

  const RecentActivity({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.isRead,
    this.actorName,
    this.actorAvatar,
    this.actionUrl,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? const <String, dynamic>{};

  RecentActivity copyWith({
    String? id,
    ActivityCategory? category,
    String? title,
    String? description,
    DateTime? timestamp,
    bool? isRead,
    String? actorName,
    String? actorAvatar,
    String? actionUrl,
    Map<String, dynamic>? metadata,
  }) {
    return RecentActivity(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      actorName: actorName ?? this.actorName,
      actorAvatar: actorAvatar ?? this.actorAvatar,
      actionUrl: actionUrl ?? this.actionUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    final meta = <String, dynamic>{};
    if (json['metadata'] is Map<String, dynamic>) {
      meta.addAll(json['metadata'] as Map<String, dynamic>);
    }
    if (json['metadata'] is String) {
      try {
        final decoded = jsonDecode(json['metadata'] as String) as Map<String, dynamic>;
        meta.addAll(decoded);
      } catch (_) {
        meta['rawMetadata'] = json['metadata'];
      }
    }

    return RecentActivity(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      category: activityCategoryFromString(json['category']?.toString()),
      title: json['title']?.toString() ?? 'Activity',
      description: json['description']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      isRead: json['isRead'] as bool? ?? true,
      actorName: json['actorName']?.toString(),
      actorAvatar: json['actorAvatar']?.toString(),
      actionUrl: json['actionUrl']?.toString(),
      metadata: meta,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.name,
      'title': title,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      if (actorName != null) 'actorName': actorName,
      if (actorAvatar != null) 'actorAvatar': actorAvatar,
      if (actionUrl != null) 'actionUrl': actionUrl,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}
