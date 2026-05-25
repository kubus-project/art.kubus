import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/achievement_progress.dart' as legacy;
import '../../models/achievements.dart' as backend;
import '../../providers/profile_provider.dart';
import '../../providers/task_provider.dart';
import '../../screens/web3/achievements/achievements_page.dart';
import '../../utils/achievement_ui.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/common/kubus_stat_card.dart';
import '../../widgets/empty_state_card.dart';

enum ProfileAchievementsPreviewMode {
  ownProfile,
  publicProfile,
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
    this.showWhenEmpty = true,
    this.padding,
  });

  final ProfileAchievementsPreviewMode mode;
  final bool compact;
  final int limit;
  final VoidCallback? onViewAll;
  final List<legacy.AchievementProgress>? publicProgress;
  final List<backend.AchievementDefinition>? publicDefinitions;
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
            final items = _ownProfileItems(taskProvider);
            return _buildSection(context, items);
          },
        );
      case ProfileAchievementsPreviewMode.publicProfile:
        final items = _publicProfileItems();
        return _buildSection(context, items);
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

  List<AchievementPreviewItem> _publicProfileItems() {
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
        title: _humanizeCode(item.achievementId),
        description: '',
        category: 'general',
        rarity: 'common',
        currentProgress: item.currentProgress,
        requiredCount: required,
        isCompleted: item.isCompleted,
        hasRequiredCount: false,
      );
    }).toList(growable: false);
  }

  Widget _buildSection(
      BuildContext context, List<AchievementPreviewItem> items) {
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
        if (items.isEmpty)
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
              child: _AchievementPreviewCard(
                item: item,
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

  static String _humanizeCode(String code) {
    final normalized = code.trim().replaceAll(RegExp(r'[_-]+'), ' ');
    if (normalized.isEmpty) return 'Achievement';
    return normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _AchievementPreviewCard extends StatelessWidget {
  const _AchievementPreviewCard({
    required this.item,
    required this.compact,
  });

  final AchievementPreviewItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final required = item.requiredCount > 0 ? item.requiredCount : 1;
    final completed = item.hasRequiredCount
        ? item.isCompleted || item.currentProgress >= required
        : item.isCompleted;
    final reward = item.kub8Reward;
    final l10n = AppLocalizations.of(context)!;
    final value = completed && reward != null && reward > 0
        ? '+${_formatReward(reward)} ${item.rewardCurrency}'
        : item.hasRequiredCount
            ? '${item.currentProgress}/$required'
            : (completed
                ? l10n.userProfileAchievementCompletedLabel
                : item.currentProgress.toString());
    final accent = AchievementUi.accentForPreview(
      context,
      category: item.category,
      rarity: item.rarity,
    );

    return KubusStatCard(
      title: item.title,
      value: value,
      icon: AchievementUi.iconForPreview(
        code: item.code,
        category: item.category,
      ),
      layout: KubusStatCardLayout.centered,
      accent: accent,
      centeredWatermarkAlignment: Alignment.center,
      centeredWatermarkScale: 0.84,
      minHeight: compact ? 96 : 104,
      padding: EdgeInsets.all(compact ? KubusSpacing.sm : KubusSpacing.md),
      titleMaxLines: 2,
      titleStyle: KubusTextStyles.detailCaption.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: completed ? 0.84 : 0.7),
      ),
      valueStyle: KubusTextStyles.detailCardTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  String _formatReward(double reward) {
    if (reward == reward.roundToDouble()) return reward.round().toString();
    return reward.toStringAsFixed(2);
  }
}
