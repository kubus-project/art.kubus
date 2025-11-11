import 'package:flutter/material.dart';

/// Achievement model representing a single achievement
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int requiredProgress;
  final String category;
  final int points;
  final String? rewardDescription;
  
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
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
    final achievement = AchievementService.getAchievementById(achievementId);
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

/// Service class for managing achievements
class AchievementService {
  /// All available achievements in the app
  static const List<Achievement> allAchievements = [
    // AR Exploration Achievements
    Achievement(
      id: 'first_ar_visit',
      title: 'First AR Explorer',
      description: 'Visited your first AR artwork',
      icon: Icons.visibility,
      color: Color.fromARGB(255, 255, 255, 255),
      category: 'AR Exploration',
      points: 10,
      rewardDescription: 'Unlock AR viewing tips',
    ),
    Achievement(
      id: 'ar_collector',
      title: 'AR Art Collector',
      description: 'Viewed 10 different AR artworks',
      icon: Icons.collections,
      color: Color(0xFF9C27B0),
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
      color: Color(0xFF00D4AA),
      requiredProgress: 60, // 60 minutes
      category: 'AR Exploration',
      points: 30,
    ),
    Achievement(
      id: 'ar_master',
      title: 'AR Master',
      description: 'Viewed 50 different AR artworks',
      icon: Icons.auto_awesome,
      color: Color(0xFFFFD700),
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
      color: Color(0xFF4CAF50),
      requiredProgress: 5,
      category: 'Exploration',
      points: 20,
    ),
    Achievement(
      id: 'world_traveler',
      title: 'Art World Traveler',
      description: 'Visited galleries in 10 different cities',
      icon: Icons.public,
      color: Color(0xFF2196F3),
      requiredProgress: 10,
      category: 'Exploration',
      points: 75,
    ),
    Achievement(
      id: 'local_guide',
      title: 'Local Art Guide',
      description: 'Discovered 25 artworks in your city',
      icon: Icons.location_on,
      color: Color(0xFFFF5722),
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
      color: Color(0xFF8BC34A),
      category: 'Community',
      points: 15,
    ),
    Achievement(
      id: 'art_critic',
      title: 'Art Critic',
      description: 'Left 10 reviews on artworks',
      icon: Icons.rate_review,
      color: Color(0xFFFF9800),
      requiredProgress: 10,
      category: 'Community',
      points: 25,
    ),
    Achievement(
      id: 'social_butterfly',
      title: 'Social Butterfly',
      description: 'Shared 20 artworks with friends',
      icon: Icons.share,
      color: Color(0xFFE91E63),
      requiredProgress: 20,
      category: 'Community',
      points: 30,
    ),
    Achievement(
      id: 'influencer',
      title: 'Art Influencer',
      description: 'Get 100 likes on your shared content',
      icon: Icons.trending_up,
      color: Color(0xFF673AB7),
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
      color: Color(0xFFE91E63),
      category: 'Collection',
      points: 5,
    ),
    Achievement(
      id: 'curator',
      title: 'Art Curator',
      description: 'Created 5 custom collections',
      icon: Icons.folder_special,
      color: Color(0xFF795548),
      requiredProgress: 5,
      category: 'Collection',
      points: 35,
    ),
    Achievement(
      id: 'mega_collector',
      title: 'Mega Collector',
      description: 'Have 100 artworks in your favorites',
      icon: Icons.collections_bookmark,
      color: Color(0xFFFFD700),
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
      color: Color(0xFFFFD700),
      category: 'Special',
      points: 100,
      rewardDescription: 'Exclusive early adopter badge',
    ),
    Achievement(
      id: 'beta_tester',
      title: 'Beta Tester',
      description: 'Tested new features before release',
      icon: Icons.bug_report,
      color: Color(0xFF9C27B0),
      category: 'Special',
      points: 50,
    ),
    Achievement(
      id: 'daily_visitor',
      title: 'Daily Art Lover',
      description: 'Used the app for 30 consecutive days',
      icon: Icons.calendar_today,
      color: Color(0xFF4CAF50),
      requiredProgress: 30,
      category: 'Special',
      points: 60,
    ),
    Achievement(
      id: 'supporter',
      title: 'Art Supporter',
      description: 'Made your first NFT purchase',
      icon: Icons.shopping_cart,
      color: Color(0xFF00BCD4),
      category: 'Web3',
      points: 40,
    ),
    Achievement(
      id: 'patron',
      title: 'Art Patron',
      description: 'Supported 10 different artists',
      icon: Icons.volunteer_activism,
      color: Color(0xFFFF6B6B),
      requiredProgress: 10,
      category: 'Web3',
      points: 80,
    ),
  ];
  
  /// Get achievement by ID
  static Achievement? getAchievementById(String id) {
    try {
      return allAchievements.firstWhere((achievement) => achievement.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Get achievements by category
  static List<Achievement> getAchievementsByCategory(String category) {
    return allAchievements.where((achievement) => achievement.category == category).toList();
  }
  
  /// Get all achievement categories
  static List<String> getAllCategories() {
    return allAchievements.map((achievement) => achievement.category).toSet().toList();
  }
  
  /// Calculate total points for completed achievements
  static int calculateTotalPoints(List<AchievementProgress> userProgress) {
    int totalPoints = 0;
    for (final progress in userProgress) {
      if (progress.isCompleted) {
        final achievement = getAchievementById(progress.achievementId);
        if (achievement != null) {
          totalPoints += achievement.points;
        }
      }
    }
    return totalPoints;
  }
  
  /// Get completion percentage for all achievements
  static double getOverallCompletionPercentage(List<AchievementProgress> userProgress) {
    if (allAchievements.isEmpty) return 0.0;
    
    int completedCount = 0;
    for (final progress in userProgress) {
      if (progress.isCompleted) {
        completedCount++;
      }
    }
    
    return (completedCount / allAchievements.length) * 100;
  }
  
  /// Get achievements that are close to completion (75%+ progress)
  static List<Achievement> getAlmostCompleteAchievements(List<AchievementProgress> userProgress) {
    List<Achievement> almostComplete = [];
    
    for (final progress in userProgress) {
      if (!progress.isCompleted && progress.progressPercentage >= 0.75) {
        final achievement = getAchievementById(progress.achievementId);
        if (achievement != null) {
          almostComplete.add(achievement);
        }
      }
    }
    
    return almostComplete;
  }
  
  /// Create default progress for all achievements (for new users)
  static List<AchievementProgress> createDefaultProgress() {
    return allAchievements.map((achievement) => AchievementProgress(
      achievementId: achievement.id,
      currentProgress: 0,
      isCompleted: false,
    )).toList();
  }
  
  /// Update progress for a specific achievement
  static List<AchievementProgress> updateProgress(
    List<AchievementProgress> currentProgress,
    String achievementId,
    int newProgress,
  ) {
    return currentProgress.map((progress) {
      if (progress.achievementId == achievementId) {
        final achievement = getAchievementById(achievementId);
        if (achievement != null) {
          final isCompleted = newProgress >= achievement.requiredProgress;
          return progress.copyWith(
            currentProgress: newProgress,
            isCompleted: isCompleted,
            completedDate: isCompleted && !progress.isCompleted ? DateTime.now() : progress.completedDate,
          );
        }
      }
      return progress;
    }).toList();
  }
  
  /// Increment progress for a specific achievement
  static List<AchievementProgress> incrementProgress(
    List<AchievementProgress> currentProgress,
    String achievementId, {
    int increment = 1,
  }) {
    return currentProgress.map((progress) {
      if (progress.achievementId == achievementId && !progress.isCompleted) {
        final newProgress = progress.currentProgress + increment;
        final achievement = getAchievementById(achievementId);
        if (achievement != null) {
          final isCompleted = newProgress >= achievement.requiredProgress;
          return progress.copyWith(
            currentProgress: newProgress,
            isCompleted: isCompleted,
            completedDate: isCompleted ? DateTime.now() : null,
          );
        }
      }
      return progress;
    }).toList();
  }
}


