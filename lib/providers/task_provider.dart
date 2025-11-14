import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/achievements.dart';
import '../services/task_service.dart';
import '../services/achievement_service.dart' as achievement_svc;

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
    _isLoading = true;
    
    try {
      // Initialize achievement progress
      _achievementProgress.clear();
      // Note: Achievement progress is initialized separately via AchievementService
      
      // Initialize task progress for initial 5 tasks
      _taskProgress.clear();
      final initialTasks = TaskService().getInitialTasks();
      
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
      _isLoading = false;
    }
    
    // Notify listeners after initialization is complete
    notifyListeners();
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
    return TaskService().getAvailableTasks(completedTasks);
  }

  /// Get active task progress (available tasks with their progress)
  List<TaskProgress> getActiveTaskProgress() {
    final availableTasks = getAvailableTasks();
    final availableTaskIds = availableTasks.map((task) => task.id).toSet();
    
    return _taskProgress.where((progress) => availableTaskIds.contains(progress.taskId)).toList();
  }

  /// Update achievement progress and recalculate task progress
  void updateAchievementProgress(String achievementId, int newProgress) {
    _isLoading = true;
    
    try {
      // Update achievement progress
      _updateAchievementProgress(achievementId, newProgress);
      
      // Recalculate task progress based on achievement progress
      _recalculateTaskProgress();
      
      // Check for newly unlocked tasks
      _checkForUnlockedTasks();
      
      _error = null;
    } catch (e) {
      _error = 'Failed to update achievement progress: $e';
    } finally {
      _isLoading = false;
    }
    
    // Notify listeners after all updates are complete
    notifyListeners();
  }

  /// Increment achievement progress
  void incrementAchievementProgress(String achievementId, {int increment = 1}) {
    debugPrint('DEBUG: Incrementing $achievementId by $increment');
    _isLoading = true;
    
    try {
      // Update achievement progress
      _incrementAchievementProgress(achievementId, increment);
      
      debugPrint('DEBUG: Achievement progress updated, recalculating tasks...');
      // Recalculate task progress
      _recalculateTaskProgress();
      
      // Check for newly unlocked tasks
      _checkForUnlockedTasks();
      
      _error = null;
    debugPrint('DEBUG: Task progress recalculated and listeners notified');
    } catch (e) {
    debugPrint('DEBUG: Error incrementing achievement progress: $e');
      _error = 'Failed to increment achievement progress: $e';
    } finally {
      _isLoading = false;
    }
    
    // Notify listeners after all updates are complete
    notifyListeners();
  }

  /// Track artwork visit/discovery
  void trackArtworkVisit(String artworkId) {
    incrementAchievementProgress('first_ar_visit', increment: 1);
    incrementAchievementProgress('local_guide', increment: 1);
    incrementAchievementProgress('gallery_explorer', increment: 1);
  }

  /// Track artwork like/favorite
  void trackArtworkLike(String artworkId) {
    debugPrint('DEBUG: Tracking artwork like for $artworkId');
    incrementAchievementProgress('art_critic', increment: 1);
    incrementAchievementProgress('social_butterfly', increment: 1);
  }

  /// Track artwork favorite action
  void trackArtworkFavorite(String artworkId) {
    debugPrint('DEBUG: Tracking artwork favorite for $artworkId');
    incrementAchievementProgress('first_favorite', increment: 1);
    incrementAchievementProgress('curator', increment: 1);
    incrementAchievementProgress('mega_collector', increment: 1);
  }

  /// Track comment on artwork
  void trackArtworkComment(String artworkId) {
    debugPrint('DEBUG: Tracking artwork comment for $artworkId');
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
  
  /// Calculate total count for a task based on its achievements
  int _calculateTaskTotal(Task task) {
    int total = 0;
    for (final achievementId in task.achievementIds) {
      final achievement = getAchievementById(achievementId);
      if (achievement != null) {
        total += achievement.requiredProgress.toInt();
      }
    }
    return total > 0 ? total : 1; // Ensure at least 1
  }

  /// Recalculate task progress based on current achievement progress
  void _recalculateTaskProgress() {
    for (int i = 0; i < _taskProgress.length; i++) {
      final taskProgress = _taskProgress[i];
      final task = TaskService().getTaskById(taskProgress.taskId);
      
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

  /// Helper method to update achievement progress
  void _updateAchievementProgress(String achievementId, int newProgress) {
    final index = _achievementProgress.indexWhere((p) => p.achievementId == achievementId);
    if (index != -1) {
      final achievement = getAchievementById(achievementId);
      if (achievement != null) {
        final isCompleted = newProgress >= achievement.requiredProgress;
        _achievementProgress[index] = AchievementProgress(
          achievementId: achievementId,
          currentProgress: newProgress,
          isCompleted: isCompleted,
          completedDate: isCompleted ? DateTime.now() : null,
        );
      }
    }
  }

  /// Helper method to increment achievement progress
  void _incrementAchievementProgress(String achievementId, int increment) {
    final index = _achievementProgress.indexWhere((p) => p.achievementId == achievementId);
    if (index != -1) {
      final currentProgress = _achievementProgress[index].currentProgress + increment;
      _updateAchievementProgress(achievementId, currentProgress);
    } else {
      // Create new progress if it doesn't exist
      _achievementProgress.add(AchievementProgress(
        achievementId: achievementId,
        currentProgress: increment,
        isCompleted: false,
      ));
    }
  }

  /// Load progress from backend achievements system
  Future<void> loadProgressFromBackend(String walletAddress) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Only initialize if not already initialized
      if (_taskProgress.isEmpty || _achievementProgress.isEmpty) {
        initializeProgress();
      }
      
      // Import AchievementService to fetch real data
      final achievementService = achievement_svc.AchievementService();
      final progressData = await achievementService.getAchievementProgress(walletAddress);
      
      debugPrint('TaskProvider: Loaded progress from backend: ${progressData.length} achievements');
      
      // Update achievement progress with real data
      for (final entry in progressData.entries) {
        final achievementId = entry.key;
        final currentProgress = entry.value;
        
        // Update or add achievement progress
        final existingIndex = _achievementProgress.indexWhere(
          (ap) => ap.achievementId == achievementId
        );
        
        if (existingIndex != -1) {
          _achievementProgress[existingIndex] = AchievementProgress(
            achievementId: achievementId,
            currentProgress: currentProgress,
            isCompleted: false, // Will be set by updateAchievementProgress
          );
        } else {
          _achievementProgress.add(AchievementProgress(
            achievementId: achievementId,
            currentProgress: currentProgress,
            isCompleted: false,
          ));
        }
        
        // Use the existing update method to properly calculate task progress
        updateAchievementProgress(achievementId, currentProgress);
      }
      
      _error = null;
      debugPrint('TaskProvider: Progress loaded successfully');
    } catch (e) {
      debugPrint('TaskProvider: Failed to load progress from backend: $e');
      _error = 'Failed to load progress: $e';
      
      // Fallback: Initialize with empty progress
      if (_taskProgress.isEmpty || _achievementProgress.isEmpty) {
        initializeProgress();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Mock data for testing - simulate some progress
  @Deprecated('Use loadProgressFromBackend instead')
  void loadMockProgress() {
    _isLoading = true;
    
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
      _isLoading = false;
    }
    
    // Notify listeners after mock progress is loaded
    notifyListeners();
  }
}
