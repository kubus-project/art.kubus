import 'achievement_progress.dart';
import 'achievements.dart' as backend_achievements;
import 'profile_identity_data.dart' show ProfileIdentityRoles;

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

  /// Whether each role value was stated by a source (true, or an explicit
  /// false). An unstated value, from a partial conversation or search payload
  /// or a synthetic fallback record, must not revoke a role already known from
  /// a fuller source. A true value is always a statement, see [roleStatements].
  final bool isArtistSpecified;
  final bool isInstitutionSpecified;
  final bool isVerifiedSpecified;
  final bool showAchievements;
  final String joinedDate;
  final List<AchievementProgress> achievementProgress;
  final List<backend_achievements.AchievementDefinition> achievementDefinitions;

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
    this.isArtistSpecified = false,
    this.isInstitutionSpecified = false,
    this.isVerifiedSpecified = false,
    this.showAchievements = true,
    required this.joinedDate,
    this.achievementProgress = const [],
    this.achievementDefinitions = const [],
  });

  /// The artist / institution / verified statements this record carries. A
  /// true value always counts as stated. Merge sources with
  /// [ProfileIdentityRoles.merge]: a stated value replaces the cached one and
  /// an unstated value keeps it.
  ProfileIdentityRoles get roleStatements => ProfileIdentityRoles(
        isArtist: isArtist,
        isInstitution: isInstitution,
        isVerified: isVerified,
        isArtistSpecified: isArtistSpecified || isArtist,
        isInstitutionSpecified: isInstitutionSpecified || isInstitution,
        isVerifiedSpecified: isVerifiedSpecified || isVerified,
      );

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
    bool? isArtistSpecified,
    bool? isInstitutionSpecified,
    bool? isVerifiedSpecified,
    bool? showAchievements,
    String? joinedDate,
    List<AchievementProgress>? achievementProgress,
    List<backend_achievements.AchievementDefinition>? achievementDefinitions,
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
      isArtistSpecified:
          isArtistSpecified ?? (isArtist != null || this.isArtistSpecified),
      isInstitutionSpecified: isInstitutionSpecified ??
          (isInstitution != null || this.isInstitutionSpecified),
      isVerifiedSpecified: isVerifiedSpecified ??
          (isVerified != null || this.isVerifiedSpecified),
      showAchievements: showAchievements ?? this.showAchievements,
      joinedDate: joinedDate ?? this.joinedDate,
      achievementProgress: achievementProgress ?? this.achievementProgress,
      achievementDefinitions:
          achievementDefinitions ?? this.achievementDefinitions,
    );
  }
}
