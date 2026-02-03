import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../models/achievement_progress.dart';
import '../models/task.dart';
import '../services/achievement_service.dart' as achievement_svc;
import '../services/task_service.dart';

class TaskProvider extends ChangeNotifier {
  static final Map<String, achievement_svc.AchievementDefinition>
      _definitionsById = <String, achievement_svc.AchievementDefinition>{
    for (final def
        in achievement_svc.AchievementService.achievementDefinitions.values)
      def.id: def,
  };

  final List<TaskProgress> _taskProgress = <TaskProgress>[];
  final List<AchievementProgress> _achievementProgress =
      <AchievementProgress>[];

  bool _isLoading = false;
  String? _error;

  List<TaskProgress> get taskProgress => List.unmodifiable(_taskProgress);
  List<AchievementProgress> get achievementProgress =>
      List.unmodifiable(_achievementProgress);
  bool get isLoading => _isLoading;
  String? get error => _error;

  achievement_svc.AchievementDefinition? definitionFor(String achievementId) {
    final id = achievementId.trim();
    if (id.isEmpty) return null;
    return _definitionsById[id];
  }

  /// Initialize progress for a fresh session.
  ///
  /// Uses the achievement definitions from [AchievementService] as the single
  /// source of truth. Local "tracking"/increment APIs were removed to avoid
  /// divergent behavior before launch.
  void initializeProgress() {
    _isLoading = true;

    try {
      _achievementProgress
        ..clear()
        ..addAll(_definitionsById.values.map((def) {
          return AchievementProgress(
            achievementId: def.id,
            currentProgress: 0,
            isCompleted: false,
          );
        }));

      _taskProgress.clear();
      final initialTasks = TaskService().getInitialTasks();
      for (final task in initialTasks) {
        _taskProgress.add(
          TaskProgress(
            taskId: task.id,
            completed: 0,
            total: _calculateTaskTotal(task),
            isCompleted: false,
            lastUpdated: DateTime.now(),
          ),
        );
      }

      _recalculateTaskProgress();
      _checkForUnlockedTasks();
      _error = null;
    } catch (e) {
      _error = 'Failed to initialize progress: $e';
    } finally {
      _isLoading = false;
    }

    notifyListeners();
  }

  TaskProgress? getTaskProgress(String taskId) {
    try {
      return _taskProgress.firstWhere((progress) => progress.taskId == taskId);
    } catch (_) {
      return null;
    }
  }

  AchievementProgress? getAchievementProgress(String achievementId) {
    try {
      return _achievementProgress
          .firstWhere((progress) => progress.achievementId == achievementId);
    } catch (_) {
      return null;
    }
  }

  List<Task> getAvailableTasks() {
    final completedTasks =
        _taskProgress.where((progress) => progress.isCompleted).toList();
    return TaskService().getAvailableTasks(completedTasks);
  }

  List<TaskProgress> getActiveTaskProgress() {
    final availableTaskIds = getAvailableTasks().map((task) => task.id).toSet();
    return _taskProgress
        .where((progress) => availableTaskIds.contains(progress.taskId))
        .toList();
  }

  double getOverallProgress() {
    final availableProgress = getActiveTaskProgress();
    if (availableProgress.isEmpty) return 0.0;

    var totalProgress = 0.0;
    for (final progress in availableProgress) {
      totalProgress += progress.progressPercentage;
    }
    return totalProgress / availableProgress.length;
  }

  int getCompletedTasksCount() =>
      _taskProgress.where((progress) => progress.isCompleted).length;

  int getTotalAvailableTasksCount() => getAvailableTasks().length;

  int _calculateTaskTotal(Task task) {
    var total = 0;
    for (final achievementId in task.achievementIds) {
      final def = definitionFor(achievementId);
      if (def != null) {
        total += def.requiredCount > 0 ? def.requiredCount : 1;
      }
    }
    return total > 0 ? total : 1;
  }

  void _recalculateTaskProgress() {
    for (var i = 0; i < _taskProgress.length; i++) {
      final taskProgress = _taskProgress[i];
      final task = TaskService().getTaskById(taskProgress.taskId);
      if (task == null) continue;

      var completed = 0;
      for (final achievementId in task.achievementIds) {
        final progress = getAchievementProgress(achievementId);
        if (progress != null) {
          completed += progress.currentProgress;
        }
      }

      final total = _calculateTaskTotal(task);
      final isCompleted = completed >= total;

      _taskProgress[i] = taskProgress.copyWith(
        completed: completed,
        total: total,
        isCompleted: isCompleted,
        completedDate: isCompleted && !taskProgress.isCompleted
            ? DateTime.now()
            : taskProgress.completedDate,
        lastUpdated: DateTime.now(),
      );
    }
  }

  void _checkForUnlockedTasks() {
    final availableTasks = getAvailableTasks();
    final currentTaskIds = _taskProgress.map((progress) => progress.taskId).toSet();

    for (final task in availableTasks) {
      if (currentTaskIds.contains(task.id)) continue;
      _taskProgress.add(
        TaskProgress(
          taskId: task.id,
          completed: 0,
          total: _calculateTaskTotal(task),
          isCompleted: false,
          lastUpdated: DateTime.now(),
        ),
      );
    }

    _recalculateTaskProgress();
  }

  void _setAchievementProgress({
    required String achievementId,
    required int currentProgress,
  }) {
    final def = definitionFor(achievementId);
    final required = def?.requiredCount ?? 1;
    final completed = required > 0 ? currentProgress >= required : currentProgress > 0;

    final updated = AchievementProgress(
      achievementId: achievementId,
      currentProgress: currentProgress,
      isCompleted: completed,
      completedDate: completed ? DateTime.now() : null,
    );

    final index = _achievementProgress
        .indexWhere((p) => p.achievementId == achievementId);
    if (index >= 0) {
      _achievementProgress[index] = updated;
    } else {
      _achievementProgress.add(updated);
    }
  }

  void _ensureAchievementProgressSeeded() {
    if (_achievementProgress.isEmpty) {
      _achievementProgress.addAll(_definitionsById.values.map((def) {
        return AchievementProgress(
          achievementId: def.id,
          currentProgress: 0,
          isCompleted: false,
        );
      }));
      return;
    }

    final existingIds = _achievementProgress.map((p) => p.achievementId).toSet();
    for (final def in _definitionsById.values) {
      if (existingIds.contains(def.id)) continue;
      _achievementProgress.add(
        AchievementProgress(
          achievementId: def.id,
          currentProgress: 0,
          isCompleted: false,
        ),
      );
    }
  }

  Future<void> loadProgressFromBackend(String walletAddress) async {
    final id = walletAddress.trim();
    if (id.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      if (_taskProgress.isEmpty) {
        initializeProgress();
      } else {
        _ensureAchievementProgressSeeded();
      }

      final achievementService = achievement_svc.AchievementService();
      final progressData = await achievementService.getAchievementProgress(id);
      AppConfig.debugPrint(
        'TaskProvider: loaded progress from backend (${progressData.length} entries)',
      );

      for (final entry in progressData.entries) {
        _setAchievementProgress(
          achievementId: entry.key,
          currentProgress: entry.value,
        );
      }

      _recalculateTaskProgress();
      _checkForUnlockedTasks();
      _error = null;
    } catch (e) {
      AppConfig.debugPrint('TaskProvider: loadProgressFromBackend failed: $e');
      _error = 'Failed to load progress: $e';
      if (_taskProgress.isEmpty || _achievementProgress.isEmpty) {
        initializeProgress();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
