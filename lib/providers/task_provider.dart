import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/achievements.dart';

class TaskProvider extends ChangeNotifier {
  final List<TaskProgress> _taskProgress = [];
  final List<AchievementProgress> _achievementProgress = [];
  bool _isLoading = false;
  String? _error;

  List<TaskProgress> get taskProgress => List.unmodifiable(_taskProgress);
  List<AchievementProgress> get achievementProgress => List.unmodifiable(_achievementProgress);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize with default progress for new users
  void initializeProgress() {
    _setLoading(true);
    
    try {
      // Initialize achievement progress
      _achievementProgress.clear();
      _achievementProgress.addAll(AchievementService.createDefaultProgress());
      
      // Initialize task progress for initial 5 tasks
      _taskProgress.clear();
      final initialTasks = TaskService.getInitialTasks();
      
      for (final task in initialTasks) {
        _taskProgress.add(TaskProgress(
          taskId: task.id,
          completed: 0,
          total: _calculateTaskTotal(task),
          isCompleted: false,
          lastUpdated: DateTime.now(),
        ));
      }
      
      _error = null;
    } catch (e) {
      _error = 'Failed to initialize progress: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Get current task progress by ID
  TaskProgress? getTaskProgress(String taskId) {
    try {
      return _taskProgress.firstWhere((progress) => progress.taskId == taskId);
    } catch (e) {
      return null;
    }
  }

  /// Get achievement progress by ID
  AchievementProgress? getAchievementProgress(String achievementId) {
    try {
      return _achievementProgress.firstWhere((progress) => progress.achievementId == achievementId);
    } catch (e) {
      return null;
    }
  }

  /// Get currently available tasks (including newly unlocked ones)
  List<Task> getAvailableTasks() {
    final completedTasks = _taskProgress.where((progress) => progress.isCompleted).toList();
    return TaskService.getAvailableTasks(completedTasks);
  }

  /// Get active task progress (available tasks with their progress)
  List<TaskProgress> getActiveTaskProgress() {
    final availableTasks = getAvailableTasks();
    final availableTaskIds = availableTasks.map((task) => task.id).toSet();
    
    return _taskProgress.where((progress) => availableTaskIds.contains(progress.taskId)).toList();
  }

  /// Update achievement progress and recalculate task progress
  void updateAchievementProgress(String achievementId, int newProgress) {
    _setLoading(true);
    
    try {
      // Update achievement progress
      _achievementProgress.clear();
      _achievementProgress.addAll(
        AchievementService.updateProgress(_achievementProgress, achievementId, newProgress)
      );
      
      // Recalculate task progress based on achievement progress
      _recalculateTaskProgress();
      
      // Check for newly unlocked tasks
      _checkForUnlockedTasks();
      
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update achievement progress: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Increment achievement progress
  void incrementAchievementProgress(String achievementId, {int increment = 1}) {
    print('DEBUG: Incrementing $achievementId by $increment');
    _setLoading(true);
    
    try {
      // Update achievement progress
      _achievementProgress.clear();
      _achievementProgress.addAll(
        AchievementService.incrementProgress(_achievementProgress, achievementId, increment: increment)
      );
      
      print('DEBUG: Achievement progress updated, recalculating tasks...');
      // Recalculate task progress
      _recalculateTaskProgress();
      
      // Check for newly unlocked tasks
      _checkForUnlockedTasks();
      
      _error = null;
      notifyListeners();
      print('DEBUG: Task progress recalculated and listeners notified');
    } catch (e) {
      print('DEBUG: Error incrementing achievement progress: $e');
      _error = 'Failed to increment achievement progress: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Track artwork visit/discovery
  void trackArtworkVisit(String artworkId) {
    incrementAchievementProgress('first_ar_visit', increment: 1);
    incrementAchievementProgress('local_guide', increment: 1);
    incrementAchievementProgress('gallery_explorer', increment: 1);
  }

  /// Track artwork like/favorite
  void trackArtworkLike(String artworkId) {
    print('DEBUG: Tracking artwork like for $artworkId');
    incrementAchievementProgress('art_critic', increment: 1);
    incrementAchievementProgress('social_butterfly', increment: 1);
  }

  /// Track artwork favorite action
  void trackArtworkFavorite(String artworkId) {
    print('DEBUG: Tracking artwork favorite for $artworkId');
    incrementAchievementProgress('first_favorite', increment: 1);
    incrementAchievementProgress('curator', increment: 1);
    incrementAchievementProgress('mega_collector', increment: 1);
  }

  /// Track comment on artwork
  void trackArtworkComment(String artworkId) {
    print('DEBUG: Tracking artwork comment for $artworkId');
    incrementAchievementProgress('art_critic', increment: 2);
    incrementAchievementProgress('social_butterfly', increment: 1);
  }

  /// Track sharing artwork
  void trackArtworkShare(String artworkId) {
    incrementAchievementProgress('social_butterfly', increment: 2);
  }

  /// Track AR interaction
  void trackARInteraction(String artworkId) {
    incrementAchievementProgress('first_ar_visit', increment: 1);
    incrementAchievementProgress('ar_collector', increment: 1);
    incrementAchievementProgress('ar_enthusiast', increment: 1);
  }

  /// Track NFT minting
  void trackNFTMint(String seriesId) {
    incrementAchievementProgress('nft_collector', increment: 1);
    incrementAchievementProgress('digital_artist', increment: 1);
  }

  /// Get overall discovery progress (0.0 to 1.0)
  double getOverallProgress() {
    if (_taskProgress.isEmpty) return 0.0;
    
    final availableProgress = getActiveTaskProgress();
    if (availableProgress.isEmpty) return 0.0;
    
    double totalProgress = 0.0;
    for (final progress in availableProgress) {
      totalProgress += progress.progressPercentage;
    }
    
    return totalProgress / availableProgress.length;
  }

  /// Get completed tasks count
  int getCompletedTasksCount() {
    return _taskProgress.where((progress) => progress.isCompleted).length;
  }

  /// Get total available tasks count
  int getTotalAvailableTasksCount() {
    return getAvailableTasks().length;
  }

  /// Private methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) notifyListeners();
  }

  /// Calculate total count for a task based on its achievements
  int _calculateTaskTotal(Task task) {
    int total = 0;
    for (final achievementId in task.achievementIds) {
      final achievement = AchievementService.getAchievementById(achievementId);
      if (achievement != null) {
        total += achievement.requiredProgress;
      }
    }
    return total > 0 ? total : 1; // Ensure at least 1
  }

  /// Recalculate task progress based on current achievement progress
  void _recalculateTaskProgress() {
    for (int i = 0; i < _taskProgress.length; i++) {
      final taskProgress = _taskProgress[i];
      final task = TaskService.getTaskById(taskProgress.taskId);
      
      if (task != null) {
        int completed = 0;
        
        // Sum up progress from all related achievements
        for (final achievementId in task.achievementIds) {
          final achievementProgress = getAchievementProgress(achievementId);
          if (achievementProgress != null) {
            completed += achievementProgress.currentProgress;
          }
        }
        
        final total = _calculateTaskTotal(task);
        final isCompleted = completed >= total;
        
        _taskProgress[i] = taskProgress.copyWith(
          completed: completed,
          total: total,
          isCompleted: isCompleted,
          completedDate: isCompleted && !taskProgress.isCompleted ? DateTime.now() : taskProgress.completedDate,
          lastUpdated: DateTime.now(),
        );
      }
    }
  }

  /// Check for newly unlocked tasks and add them to progress
  void _checkForUnlockedTasks() {
    final availableTasks = getAvailableTasks();
    final currentTaskIds = _taskProgress.map((progress) => progress.taskId).toSet();
    
    for (final task in availableTasks) {
      if (!currentTaskIds.contains(task.id)) {
        // This is a newly unlocked task
        _taskProgress.add(TaskProgress(
          taskId: task.id,
          completed: 0,
          total: _calculateTaskTotal(task),
          isCompleted: false,
          lastUpdated: DateTime.now(),
        ));
        
        // Recalculate its progress immediately
        _recalculateTaskProgress();
      }
    }
  }

  /// Mock data for testing - simulate some progress
  void loadMockProgress() {
    _setLoading(true);
    
    try {
      // Only initialize if not already initialized
      if (_taskProgress.isEmpty || _achievementProgress.isEmpty) {
        initializeProgress();
      }
      
      // Simulate some achievements completed
      incrementAchievementProgress('first_ar_visit', increment: 1);
      incrementAchievementProgress('local_guide', increment: 5);
      incrementAchievementProgress('gallery_explorer', increment: 2);
      incrementAchievementProgress('first_favorite', increment: 1);
      incrementAchievementProgress('art_critic', increment: 3);
      
      _error = null;
    } catch (e) {
      _error = 'Failed to load mock progress: $e';
    } finally {
      _setLoading(false);
    }
  }
}
