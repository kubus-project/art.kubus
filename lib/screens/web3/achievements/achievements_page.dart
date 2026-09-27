import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/achievement_progress.dart';
import 'package:art_kubus/models/achievements.dart' as backend_achievements;
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/common/kubus_meter_bar.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshAchievements();
    });
  }

  Future<void> _refreshAchievements() async {
    setState(() => _isLoadingTokens = true);
    try {
      await context.read<TaskProvider>().refreshAchievementsForCurrentUser();
      if (!mounted) return;
      setState(() =>
          _totalTokens = context.read<TaskProvider>().totalKub8Earned.round());
    } catch (e) {
      AppConfig.debugPrint('AchievementsPage: refresh failed: $e');
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
    final l10n = AppLocalizations.of(context)!;
    final taskProvider = context.watch<TaskProvider>();
    final progressById = <String, AchievementProgress>{
      for (final progress in taskProvider.achievementProgress)
        progress.achievementId: progress,
    };

    final achievements = taskProvider.achievementDefinitions;

    final completedCount = achievements.where((achievement) {
      final progress = progressById[achievement.code];
      if (progress == null) return false;
      final required =
          achievement.requiredCount > 0 ? achievement.requiredCount : 1;
      return progress.isCompleted || progress.currentProgress >= required;
    }).length;

    int maxProgressForCategory(Set<String> categories) {
      var maxProgress = 0;
      for (final achievement in achievements) {
        if (!categories.contains(achievement.category.toLowerCase())) {
          continue;
        }
        final progress = progressById[achievement.code]?.currentProgress ?? 0;
        if (progress > maxProgress) {
          maxProgress = progress;
        }
      }
      return maxProgress;
    }

    final discoveryCount = maxProgressForCategory({'discovery'});
    final arViews = maxProgressForCategory({'ar'});
    final eventCount = maxProgressForCategory({'events'});

    final roles = KubusColorRoles.of(context);
    final total = achievements.length;

    // Flat record of participation: a progress line, four plain counts and a
    // readable list. No glass, no tinted tiles, no watermark icons.
    return Scaffold(
      backgroundColor: roles.ground,
      appBar: AppBar(
        backgroundColor: roles.ground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: roles.rule, width: KubusSizes.hairline),
        ),
        title: Text(
          l10n.userProfileAchievementsTitle,
          style: KubusTextStyles.mobileAppBarTitle.copyWith(
            color: roles.foreground,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAchievements,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              children: [
                Text(
                  l10n.userProfileAchievementsProgressLabel(
                    completedCount,
                    total,
                  ),
                  style: KubusTextStyles.machineValue.copyWith(
                    color: roles.foregroundMuted,
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                ExcludeSemantics(
                  child: KubusMeterBar(
                    progress: total == 0 ? 0 : completedCount / total,
                    height: 4,
                    color: roles.active,
                    trackColor: roles.rule,
                  ),
                ),
                const SizedBox(height: KubusSpacing.lg),
                _buildStatsHeader(
                  l10n: l10n,
                  discoveryCount: discoveryCount,
                  arViews: arViews,
                  eventCount: eventCount,
                ),
                const SizedBox(height: KubusSpacing.xl),
                _buildAchievementsList(
                  l10n: l10n,
                  achievements: achievements,
                  progressById: progressById,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsHeader({
    required AppLocalizations l10n,
    required int discoveryCount,
    required int arViews,
    required int eventCount,
  }) {
    final stats = <(String, String)>[
      (
        l10n.desktopSettingsAchievementsStatArtworksDiscovered,
        discoveryCount.toString(),
      ),
      (l10n.desktopSettingsAchievementsStatArViews, arViews.toString()),
      (
        l10n.desktopSettingsAchievementsStatEventsAttended,
        eventCount.toString(),
      ),
      (
        l10n.achievementsStatKub8Earned,
        _isLoadingTokens ? '…' : _totalTokens.toString(),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        final cellWidth =
            (constraints.maxWidth - KubusSpacing.sm * (columns - 1)) / columns;
        return Wrap(
          spacing: KubusSpacing.sm,
          runSpacing: KubusSpacing.sm,
          children: [
            for (final stat in stats)
              SizedBox(
                width: cellWidth,
                child: _AchievementStat(label: stat.$1, value: stat.$2),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAchievementsList({
    required AppLocalizations l10n,
    required List<backend_achievements.AchievementDefinition> achievements,
    required Map<String, AchievementProgress> progressById,
  }) {
    if (achievements.isEmpty) {
      return const SizedBox.shrink();
    }
    final roles = KubusColorRoles.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: roles.surface,
        borderRadius: BorderRadius.circular(KubusRadius.surface),
        border: Border.all(color: roles.rule, width: KubusSizes.hairline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < achievements.length; i++) ...[
            if (i > 0)
              Divider(
                height: KubusSizes.hairline,
                thickness: KubusSizes.hairline,
                color: roles.rule,
              ),
            _buildAchievementRow(
              achievement: achievements[i],
              progress: progressById[achievements[i].code] ??
                  AchievementProgress(
                    achievementId: achievements[i].code,
                    currentProgress: 0,
                    isCompleted: false,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAchievementRow({
    required backend_achievements.AchievementDefinition achievement,
    required AchievementProgress progress,
  }) {
    final roles = KubusColorRoles.of(context);
    final textTheme = Theme.of(context).textTheme;
    final required =
        achievement.requiredCount > 0 ? achievement.requiredCount : 1;
    final isUnlocked =
        progress.isCompleted || progress.currentProgress >= required;
    // Name KUB8 only when this achievement actually carries a KUB8 reward.
    final l10n = AppLocalizations.of(context)!;
    final progressLabel = !isUnlocked
        ? '${progress.currentProgress}/$required'
        : achievement.kub8Reward > 0
            ? '+${achievement.kub8Reward.round()} KUB8'
            : l10n.achievementUnlockedLabel;
    final description = achievement.description.trim();
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.md,
          vertical: KubusSpacing.sm + KubusSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: KubusSpacing.xxs),
              child: Icon(
                isUnlocked
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                size: 20,
                color: isUnlocked ? roles.success : roles.foregroundSubtle,
              ),
            ),
            const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: textTheme.titleSmall?.copyWith(
                      color: roles.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: KubusSpacing.xxs),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: roles.foregroundMuted,
                      ),
                    ),
                  ],
                  if (!isUnlocked && required > 1) ...[
                    const SizedBox(height: KubusSpacing.sm),
                    ExcludeSemantics(
                      child: KubusMeterBar(
                        progress: progress.currentProgress / required,
                        height: 3,
                        color: roles.foregroundMuted,
                        trackColor: roles.rule,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: KubusSpacing.sm),
            Text(
              progressLabel,
              style: KubusTextStyles.machineValue.copyWith(
                color: isUnlocked ? roles.foreground : roles.foregroundMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One plain count: machine-register value over a muted label.
class _AchievementStat extends StatelessWidget {
  const _AchievementStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
        decoration: BoxDecoration(
          color: roles.surface,
          borderRadius: BorderRadius.circular(KubusRadius.surface),
          border: Border.all(color: roles.rule, width: KubusSizes.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: KubusTextStyles.machineValue.copyWith(
                fontSize: 20,
                color: roles.foreground,
              ),
            ),
            const SizedBox(height: KubusSpacing.xs),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: roles.foregroundMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
