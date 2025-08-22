import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Achievements & POAPs',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9C27B0), Color(0xFF6C63FF)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
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
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsList() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return _buildAchievementCard(index);
      },
    );
  }

  Widget _buildAchievementCard(int index) {
    final achievements = [
      {
        'title': 'First AR Visit',
        'description': 'Visited your first AR artwork',
        'icon': Icons.visibility,
        'color': const Color(0xFF6C63FF),
        'unlocked': true,
      },
      {
        'title': 'Art Collector',
        'description': 'Collected 5 unique artworks',
        'icon': Icons.collections,
        'color': const Color(0xFF9C27B0),
        'unlocked': true,
      },
      {
        'title': 'Gallery Explorer',
        'description': 'Visited 10 different galleries',
        'icon': Icons.explore,
        'color': const Color(0xFF00D4AA),
        'unlocked': false,
      },
      {
        'title': 'Community Member',
        'description': 'Participated in DAO voting',
        'icon': Icons.how_to_vote,
        'color': const Color(0xFF4CAF50),
        'unlocked': true,
      },
    ];

    final achievement = achievements[index % achievements.length];
    final isUnlocked = achievement['unlocked'] as bool;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked 
              ? (achievement['color'] as Color)
              : Colors.grey[800]!,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isUnlocked 
                  ? (achievement['color'] as Color).withOpacity(0.1)
                  : Colors.grey[800]!.withOpacity(0.3),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              achievement['icon'] as IconData,
              color: isUnlocked 
                  ? (achievement['color'] as Color)
                  : Colors.grey[600],
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            achievement['title'] as String,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isUnlocked ? Colors.white : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            achievement['description'] as String,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isUnlocked ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (isUnlocked) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (achievement['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'UNLOCKED',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: achievement['color'] as Color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
