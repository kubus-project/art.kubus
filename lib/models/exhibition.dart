import 'event.dart';

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final str = value.toString();
  if (str.isEmpty) return null;
  return DateTime.tryParse(str);
}

num? _toNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

class Exhibition {
  final String id;
  final String? eventId;
  final String title;
  final String? description;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? locationName;
  final double? lat;
  final double? lng;
  final String? coverUrl;
  final String? status; // draft|published
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? myRole;
  final UserSummaryDto? host;
  final List<String> artworkIds;

  const Exhibition({
    required this.id,
    this.eventId,
    required this.title,
    this.description,
    this.startsAt,
    this.endsAt,
    this.locationName,
    this.lat,
    this.lng,
    this.coverUrl,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.myRole,
    this.host,
    this.artworkIds = const <String>[],
  });

  bool get isPublished => (status ?? '').toLowerCase() == 'published';

  factory Exhibition.fromJson(Map<String, dynamic> json) {
    final hostRaw = json['host'];
    final artworkIdsRaw = json['artworkIds'] ?? json['artwork_ids'];
    final artworkIds = <String>[];
    if (artworkIdsRaw is List) {
      for (final v in artworkIdsRaw) {
        final s = v?.toString().trim();
        if (s != null && s.isNotEmpty) artworkIds.add(s);
      }
    }
    return Exhibition(
      id: (json['id'] ?? '').toString(),
      eventId: (json['eventId'] ?? json['event_id'])?.toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      startsAt: _parseDateTime(json['startsAt'] ?? json['starts_at']),
      endsAt: _parseDateTime(json['endsAt'] ?? json['ends_at']),
      locationName: (json['locationName'] ?? json['location_name'])?.toString(),
      lat: (_toNum(json['lat'] ?? json['latitude']))?.toDouble(),
      lng: (_toNum(json['lng'] ?? json['longitude']))?.toDouble(),
      coverUrl: (json['coverUrl'] ?? json['cover_url'])?.toString(),
      status: json['status']?.toString(),
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at']),
      myRole: (json['myRole'] ?? json['my_role'])?.toString(),
      host: hostRaw is Map<String, dynamic> ? UserSummaryDto.fromJson(hostRaw) : null,
      artworkIds: artworkIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'title': title,
      'description': description,
      'startsAt': startsAt?.toIso8601String(),
      'endsAt': endsAt?.toIso8601String(),
      'locationName': locationName,
      'lat': lat,
      'lng': lng,
      'coverUrl': coverUrl,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'myRole': myRole,
      'host': host?.toJson(),
      'artworkIds': artworkIds,
    };
  }

  Exhibition copyWith({
    String? id,
    String? eventId,
    String? title,
    String? description,
    DateTime? startsAt,
    DateTime? endsAt,
    String? locationName,
    double? lat,
    double? lng,
    String? coverUrl,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? myRole,
    UserSummaryDto? host,
    List<String>? artworkIds,
  }) {
    return Exhibition(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      description: description ?? this.description,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      locationName: locationName ?? this.locationName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      coverUrl: coverUrl ?? this.coverUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      myRole: myRole ?? this.myRole,
      host: host ?? this.host,
      artworkIds: artworkIds ?? this.artworkIds,
    );
  }
}

class ExhibitionPoap {
  final String id;
  final String code;
  final String title;
  final String? description;
  final String? iconUrl;
  final int rewardKub8;
  final String rarity;
  final String exhibitionId;
  final bool isPoap;
  final DateTime? createdAt;

  const ExhibitionPoap({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    this.iconUrl,
    required this.rewardKub8,
    required this.rarity,
    required this.exhibitionId,
    required this.isPoap,
    this.createdAt,
  });

  factory ExhibitionPoap.fromJson(Map<String, dynamic> json) {
    return ExhibitionPoap(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      iconUrl: (json['iconUrl'] ?? json['icon_url'] ?? json['icon'])?.toString(),
      rewardKub8: (json['rewardKub8'] ?? json['reward_kub8'] ?? 0) is num
          ? (json['rewardKub8'] ?? json['reward_kub8'] ?? 0).toInt()
          : int.tryParse((json['rewardKub8'] ?? json['reward_kub8'] ?? '0').toString()) ?? 0,
      rarity: (json['rarity'] ?? 'common').toString(),
      exhibitionId: (json['exhibitionId'] ?? json['exhibition_id'] ?? '').toString(),
      isPoap: (json['isPoap'] ?? json['is_poap'] ?? false) == true,
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'title': title,
      'description': description,
      'iconUrl': iconUrl,
      'rewardKub8': rewardKub8,
      'rarity': rarity,
      'exhibitionId': exhibitionId,
      'isPoap': isPoap,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class ExhibitionPoapStatus {
  final String exhibitionId;
  final String? exhibitionStatus;
  final ExhibitionPoap poap;
  final bool claimed;

  const ExhibitionPoapStatus({
    required this.exhibitionId,
    required this.exhibitionStatus,
    required this.poap,
    required this.claimed,
  });

  factory ExhibitionPoapStatus.fromJson(Map<String, dynamic> json) {
    final poapRaw = json['poap'];
    return ExhibitionPoapStatus(
      exhibitionId: (json['exhibitionId'] ?? json['exhibition_id'] ?? '').toString(),
      exhibitionStatus: (json['exhibitionStatus'] ?? json['exhibition_status'])?.toString(),
      poap: poapRaw is Map<String, dynamic> ? ExhibitionPoap.fromJson(poapRaw) : ExhibitionPoap.fromJson(const {}),
      claimed: json['claimed'] == true,
    );
  }
}
