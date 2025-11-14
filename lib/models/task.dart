import 'package:flutter/material.dart';

/// Task model representing a discovery task tied to achievements
class Task {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
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
    required this.color,
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
    Color? color,
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
      color: color ?? this.color,
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
      color: Color(0xFF4CAF50),
      category: 'Exploration',
      achievementIds: ['local_guide', 'first_ar_visit'],
      priority: 1,
    ),
    Task(
      id: 'visit_museums',
      name: 'Visit Museums',
      description: 'Explore different galleries and museums',
      icon: Icons.museum,
      color: Color(0xFF2196F3),
      category: 'Exploration',
      achievementIds: ['gallery_explorer'],
      priority: 2,
    ),
    Task(
      id: 'ar_experiences',
      name: 'AR Experiences',
      description: 'View artworks using augmented reality',
      icon: Icons.view_in_ar,
      color: Color(0xFF9C27B0),
      category: 'AR Exploration',
      achievementIds: ['first_ar_visit', 'ar_collector'],
      priority: 3,
    ),
    Task(
      id: 'artist_interactions',
      name: 'Artist Interactions',
      description: 'Connect and interact with artists',
      icon: Icons.people,
      color: Color(0xFFFF9800),
      category: 'Community',
      achievementIds: ['art_critic', 'social_butterfly'],
      priority: 4,
    ),
    Task(
      id: 'build_collection',
      name: 'Build Collection',
      description: 'Create your personal art collection',
      icon: Icons.collections,
      color: Color(0xFFE91E63),
      category: 'Collection',
      achievementIds: ['first_favorite', 'curator'],
      priority: 5,
    ),
    
    // Unlockable tasks (unlocked after completing initial 5)
    Task(
      id: 'become_ar_master',
      name: 'Become AR Master',
      description: 'Master augmented reality art viewing',
      icon: Icons.auto_awesome,
      color: Color(0xFFFFD700),
      category: 'AR Exploration',
      achievementIds: ['ar_master', 'ar_enthusiast'],
      priority: 6,
      isUnlocked: false,
      unlockedByTaskId: 'ar_experiences',
    ),
    Task(
      id: 'world_traveler',
      name: 'Art World Traveler',
      description: 'Explore art across different cities',
      icon: Icons.public,
      color: Color(0xFF00BCD4),
      category: 'Exploration',
      achievementIds: ['world_traveler'],
      priority: 7,
      isUnlocked: false,
      unlockedByTaskId: 'visit_museums',
    ),
    Task(
      id: 'community_leader',
      name: 'Community Leader',
      description: 'Become a leader in the art community',
      icon: Icons.star,
      color: Color(0xFF673AB7),
      category: 'Community',
      achievementIds: ['influencer', 'community_member'],
      priority: 8,
      isUnlocked: false,
      unlockedByTaskId: 'artist_interactions',
    ),
    Task(
      id: 'mega_collector',
      name: 'Mega Collector',
      description: 'Build an extensive art collection',
      icon: Icons.collections_bookmark,
      color: Color(0xFF795548),
      category: 'Collection',
      achievementIds: ['mega_collector'],
      priority: 9,
      isUnlocked: false,
      unlockedByTaskId: 'build_collection',
    ),
    Task(
      id: 'web3_patron',
      name: 'Web3 Art Patron',
      description: 'Support artists through Web3 technologies',
      icon: Icons.volunteer_activism,
      color: Color(0xFFFF6B6B),
      category: 'Web3',
      achievementIds: ['supporter', 'patron'],
      priority: 10,
      isUnlocked: false,
      unlockedByTaskId: 'discover_local_art',
    ),
];
