import 'achievement_progress.dart';

class User {
  final String id;
  final String name;
  final String username;
  final String bio;
  final String? profileImageUrl;
  final String? coverImageUrl;
  /// Artist profile: field(s) of work (aka specialty/categories).
  ///
  /// Kept as plain strings (no UI concern).
  final List<String> fieldOfWork;
  /// Artist profile: years active (0 when unset).
  final int yearsActive;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final bool isFollowing;
  final bool isVerified;
  final bool isArtist;
  final bool isInstitution;
  final String joinedDate;
  final List<AchievementProgress> achievementProgress;

  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.bio,
    this.profileImageUrl,
    this.coverImageUrl,
    this.fieldOfWork = const <String>[],
    this.yearsActive = 0,
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.isFollowing,
    required this.isVerified,
    this.isArtist = false,
    this.isInstitution = false,
    required this.joinedDate,
    this.achievementProgress = const [],
  });

  User copyWith({
    String? id,
    String? name,
    String? username,
    String? bio,
    String? profileImageUrl,
    String? coverImageUrl,
    List<String>? fieldOfWork,
    int? yearsActive,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    bool? isFollowing,
    bool? isVerified,
    bool? isArtist,
    bool? isInstitution,
    String? joinedDate,
    List<AchievementProgress>? achievementProgress,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      fieldOfWork: fieldOfWork ?? this.fieldOfWork,
      yearsActive: yearsActive ?? this.yearsActive,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isVerified: isVerified ?? this.isVerified,
      isArtist: isArtist ?? this.isArtist,
      isInstitution: isInstitution ?? this.isInstitution,
      joinedDate: joinedDate ?? this.joinedDate,
      achievementProgress: achievementProgress ?? this.achievementProgress,
    );
  }
}
