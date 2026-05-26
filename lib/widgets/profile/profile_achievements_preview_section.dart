import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/achievement_progress.dart' as legacy;
import '../../models/achievements.dart' as backend;
import '../../providers/profile_provider.dart';
import '../../providers/task_provider.dart';
import '../../screens/web3/achievements/achievements_page.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/achievement/achievement_stat_card.dart';
import '../../widgets/empty_state_card.dart';

enum ProfileAchievementsPreviewMode {
  ownProfile,
  publicProfile,
}

enum AchievementPreviewDataState {
  loading,
  ready,
  fallback,
  unavailable,
}

class AchievementPreviewItem {
  const AchievementPreviewItem({
    required this.code,
    required this.title,
    required this.description,
    required this.category,
    required this.rarity,
    required this.currentProgress,
    required this.requiredCount,
    required this.isCompleted,
    this.hasRequiredCount = true,
    this.kub8Reward,
    this.rewardCurrency = 'KUB8',
    this.subdued = false,
  });

  final String code;
  final String title;
  final String description;
  final String category;
  final String rarity;
  final int currentProgress;
  final int requiredCount;
  final bool isCompleted;
  final bool hasRequiredCount;
  final double? kub8Reward;
  final String rewardCurrency;
  final bool subdued;
}

class ProfileAchievementsPreviewSection extends StatelessWidget {
  const ProfileAchievementsPreviewSection({
    super.key,
    required this.mode,
    this.compact = false,
    this.limit = 6,
    this.onViewAll,
    this.publicProgress,
    this.publicDefinitions,
    this.dataState = AchievementPreviewDataState.ready,
    this.showWhenEmpty = true,
    this.padding,
  });

  final ProfileAchievementsPreviewMode mode;
  final bool compact;
  final int limit;
  final VoidCallback? onViewAll;
  final List<legacy.AchievementProgress>? publicProgress;
  final List<backend.AchievementDefinition>? publicDefinitions;
  final AchievementPreviewDataState dataState;
  final bool showWhenEmpty;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case ProfileAchievementsPreviewMode.ownProfile:
        return Consumer2<TaskProvider, ProfileProvider>(
          builder: (context, taskProvider, profileProvider, _) {
            if (!profileProvider.preferences.showAchievements) {
              return const SizedBox.shrink();
            }
            if (!taskProvider.hasBackendAchievementDefinitions) {
              if (taskProvider.achievementHydrationStatus ==
                      AchievementHydrationStatus.loading ||
                  taskProvider.achievementHydrationStatus ==
                      AchievementHydrationStatus.idle) {
                return _buildSection(
                  context,
                  const <AchievementPreviewItem>[],
                  state: AchievementPreviewDataState.loading,
                );
              }
              if (taskProvider.achievementHydrationStatus ==
                  AchievementHydrationStatus.failed) {
                return _buildSection(
                  context,
                  const <AchievementPreviewItem>[],
                  state: AchievementPreviewDataState.unavailable,
                );
              }
            }
            final items = _ownProfileItems(taskProvider);
            return _buildSection(context, items);
          },
        );
      case ProfileAchievementsPreviewMode.publicProfile:
        if (dataState == AchievementPreviewDataState.loading ||
            dataState == AchievementPreviewDataState.unavailable) {
          return _buildSection(
            context,
            const <AchievementPreviewItem>[],
            state: dataState,
          );
        }
        final l10n = AppLocalizations.of(context)!;
        final items = _publicProfileItems(
          progressOnlyTitle: l10n.profileAchievementsProgressOnlyTitle,
          isFallback: dataState == AchievementPreviewDataState.fallback,
        );
        return _buildSection(context, items, state: dataState);
    }
  }

  List<AchievementPreviewItem> _ownProfileItems(TaskProvider taskProvider) {
    final definitions =
        taskProvider.achievementDefinitions.take(limit).toList();
    final progressById = <String, legacy.AchievementProgress>{
      for (final progress in taskProvider.achievementProgress)
        progress.achievementId: progress,
    };
    final rewardsAreBackendOwned =
        taskProvider.hasBackendAchievementDefinitions;

    return definitions.map((definition) {
      final required =
          definition.requiredCount > 0 ? definition.requiredCount : 1;
      final progress = progressById[definition.code];
      final currentProgress = progress?.currentProgress ?? 0;
      final isCompleted =
          progress?.isCompleted == true || currentProgress >= required;
      return AchievementPreviewItem(
        code: definition.code,
        title: definition.title,
        description: definition.description,
        category: definition.category,
        rarity: definition.rarity,
        currentProgress: currentProgress,
        requiredCount: required,
        isCompleted: isCompleted,
        kub8Reward: rewardsAreBackendOwned ? definition.kub8Reward : null,
      );
    }).toList(growable: false);
  }

  List<AchievementPreviewItem> _publicProfileItems({
    required String progressOnlyTitle,
    required bool isFallback,
  }) {
    final progress = publicProgress ?? const <legacy.AchievementProgress>[];
    final definitionsByCode = <String, backend.AchievementDefinition>{
      for (final definition
          in publicDefinitions ?? const <backend.AchievementDefinition>[])
        definition.code: definition,
    };

    if (definitionsByCode.isNotEmpty) {
      final progressById = <String, legacy.AchievementProgress>{
        for (final item in progress) item.achievementId: item,
      };
      return definitionsByCode.values.take(limit).map((definition) {
        final required =
            definition.requiredCount > 0 ? definition.requiredCount : 1;
        final item = progressById[definition.code];
        final currentProgress = item?.currentProgress ?? 0;
        final isCompleted =
            item?.isCompleted == true || currentProgress >= required;
        return AchievementPreviewItem(
          code: definition.code,
          title: definition.title,
          description: definition.description,
          category: definition.category,
          rarity: definition.rarity,
          currentProgress: currentProgress,
          requiredCount: required,
          isCompleted: isCompleted,
          kub8Reward: definition.kub8Reward,
        );
      }).toList(growable: false);
    }

    return progress.take(limit).map((item) {
      final required = item.isCompleted
          ? (item.currentProgress > 0 ? item.currentProgress : 1)
          : (item.currentProgress > 0 ? item.currentProgress : 1);
      return AchievementPreviewItem(
        code: item.achievementId,
        title: progressOnlyTitle,
        description: '',
        category: 'general',
        rarity: 'common',
        currentProgress: item.currentProgress,
        requiredCount: required,
        isCompleted: item.isCompleted,
        hasRequiredCount: false,
        subdued: isFallback,
      );
    }).toList(growable: false);
  }

  Widget _buildSection(
    BuildContext context,
    List<AchievementPreviewItem> items, {
    AchievementPreviewDataState state = AchievementPreviewDataState.ready,
  }) {
    if (items.isEmpty && !showWhenEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.profileAchievementsPreviewTitle,
                    style: KubusTextStyles.detailCardTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: compact ? 17 : 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.xxs),
                  Text(
                    l10n.profileAchievementsPreviewSubtitle,
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
            if (mode == ProfileAchievementsPreviewMode.ownProfile)
              TextButton.icon(
                onPressed: onViewAll ?? () => _openAchievementsPage(context),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(l10n.commonViewAll),
              ),
          ],
        ),
        SizedBox(height: compact ? KubusSpacing.md : KubusSpacing.lg),
        if (state == AchievementPreviewDataState.loading)
          _buildLoadingGrid(context)
        else if (state == AchievementPreviewDataState.unavailable)
          EmptyStateCard(
            title: l10n.profileAchievementsUnavailableTitle,
            description: l10n.profileAchievementsUnavailableDescription,
            icon: Icons.emoji_events_outlined,
          )
        else if (items.isEmpty)
          EmptyStateCard(
            title: l10n.profileAchievementsEmptyTitle,
            description: l10n.userProfileAchievementsEmptyDescription,
            icon: Icons.emoji_events_outlined,
          )
        else
          _buildPreviewGrid(context, items),
      ],
    );

    final resolvedPadding = padding;
    if (resolvedPadding == null) return content;
    return Padding(
      padding: resolvedPadding,
      child: content,
    );
  }

  Widget _buildPreviewGrid(
    BuildContext context,
    List<AchievementPreviewItem> items,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final minCardWidth = compact ? 132.0 : 156.0;
        final cardWidth = availableWidth < 420
            ? ((availableWidth - KubusSpacing.md) / 2)
            : minCardWidth;

        return Wrap(
          spacing: KubusSpacing.md,
          runSpacing: KubusSpacing.md,
          children: items.map((item) {
            return SizedBox(
              width: cardWidth,
              child: AchievementStatCard(
                data: item.toStatCardData(context),
                compact: compact,
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  void _openAchievementsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AchievementsPage()),
    );
  }

  Widget _buildLoadingGrid(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final minCardWidth = compact ? 132.0 : 156.0;
        final cardWidth = availableWidth < 420
            ? ((availableWidth - KubusSpacing.md) / 2)
            : minCardWidth;

        return Wrap(
          key: const ValueKey<String>('profile-achievements-loading'),
          spacing: KubusSpacing.md,
          runSpacing: KubusSpacing.md,
          children: List<Widget>.generate(3, (index) {
            return Container(
              width: cardWidth,
              height: compact ? 96 : 104,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(KubusRadius.md),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.08),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

extension on AchievementPreviewItem {
  AchievementStatCardData toStatCardData(BuildContext context) {
    final required = requiredCount > 0 ? requiredCount : 1;
    final completed = hasRequiredCount
        ? isCompleted || currentProgress >= required
        : isCompleted;
    final reward = kub8Reward;
    final l10n = AppLocalizations.of(context)!;
    final value = completed && reward != null && reward > 0
        ? '+${_formatReward(reward)} $rewardCurrency'
        : hasRequiredCount
            ? '$currentProgress/$required'
            : (completed
                ? l10n.userProfileAchievementCompletedLabel
                : currentProgress.toString());

    return AchievementStatCardData(
      code: code,
      title: title,
      category: category,
      rarity: rarity,
      value: value,
      isCompleted: completed,
      subdued: subdued,
    );
  }

  String _formatReward(double reward) {
    if (reward == reward.roundToDouble()) return reward.round().toString();
    return reward.toStringAsFixed(2);
  }
}
