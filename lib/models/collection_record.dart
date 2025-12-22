DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final raw = value.toString();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

bool _parseBool(dynamic value, bool fallback) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') return true;
    if (normalized == 'false' || normalized == '0' || normalized == 'no') return false;
  }
  return fallback;
}

int _parseInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _stringOrEmpty(dynamic value) => value?.toString() ?? '';

class CollectionArtworkRecord {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? imageCid;
  final String? artistName;
  final String? artistWallet;
  final List<String> tags;
  final DateTime? addedAt;
  final String? notes;

  const CollectionArtworkRecord({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.imageCid,
    this.artistName,
    this.artistWallet,
    this.tags = const <String>[],
    this.addedAt,
    this.notes,
  });

  factory CollectionArtworkRecord.fromMap(Map<String, dynamic> map) {
    final tagsRaw = map['tags'];
    final tags = tagsRaw is List
        ? tagsRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return CollectionArtworkRecord(
      id: _stringOrEmpty(map['id'] ?? map['artworkId'] ?? map['artwork_id']),
      title: _stringOrEmpty(map['title'] ?? map['name']),
      description: map['description']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
      imageCid: map['imageCid']?.toString(),
      artistName: map['artistName']?.toString(),
      artistWallet: map['artistWallet']?.toString(),
      tags: tags,
      addedAt: _parseDateTime(map['addedAt'] ?? map['added_at']),
      notes: map['notes']?.toString(),
    );
  }
}

class CollectionRecord {
  final String id;
  final String walletAddress;
  final String name;
  final String? description;
  final bool isPublic;
  final int artworkCount;
  final String? thumbnailUrl;
  final List<CollectionArtworkRecord> artworks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CollectionRecord({
    required this.id,
    required this.walletAddress,
    required this.name,
    this.description,
    required this.isPublic,
    required this.artworkCount,
    this.thumbnailUrl,
    this.artworks = const <CollectionArtworkRecord>[],
    this.createdAt,
    this.updatedAt,
  });

  factory CollectionRecord.fromMap(Map<String, dynamic> map) {
    final rawArtworks = map['artworks'] ?? map['items'] ?? const <dynamic>[];
    final artworks = rawArtworks is List
        ? rawArtworks
            .whereType<dynamic>()
            .map((e) => e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map))
            .map(CollectionArtworkRecord.fromMap)
            .toList()
        : const <CollectionArtworkRecord>[];

    return CollectionRecord(
      id: _stringOrEmpty(map['id']),
      walletAddress: _stringOrEmpty(map['walletAddress'] ?? map['wallet_address']),
      name: _stringOrEmpty(map['name'] ?? map['title']),
      description: map['description']?.toString(),
      isPublic: _parseBool(map['isPublic'] ?? map['is_public'], true),
      artworkCount: _parseInt(map['artworkCount'] ?? map['artwork_count'], artworks.length),
      thumbnailUrl: (map['thumbnailUrl'] ??
              map['thumbnail_url'] ??
              map['coverImage'] ??
              map['cover_image'] ??
              map['coverImageUrl'] ??
              map['cover_image_url'] ??
              map['coverUrl'] ??
              map['cover_url'])
          ?.toString(),
      artworks: artworks,
      createdAt: _parseDateTime(map['createdAt'] ?? map['created_at']),
      updatedAt: _parseDateTime(map['updatedAt'] ?? map['updated_at']),
    );
  }

  CollectionRecord copyWith({
    String? name,
    String? description,
    bool? isPublic,
    int? artworkCount,
    String? thumbnailUrl,
    List<CollectionArtworkRecord>? artworks,
    DateTime? updatedAt,
  }) {
    return CollectionRecord(
      id: id,
      walletAddress: walletAddress,
      name: name ?? this.name,
      description: description ?? this.description,
      isPublic: isPublic ?? this.isPublic,
      artworkCount: artworkCount ?? this.artworkCount,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      artworks: artworks ?? this.artworks,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
