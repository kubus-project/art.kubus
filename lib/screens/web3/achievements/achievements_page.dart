import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/achievements.dart';
import '../../../utils/category_accent_color.dart';
import '../../../widgets/inline_loading.dart';
import '../../../services/achievement_service.dart' as achievement_svc;

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
      final tokens = await achievement_svc.AchievementService().getTotalEarnedTokens();
      if (!mounted) return;
      setState(() => _totalTokens = tokens);
    } catch (e) {
      debugPrint('AchievementsPage: Failed to load token balance: $e');
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          _buildStatsHeader(progressById),
          Expanded(child: _buildAchievementsList(progressById)),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(Map<String, AchievementProgress> progressById) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final completedCount = allAchievements.where((achievement) {
      final progress = progressById[achievement.id];
      final required = achievement.requiredProgress > 0 ? achievement.requiredProgress : 1;
      final ratio = ((progress?.currentProgress ?? 0) / required).clamp(0.0, 1.0);
      return (progress?.isCompleted ?? false) || ratio >= 1.0;
    }).length;
    final completionPercentage =
        allAchievements.isEmpty ? 0.0 : (completedCount / allAchievements.length * 100);

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [themeProvider.accentColor, themeProvider.accentColor.withValues(alpha: 0.7)],
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
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: Colors.white,
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
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Collect POAPs and unlock KUB8 token rewards',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
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
                child: _buildStatItem('Completed', '$completedCount/${allAchievements.length}'),
              ),
              Expanded(
                child: _buildStatItem(
                  'KUB8 Tokens',
                  _isLoadingTokens ? '…' : '$_totalTokens',
                ),
              ),
              Expanded(
                child: _buildStatItem('Progress', '${completionPercentage.toInt()}%'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final onAccent = themeProvider.onAccentColor;
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: onAccent,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: onAccent.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsList(Map<String, AchievementProgress> progressById) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: allAchievements.length,
      itemBuilder: (context, index) {
        final achievement = allAchievements[index];
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

  Widget _buildAchievementCard(Achievement achievement, AchievementProgress progress) {
    final required = achievement.requiredProgress > 0 ? achievement.requiredProgress : 1;
    final progressPercent = (progress.currentProgress / required).clamp(0.0, 1.0);
    final isUnlocked = progress.isCompleted || progressPercent >= 1.0;
    final scheme = Theme.of(context).colorScheme;
    final accent = CategoryAccentColor.resolve(context, achievement.category);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked 
              ? accent
              : scheme.outline,
        ),
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
              achievement.icon,
              color: isUnlocked 
                  ? accent
                  : scheme.onSurface.withValues(alpha: 0.4),
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
          if (!isUnlocked && achievement.requiredProgress > 1) ...[
            Text(
              '${progress.currentProgress}/${achievement.requiredProgress}',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                'UNLOCKED',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.monetization_on, size: 12, color: accent),
              const SizedBox(width: 2),
              Text(
                '${achievement.points}',
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



