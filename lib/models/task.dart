import 'package:flutter/material.dart';

/// Task model representing a discovery task tied to achievements
class Task {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String category;
  final List<String> achievementIds; // Achievements that contribute to this task
  final int priority; // Lower number = higher priority
  final bool isUnlocked;
  final String? unlockedByTaskId; // Task that unlocks this one
  
  const Task({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.achievementIds,
    this.priority = 0,
    this.isUnlocked = true,
    this.unlockedByTaskId,
  });
  
  Task copyWith({
    String? id,
    String? name,
    String? description,
    IconData? icon,
    String? category,
    List<String>? achievementIds,
    int? priority,
    bool? isUnlocked,
    String? unlockedByTaskId,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      achievementIds: achievementIds ?? this.achievementIds,
      priority: priority ?? this.priority,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedByTaskId: unlockedByTaskId ?? this.unlockedByTaskId,
    );
  }
}

/// Task progress model
class TaskProgress {
  final String taskId;
  final int completed;
  final int total;
  final bool isCompleted;
  final DateTime? completedDate;
  final DateTime lastUpdated;
  
  const TaskProgress({
    required this.taskId,
    required this.completed,
    required this.total,
    required this.isCompleted,
    this.completedDate,
    required this.lastUpdated,
  });
  
  double get progressPercentage {
    if (total == 0) return 0.0;
    return (completed / total).clamp(0.0, 1.0);
  }
  
  TaskProgress copyWith({
    String? taskId,
    int? completed,
    int? total,
    bool? isCompleted,
    DateTime? completedDate,
    DateTime? lastUpdated,
  }) {
    return TaskProgress(
      taskId: taskId ?? this.taskId,
      completed: completed ?? this.completed,
      total: total ?? this.total,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDate: completedDate ?? this.completedDate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// All available tasks in the app
const List<Task> allTasks = [
    // Initial 5 tasks
    Task(
      id: 'discover_local_art',
      name: 'Discover Local Art',
      description: 'Find and explore artworks in your area',
      icon: Icons.explore,
      category: 'Exploration',
      achievementIds: ['first_discovery', 'art_explorer'],
      priority: 1,
    ),
    Task(
      id: 'visit_museums',
      name: 'Visit Museums',
      description: 'Explore different galleries and museums',
      icon: Icons.museum,
      category: 'Exploration',
      achievementIds: ['gallery_visitor', 'event_attendee'],
      priority: 2,
    ),
    Task(
      id: 'ar_experiences',
      name: 'AR Experiences',
      description: 'View artworks using augmented reality',
      icon: Icons.view_in_ar,
      category: 'AR Exploration',
      achievementIds: ['first_ar_view', 'ar_enthusiast'],
      priority: 3,
    ),
    Task(
      id: 'artist_interactions',
      name: 'Artist Interactions',
      description: 'Connect and interact with artists',
      icon: Icons.people,
      category: 'Community',
      achievementIds: ['first_post', 'first_comment'],
      priority: 4,
    ),
    Task(
      id: 'build_collection',
      name: 'Build Collection',
      description: 'Create your personal art collection',
      icon: Icons.collections,
      category: 'Collection',
      achievementIds: ['first_nft_mint', 'nft_collector'],
      priority: 5,
    ),
    
    // Unlockable tasks (unlocked after completing initial 5)
    Task(
      id: 'become_ar_master',
      name: 'Become AR Master',
      description: 'Master augmented reality art viewing',
      icon: Icons.auto_awesome,
      category: 'AR Exploration',
      achievementIds: ['ar_pro'],
      priority: 6,
      isUnlocked: false,
      unlockedByTaskId: 'ar_experiences',
    ),
    Task(
      id: 'world_traveler',
      name: 'Become an Art Master',
      description: 'Discover 50 artworks',
      icon: Icons.public,
      category: 'Exploration',
      achievementIds: ['art_master'],
      priority: 7,
      isUnlocked: false,
      unlockedByTaskId: 'visit_museums',
    ),
    Task(
      id: 'community_leader',
      name: 'Community Leader',
      description: 'Become a leader in the art community',
      icon: Icons.star,
      category: 'Community',
      achievementIds: ['community_builder', 'influencer'],
      priority: 8,
      isUnlocked: false,
      unlockedByTaskId: 'artist_interactions',
    ),
    Task(
      id: 'mega_collector',
      name: 'NFT Trader',
      description: 'Complete 5 NFT trades',
      icon: Icons.collections_bookmark,
      category: 'Collection',
      achievementIds: ['nft_trader'],
      priority: 9,
      isUnlocked: false,
      unlockedByTaskId: 'build_collection',
    ),
    Task(
      id: 'web3_patron',
      name: 'Web3 Art Patron',
      description: 'Support artists through Web3 technologies',
      icon: Icons.volunteer_activism,
      category: 'Web3',
      achievementIds: ['art_supporter'],
      priority: 10,
      isUnlocked: false,
      unlockedByTaskId: 'discover_local_art',
    ),
];
