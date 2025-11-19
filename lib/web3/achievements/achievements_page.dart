import 'package:art_kubus/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/achievements.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/inline_loading.dart';
import '../../services/achievement_service.dart' as new_service;

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  late List<AchievementProgress> _userProgress;
  int _totalTokens = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeUserProgress();
  }

  Future<void> _initializeUserProgress() async {
    setState(() => _isLoading = true);
    
    // Get token balance from new achievement service
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'demo_user';
    
    try {
      // Get actual unlocked achievements from new service
      final unlockedAchievements = await new_service.AchievementService().getUnlockedAchievements(userId);
      _totalTokens = await new_service.AchievementService().getTotalEarnedTokens(userId);
      
      // Convert new service achievements to old format for UI compatibility
      _userProgress = unlockedAchievements.map((achievement) {
        return AchievementProgress(
          achievementId: _mapNewToOldAchievementId(achievement.id),
          currentProgress: 1,
          isCompleted: true,
          completedDate: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading achievements: $e');
      _userProgress = [];
      _totalTokens = 0;
    }
    
    setState(() => _isLoading = false);
  }
  
  // Map new achievement IDs to old UI format
  String _mapNewToOldAchievementId(String newId) {
    final mapping = {
      'first_discovery': 'first_ar_visit',
      'art_explorer': 'ar_collector',
      'first_ar_view': 'first_ar_visit',
      'ar_enthusiast': 'ar_collector',
      'first_post': 'community_member',
      'first_like': 'first_favorite',
      'first_comment': 'art_critic',
    };
    return mapping[newId] ?? newId;
  }

  @override
  Widget build(BuildContext context) {
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
      body: _isLoading
        ? const AppLoading()
            : Column(
                children: [
                  _buildStatsHeader(),
                  Expanded(child: _buildAchievementsList()),
                ],
              ),
    );
  }

  Widget _buildStatsHeader() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final completedCount = _userProgress.where((p) => p.isCompleted).length;
    final completionPercentage = completedCount / allAchievements.length * 100;

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
                child: _buildStatItem('KUB8 Tokens', '$_totalTokens'),
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
        final achievement = getAchievementById(progress.achievementId);
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
                color: isUnlocked ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                color: isUnlocked ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                  color: achievement.color,
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





