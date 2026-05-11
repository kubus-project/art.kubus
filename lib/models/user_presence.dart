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

enum PresenceSource {
  unknown,
  cache,
  api,
  socket,
  localOptimistic,
}

class UserPresenceEntry {
  static const Duration freshOnlineWindow = Duration(seconds: 60);

  final String walletAddress;
  final bool exists;
  final bool visible;
  final bool? isOnline;
  final DateTime? lastSeenAt;
  final DateTime? observedAt;
  final PresenceSource source;
  final UserPresenceLastVisited? lastVisited;
  final String? lastVisitedTitle;

  const UserPresenceEntry({
    required this.walletAddress,
    required this.exists,
    required this.visible,
    required this.isOnline,
    required this.lastSeenAt,
    this.observedAt,
    this.source = PresenceSource.unknown,
    required this.lastVisited,
    required this.lastVisitedTitle,
  });

  factory UserPresenceEntry.fromJson(Map<String, dynamic> json) {
    final lastVisitedRaw = json['lastVisited'] ?? json['last_visited'];
    final lastVisited = lastVisitedRaw is Map
        ? UserPresenceLastVisited.fromJson(
            Map<String, dynamic>.from(lastVisitedRaw))
        : null;

    return UserPresenceEntry(
      walletAddress:
          (json['walletAddress'] ?? json['wallet_address'] ?? '').toString(),
      exists: json['exists'] == true,
      visible: json['visible'] == true,
      isOnline: _parseBoolNullable(json['isOnline'] ?? json['is_online']),
      lastSeenAt: _parseDate(json['lastSeenAt'] ?? json['last_seen_at']),
      observedAt: _parseDate(
            json['observedAt'] ??
                json['observed_at'] ??
                json['updatedAt'] ??
                json['updated_at'],
          ) ??
          _parseDate(json['lastSeenAt'] ?? json['last_seen_at']),
      source: _parsePresenceSource(json['source']) ?? PresenceSource.api,
      lastVisited: lastVisited,
      lastVisitedTitle:
          (json['lastVisitedTitle'] ?? json['last_visited_title'])?.toString(),
    );
  }

  bool isFreshOnline({
    DateTime? now,
    Duration maxAge = freshOnlineWindow,
  }) {
    if (!visible) return false;
    if (isOnline != true) return false;

    final reference = observedAt ?? lastSeenAt;
    if (reference == null) return false;

    final current = now ?? DateTime.now();
    if (reference.isAfter(current.add(const Duration(seconds: 5)))) {
      return true;
    }
    return current.difference(reference) <= maxAge;
  }

  bool isNewerThan(UserPresenceEntry other) {
    final mine = observedAt ?? lastSeenAt;
    final theirs = other.observedAt ?? other.lastSeenAt;
    if (mine == null) return false;
    if (theirs == null) return true;
    return mine.isAfter(theirs);
  }

  UserPresenceEntry mergeFreshnessAware(UserPresenceEntry next) {
    if (next.source == PresenceSource.unknown &&
        source != PresenceSource.unknown) {
      return this;
    }

    final nextIsLocalOrSocket = next.source == PresenceSource.localOptimistic ||
        next.source == PresenceSource.socket;
    final currentIsLocalOrSocket = source == PresenceSource.localOptimistic ||
        source == PresenceSource.socket;

    if (currentIsLocalOrSocket &&
        !nextIsLocalOrSocket &&
        !next.isNewerThan(this)) {
      return this;
    }

    if (!next.isNewerThan(this)) {
      final mine = observedAt ?? lastSeenAt;
      final theirs = next.observedAt ?? next.lastSeenAt;
      if (mine != null && theirs != null && theirs.isBefore(mine)) {
        return this;
      }
    }

    return next;
  }

  UserPresenceEntry copyWith({
    String? walletAddress,
    bool? exists,
    bool? visible,
    bool? isOnline,
    DateTime? lastSeenAt,
    DateTime? observedAt,
    PresenceSource? source,
    UserPresenceLastVisited? lastVisited,
    String? lastVisitedTitle,
  }) {
    return UserPresenceEntry(
      walletAddress: walletAddress ?? this.walletAddress,
      exists: exists ?? this.exists,
      visible: visible ?? this.visible,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      observedAt: observedAt ?? this.observedAt,
      source: source ?? this.source,
      lastVisited: lastVisited ?? this.lastVisited,
      lastVisitedTitle: lastVisitedTitle ?? this.lastVisitedTitle,
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
        other.observedAt == observedAt &&
        other.source == source &&
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
        observedAt,
        source,
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

PresenceSource? _parsePresenceSource(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  for (final source in PresenceSource.values) {
    if (source.name == raw) return source;
  }
  final normalized = raw.toLowerCase();
  for (final source in PresenceSource.values) {
    if (source.name.toLowerCase() == normalized) return source;
  }
  return null;
}
