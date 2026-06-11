class UserSummaryDto {
  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? walletAddress;

  const UserSummaryDto({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.walletAddress,
  });

  factory UserSummaryDto.fromJson(Map<String, dynamic> json) {
    return UserSummaryDto(
      id: (json['id'] ?? json['userId'] ?? json['user_id'] ?? '').toString(),
      username: json['username']?.toString(),
      displayName: (json['displayName'] ?? json['display_name'])?.toString(),
      avatarUrl: (json['avatarUrl'] ?? json['avatar_url'] ?? json['avatar'])?.toString(),
      walletAddress: (json['walletAddress'] ?? json['wallet_address'] ?? json['wallet'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'walletAddress': walletAddress,
    };
  }
}

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

class KubusEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? locationName;
  final String? city;
  final String? country;
  final double? lat;
  final double? lng;
  final String? coverUrl;
  final String? status; // draft|published (server-defined)
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? myRole; // viewer|editor|publisher|admin|owner (server-defined)
  final UserSummaryDto? host;

  /// Program relation context, present when this event was loaded through an
  /// exhibition program (opening|artist_talk|guided_tour|workshop|...).
  final String? relationType;
  final int sortOrder;

  const KubusEvent({
    required this.id,
    required this.title,
    this.description,
    this.startsAt,
    this.endsAt,
    this.locationName,
    this.city,
    this.country,
    this.lat,
    this.lng,
    this.coverUrl,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.myRole,
    this.host,
    this.relationType,
    this.sortOrder = 0,
  });

  bool get isPublished => (status ?? '').toLowerCase() == 'published';

  factory KubusEvent.fromJson(Map<String, dynamic> json) {
    final hostRaw = json['host'];
    return KubusEvent(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      startsAt: _parseDateTime(json['startsAt'] ?? json['starts_at'] ?? json['startDate'] ?? json['start_date']),
      endsAt: _parseDateTime(json['endsAt'] ?? json['ends_at'] ?? json['endDate'] ?? json['end_date']),
      locationName: (json['locationName'] ?? json['location_name'] ?? json['location'])?.toString(),
      city: json['city']?.toString(),
      country: json['country']?.toString(),
      lat: (_toNum(json['lat'] ?? json['latitude']))?.toDouble(),
      lng: (_toNum(json['lng'] ?? json['longitude']))?.toDouble(),
      coverUrl: (json['coverUrl'] ?? json['cover_url'])?.toString(),
      status: json['status']?.toString(),
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at']),
      myRole: (json['myRole'] ?? json['my_role'])?.toString(),
      host: hostRaw is Map<String, dynamic> ? UserSummaryDto.fromJson(hostRaw) : null,
      relationType: (json['relationType'] ?? json['relation_type'])?.toString(),
      sortOrder: (_toNum(json['sortOrder'] ?? json['sort_order']))?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startsAt': startsAt?.toIso8601String(),
      'endsAt': endsAt?.toIso8601String(),
      'locationName': locationName,
      'city': city,
      'country': country,
      'lat': lat,
      'lng': lng,
      'coverUrl': coverUrl,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'myRole': myRole,
      'host': host?.toJson(),
      if (relationType != null) 'relationType': relationType,
      'sortOrder': sortOrder,
    };
  }

  KubusEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startsAt,
    DateTime? endsAt,
    String? locationName,
    String? city,
    String? country,
    double? lat,
    double? lng,
    String? coverUrl,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? myRole,
    UserSummaryDto? host,
    String? relationType,
    int? sortOrder,
  }) {
    return KubusEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      locationName: locationName ?? this.locationName,
      city: city ?? this.city,
      country: country ?? this.country,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      coverUrl: coverUrl ?? this.coverUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      myRole: myRole ?? this.myRole,
      host: host ?? this.host,
      relationType: relationType ?? this.relationType,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// First-class POAP badge owned by an event (mirrors the exhibition POAP
/// payload returned by `GET /api/events/:id/poap`).
class EventPoap {
  final String id;
  final String code;
  final String title;
  final String? description;
  final String? iconUrl;
  final int rewardKub8;
  final String rarity;
  final String eventId;
  final String? proofType; // marker_attendance | scan_proof
  final bool isPoap;
  final DateTime? createdAt;

  const EventPoap({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    this.iconUrl,
    required this.rewardKub8,
    required this.rarity,
    required this.eventId,
    this.proofType,
    required this.isPoap,
    this.createdAt,
  });

  factory EventPoap.fromJson(Map<String, dynamic> json, {String? eventId}) {
    final rewardRaw = json['rewardKub8'] ?? json['reward_kub8'] ?? 0;
    return EventPoap(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      iconUrl: (json['iconUrl'] ?? json['icon_url'] ?? json['icon'])?.toString(),
      rewardKub8: rewardRaw is num
          ? rewardRaw.toInt()
          : int.tryParse(rewardRaw.toString()) ?? 0,
      rarity: (json['rarity'] ?? 'common').toString(),
      eventId: (eventId ??
              json['subjectId'] ??
              json['subject_id'] ??
              json['eventId'] ??
              json['event_id'] ??
              '')
          .toString(),
      proofType: (json['proofType'] ?? json['proof_type'])?.toString(),
      isPoap: (json['isPoap'] ?? json['is_poap'] ?? false) == true,
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
    );
  }
}

class EventPoapStatus {
  final String eventId;
  final String? eventStatus;
  final EventPoap poap;
  final bool claimed;
  final String? eligibilityState;
  final String? eligibilityReason;
  final bool canClaim;
  final String? proofType;
  final int linkedMarkerCount;
  final String? latestAttendanceMarkerId;
  final DateTime? latestAttendanceAt;
  final int unlockedAchievementsCount;
  final double? totalKub8Earned;

  const EventPoapStatus({
    required this.eventId,
    required this.eventStatus,
    required this.poap,
    required this.claimed,
    this.eligibilityState,
    this.eligibilityReason,
    this.canClaim = false,
    this.proofType,
    this.linkedMarkerCount = 0,
    this.latestAttendanceMarkerId,
    this.latestAttendanceAt,
    this.unlockedAchievementsCount = 0,
    this.totalKub8Earned,
  });

  factory EventPoapStatus.fromJson(Map<String, dynamic> json) {
    final poapRaw = json['poap'];
    final eligibilityRaw = json['eligibility'];
    final eligibility = eligibilityRaw is Map<String, dynamic>
        ? eligibilityRaw
        : (eligibilityRaw is Map
            ? Map<String, dynamic>.from(eligibilityRaw)
            : null);
    final latestAttendanceRaw = eligibility?['latestAttendance'];
    final latestAttendance = latestAttendanceRaw is Map<String, dynamic>
        ? latestAttendanceRaw
        : (latestAttendanceRaw is Map
            ? Map<String, dynamic>.from(latestAttendanceRaw)
            : null);
    final achievementRaw = json['achievement'];
    final achievement = achievementRaw is Map<String, dynamic>
        ? achievementRaw
        : (achievementRaw is Map
            ? Map<String, dynamic>.from(achievementRaw)
            : null);
    final unlockedRaw = achievement?['unlocked'];
    final markerCountRaw = eligibility?['linkedMarkerCount'] ??
        eligibility?['linked_marker_count'] ??
        0;

    final eventId =
        (json['eventId'] ?? json['event_id'] ?? '').toString();
    return EventPoapStatus(
      eventId: eventId,
      eventStatus: (json['eventStatus'] ?? json['event_status'])?.toString(),
      poap: poapRaw is Map<String, dynamic>
          ? EventPoap.fromJson(poapRaw, eventId: eventId)
          : EventPoap.fromJson(const {}, eventId: eventId),
      claimed: json['claimed'] == true,
      eligibilityState:
          (eligibility?['state'] ?? eligibility?['eligibilityState'])?.toString(),
      eligibilityReason:
          (eligibility?['reason'] ?? eligibility?['eligibilityReason'])?.toString(),
      canClaim: (eligibility?['canClaim'] == true) ||
          (eligibility?['can_claim'] == true),
      proofType:
          (eligibility?['proofType'] ?? eligibility?['proof_type'])?.toString(),
      linkedMarkerCount: markerCountRaw is num
          ? markerCountRaw.toInt()
          : int.tryParse(markerCountRaw.toString()) ?? 0,
      latestAttendanceMarkerId:
          (latestAttendance?['markerId'] ?? latestAttendance?['marker_id'])
              ?.toString(),
      latestAttendanceAt: _parseDateTime(
          latestAttendance?['attendedAt'] ?? latestAttendance?['attended_at']),
      unlockedAchievementsCount: unlockedRaw is List ? unlockedRaw.length : 0,
      totalKub8Earned:
          (_toNum(achievement?['totalKub8Earned']))?.toDouble(),
    );
  }
}
