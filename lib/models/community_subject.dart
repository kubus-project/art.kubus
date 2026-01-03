class CommunitySubjectRef {
  final String type;
  final String id;

  const CommunitySubjectRef({
    required this.type,
    required this.id,
  });

  String get normalizedType => type.trim().toLowerCase();

  String get key => '$normalizedType::$id';
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
    return CommunitySubjectPreview(
      ref: CommunitySubjectRef(type: type, id: id),
      title: (map['title'] ?? map['name'] ?? 'Untitled').toString(),
      subtitle: map['subtitle']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
    );
  }
}
