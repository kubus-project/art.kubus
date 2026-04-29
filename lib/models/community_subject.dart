class CommunitySubjectRef {
  final String type;
  final String id;
  final String? title;
  final String? subtitle;
  final String? imageUrl;
  final String? ownerName;

  const CommunitySubjectRef({
    required this.type,
    required this.id,
    this.title,
    this.subtitle,
    this.imageUrl,
    this.ownerName,
  });

  String get normalizedType => type.trim().toLowerCase();

  String get key => '$normalizedType::$id';

  factory CommunitySubjectRef.fromJson(Map<String, dynamic> json) {
    return CommunitySubjectRef(
      type: (json['type'] ?? json['subjectType'] ?? json['subject_type'] ?? '')
          .toString()
          .trim(),
      id: (json['id'] ?? json['subjectId'] ?? json['subject_id'] ?? '')
          .toString()
          .trim(),
      title: _nullableString(json['title']),
      subtitle: _nullableString(json['subtitle']),
      imageUrl: _nullableString(json['imageUrl'] ?? json['image_url']),
      ownerName: _nullableString(json['ownerName'] ?? json['owner_name']),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': normalizedType,
        'id': id,
        if (title != null) 'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (ownerName != null) 'ownerName': ownerName,
      };
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

class CommunitySubjectPreview {
  final CommunitySubjectRef ref;
  final String title;
  final String? subtitle;
  final String? imageUrl;

  const CommunitySubjectPreview({
    required this.ref,
    required this.title,
    this.subtitle,
    this.imageUrl,
  });

  factory CommunitySubjectPreview.fromMap(Map<String, dynamic> map) {
    final type = (map['type'] ?? map['subjectType'] ?? map['subject_type'] ?? '').toString();
    final id = (map['id'] ?? map['subjectId'] ?? map['subject_id'] ?? '').toString();
    final image = map['imageUrl'] ??
        map['image_url'] ??
        map['coverImageUrl'] ??
        map['cover_image_url'] ??
        map['coverUrl'] ??
        map['cover_url'] ??
        map['thumbnailUrl'] ??
        map['thumbnail_url'] ??
        map['avatar'] ??
        map['avatarUrl'] ??
        map['avatar_url'];
    return CommunitySubjectPreview(
      ref: CommunitySubjectRef(type: type, id: id),
      title: (map['title'] ?? map['name'] ?? 'Untitled').toString(),
      subtitle: map['subtitle']?.toString(),
      imageUrl: image?.toString(),
    );
  }
}
