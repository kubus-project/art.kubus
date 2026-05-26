import '../community/community_interactions.dart';
import 'achievement_progress.dart';
import 'achievements.dart' as backend;
import 'user.dart';

class ProfileCriticalPackage {
  const ProfileCriticalPackage({
    required this.user,
    required this.achievementProgress,
    required this.achievementDefinitions,
    required this.publicStats,
    required this.fetchedAt,
    required this.isComplete,
    this.achievementsUnavailable = false,
  });

  final User user;
  final List<AchievementProgress> achievementProgress;
  final List<backend.AchievementDefinition> achievementDefinitions;
  final Map<String, int> publicStats;
  final DateTime fetchedAt;
  final bool isComplete;
  final bool achievementsUnavailable;

  bool get hasAchievementDefinitions => achievementDefinitions.isNotEmpty;

  bool get hasAchievementProgress => achievementProgress.isNotEmpty;

  bool isFresh(Duration ttl) => DateTime.now().difference(fetchedAt) <= ttl;

  ProfileCriticalPackage copyWith({
    User? user,
    List<AchievementProgress>? achievementProgress,
    List<backend.AchievementDefinition>? achievementDefinitions,
    Map<String, int>? publicStats,
    DateTime? fetchedAt,
    bool? isComplete,
    bool? achievementsUnavailable,
  }) {
    final resolvedProgress = achievementProgress ?? this.achievementProgress;
    final resolvedDefinitions =
        achievementDefinitions ?? this.achievementDefinitions;
    final resolvedUser = (user ?? this.user).copyWith(
      achievementProgress: resolvedProgress,
      achievementDefinitions: resolvedDefinitions,
    );

    return ProfileCriticalPackage(
      user: resolvedUser,
      achievementProgress: resolvedProgress,
      achievementDefinitions: resolvedDefinitions,
      publicStats: publicStats ?? this.publicStats,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      isComplete: isComplete ?? this.isComplete,
      achievementsUnavailable:
          achievementsUnavailable ?? this.achievementsUnavailable,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user': _ProfilePackageJson.userToJson(user),
      'achievementProgress':
          achievementProgress.map(_ProfilePackageJson.progressToJson).toList(
                growable: false,
              ),
      'achievementDefinitions': achievementDefinitions
          .map(_ProfilePackageJson.definitionToJson)
          .toList(
            growable: false,
          ),
      'publicStats': publicStats,
      'fetchedAt': fetchedAt.toIso8601String(),
      'isComplete': isComplete,
      'achievementsUnavailable': achievementsUnavailable,
    };
  }

  factory ProfileCriticalPackage.fromJson(Map<String, dynamic> json) {
    final user = _ProfilePackageJson.userFromJson(
      _ProfilePackageJson.mapFrom(json['user']),
    );
    final progress = _ProfilePackageJson.listOfMaps(json['achievementProgress'])
        .map(_ProfilePackageJson.progressFromJson)
        .toList(growable: false);
    final definitions =
        _ProfilePackageJson.listOfMaps(json['achievementDefinitions'])
            .map(backend.AchievementDefinition.fromJson)
            .where((definition) => definition.code.trim().isNotEmpty)
            .toList(growable: false);

    return ProfileCriticalPackage(
      user: user.copyWith(
        achievementProgress: progress,
        achievementDefinitions: definitions,
      ),
      achievementProgress: progress,
      achievementDefinitions: definitions,
      publicStats: _ProfilePackageJson.intMap(json['publicStats']),
      fetchedAt: DateTime.tryParse(json['fetchedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isComplete: json['isComplete'] == true,
      achievementsUnavailable: json['achievementsUnavailable'] == true,
    );
  }
}

class ProfileExtendedPackage {
  const ProfileExtendedPackage({
    this.initialPosts,
    this.artistArtworks = const <Map<String, dynamic>>[],
    this.artistCollections = const <Map<String, dynamic>>[],
    this.artistEvents = const <Map<String, dynamic>>[],
    required this.fetchedAt,
  });

  final List<CommunityPost>? initialPosts;
  final List<Map<String, dynamic>> artistArtworks;
  final List<Map<String, dynamic>> artistCollections;
  final List<Map<String, dynamic>> artistEvents;
  final DateTime fetchedAt;

  bool get hasPosts => initialPosts != null;

  ProfileExtendedPackage copyWith({
    List<CommunityPost>? initialPosts,
    List<Map<String, dynamic>>? artistArtworks,
    List<Map<String, dynamic>>? artistCollections,
    List<Map<String, dynamic>>? artistEvents,
    DateTime? fetchedAt,
  }) {
    return ProfileExtendedPackage(
      initialPosts: initialPosts ?? this.initialPosts,
      artistArtworks: artistArtworks ?? this.artistArtworks,
      artistCollections: artistCollections ?? this.artistCollections,
      artistEvents: artistEvents ?? this.artistEvents,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'artistArtworks': artistArtworks,
      'artistCollections': artistCollections,
      'artistEvents': artistEvents,
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }

  factory ProfileExtendedPackage.fromJson(Map<String, dynamic> json) {
    return ProfileExtendedPackage(
      artistArtworks: _ProfilePackageJson.listOfMaps(json['artistArtworks']),
      artistCollections:
          _ProfilePackageJson.listOfMaps(json['artistCollections']),
      artistEvents: _ProfilePackageJson.listOfMaps(json['artistEvents']),
      fetchedAt: DateTime.tryParse(json['fetchedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ProfilePackage {
  ProfilePackage({
    ProfileCriticalPackage? critical,
    this.extended,
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
    bool achievementsUnavailable = false,
  }) : critical = critical ??
            ProfileCriticalPackage(
              user: user!,
              achievementProgress:
                  achievementProgress ?? user.achievementProgress,
              achievementDefinitions:
                  achievementDefinitions ?? user.achievementDefinitions,
              publicStats: publicStats ?? const <String, int>{},
              fetchedAt: fetchedAt ?? DateTime.now(),
              isComplete: isComplete ?? false,
              achievementsUnavailable: achievementsUnavailable,
            ) {
    if (critical == null &&
        (initialPosts != null ||
            artistArtworks != null ||
            artistCollections != null ||
            artistEvents != null)) {
      extended = ProfileExtendedPackage(
        initialPosts: initialPosts,
        artistArtworks: artistArtworks ?? const <Map<String, dynamic>>[],
        artistCollections: artistCollections ?? const <Map<String, dynamic>>[],
        artistEvents: artistEvents ?? const <Map<String, dynamic>>[],
        fetchedAt: fetchedAt ?? DateTime.now(),
      );
    }
  }

  ProfilePackage.fromParts({
    required this.critical,
    this.extended,
  });

  final ProfileCriticalPackage critical;
  ProfileExtendedPackage? extended;

  User get user => critical.user;
  List<AchievementProgress> get achievementProgress =>
      critical.achievementProgress;
  List<backend.AchievementDefinition> get achievementDefinitions =>
      critical.achievementDefinitions;
  Map<String, int> get publicStats => critical.publicStats;
  List<CommunityPost>? get initialPosts => extended?.initialPosts;
  List<Map<String, dynamic>> get artistArtworks =>
      extended?.artistArtworks ?? const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> get artistCollections =>
      extended?.artistCollections ?? const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> get artistEvents =>
      extended?.artistEvents ?? const <Map<String, dynamic>>[];
  DateTime get fetchedAt => critical.fetchedAt;
  bool get isComplete => critical.isComplete;
  bool get achievementsUnavailable => critical.achievementsUnavailable;
  bool get hasAchievementDefinitions => critical.hasAchievementDefinitions;
  bool get hasAchievementProgress => critical.hasAchievementProgress;
  bool isFresh(Duration ttl) => critical.isFresh(ttl);

  ProfilePackage copyWith({
    ProfileCriticalPackage? critical,
    ProfileExtendedPackage? extended,
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
    final nextCritical = (critical ?? this.critical).copyWith(
      user: user,
      achievementProgress: achievementProgress,
      achievementDefinitions: achievementDefinitions,
      publicStats: publicStats,
      fetchedAt: fetchedAt,
      isComplete: isComplete,
      achievementsUnavailable: achievementsUnavailable,
    );
    final hasExtendedPatch = initialPosts != null ||
        artistArtworks != null ||
        artistCollections != null ||
        artistEvents != null;
    final currentExtended = extended ?? this.extended;
    final nextExtended = hasExtendedPatch
        ? (currentExtended ??
                ProfileExtendedPackage(
                  fetchedAt: fetchedAt ?? DateTime.now(),
                ))
            .copyWith(
            initialPosts: initialPosts,
            artistArtworks: artistArtworks,
            artistCollections: artistCollections,
            artistEvents: artistEvents,
            fetchedAt: fetchedAt,
          )
        : currentExtended;

    return ProfilePackage.fromParts(
      critical: nextCritical,
      extended: nextExtended,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'critical': critical.toJson(),
      if (extended != null) 'extended': extended!.toJson(),
    };
  }

  factory ProfilePackage.fromJson(Map<String, dynamic> json) {
    final criticalPayload = json['critical'];
    if (criticalPayload is Map) {
      return ProfilePackage.fromParts(
        critical: ProfileCriticalPackage.fromJson(
          Map<String, dynamic>.from(criticalPayload),
        ),
        extended: json['extended'] is Map
            ? ProfileExtendedPackage.fromJson(
                Map<String, dynamic>.from(json['extended'] as Map),
              )
            : null,
      );
    }

    final legacyCritical = ProfileCriticalPackage.fromJson(json);
    return ProfilePackage.fromParts(
      critical: legacyCritical,
      extended: ProfileExtendedPackage.fromJson(json),
    );
  }
}

class _ProfilePackageJson {
  static Map<String, dynamic> userToJson(User user) {
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

  static User userFromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown artist',
      username: json['username']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      profileImageUrl: stringOrNull(json['profileImageUrl']),
      coverImageUrl: stringOrNull(json['coverImageUrl']),
      fieldOfWork: (json['fieldOfWork'] is List)
          ? (json['fieldOfWork'] as List)
              .map((value) => value.toString())
              .where((value) => value.trim().isNotEmpty)
              .toList(growable: false)
          : const <String>[],
      yearsActive: intValue(json['yearsActive']),
      followersCount: intValue(json['followersCount']),
      followingCount: intValue(json['followingCount']),
      postsCount: intValue(json['postsCount']),
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

  static Map<String, dynamic> progressToJson(AchievementProgress progress) {
    return <String, dynamic>{
      'achievementId': progress.achievementId,
      'currentProgress': progress.currentProgress,
      'isCompleted': progress.isCompleted,
      'completedDate': progress.completedDate?.toIso8601String(),
    };
  }

  static AchievementProgress progressFromJson(Map<String, dynamic> json) {
    return AchievementProgress(
      achievementId: json['achievementId']?.toString() ?? '',
      currentProgress: intValue(json['currentProgress']),
      isCompleted: json['isCompleted'] == true,
      completedDate: DateTime.tryParse(json['completedDate']?.toString() ?? ''),
    );
  }

  static Map<String, dynamic> definitionToJson(
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

  static Map<String, dynamic> mapFrom(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> listOfMaps(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Map<String, int> intMap(dynamic raw) {
    if (raw is! Map) return const <String, int>{};
    return raw.map((key, value) => MapEntry(key.toString(), intValue(value)));
  }

  static int intValue(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static String? stringOrNull(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
