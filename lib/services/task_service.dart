import '../models/task.dart';

/// Service for managing tasks and task progress
class TaskService {
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();
  
  /// Get all tasks
  List<Task> getAllTasks() => allTasks;
  
  /// Get task by ID
  Task? getTaskById(String id) {
    try {
      return allTasks.firstWhere((task) => task.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Get tasks by category
  List<Task> getTasksByCategory(String category) {
    return allTasks.where((task) => task.category == category).toList();
  }
  
  /// Get the first 5 priority tasks (initial tasks)
  List<Task> getInitialTasks() {
    return allTasks.where((task) => task.priority <= 5).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }
  
  /// Get unlockable tasks
  List<Task> getUnlockableTasks() {
    return allTasks.where((task) => !task.isUnlocked).toList();
  }
  
  /// Get currently available tasks (unlocked)
  List<Task> getAvailableTasks(List<TaskProgress> completedTasks) {
    final completedTaskIds = completedTasks
        .where((progress) => progress.isCompleted)
        .map((progress) => progress.taskId)
        .toSet();
    
    return allTasks.where((task) {
      if (task.isUnlocked) return true;
      if (task.unlockedByTaskId != null) {
        return completedTaskIds.contains(task.unlockedByTaskId);
      }
      return false;
    }).toList();
  }
  
  /// Check if a task should be unlocked based on completed tasks
  bool shouldUnlockTask(Task task, List<TaskProgress> completedTasks) {
    if (task.isUnlocked) return true;
    if (task.unlockedByTaskId == null) return false;
    
    return completedTasks.any((progress) => 
      progress.taskId == task.unlockedByTaskId && progress.isCompleted
    );
  }
  
  /// Get all task categories
  List<String> getAllCategories() {
    return allTasks.map((task) => task.category).toSet().toList();
  }
}
