// Example Usage of the Centralized Achievement System
// 
// This file demonstrates how to use the new achievement system
// in different parts of the app.

import '../models/achievements.dart';
import '../services/user_service.dart';

/// Example class showing how to integrate achievement tracking
class AchievementExamples {
  
  /// Example: User views an AR artwork
  static Future<void> onARViewCompleted(String userId) async {
    // Trigger the AR view achievement events
    await UserService.triggerAchievementEvent(userId, 'ar_view');
    
    // This will automatically increment:
    // - first_ar_visit (if not completed)
    // - ar_collector (progress towards viewing 10 AR artworks)
  }
  
  /// Example: User visits a gallery
  static Future<void> onGalleryVisit(String userId, String galleryId) async {
    await UserService.triggerAchievementEvent(userId, 'gallery_visit');
    
    // This increments the gallery_explorer achievement
  }
  
  /// Example: User likes an artwork
  static Future<void> onArtworkLiked(String userId, String artworkId) async {
    await UserService.triggerAchievementEvent(userId, 'artwork_like');
    
    // This increments the social_butterfly achievement
  }
  
  /// Example: User posts a review
  static Future<void> onReviewPosted(String userId, String artworkId, String review) async {
    await UserService.triggerAchievementEvent(userId, 'review_posted');
    
    // This increments the art_critic achievement
  }
  
  /// Example: User participates in DAO voting
  static Future<void> onDAOVote(String userId, String proposalId) async {
    await UserService.triggerAchievementEvent(userId, 'dao_vote');
    
    // This completes the community_member achievement
  }
  
  /// Example: User shares an artwork
  static Future<void> onArtworkShared(String userId, String artworkId) async {
    await UserService.triggerAchievementEvent(userId, 'artwork_shared');
    
    // This increments the social_butterfly achievement
  }
  
  /// Example: User makes an NFT purchase
  static Future<void> onNFTPurchase(String userId, String nftId) async {
    await UserService.triggerAchievementEvent(userId, 'nft_purchase');
    
    // This completes the supporter achievement and may increment patron
  }
  
  /// Example: Get user's achievement statistics
  static void showAchievementStats(List<AchievementProgress> userProgress) {
    final totalPoints = AchievementService.calculateTotalPoints(userProgress);
    final completionPercentage = AchievementService.getOverallCompletionPercentage(userProgress);
    final almostComplete = AchievementService.getAlmostCompleteAchievements(userProgress);
    
    print('Total Points: $totalPoints');
    print('Completion: ${completionPercentage.toInt()}%');
    print('Almost Complete: ${almostComplete.map((a) => a.title).join(', ')}');
  }
  
  /// Example: Get achievements by category
  static void showAchievementsByCategory() {
    final categories = AchievementService.getAllCategories();
    
    for (final category in categories) {
      final achievements = AchievementService.getAchievementsByCategory(category);
      print('$category: ${achievements.length} achievements');
      for (final achievement in achievements) {
        print('  - ${achievement.title} (${achievement.points} points)');
      }
    }
  }
  
  /// Example: Check if user has completed specific achievements
  static bool hasCompletedAchievement(List<AchievementProgress> userProgress, String achievementId) {
    final progress = userProgress.firstWhere(
      (p) => p.achievementId == achievementId,
      orElse: () => const AchievementProgress(
        achievementId: '', 
        currentProgress: 0, 
        isCompleted: false,
      ),
    );
    return progress.isCompleted;
  }
  
  /// Example: Get progress for a specific achievement
  static AchievementProgress? getAchievementProgress(List<AchievementProgress> userProgress, String achievementId) {
    try {
      return userProgress.firstWhere((p) => p.achievementId == achievementId);
    } catch (e) {
      return null;
    }
  }
  
  /// Example: Manual progress update (for special events)
  static List<AchievementProgress> updateSpecialAchievement(
    List<AchievementProgress> userProgress,
    String achievementId,
    int newProgress,
  ) {
    return AchievementService.updateProgress(userProgress, achievementId, newProgress);
  }
}

/* 
How to use in your widgets:

1. In AR Viewer:
```dart
@override
void onARSessionCompleted() {
  AchievementExamples.onARViewCompleted(currentUserId);
}
```

2. In Gallery Screen:
```dart
@override
void onGalleryEntered(String galleryId) {
  AchievementExamples.onGalleryVisit(currentUserId, galleryId);
}
```

3. In Art Detail Screen:
```dart
void _onLikePressed() {
  // ... existing like logic
  AchievementExamples.onArtworkLiked(currentUserId, artwork.id);
}
```

4. In Review Screen:
```dart
void _submitReview(String review) {
  // ... existing review logic
  AchievementExamples.onReviewPosted(currentUserId, artwork.id, review);
}
```

5. In DAO Voting Screen:
```dart
void _castVote(String proposalId, bool vote) {
  // ... existing voting logic
  AchievementExamples.onDAOVote(currentUserId, proposalId);
}
```

6. Display Achievement Stats:
```dart
Widget buildAchievementStats(User user) {
  return Column(
    children: [
      Text('Points: ${user.totalAchievementPoints}'),
      Text('Progress: ${user.achievementCompletionPercentage.toInt()}%'),
      Text('Completed: ${user.completedAchievementsCount}/${AchievementService.allAchievements.length}'),
    ],
  );
}
```

7. Achievement Categories View:
```dart
Widget buildCategorizedAchievements() {
  final categories = AchievementService.getAllCategories();
  
  return ListView.builder(
    itemCount: categories.length,
    itemBuilder: (context, index) {
      final category = categories[index];
      final achievements = AchievementService.getAchievementsByCategory(category);
      
      return ExpansionTile(
        title: Text(category),
        children: achievements.map((achievement) => 
          ListTile(
            leading: Icon(achievement.icon, color: achievement.color),
            title: Text(achievement.title),
            subtitle: Text(achievement.description),
            trailing: Text('${achievement.points}pts'),
          ),
        ).toList(),
      );
    },
  );
}
```
*/
