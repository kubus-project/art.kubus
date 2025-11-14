import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/achievements.dart';
import 'backend_api_service.dart';

class UserService {
  static const String _followingKey = 'following_users';

  // Sample users data
  static final List<User> _sampleUsers = [
    const User(
      id: 'maya_3d',
      name: 'Maya Digital',
      username: '@maya_3d',
      bio: 'AR artist exploring the intersection of digital and physical reality. Creating immersive experiences that transform everyday spaces.',
      followersCount: 1250,
      followingCount: 189,
      postsCount: 42,
      isFollowing: false,
      isVerified: true,
      joinedDate: 'Joined March 2024',
      achievementProgress: [
        AchievementProgress(achievementId: 'first_ar_visit', currentProgress: 1, isCompleted: true),
        AchievementProgress(achievementId: 'ar_collector', currentProgress: 10, isCompleted: true),
        AchievementProgress(achievementId: 'community_member', currentProgress: 1, isCompleted: true),
        AchievementProgress(achievementId: 'early_adopter', currentProgress: 1, isCompleted: true),
      ],
    ),
    const User(
      id: 'alex_nft',
      name: 'Alex Creator',
      username: '@alex_nft',
      bio: 'NFT creator and blockchain enthusiast. Building the future of digital ownership through art and technology.',
      followersCount: 892,
      followingCount: 341,
      postsCount: 67,
      isFollowing: false,
      isVerified: false,
      joinedDate: 'Joined January 2024',
      achievementProgress: [
        AchievementProgress(achievementId: 'first_ar_visit', currentProgress: 1, isCompleted: true),
        AchievementProgress(achievementId: 'supporter', currentProgress: 1, isCompleted: true),
        AchievementProgress(achievementId: 'first_favorite', currentProgress: 1, isCompleted: true),
      ],
    ),
    const User(
      id: 'sam_ar',
      name: 'Sam Artist',
      username: '@sam_ar',
      bio: 'Interactive AR sculptor. Passionate about collaborative art that responds to viewer interaction. Let\'s build the future together! 🚀',
      followersCount: 2150,
      followingCount: 203,
      postsCount: 28,
      isFollowing: false,
      isVerified: true,
      joinedDate: 'Joined February 2024',
      achievementProgress: [
        AchievementProgress(achievementId: 'first_ar_visit', currentProgress: 1, isCompleted: true),
        AchievementProgress(achievementId: 'ar_collector', currentProgress: 8, isCompleted: false),
        AchievementProgress(achievementId: 'social_butterfly', currentProgress: 20, isCompleted: true),
        AchievementProgress(achievementId: 'patron', currentProgress: 5, isCompleted: false),
      ],
    ),
    const User(
      id: 'luna_viz',
      name: 'Luna Vision',
      username: '@luna_viz',
      bio: 'Exploring the infinite possibilities at the intersection of blockchain and creativity. Every pixel tells a story.',
      followersCount: 743,
      followingCount: 156,
      postsCount: 91,
      isFollowing: false,
      isVerified: false,
      joinedDate: 'Joined April 2024',
      achievementProgress: [
        AchievementProgress(achievementId: 'first_ar_visit', currentProgress: 1, isCompleted: true),
        AchievementProgress(achievementId: 'art_critic', currentProgress: 7, isCompleted: false),
        AchievementProgress(achievementId: 'gallery_explorer', currentProgress: 3, isCompleted: false),
      ],
    ),
  ];

  static Future<User?> getUserById(String userId) async {
    try {
      // Fetch profile from backend using wallet address
      final profile = await BackendApiService().getProfileByWallet(userId);
      
      final followingList = await getFollowingUsers();
      final isFollowing = followingList.contains(userId);
      
      // Convert backend profile to User model
      return User(
        id: profile['walletAddress'] ?? userId,
        name: profile['displayName'] ?? profile['username'] ?? 'Anonymous',
        username: '@${profile['username'] ?? userId.substring(0, 8)}',
        bio: profile['bio'] ?? '',
        followersCount: 0, // TODO: Get from backend followers API
        followingCount: 0, // TODO: Get from backend following API
        postsCount: 0, // TODO: Get from backend posts count
        isFollowing: isFollowing,
        isVerified: profile['isVerified'] ?? false,
        joinedDate: profile['createdAt'] != null 
            ? 'Joined ${DateTime.parse(profile['createdAt']).month}/${DateTime.parse(profile['createdAt']).year}'
            : 'Joined recently',
        achievementProgress: [], // TODO: Load achievements from backend
        profileImageUrl: profile['avatar'],
      );
    } catch (e) {
      debugPrint('Error loading user profile for $userId: $e');
      // Return null if profile not found
      return null;
    }
  }

  static Future<User?> getUserByUsername(String username) async {
    try {
      final followingList = await getFollowingUsers();
      
      final user = _sampleUsers.firstWhere(
        (user) => user.username == username,
        orElse: () => _sampleUsers.first,
      );
      
      return user.copyWith(isFollowing: followingList.contains(user.id));
    } catch (e) {
      return null;
    }
  }

  static Future<List<String>> getFollowingUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final followingJson = prefs.getString(_followingKey) ?? '[]';
    return List<String>.from(json.decode(followingJson));
  }

  static Future<void> followUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final followingList = await getFollowingUsers();
    
    if (!followingList.contains(userId)) {
      followingList.add(userId);
      await prefs.setString(_followingKey, json.encode(followingList));
    }
  }

  static Future<void> unfollowUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final followingList = await getFollowingUsers();
    
    followingList.remove(userId);
    await prefs.setString(_followingKey, json.encode(followingList));
  }

  static Future<bool> toggleFollow(String userId) async {
    final followingList = await getFollowingUsers();
    final isCurrentlyFollowing = followingList.contains(userId);
    
    if (isCurrentlyFollowing) {
      await unfollowUser(userId);
      return false;
    } else {
      await followUser(userId);
      return true;
    }
  }

  static Future<List<User>> getFollowingUsersList() async {
    final followingList = await getFollowingUsers();
    final followingUsers = <User>[];
    
    for (String userId in followingList) {
      final user = await getUserById(userId);
      if (user != null) {
        followingUsers.add(user);
      }
    }
    
    return followingUsers;
  }

  static Future<List<User>> getAllUsers() async {
    final followingList = await getFollowingUsers();
    
    return _sampleUsers.map((user) {
      return user.copyWith(isFollowing: followingList.contains(user.id));
    }).toList();
  }

  /// Update achievement progress for a user
  static Future<void> updateAchievementProgress(String userId, String achievementId, int newProgress) async {
    // In a real app, this would make an API call to update the server
    // For now, this is just an example of how you might handle achievement updates
    debugPrint('Updating achievement $achievementId for user $userId to progress $newProgress');
  }

  /// Increment achievement progress for a user
  static Future<void> incrementAchievementProgress(String userId, String achievementId, {int increment = 1}) async {
    // In a real app, this would make an API call to increment the server-side progress
    debugPrint('Incrementing achievement $achievementId for user $userId by $increment');
  }

  /// Trigger achievement events (call when user performs actions)
  static Future<void> triggerAchievementEvent(String userId, String event, {Map<String, dynamic>? data}) async {
    // Example achievement event triggers
    switch (event) {
      case 'ar_view':
        await incrementAchievementProgress(userId, 'first_ar_visit');
        await incrementAchievementProgress(userId, 'ar_collector');
        break;
      case 'gallery_visit':
        await incrementAchievementProgress(userId, 'gallery_explorer');
        break;
      case 'artwork_like':
        await incrementAchievementProgress(userId, 'social_butterfly');
        break;
      case 'review_posted':
        await incrementAchievementProgress(userId, 'art_critic');
        break;
      case 'dao_vote':
        await incrementAchievementProgress(userId, 'community_member');
        break;
      case 'artwork_shared':
        await incrementAchievementProgress(userId, 'social_butterfly');
        break;
      case 'nft_purchase':
        await incrementAchievementProgress(userId, 'supporter');
        break;
    }
  }
}
