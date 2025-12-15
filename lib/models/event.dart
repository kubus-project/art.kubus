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
    );
  }
}
