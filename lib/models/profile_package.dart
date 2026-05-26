import '../community/community_interactions.dart';
import 'achievement_progress.dart';
import 'achievements.dart' as backend;
import 'user.dart';

class ProfilePackage {
  const ProfilePackage({
    required this.user,
    required this.achievementProgress,
    required this.achievementDefinitions,
    required this.publicStats,
    this.initialPosts,
    this.artistArtworks = const <Map<String, dynamic>>[],
    this.artistCollections = const <Map<String, dynamic>>[],
    this.artistEvents = const <Map<String, dynamic>>[],
    required this.fetchedAt,
    required this.isComplete,
    this.achievementsUnavailable = false,
  });

  final User user;
  final List<AchievementProgress> achievementProgress;
  final List<backend.AchievementDefinition> achievementDefinitions;
  final Map<String, int> publicStats;
  final List<CommunityPost>? initialPosts;
  final List<Map<String, dynamic>> artistArtworks;
  final List<Map<String, dynamic>> artistCollections;
  final List<Map<String, dynamic>> artistEvents;
  final DateTime fetchedAt;
  final bool isComplete;
  final bool achievementsUnavailable;

  bool get hasAchievementDefinitions => achievementDefinitions.isNotEmpty;

  bool get hasAchievementProgress => achievementProgress.isNotEmpty;

  bool isFresh(Duration ttl) => DateTime.now().difference(fetchedAt) <= ttl;

  ProfilePackage copyWith({
    User? user,
    List<AchievementProgress>? achievementProgress,
    List<backend.AchievementDefinition>? achievementDefinitions,
    Map<String, int>? publicStats,
    List<CommunityPost>? initialPosts,
    List<Map<String, dynamic>>? artistArtworks,
    List<Map<String, dynamic>>? artistCollections,
    List<Map<String, dynamic>>? artistEvents,
    DateTime? fetchedAt,
    bool? isComplete,
    bool? achievementsUnavailable,
  }) {
    return ProfilePackage(
      user: user ?? this.user,
      achievementProgress: achievementProgress ?? this.achievementProgress,
      achievementDefinitions:
          achievementDefinitions ?? this.achievementDefinitions,
      publicStats: publicStats ?? this.publicStats,
      initialPosts: initialPosts ?? this.initialPosts,
      artistArtworks: artistArtworks ?? this.artistArtworks,
      artistCollections: artistCollections ?? this.artistCollections,
      artistEvents: artistEvents ?? this.artistEvents,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      isComplete: isComplete ?? this.isComplete,
      achievementsUnavailable:
          achievementsUnavailable ?? this.achievementsUnavailable,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user': _userToJson(user),
      'achievementProgress':
          achievementProgress.map(_progressToJson).toList(growable: false),
      'achievementDefinitions':
          achievementDefinitions.map(_definitionToJson).toList(growable: false),
      'publicStats': publicStats,
      'artistArtworks': artistArtworks,
      'artistCollections': artistCollections,
      'artistEvents': artistEvents,
      'fetchedAt': fetchedAt.toIso8601String(),
      'isComplete': isComplete,
      'achievementsUnavailable': achievementsUnavailable,
    };
  }

  factory ProfilePackage.fromJson(Map<String, dynamic> json) {
    final user = _userFromJson(_mapFrom(json['user']));
    final progress = _listOfMaps(json['achievementProgress'])
        .map(_progressFromJson)
        .toList(growable: false);
    final definitions = _listOfMaps(json['achievementDefinitions'])
        .map(backend.AchievementDefinition.fromJson)
        .where((definition) => definition.code.trim().isNotEmpty)
        .toList(growable: false);
    return ProfilePackage(
      user: user.copyWith(
        achievementProgress: progress,
        achievementDefinitions: definitions,
      ),
      achievementProgress: progress,
      achievementDefinitions: definitions,
      publicStats: _intMap(json['publicStats']),
      artistArtworks: _listOfMaps(json['artistArtworks']),
      artistCollections: _listOfMaps(json['artistCollections']),
      artistEvents: _listOfMaps(json['artistEvents']),
      fetchedAt: DateTime.tryParse(json['fetchedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isComplete: json['isComplete'] == true,
      achievementsUnavailable: json['achievementsUnavailable'] == true,
    );
  }

  static Map<String, dynamic> _userToJson(User user) {
    return <String, dynamic>{
      'id': user.id,
      'name': user.name,
      'username': user.username,
      'bio': user.bio,
      'profileImageUrl': user.profileImageUrl,
      'coverImageUrl': user.coverImageUrl,
      'fieldOfWork': user.fieldOfWork,
      'yearsActive': user.yearsActive,
      'followersCount': user.followersCount,
      'followingCount': user.followingCount,
      'postsCount': user.postsCount,
      'isFollowing': user.isFollowing,
      'isVerified': user.isVerified,
      'isArtist': user.isArtist,
      'isInstitution': user.isInstitution,
      'showAchievements': user.showAchievements,
      'joinedDate': user.joinedDate,
    };
  }

  static User _userFromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown artist',
      username: json['username']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      profileImageUrl: _stringOrNull(json['profileImageUrl']),
      coverImageUrl: _stringOrNull(json['coverImageUrl']),
      fieldOfWork: (json['fieldOfWork'] is List)
          ? (json['fieldOfWork'] as List)
              .map((value) => value.toString())
              .where((value) => value.trim().isNotEmpty)
              .toList(growable: false)
          : const <String>[],
      yearsActive: _intValue(json['yearsActive']),
      followersCount: _intValue(json['followersCount']),
      followingCount: _intValue(json['followingCount']),
      postsCount: _intValue(json['postsCount']),
      isFollowing: json['isFollowing'] == true,
      isVerified: json['isVerified'] == true,
      isArtist: json['isArtist'] == true,
      isInstitution: json['isInstitution'] == true,
      showAchievements: json['showAchievements'] is bool
          ? json['showAchievements'] as bool
          : true,
      joinedDate: json['joinedDate']?.toString() ?? 'Joined recently',
    );
  }

  static Map<String, dynamic> _progressToJson(AchievementProgress progress) {
    return <String, dynamic>{
      'achievementId': progress.achievementId,
      'currentProgress': progress.currentProgress,
      'isCompleted': progress.isCompleted,
      'completedDate': progress.completedDate?.toIso8601String(),
    };
  }

  static AchievementProgress _progressFromJson(Map<String, dynamic> json) {
    return AchievementProgress(
      achievementId: json['achievementId']?.toString() ?? '',
      currentProgress: _intValue(json['currentProgress']),
      isCompleted: json['isCompleted'] == true,
      completedDate: DateTime.tryParse(json['completedDate']?.toString() ?? ''),
    );
  }

  static Map<String, dynamic> _definitionToJson(
    backend.AchievementDefinition definition,
  ) {
    return <String, dynamic>{
      'code': definition.code,
      'title': definition.title,
      'description': definition.description,
      'category': definition.category,
      'rarity': definition.rarity,
      'iconKey': definition.iconKey,
      'isPoap': definition.isPoap,
      'isActive': definition.isActive,
      'seasonId': definition.seasonId,
      'requiredCount': definition.requiredCount,
      'eventType': definition.eventType,
      'metricKey': definition.metricKey,
      'kub8Reward': definition.kub8Reward,
    };
  }

  static Map<String, dynamic> _mapFrom(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _listOfMaps(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Map<String, int> _intMap(dynamic raw) {
    if (raw is! Map) return const <String, int>{};
    return raw.map((key, value) => MapEntry(key.toString(), _intValue(value)));
  }

  static int _intValue(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static String? _stringOrNull(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
