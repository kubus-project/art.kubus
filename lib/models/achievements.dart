import 'package:flutter/material.dart';

/// Achievement model representing a single achievement
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int requiredProgress;
  final String category;
  final int points;
  final String? rewardDescription;
  
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.requiredProgress = 1,
    required this.category,
    this.points = 10,
    this.rewardDescription,
  });
}

/// User's progress on a specific achievement
class AchievementProgress {
  final String achievementId;
  final int currentProgress;
  final bool isCompleted;
  final DateTime? completedDate;
  
  const AchievementProgress({
    required this.achievementId,
    required this.currentProgress,
    required this.isCompleted,
    this.completedDate,
  });
  
  double get progressPercentage {
    final achievement = getAchievementById(achievementId);
    if (achievement == null) return 0.0;
    return (currentProgress / achievement.requiredProgress).clamp(0.0, 1.0);
  }
  
  AchievementProgress copyWith({
    String? achievementId,
    int? currentProgress,
    bool? isCompleted,
    DateTime? completedDate,
  }) {
    return AchievementProgress(
      achievementId: achievementId ?? this.achievementId,
      currentProgress: currentProgress ?? this.currentProgress,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDate: completedDate ?? this.completedDate,
    );
  }
}

/// All available achievements in the app
const List<Achievement> allAchievements = [
    // AR Exploration Achievements
    Achievement(
      id: 'first_ar_visit',
      title: 'First AR Explorer',
      description: 'Visited your first AR artwork',
      icon: Icons.visibility,
      category: 'AR Exploration',
      points: 10,
      rewardDescription: 'Unlock AR viewing tips',
    ),
    Achievement(
      id: 'ar_collector',
      title: 'AR Art Collector',
      description: 'Viewed 10 different AR artworks',
      icon: Icons.collections,
      requiredProgress: 10,
      category: 'AR Exploration',
      points: 25,
      rewardDescription: 'Special AR filters unlocked',
    ),
    Achievement(
      id: 'ar_enthusiast',
      title: 'AR Enthusiast',
      description: 'Spent 1 hour total viewing AR art',
      icon: Icons.timer,
      requiredProgress: 60, // 60 minutes
      category: 'AR Exploration',
      points: 30,
    ),
    Achievement(
      id: 'ar_master',
      title: 'AR Master',
      description: 'Viewed 50 different AR artworks',
      icon: Icons.auto_awesome,
      requiredProgress: 50,
      category: 'AR Exploration',
      points: 100,
      rewardDescription: 'Exclusive AR artwork access',
    ),
    
    // Gallery & Location Achievements
    Achievement(
      id: 'gallery_explorer',
      title: 'Gallery Explorer',
      description: 'Visited 5 different galleries',
      icon: Icons.explore,
      requiredProgress: 5,
      category: 'Exploration',
      points: 20,
    ),
    Achievement(
      id: 'world_traveler',
      title: 'Art World Traveler',
      description: 'Visited galleries in 10 different cities',
      icon: Icons.public,
      requiredProgress: 10,
      category: 'Exploration',
      points: 75,
    ),
    Achievement(
      id: 'local_guide',
      title: 'Local Art Guide',
      description: 'Discovered 25 artworks in your city',
      icon: Icons.location_on,
      requiredProgress: 25,
      category: 'Exploration',
      points: 40,
    ),
    
    // Community Achievements
    Achievement(
      id: 'community_member',
      title: 'Community Member',
      description: 'Participated in DAO voting',
      icon: Icons.how_to_vote,
      category: 'Community',
      points: 15,
    ),
    Achievement(
      id: 'art_critic',
      title: 'Art Critic',
      description: 'Left 10 reviews on artworks',
      icon: Icons.rate_review,
      requiredProgress: 10,
      category: 'Community',
      points: 25,
    ),
    Achievement(
      id: 'social_butterfly',
      title: 'Social Butterfly',
      description: 'Shared 20 artworks with friends',
      icon: Icons.share,
      requiredProgress: 20,
      category: 'Community',
      points: 30,
    ),
    Achievement(
      id: 'influencer',
      title: 'Art Influencer',
      description: 'Get 100 likes on your shared content',
      icon: Icons.trending_up,
      requiredProgress: 100,
      category: 'Community',
      points: 50,
    ),
    
    // Collection Achievements
    Achievement(
      id: 'first_favorite',
      title: 'First Love',
      description: 'Added your first artwork to favorites',
      icon: Icons.favorite,
      category: 'Collection',
      points: 5,
    ),
    Achievement(
      id: 'curator',
      title: 'Art Curator',
      description: 'Created 5 custom collections',
      icon: Icons.folder_special,
      requiredProgress: 5,
      category: 'Collection',
      points: 35,
    ),
    Achievement(
      id: 'mega_collector',
      title: 'Mega Collector',
      description: 'Have 100 artworks in your favorites',
      icon: Icons.collections_bookmark,
      requiredProgress: 100,
      category: 'Collection',
      points: 75,
    ),
    
    // Special Achievements
    Achievement(
      id: 'early_adopter',
      title: 'Early Adopter',
      description: 'One of the first 1000 users',
      icon: Icons.stars,
      category: 'Special',
      points: 100,
      rewardDescription: 'Exclusive early adopter badge',
    ),
    Achievement(
      id: 'beta_tester',
      title: 'Beta Tester',
      description: 'Tested new features before release',
      icon: Icons.bug_report,
      category: 'Special',
      points: 50,
    ),
    Achievement(
      id: 'daily_visitor',
      title: 'Daily Art Lover',
      description: 'Used the app for 30 consecutive days',
      icon: Icons.calendar_today,
      requiredProgress: 30,
      category: 'Special',
      points: 60,
    ),
    Achievement(
      id: 'supporter',
      title: 'Art Supporter',
      description: 'Made your first NFT purchase',
      icon: Icons.shopping_cart,
      category: 'Web3',
      points: 40,
    ),
    Achievement(
      id: 'patron',
      title: 'Art Patron',
      description: 'Supported 10 different artists',
      icon: Icons.volunteer_activism,
      requiredProgress: 10,
      category: 'Web3',
      points: 80,
    ),
];

/// Helper function to get achievement by ID
/// For full achievement management, use AchievementService
Achievement? getAchievementById(String id) {
  try {
    return allAchievements.firstWhere((achievement) => achievement.id == id);
  } catch (e) {
    return null;
  }
}

