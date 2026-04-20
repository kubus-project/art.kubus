import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/models/achievement_progress.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/services/achievement_service.dart' as achievement_svc;
import 'package:art_kubus/utils/achievement_ui.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/inline_loading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  int _totalTokens = 0;
  bool _isLoadingTokens = true;

  @override
  void initState() {
    super.initState();
    _loadTokenBalance();
  }

  Future<void> _loadTokenBalance() async {
    setState(() => _isLoadingTokens = true);
    try {
      final tokens =
          await achievement_svc.AchievementService().getTotalEarnedTokens();
      if (!mounted) return;
      setState(() => _totalTokens = tokens);
    } catch (e) {
      AppConfig.debugPrint('AchievementsPage: token balance load failed: $e');
      if (!mounted) return;
      setState(() => _totalTokens = 0);
    } finally {
      if (mounted) {
        setState(() => _isLoadingTokens = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final progressById = <String, AchievementProgress>{
      for (final progress in taskProvider.achievementProgress)
        progress.achievementId: progress,
    };

    final achievements = achievement_svc
        .AchievementService.achievementDefinitions.values
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          'Achievements & POAPs',
          style: KubusTextStyles.mobileAppBarTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildStatsHeader(achievements, progressById),
          Expanded(
            child: _buildAchievementsList(achievements, progressById),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(
    List<achievement_svc.AchievementDefinition> achievements,
    Map<String, AchievementProgress> progressById,
  ) {
    final completedCount = achievements.where((achievement) {
      final progress = progressById[achievement.id];
      final required =
          achievement.requiredCount > 0 ? achievement.requiredCount : 1;
      final ratio =
          ((progress?.currentProgress ?? 0) / required).clamp(0.0, 1.0);
      return (progress?.isCompleted ?? false) || ratio >= 1.0;
    }).length;
    final completionPercentage = achievements.isEmpty
        ? 0.0
        : (completedCount / achievements.length * 100);

    final roles = KubusColorRoles.of(context);
    final scheme = Theme.of(context).colorScheme;
    final accentPrimary = roles.achievementGold;
    final accentSecondary =
        Color.lerp(accentPrimary, scheme.primary, 0.25) ?? scheme.primary;

    return Container(
      margin: const EdgeInsets.all(KubusSpacing.lg),
      padding: const EdgeInsets.all(KubusChromeMetrics.cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentPrimary, accentSecondary],
        ),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: scheme.onPrimary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Achievements',
                      style: KubusTextStyles.heroTitle
                          .copyWith(color: scheme.onPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Collect POAPs and unlock KUB8 rewards',
                      style: KubusTextStyles.heroSubtitle.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildHeaderStat(
                  label: 'Completed',
                  value: '$completedCount/${achievements.length}',
                ),
              ),
              Expanded(
                child: _buildHeaderStat(
                  label: 'KUB8',
                  value: _isLoadingTokens ? '…' : '$_totalTokens',
                ),
              ),
              Expanded(
                child: _buildHeaderStat(
                  label: 'Progress',
                  value: '${completionPercentage.toInt()}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat({
    required String label,
    required String value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: KubusTextStyles.statValue.copyWith(color: scheme.onPrimary),
        ),
        Text(
          label,
          style: KubusTextStyles.statLabel.copyWith(
            color: scheme.onPrimary.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsList(
    List<achievement_svc.AchievementDefinition> achievements,
    Map<String, AchievementProgress> progressById,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        final progress = progressById[achievement.id] ??
            AchievementProgress(
              achievementId: achievement.id,
              currentProgress: 0,
              isCompleted: false,
            );
        return _buildAchievementCard(achievement, progress);
      },
    );
  }

  Widget _buildAchievementCard(
    achievement_svc.AchievementDefinition achievement,
    AchievementProgress progress,
  ) {
    final required =
        achievement.requiredCount > 0 ? achievement.requiredCount : 1;
    final progressPercent =
        (progress.currentProgress / required).clamp(0.0, 1.0);
    final isUnlocked = progress.isCompleted || progressPercent >= 1.0;
    final scheme = Theme.of(context).colorScheme;
    final accent = AchievementUi.accentFor(context, achievement);

    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(color: isUnlocked ? accent : scheme.outline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? accent.withValues(alpha: 0.12)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              AchievementUi.iconFor(achievement),
              color:
                  isUnlocked ? accent : scheme.onSurface.withValues(alpha: 0.4),
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: Text(
              achievement.title,
              style: KubusTextStyles.sectionTitle.copyWith(
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              achievement.description,
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color:
                    scheme.onSurface.withValues(alpha: isUnlocked ? 0.8 : 0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          if (!isUnlocked && required > 1) ...[
            Text(
              '${progress.currentProgress}/$required',
              style: KubusTextStyles.compactBadge.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: InlineLoading(
                  progress: progressPercent,
                  tileSize: 6.0,
                  color: accent,
                  duration: const Duration(milliseconds: 700),
                ),
              ),
            ),
          ],
          if (isUnlocked) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(KubusRadius.md),
              ),
              child: Text(
                achievement.isPOAP ? 'POAP' : 'UNLOCKED',
                style: KubusTextStyles.compactBadge.copyWith(
                  color: accent,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.monetization_on, size: 12, color: accent),
              const SizedBox(width: 2),
              Text(
                '${achievement.tokenReward}',
                style: KubusTextStyles.compactBadge.copyWith(color: accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
