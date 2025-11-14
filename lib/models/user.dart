import 'achievements.dart';

class User {
  final String id;
  final String name;
  final String username;
  final String bio;
  final String? profileImageUrl;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final bool isFollowing;
  final bool isVerified;
  final String joinedDate;
  final List<AchievementProgress> achievementProgress;

  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.bio,
    this.profileImageUrl,
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.isFollowing,
    required this.isVerified,
    required this.joinedDate,
    this.achievementProgress = const [],
  });

  /// Get total achievement points for this user
  int get totalAchievementPoints {
    int total = 0;
    for (final progress in achievementProgress) {
      if (progress.isCompleted) {
        final achievement = getAchievementById(progress.achievementId);
        if (achievement != null) {
          total += achievement.points;
        }
      }
    }
    return total;
  }

  /// Get achievement completion percentage
  double get achievementCompletionPercentage {
    if (allAchievements.isEmpty) return 0.0;
    final completedCount = achievementProgress.where((p) => p.isCompleted).length;
    return (completedCount / allAchievements.length * 100).clamp(0.0, 100.0);
  }

  /// Get completed achievements count
  int get completedAchievementsCount => achievementProgress.where((p) => p.isCompleted).length;

  User copyWith({
    String? id,
    String? name,
    String? username,
    String? bio,
    String? profileImageUrl,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    bool? isFollowing,
    bool? isVerified,
    String? joinedDate,
    List<AchievementProgress>? achievementProgress,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isVerified: isVerified ?? this.isVerified,
      joinedDate: joinedDate ?? this.joinedDate,
      achievementProgress: achievementProgress ?? this.achievementProgress,
    );
  }
}
