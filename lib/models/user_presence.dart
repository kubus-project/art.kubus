class UserPresenceLastVisited {
  final String type; // artwork | exhibition | collection | event
  final String id;
  final DateTime? visitedAt;
  final DateTime? expiresAt;

  const UserPresenceLastVisited({
    required this.type,
    required this.id,
    this.visitedAt,
    this.expiresAt,
  });

  bool get isExpired {
    final exp = expiresAt;
    if (exp == null) return false;
    return exp.isBefore(DateTime.now());
  }

  factory UserPresenceLastVisited.fromJson(Map<String, dynamic> json) {
    return UserPresenceLastVisited(
      type: (json['type'] ?? '').toString(),
      id: (json['id'] ?? '').toString(),
      visitedAt: _parseDate(json['visitedAt'] ?? json['visited_at']),
      expiresAt: _parseDate(json['expiresAt'] ?? json['expires_at']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPresenceLastVisited &&
        other.type == type &&
        other.id == id &&
        other.visitedAt == visitedAt &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => Object.hash(type, id, visitedAt, expiresAt);
}

class UserPresenceEntry {
  final String walletAddress;
  final bool exists;
  final bool visible;
  final bool? isOnline;
  final DateTime? lastSeenAt;
  final UserPresenceLastVisited? lastVisited;
  final String? lastVisitedTitle;

  const UserPresenceEntry({
    required this.walletAddress,
    required this.exists,
    required this.visible,
    required this.isOnline,
    required this.lastSeenAt,
    required this.lastVisited,
    required this.lastVisitedTitle,
  });

  factory UserPresenceEntry.fromJson(Map<String, dynamic> json) {
    final lastVisitedRaw = json['lastVisited'] ?? json['last_visited'];
    final lastVisited = lastVisitedRaw is Map
        ? UserPresenceLastVisited.fromJson(Map<String, dynamic>.from(lastVisitedRaw))
        : null;

    return UserPresenceEntry(
      walletAddress: (json['walletAddress'] ?? json['wallet_address'] ?? '').toString(),
      exists: json['exists'] == true,
      visible: json['visible'] == true,
      isOnline: _parseBoolNullable(json['isOnline'] ?? json['is_online']),
      lastSeenAt: _parseDate(json['lastSeenAt'] ?? json['last_seen_at']),
      lastVisited: lastVisited,
      lastVisitedTitle: (json['lastVisitedTitle'] ?? json['last_visited_title'])?.toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPresenceEntry &&
        other.walletAddress == walletAddress &&
        other.exists == exists &&
        other.visible == visible &&
        other.isOnline == isOnline &&
        other.lastSeenAt == lastSeenAt &&
        other.lastVisited == lastVisited &&
        other.lastVisitedTitle == lastVisitedTitle;
  }

  @override
  int get hashCode => Object.hash(
        walletAddress,
        exists,
        visible,
        isOnline,
        lastSeenAt,
        lastVisited,
        lastVisitedTitle,
      );
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

bool? _parseBoolNullable(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final raw = value.toString().trim().toLowerCase();
  if (raw == 'true' || raw == '1') return true;
  if (raw == 'false' || raw == '0') return false;
  return null;
}
