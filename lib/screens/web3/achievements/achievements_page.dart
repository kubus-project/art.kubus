import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/achievement_progress.dart';
import 'package:art_kubus/models/achievements.dart' as backend_achievements;
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/utils/achievement_ui.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:art_kubus/widgets/detail/shared_section_widgets.dart';
import 'package:art_kubus/widgets/glass_components.dart';
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
      setState(() => _totalTokens =
          context.read<TaskProvider>().totalKub8Earned.round());
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.userProfileAchievementsTitle,
          style: KubusTextStyles.mobileAppBarTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAchievements,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1680),
            child: ListView(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              children: [
                LiquidGlassCard(
                  padding: const EdgeInsets.all(KubusChromeMetrics.cardPadding),
                  borderRadius: BorderRadius.circular(KubusRadius.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SharedSectionHeader(
                        title: l10n.userProfileAchievementsTitle,
                        subtitle: l10n.userProfileAchievementsProgressLabel(
                          completedCount,
                          achievements.length,
                        ),
                        icon: Icons.emoji_events_outlined,
                        iconColor: KubusColorRoles.of(context).achievementGold,
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: KubusSpacing.md),
                      _buildStatsHeader(
                        l10n: l10n,
                        discoveryCount: discoveryCount,
                        arViews: arViews,
                        eventCount: eventCount,
                      ),
                    ],
                  ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 900
            ? (constraints.maxWidth - (KubusSpacing.md * 3)) / 4
            : (constraints.maxWidth - KubusSpacing.md) / 2;

        return Wrap(
          spacing: KubusSpacing.md,
          runSpacing: KubusSpacing.md,
          children: [
            SizedBox(
              width: cardWidth,
              child: KubusStatCard(
                title: l10n.desktopSettingsAchievementsStatArtworksDiscovered,
                value: discoveryCount.toString(),
                icon: Icons.explore_outlined,
                layout: KubusStatCardLayout.centered,
                accent: KubusColorRoles.of(context).statBlue,
                centeredWatermarkAlignment: Alignment.center,
                centeredWatermarkScale: 0.84,
                minHeight: 0,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: KubusStatCard(
                title: l10n.desktopSettingsAchievementsStatArViews,
                value: arViews.toString(),
                icon: Icons.view_in_ar,
                layout: KubusStatCardLayout.centered,
                accent: KubusColorRoles.of(context).statTeal,
                centeredWatermarkAlignment: Alignment.center,
                centeredWatermarkScale: 0.84,
                minHeight: 0,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: KubusStatCard(
                title: l10n.desktopSettingsAchievementsStatEventsAttended,
                value: eventCount.toString(),
                icon: Icons.event_available,
                layout: KubusStatCardLayout.centered,
                accent: KubusColorRoles.of(context).web3InstitutionAccent,
                centeredWatermarkAlignment: Alignment.center,
                centeredWatermarkScale: 0.84,
                minHeight: 0,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: KubusStatCard(
                title: l10n.desktopSettingsAchievementsStatKub8PointsEarned,
                value: _isLoadingTokens ? '...' : _totalTokens.toString(),
                icon: Icons.token,
                layout: KubusStatCardLayout.centered,
                accent: KubusColorRoles.of(context).web3MarketplaceAccent,
                centeredWatermarkAlignment: Alignment.center,
                centeredWatermarkScale: 0.84,
                minHeight: 0,
              ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
      final crossAxisCount = width >= 1780
        ? 6
        : width >= 1480
          ? 5
          : width >= 1160
            ? 4
            : width >= 860
              ? 3
              : width >= 520
                ? 2
                : 1;
      final crossSpacing =
        width >= 1480 ? KubusSpacing.lg : KubusSpacing.md;
      final mainSpacing =
        width >= 1480 ? KubusSpacing.lg : KubusSpacing.md;
      final cardWidth =
        (width - (crossSpacing * (crossAxisCount - 1))) / crossAxisCount;
      final childAspectRatio = crossAxisCount == 1
        ? 2.45
        : (cardWidth >= 280 ? 1.12 : 1.22);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossSpacing,
        mainAxisSpacing: mainSpacing,
        childAspectRatio: childAspectRatio,
          ),
          itemCount: achievements.length,
          itemBuilder: (context, index) {
            final achievement = achievements[index];
            final progress = progressById[achievement.code] ??
                AchievementProgress(
                  achievementId: achievement.code,
                  currentProgress: 0,
                  isCompleted: false,
                );
            return _buildAchievementCard(
              achievement: achievement,
              progress: progress,
              cardWidth: cardWidth,
            );
          },
        );
      },
    );
  }

  Widget _buildAchievementCard({
    required backend_achievements.AchievementDefinition achievement,
    required AchievementProgress progress,
    required double cardWidth,
  }) {
    final required =
        achievement.requiredCount > 0 ? achievement.requiredCount : 1;
    final isUnlocked = progress.isCompleted || progress.currentProgress >= required;
    final progressLabel = isUnlocked
        ? '+${achievement.kub8Reward.round()} KUB8'
        : '${progress.currentProgress}/$required';
    final accent = AchievementUi.accentFor(context, achievement);
    final roomyCard = cardWidth >= 280;
    final compactCard = cardWidth < 220;

    return KubusStatCard(
      title: achievement.title,
      value: progressLabel,
      icon: AchievementUi.iconFor(achievement),
      layout: KubusStatCardLayout.centered,
      accent: accent,
      centeredWatermarkAlignment: Alignment.center,
      centeredWatermarkScale: compactCard ? 0.80 : 0.84,
      minHeight: 0,
      padding: EdgeInsets.all(
        roomyCard ? KubusChromeMetrics.cardPadding : KubusSpacing.md,
      ),
      titleMaxLines: roomyCard ? 3 : 2,
      titleStyle: KubusTextStyles.detailCaption.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: roomyCard ? 13 : 12,
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: isUnlocked ? 0.84 : 0.7),
      ),
      valueStyle: KubusTextStyles.detailCardTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: roomyCard ? 15 : 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
