import 'package:art_kubus/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/achievements.dart';
import '../../providers/mockup_data_provider.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  late List<AchievementProgress> _userProgress;

  @override
  void initState() {
    super.initState();
    _initializeUserProgress();
  }

  void _initializeUserProgress() {
    final mockupProvider = Provider.of<MockupDataProvider>(context, listen: false);
    
    if (mockupProvider.isMockDataEnabled) {
      // Enhanced mock data for testing
      _userProgress = [
        const AchievementProgress(achievementId: 'first_ar_visit', currentProgress: 1, isCompleted: true),
        const AchievementProgress(achievementId: 'ar_collector', currentProgress: 12, isCompleted: true),
        const AchievementProgress(achievementId: 'gallery_explorer', currentProgress: 8, isCompleted: true),
        const AchievementProgress(achievementId: 'community_member', currentProgress: 1, isCompleted: true),
        const AchievementProgress(achievementId: 'first_favorite', currentProgress: 1, isCompleted: true),
        const AchievementProgress(achievementId: 'art_critic', currentProgress: 25, isCompleted: true),
        const AchievementProgress(achievementId: 'social_butterfly', currentProgress: 50, isCompleted: true),
        const AchievementProgress(achievementId: 'early_adopter', currentProgress: 1, isCompleted: true),
      ];
    } else {
      // No mock data - empty achievements when disabled
      _userProgress = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MockupDataProvider>(
      builder: (context, mockupProvider, child) {
        // Reinitialize when mock data setting changes
        _initializeUserProgress();
        
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
              _buildStatsHeader(),
              Expanded(child: _buildAchievementsList()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsHeader() {
    final completedCount = _userProgress.where((p) => p.isCompleted).length;
    final totalPoints = AchievementService.calculateTotalPoints(_userProgress);
    final completionPercentage = AchievementService.getOverallCompletionPercentage(_userProgress);

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9C27B0), Provider.of<ThemeProvider>(context).accentColor],
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
                      'Collect POAPs and unlock rewards for your AR art journey',
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
                child: _buildStatItem('Completed', '$completedCount/${AchievementService.allAchievements.length}'),
              ),
              Expanded(
                child: _buildStatItem('Points', '$totalPoints'),
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
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsList() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _userProgress.length,
      itemBuilder: (context, index) {
        final progress = _userProgress[index];
        final achievement = AchievementService.getAchievementById(progress.achievementId);
        if (achievement != null) {
          return _buildAchievementCard(achievement, progress);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAchievementCard(Achievement achievement, AchievementProgress progress) {
    final isUnlocked = progress.isCompleted;
    final progressPercent = progress.progressPercentage;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked 
              ? achievement.color
              : Theme.of(context).colorScheme.outline,
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
                  ? achievement.color.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              achievement.icon,
              color: isUnlocked 
                  ? achievement.color
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
                color: isUnlocked ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                color: isUnlocked ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.8) : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
            LinearProgressIndicator(
              value: progressPercent,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(achievement.color),
              minHeight: 3,
            ),
          ],
          if (isUnlocked) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: achievement.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'UNLOCKED',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: achievement.color,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.monetization_on,
                size: 12,
                color: Colors.amber,
              ),
              const SizedBox(width: 2),
              Text(
                '${achievement.points}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}




