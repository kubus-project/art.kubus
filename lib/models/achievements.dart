class AchievementDefinition {
  final String code;
  final String title;
  final String description;
  final String category;
  final String rarity;
  final String? iconKey;
  final bool isPoap;
  final bool isActive;
  final String seasonId;
  final int requiredCount;
  final String? eventType;
  final String? metricKey;
  final double kub8Reward;

  const AchievementDefinition({
    required this.code,
    required this.title,
    required this.description,
    required this.category,
    required this.rarity,
    this.iconKey,
    this.isPoap = false,
    this.isActive = true,
    this.seasonId = 'default',
    this.requiredCount = 1,
    this.eventType,
    this.metricKey,
    this.kub8Reward = 0,
  });

  factory AchievementDefinition.fromJson(Map<String, dynamic> json) {
    final rule = json['rule'];
    final ruleMap =
        rule is Map ? Map<String, dynamic>.from(rule) : <String, dynamic>{};
    return AchievementDefinition(
      code: (json['code'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? 'general').toString(),
      rarity: (json['rarity'] ?? 'common').toString(),
      iconKey: (json['iconKey'] ?? json['icon_key'])?.toString(),
      isPoap: _boolValue(json['isPoap'] ?? json['is_poap']),
      isActive: !_hasFalseValue(json['isActive'] ?? json['is_active']),
      seasonId: (json['seasonId'] ?? json['season_id'] ?? 'default').toString(),
      requiredCount: _intValue(
        json['requiredCount'] ??
            json['required_count'] ??
            ruleMap['requiredCount'] ??
            ruleMap['required_count'],
        fallback: 1,
      ),
      eventType: (json['eventType'] ??
              json['event_type'] ??
              ruleMap['eventType'] ??
              ruleMap['event_type'])
          ?.toString(),
      metricKey: (json['metricKey'] ??
              json['metric_key'] ??
              ruleMap['metricKey'] ??
              ruleMap['metric_key'])
          ?.toString(),
      kub8Reward: _doubleValue(
        json['kub8Reward'] ??
            json['kub8_reward'] ??
            json['tokenReward'] ??
            json['token_reward'],
      ),
    );
  }
}

class AchievementProgress {
  final String achievementCode;
  final int currentProgress;
  final int requiredCount;
  final bool isCompleted;
  final DateTime? completedAt;

  const AchievementProgress({
    required this.achievementCode,
    required this.currentProgress,
    required this.requiredCount,
    required this.isCompleted,
    this.completedAt,
  });

  factory AchievementProgress.fromJson(Map<String, dynamic> json) {
    return AchievementProgress(
      achievementCode:
          (json['achievementCode'] ?? json['achievement_code'] ?? json['code'])
              .toString(),
      currentProgress: _intValue(
        json['currentProgress'] ?? json['current_progress'] ?? json['progress'],
      ),
      requiredCount: _intValue(
        json['requiredCount'] ?? json['required_count'],
        fallback: 1,
      ),
      isCompleted: _boolValue(json['isCompleted'] ?? json['is_completed']),
      completedAt:
          _dateValue(json['completedAt'] ?? json['completed_at']),
    );
  }
}

class UserAchievement {
  final String code;
  final String title;
  final String description;
  final String category;
  final String rarity;
  final double kub8Reward;
  final String rewardCurrency;
  final DateTime? unlockedAt;

  const UserAchievement({
    required this.code,
    required this.title,
    required this.description,
    required this.category,
    required this.rarity,
    required this.kub8Reward,
    this.rewardCurrency = 'KUB8',
    this.unlockedAt,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    return UserAchievement(
      code: (json['code'] ?? json['achievementCode'] ?? json['achievement_code'])
          .toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? 'general').toString(),
      rarity: (json['rarity'] ?? 'common').toString(),
      kub8Reward: _doubleValue(
        json['kub8Reward'] ?? json['kub8_reward'] ?? json['reward_amount'],
      ),
      rewardCurrency:
          (json['rewardCurrency'] ?? json['reward_currency'] ?? 'KUB8')
              .toString(),
      unlockedAt: _dateValue(json['unlockedAt'] ?? json['unlocked_at']),
    );
  }
}

class AchievementEventResult {
  final List<AchievementProgress> progress;
  final List<UserAchievement> unlocked;
  final double totalKub8Earned;
  final bool duplicate;

  const AchievementEventResult({
    this.progress = const <AchievementProgress>[],
    this.unlocked = const <UserAchievement>[],
    this.totalKub8Earned = 0,
    this.duplicate = false,
  });

  bool get hasUnlocks => unlocked.isNotEmpty;

  factory AchievementEventResult.fromJson(Map<String, dynamic> json) {
    final payload = json['achievements'] is Map
        ? Map<String, dynamic>.from(json['achievements'] as Map)
        : json;
    return AchievementEventResult(
      progress: _listOfMaps(payload['progress'])
          .map(AchievementProgress.fromJson)
          .toList(growable: false),
      unlocked: _listOfMaps(payload['unlocked'])
          .map(UserAchievement.fromJson)
          .toList(growable: false),
      totalKub8Earned: _doubleValue(
        payload['totalKub8Earned'] ?? payload['total_kub8_earned'],
      ),
      duplicate: _boolValue(payload['duplicate']),
    );
  }
}

class UserAchievementsSummary {
  final List<AchievementDefinition> definitions;
  final List<AchievementProgress> progress;
  final List<UserAchievement> unlocked;
  final double totalKub8Earned;

  const UserAchievementsSummary({
    this.definitions = const <AchievementDefinition>[],
    this.progress = const <AchievementProgress>[],
    this.unlocked = const <UserAchievement>[],
    this.totalKub8Earned = 0,
  });

  factory UserAchievementsSummary.fromJson(Map<String, dynamic> json) {
    return UserAchievementsSummary(
      definitions: _listOfMaps(json['definitions'] ?? json['achievements'])
          .map(AchievementDefinition.fromJson)
          .toList(growable: false),
      progress: _listOfMaps(json['progress'])
          .map(AchievementProgress.fromJson)
          .toList(growable: false),
      unlocked: _listOfMaps(json['unlocked'])
          .map(UserAchievement.fromJson)
          .toList(growable: false),
      totalKub8Earned: _doubleValue(
        json['totalKub8Earned'] ??
            json['total_kub8_earned'] ??
            json['totalTokens'] ??
            json['total_tokens'],
      ),
    );
  }
}

List<Map<String, dynamic>> _listOfMaps(dynamic raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

bool _boolValue(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final value = raw?.toString().trim().toLowerCase();
  return value == 'true' || value == '1' || value == 'yes';
}

bool _hasFalseValue(dynamic raw) {
  if (raw is bool) return raw == false;
  if (raw is num) return raw == 0;
  final value = raw?.toString().trim().toLowerCase();
  return value == 'false' || value == '0' || value == 'no';
}

int _intValue(dynamic raw, {int fallback = 0}) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

double _doubleValue(dynamic raw) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0;
}

DateTime? _dateValue(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}
