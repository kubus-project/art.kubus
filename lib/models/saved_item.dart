import 'package:flutter/foundation.dart';

enum SavedItemType {
  artwork,
  communityPost,
  event,
  collection,
  exhibition,
  artist,
  institution,
  group,
  marker,
}

extension SavedItemTypeX on SavedItemType {
  String get storageKey => switch (this) {
        SavedItemType.artwork => 'artwork',
        SavedItemType.communityPost => 'community_post',
        SavedItemType.event => 'event',
        SavedItemType.collection => 'collection',
        SavedItemType.exhibition => 'exhibition',
        SavedItemType.artist => 'artist',
        SavedItemType.institution => 'institution',
        SavedItemType.group => 'group',
        SavedItemType.marker => 'marker',
      };

  String get storageLabel => storageKey;

  static SavedItemType? fromStorageKey(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'artwork':
        return SavedItemType.artwork;
      case 'post':
      case 'communitypost':
      case 'community_post':
        return SavedItemType.communityPost;
      case 'event':
        return SavedItemType.event;
      case 'collection':
        return SavedItemType.collection;
      case 'exhibition':
        return SavedItemType.exhibition;
      case 'artist':
        return SavedItemType.artist;
      case 'institution':
        return SavedItemType.institution;
      case 'group':
        return SavedItemType.group;
      case 'art_marker':
      case 'artmarker':
      case 'marker':
        return SavedItemType.marker;
      default:
        return null;
    }
  }
}

@immutable
class SavedItemRecord {
  final SavedItemType type;
  final String id;
  final DateTime savedAt;
  final String? title;
  final String? subtitle;
  final String? imageUrl;
  final String? authorId;
  final String? authorName;
  final Map<String, dynamic> metadata;

  const SavedItemRecord({
    required this.type,
    required this.id,
    required this.savedAt,
    this.title,
    this.subtitle,
    this.imageUrl,
    this.authorId,
    this.authorName,
    this.metadata = const <String, dynamic>{},
  });

  SavedItemRecord copyWith({
    SavedItemType? type,
    String? id,
    DateTime? savedAt,
    String? title,
    String? subtitle,
    String? imageUrl,
    String? authorId,
    String? authorName,
    Map<String, dynamic>? metadata,
  }) {
    return SavedItemRecord(
      type: type ?? this.type,
      id: id ?? this.id,
      savedAt: savedAt ?? this.savedAt,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.storageKey,
      'id': id,
      'savedAt': savedAt.toIso8601String(),
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (authorId != null) 'authorId': authorId,
      if (authorName != null) 'authorName': authorName,
      'metadata': metadata,
    };
  }

  factory SavedItemRecord.fromJson(Map<String, dynamic> json) {
    final type = SavedItemTypeX.fromStorageKey(
          (json['type'] ?? json['itemType'] ?? json['item_type'])?.toString(),
        ) ??
        SavedItemType.artwork;
    final rawMetadata = json['metadata'];
    return SavedItemRecord(
      type: type,
      id: (json['itemId'] ?? json['item_id'] ?? json['id'] ?? '')
          .toString()
          .trim(),
      savedAt: DateTime.tryParse(
            (json['savedAt'] ?? json['saved_at'])?.toString() ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      title: _nullableString(json['title']),
      subtitle: _nullableString(json['subtitle']),
      imageUrl: _nullableString(json['imageUrl'] ?? json['image_url']),
      authorId: _nullableString(json['authorId'] ?? json['author_id']),
      authorName: _nullableString(json['authorName'] ?? json['author_name']),
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const <String, dynamic>{},
    );
  }
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

@immutable
class SavedItemsPage {
  final List<SavedItemRecord> items;
  final String? nextCursor;

  const SavedItemsPage({
    required this.items,
    this.nextCursor,
  });
}
