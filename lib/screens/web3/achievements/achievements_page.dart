import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/models/achievement_progress.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/services/achievement_service.dart' as achievement_svc;
import 'package:art_kubus/utils/category_accent_color.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/inline_loading.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    final achievements =
        achievement_svc.AchievementService.achievementDefinitions.values.toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          'Achievements & POAPs',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
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
      final required = achievement.requiredCount > 0 ? achievement.requiredCount : 1;
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
    final accentSecondary = Color.lerp(accentPrimary, scheme.primary, 0.25) ??
        scheme.primary;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentPrimary, accentSecondary],
        ),
        borderRadius: BorderRadius.circular(16),
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
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Collect POAPs and unlock KUB8 rewards',
                      style: GoogleFonts.inter(
                        fontSize: 14,
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
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: scheme.onPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
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

  String _categoryFor(achievement_svc.AchievementDefinition achievement) {
    if (achievement.isPOAP) return 'Events';
    switch (achievement.type) {
      case achievement_svc.AchievementType.firstDiscovery:
      case achievement_svc.AchievementType.artExplorer:
      case achievement_svc.AchievementType.artMaster:
      case achievement_svc.AchievementType.artLegend:
        return 'Discovery';
      case achievement_svc.AchievementType.firstARView:
      case achievement_svc.AchievementType.arEnthusiast:
      case achievement_svc.AchievementType.arPro:
        return 'AR';
      case achievement_svc.AchievementType.firstNFTMint:
      case achievement_svc.AchievementType.nftCollector:
      case achievement_svc.AchievementType.nftTrader:
        return 'NFT';
      case achievement_svc.AchievementType.firstPost:
      case achievement_svc.AchievementType.influencer:
      case achievement_svc.AchievementType.communityBuilder:
        return 'Community';
      case achievement_svc.AchievementType.firstLike:
      case achievement_svc.AchievementType.popularCreator:
      case achievement_svc.AchievementType.firstComment:
      case achievement_svc.AchievementType.commentator:
        return 'Social';
      case achievement_svc.AchievementType.firstTrade:
      case achievement_svc.AchievementType.smartTrader:
      case achievement_svc.AchievementType.marketMaster:
        return 'Trading';
      case achievement_svc.AchievementType.earlyAdopter:
      case achievement_svc.AchievementType.betaTester:
      case achievement_svc.AchievementType.artSupporter:
        return 'Special';
      case achievement_svc.AchievementType.eventAttendee:
      case achievement_svc.AchievementType.galleryVisitor:
      case achievement_svc.AchievementType.workshopParticipant:
        return 'Events';
    }
  }

  IconData _iconFor(achievement_svc.AchievementDefinition achievement) {
    if (achievement.isPOAP) return Icons.verified;
    switch (achievement.type) {
      case achievement_svc.AchievementType.firstDiscovery:
      case achievement_svc.AchievementType.artExplorer:
      case achievement_svc.AchievementType.artMaster:
      case achievement_svc.AchievementType.artLegend:
        return Icons.explore_outlined;
      case achievement_svc.AchievementType.firstARView:
      case achievement_svc.AchievementType.arEnthusiast:
      case achievement_svc.AchievementType.arPro:
        return Icons.view_in_ar;
      case achievement_svc.AchievementType.firstNFTMint:
      case achievement_svc.AchievementType.nftCollector:
      case achievement_svc.AchievementType.nftTrader:
        return Icons.token;
      case achievement_svc.AchievementType.firstPost:
      case achievement_svc.AchievementType.influencer:
      case achievement_svc.AchievementType.communityBuilder:
        return Icons.forum_outlined;
      case achievement_svc.AchievementType.firstLike:
      case achievement_svc.AchievementType.popularCreator:
        return Icons.favorite_border;
      case achievement_svc.AchievementType.firstComment:
      case achievement_svc.AchievementType.commentator:
        return Icons.chat_bubble_outline;
      case achievement_svc.AchievementType.firstTrade:
      case achievement_svc.AchievementType.smartTrader:
      case achievement_svc.AchievementType.marketMaster:
        return Icons.swap_horiz;
      case achievement_svc.AchievementType.earlyAdopter:
      case achievement_svc.AchievementType.betaTester:
      case achievement_svc.AchievementType.artSupporter:
        return Icons.auto_awesome;
      case achievement_svc.AchievementType.eventAttendee:
      case achievement_svc.AchievementType.galleryVisitor:
      case achievement_svc.AchievementType.workshopParticipant:
        return Icons.event_available;
    }
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
    final category = _categoryFor(achievement);
    final accent = CategoryAccentColor.resolve(context, category);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
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
              _iconFor(achievement),
              color: isUnlocked ? accent : scheme.onSurface.withValues(alpha: 0.4),
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: Text(
              achievement.title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
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
              style: GoogleFonts.inter(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: isUnlocked ? 0.8 : 0.6),
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
              style: GoogleFonts.inter(
                fontSize: 10,
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                achievement.isPOAP ? 'POAP' : 'UNLOCKED',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
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
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

