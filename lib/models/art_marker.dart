import 'package:latlong2/latlong.dart';

import '../providers/storage_provider.dart';
import '../utils/media_url_resolver.dart';

/// High-level category for an art marker shown on the map
enum ArtMarkerType {
  artwork,
  institution,
  event,
  residency,
  drop,
  experience,
  other,
}

/// Signal tier helps the UI decide how vivid the cube should render
enum ArtMarkerSignal {
  subtle,
  active,
  featured,
  legendary,
}

/// Art marker that links physical locations to digital/AR content
class ArtMarker {
  final String id;
  final String name;
  final String description;
  final LatLng position;
  final String? artworkId; // Reference to Artwork when applicable
  final ArtMarkerType type;
  final String category;

  // AR Content references
  final String? modelCID; // IPFS CID for 3D model (if using IPFS)
  final String? modelURL; // HTTP URL for 3D model (if using HTTP)
  final StorageProvider storageProvider;

  // AR Configuration
  final double scale; // Model scale (1.0 = original size)
  final Map<String, double> rotation; // {x, y, z} rotation in degrees
  final bool enableAnimation;
  final String? animationName;
  final bool enablePhysics;
  final bool enableInteraction; // Allow user to manipulate object

  // Metadata
  final Map<String, dynamic>? metadata;
  final List<ExhibitionSummaryDto> exhibitionSummaries;
  final List<String> tags;
  final DateTime createdAt;
  final String createdBy;
  final int viewCount;
  final int interactionCount;

  // Discovery settings
  final double activationRadius; // Meters from marker to activate AR
  final bool requiresProximity; // Must be near to activate
  final bool isPublic; // Visible to all users

  const ArtMarker({
    required this.id,
    required this.name,
    required this.description,
    required this.position,
    required this.type,
    this.artworkId,
    this.category = 'General',
    this.modelCID,
    this.modelURL,
    this.storageProvider = StorageProvider.hybrid,
    this.scale = 1.0,
    this.rotation = const {'x': 0, 'y': 0, 'z': 0},
    this.enableAnimation = false,
    this.animationName,
    this.enablePhysics = false,
    this.enableInteraction = true,
    this.metadata,
    this.exhibitionSummaries = const <ExhibitionSummaryDto>[],
    this.tags = const [],
    required this.createdAt,
    required this.createdBy,
    this.viewCount = 0,
    this.interactionCount = 0,
    this.activationRadius = 50.0,
    this.requiresProximity = true,
    this.isPublic = true,
  });

  /// Convenience getter for map visuals
  ArtMarkerSignal get signalTier {
    final explicitTier = metadata?["signalTier"];
    if (explicitTier is String) {
      final normalized = explicitTier.toLowerCase();
      if (normalized == 'legendary') return ArtMarkerSignal.legendary;
      if (normalized == 'featured') return ArtMarkerSignal.featured;
      if (normalized == 'active') return ArtMarkerSignal.active;
      if (normalized == 'subtle') return ArtMarkerSignal.subtle;
    }

    final score = _popularityScore;
    if (score >= 75) return ArtMarkerSignal.legendary;
    if (score >= 45) return ArtMarkerSignal.featured;
    if (score >= 20) return ArtMarkerSignal.active;
    return ArtMarkerSignal.subtle;
  }

  double get _popularityScore {
    final metaScoreRaw = metadata?["popularityScore"];
    if (metaScoreRaw is num) return metaScoreRaw.toDouble();
    final views = viewCount.toDouble();
    final interactions = interactionCount.toDouble();
    final boost = metadata?["boost"] is num ? (metadata?["boost"] as num).toDouble() : 0;
    return (views * 0.35) + (interactions * 0.65) + boost;
  }

  /// Get the appropriate content URL based on storage provider
  String? getContentURL() {
    if (storageProvider == StorageProvider.http) {
      return MediaUrlResolver.resolve(modelURL);
    }

    if (modelCID != null && modelCID!.isNotEmpty) {
      return MediaUrlResolver.resolve('ipfs://${modelCID!}');
    }

    return MediaUrlResolver.resolve(modelURL);
  }

  /// Get fallback URL if primary fails
  String? getFallbackURL() {
    if (storageProvider == StorageProvider.hybrid &&
        modelCID != null &&
        modelURL != null &&
        modelURL!.isNotEmpty) {
      return MediaUrlResolver.resolve(modelURL);
    }

    return null;
  }

  /// Whether the marker has a meaningful coordinate (filters out null-island defaults).
  bool get hasValidPosition {
    final nearNullIsland =
        position.latitude.abs() < 0.0001 && position.longitude.abs() < 0.0001;
    return !nearNullIsland;
  }

  /// Check if marker is active at given position
  bool isActiveAt(LatLng currentPosition) {
    if (!requiresProximity) return true;

    const distance = Distance();
    final distanceMeters = distance.as(
      LengthUnit.Meter,
      currentPosition,
      position,
    );

    return distanceMeters <= activationRadius;
  }

  /// Get distance from current position (in meters)
  double getDistanceFrom(LatLng currentPosition) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, currentPosition, position);
  }

  /// Convert to Map for storage/API
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'artworkId': artworkId,
      'markerType': type.name,
      'type': type.name,
      'modelCID': modelCID,
      'modelURL': modelURL,
      'storageProvider': storageProvider.name,
      'scale': scale,
      'rotation': rotation,
      'enableAnimation': enableAnimation,
      'animationName': animationName,
      'enablePhysics': enablePhysics,
      'enableInteraction': enableInteraction,
      'metadata': metadata,
      'exhibitionSummaries': exhibitionSummaries.map((e) => e.toJson()).toList(growable: false),
      'tags': tags,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'viewCount': viewCount,
      'interactionCount': interactionCount,
      'activationRadius': activationRadius,
      'requiresProximity': requiresProximity,
      'isPublic': isPublic,
    };
  }

  /// Create from Map (from storage/API)
  factory ArtMarker.fromMap(Map<String, dynamic> map) {
    final metadata = _normalizeMetadata(map['metadata']);
    final exhibitionSummaries = _parseExhibitionSummaries(map, metadata);
    final markerType = _parseMarkerType(
      map['markerType'] ?? map['type'] ?? map['category'],
      metadata,
    );
    final rotation = _normalizeRotation(map['rotation']);
    return ArtMarker(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      position: LatLng(
        _parseDouble(map['latitude'] ?? map['lat'], 0),
        _parseDouble(map['longitude'] ?? map['lng'], 0),
      ),
      artworkId: map['artworkId']?.toString(),
      type: markerType,
      category: map['category']?.toString() ?? 'General',
      modelCID: map['modelCID']?.toString(),
      modelURL: map['modelURL']?.toString(),
      storageProvider: StorageProvider.values.firstWhere(
        (e) => e.name == map['storageProvider'],
        orElse: () => StorageProvider.hybrid,
      ),
      scale: _parseDouble(map['scale'], 1.0),
      rotation: rotation,
      enableAnimation: _parseBool(map['enableAnimation'], false),
      animationName: map['animationName']?.toString(),
      enablePhysics: _parseBool(map['enablePhysics'], false),
      enableInteraction: _parseBool(map['enableInteraction'], true),
      metadata: metadata,
      exhibitionSummaries: exhibitionSummaries,
      tags: List<String>.from(map['tags'] ?? const []),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      createdBy: map['createdBy']?.toString() ?? 'system',
      viewCount: _parseInt(map['viewCount'], 0),
      interactionCount: _parseInt(map['interactionCount'], 0),
      activationRadius: _parseDouble(map['activationRadius'], 50.0),
      requiresProximity: _parseBool(map['requiresProximity'], true),
      isPublic: _parseBool(map['isPublic'], true),
    );
  }

  /// Create a copy with updated fields
  ArtMarker copyWith({
    String? id,
    String? name,
    String? description,
    LatLng? position,
    String? artworkId,
    ArtMarkerType? type,
    String? category,
    String? modelCID,
    String? modelURL,
    StorageProvider? storageProvider,
    double? scale,
    Map<String, double>? rotation,
    bool? enableAnimation,
    String? animationName,
    bool? enablePhysics,
    bool? enableInteraction,
    Map<String, dynamic>? metadata,
    List<ExhibitionSummaryDto>? exhibitionSummaries,
    List<String>? tags,
    DateTime? createdAt,
    String? createdBy,
    int? viewCount,
    int? interactionCount,
    double? activationRadius,
    bool? requiresProximity,
    bool? isPublic,
  }) {
    return ArtMarker(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      position: position ?? this.position,
      artworkId: artworkId ?? this.artworkId,
      type: type ?? this.type,
      category: category ?? this.category,
      modelCID: modelCID ?? this.modelCID,
      modelURL: modelURL ?? this.modelURL,
      storageProvider: storageProvider ?? this.storageProvider,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      enableAnimation: enableAnimation ?? this.enableAnimation,
      animationName: animationName ?? this.animationName,
      enablePhysics: enablePhysics ?? this.enablePhysics,
      enableInteraction: enableInteraction ?? this.enableInteraction,
      metadata: metadata ?? this.metadata,
      exhibitionSummaries: exhibitionSummaries ?? this.exhibitionSummaries,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      viewCount: viewCount ?? this.viewCount,
      interactionCount: interactionCount ?? this.interactionCount,
      activationRadius: activationRadius ?? this.activationRadius,
      requiresProximity: requiresProximity ?? this.requiresProximity,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ArtMarker && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ArtMarker(id: $id, type: ${type.name}, name: $name)';
  }

  static ArtMarkerType _parseMarkerType(dynamic raw, Map<String, dynamic>? metadata) {
    final metaType = metadata?['subjectType'] ?? metadata?['subject_type'];
    final metaCategory = metadata?['subjectCategory'] ?? metadata?['subject_category'];
    final metaLabel = metadata?['subjectLabel'] ?? metadata?['subject_label'];

    String normalized = raw?.toString().toLowerCase() ?? '';
    if ((normalized.isEmpty || normalized == 'geolocation') && metaType is String) {
      normalized = metaType.toLowerCase();
    }
    if (metaCategory is String && normalized.isEmpty) {
      normalized = metaCategory.toLowerCase();
    }
    if (metaLabel is String && normalized.isEmpty) {
      normalized = metaLabel.toLowerCase();
    }

    if (normalized.contains('institution') || normalized.contains('museum') || normalized.contains('gallery')) {
      return ArtMarkerType.institution;
    }
    if (normalized.contains('event')) {
      return ArtMarkerType.event;
    }
    if (normalized.contains('residency') || normalized.contains('group') || normalized.contains('dao')) {
      return ArtMarkerType.residency;
    }
    if (normalized.contains('drop') || normalized.contains('airdrop')) {
      return ArtMarkerType.drop;
    }
    if (normalized.contains('experience') || normalized.contains('ar') || normalized.contains('xr')) {
      return ArtMarkerType.experience;
    }
    if (normalized.contains('artwork') || normalized.contains('art') || normalized.isEmpty) {
      return ArtMarkerType.artwork;
    }
    return ArtMarkerType.other;
  }

  static double _parseDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static int _parseInt(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      final parsedDouble = double.tryParse(value);
      if (parsedDouble != null) return parsedDouble.toInt();
    }
    return fallback;
  }

  static bool _parseBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return fallback;
  }

  static Map<String, double> _normalizeRotation(dynamic raw) {
    if (raw is Map) {
      return {
        'x': _parseDouble(raw['x'], 0),
        'y': _parseDouble(raw['y'], 0),
        'z': _parseDouble(raw['z'], 0),
      };
    }
    return const {'x': 0, 'y': 0, 'z': 0};
  }

  static Map<String, dynamic>? _normalizeMetadata(dynamic raw) {
    Map<String, dynamic>? metadata;
    if (raw is Map<String, dynamic>) {
      metadata = Map<String, dynamic>.from(raw);
    } else if (raw is Map) {
      metadata = raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return metadata;
  }

  ExhibitionSummaryDto? get primaryExhibitionSummary {
    if (exhibitionSummaries.isEmpty) return null;
    return exhibitionSummaries.first;
  }

  String? _metadataString(List<String> keys) {
    String? readFromMap(Map<String, dynamic>? map) {
      if (map == null) return null;
      for (final key in keys) {
        final raw = map[key];
        if (raw == null) continue;
        final value = raw.toString().trim();
        if (value.isNotEmpty) return value;
      }
      return null;
    }

    final direct = readFromMap(metadata);
    if (direct != null) return direct;

    final nested = metadata?['metadata'] ?? metadata?['meta'];
    if (nested is Map) {
      return readFromMap(Map<String, dynamic>.from(nested));
    }
    return null;
  }

  String? get subjectType {
    final value = _metadataString(const ['subjectType', 'subject_type']);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  String? get subjectId {
    final value = _metadataString(const ['subjectId', 'subject_id']);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  String? get subjectTitle {
    final value = _metadataString(const ['subjectTitle', 'subject_title']);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  ExhibitionSummaryDto? get resolvedExhibitionSummary {
    final primary = primaryExhibitionSummary;
    if (primary != null && primary.id.trim().isNotEmpty) return primary;

    final subjectTypeValue = subjectType?.toLowerCase();
    final explicitExhibitionId = _metadataString(const ['exhibitionId', 'exhibition_id']);
    final allowFallback = subjectTypeValue == null || subjectTypeValue.isEmpty;
    final isExhibition = (subjectTypeValue != null && subjectTypeValue.contains('exhibition')) ||
        (allowFallback && explicitExhibitionId != null && explicitExhibitionId.isNotEmpty);
    if (!isExhibition) return null;

    final resolvedId = (subjectTypeValue != null && subjectTypeValue.contains('exhibition'))
        ? (subjectId ?? explicitExhibitionId)
        : explicitExhibitionId;
    if (resolvedId == null || resolvedId.isEmpty) return null;

    final title = subjectTitle ?? _metadataString(const ['exhibitionTitle', 'exhibition_title']);
    return ExhibitionSummaryDto(
      id: resolvedId,
      title: (title != null && title.isNotEmpty) ? title : null,
    );
  }

  bool get isExhibitionSubject {
    final normalized = subjectType?.toLowerCase();
    return normalized != null && normalized.contains('exhibition');
  }

  bool get isExhibitionMarker {
    if (isExhibitionSubject) return true;
    final resolved = resolvedExhibitionSummary;
    if (resolved == null || resolved.id.trim().isEmpty) return false;
    return artworkId == null || artworkId!.isEmpty;
  }
}

/// Lightweight summary for exhibition linkage on markers.
///
/// This is intentionally small to avoid coupling map marker payloads to the
/// full Exhibition model.
class ExhibitionSummaryDto {
  final String id;
  final String? title;

  const ExhibitionSummaryDto({
    required this.id,
    this.title,
  });

  factory ExhibitionSummaryDto.fromJson(Map<String, dynamic> json) {
    return ExhibitionSummaryDto(
      id: (json['id'] ?? json['exhibitionId'] ?? json['exhibition_id'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? json['label'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (title != null) 'title': title,
    };
  }
}

List<ExhibitionSummaryDto> _parseExhibitionSummaries(
  Map<String, dynamic> map,
  Map<String, dynamic>? normalizedMetadata,
) {
  dynamic raw = map['exhibitionSummaries'] ?? map['exhibition_summaries'];

  if (raw == null && normalizedMetadata != null) {
    raw = normalizedMetadata['exhibitionSummaries'] ??
        normalizedMetadata['exhibition_summaries'] ??
        normalizedMetadata['exhibitions'];
  }

  if (raw is List) {
    return raw
        .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
        .map(ExhibitionSummaryDto.fromJson)
        .where((e) => e.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  // Support single-object shape.
  if (raw is Map) {
    final dto = ExhibitionSummaryDto.fromJson(Map<String, dynamic>.from(raw));
    if (dto.id.trim().isEmpty) return const <ExhibitionSummaryDto>[];
    return <ExhibitionSummaryDto>[dto];
  }

  final subjectType =
      (normalizedMetadata?['subjectType'] ?? normalizedMetadata?['subject_type'] ?? map['subjectType'] ?? map['subject_type'])
          ?.toString()
          .toLowerCase();
  if (subjectType != null && subjectType.contains('exhibition')) {
    final subjectId =
        (normalizedMetadata?['subjectId'] ?? normalizedMetadata?['subject_id'] ?? map['subjectId'] ?? map['subject_id'])
            ?.toString()
            .trim();
    if (subjectId != null && subjectId.isNotEmpty) {
      final subjectTitle =
          (normalizedMetadata?['subjectTitle'] ?? normalizedMetadata?['subject_title'] ?? map['subjectTitle'] ?? map['subject_title'])
              ?.toString()
              .trim();
      return <ExhibitionSummaryDto>[
        ExhibitionSummaryDto(
          id: subjectId,
          title: subjectTitle != null && subjectTitle.isNotEmpty ? subjectTitle : null,
        ),
      ];
    }
  }

  return const <ExhibitionSummaryDto>[];
}
