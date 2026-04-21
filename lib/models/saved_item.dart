import 'package:flutter/foundation.dart';

enum SavedItemType {
  artwork,
  event,
  collection,
  exhibition,
  post,
}

extension SavedItemTypeX on SavedItemType {
  String get storageKey => switch (this) {
        SavedItemType.artwork => 'artwork',
        SavedItemType.event => 'event',
        SavedItemType.collection => 'collection',
        SavedItemType.exhibition => 'exhibition',
        SavedItemType.post => 'post',
      };

  String get storageLabel => storageKey;

  static SavedItemType? fromStorageKey(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'artwork':
        return SavedItemType.artwork;
      case 'event':
        return SavedItemType.event;
      case 'collection':
        return SavedItemType.collection;
      case 'exhibition':
        return SavedItemType.exhibition;
      case 'post':
        return SavedItemType.post;
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

  const SavedItemRecord({
    required this.type,
    required this.id,
    required this.savedAt,
  });

  SavedItemRecord copyWith({
    SavedItemType? type,
    String? id,
    DateTime? savedAt,
  }) {
    return SavedItemRecord(
      type: type ?? this.type,
      id: id ?? this.id,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.storageKey,
      'id': id,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory SavedItemRecord.fromJson(Map<String, dynamic> json) {
    final type = SavedItemTypeX.fromStorageKey(json['type']?.toString()) ??
        SavedItemType.artwork;
    return SavedItemRecord(
      type: type,
      id: (json['id'] ?? '').toString().trim(),
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
