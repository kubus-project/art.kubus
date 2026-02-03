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

