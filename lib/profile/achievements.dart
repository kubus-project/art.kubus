import 'package:flutter/material.dart';

class Achievement {
  final String title;
  final String description;
  final DateTime date;
  final IconData icon;

  Achievement({
    required this.title,
    required this.description,
    required this.date,
    required this.icon,
  });
}

class AchievementsPage extends StatelessWidget {
  AchievementsPage({super.key});

  final List<Achievement> achievements = [
    Achievement(
      title: 'Your First',
      description: 'Visit your first artwork.',
      date: DateTime.now().subtract(const Duration(days: 365)),
      icon: Icons.star,
    ),
    Achievement(
      title: 'Enthusiast',
      description: 'Visit 10 artworks.',
      date: DateTime.now().subtract(const Duration(days: 330)),
      icon: Icons.favorite,
    ),
    Achievement(
      title: 'Institutionalized',
      description: 'Visit your first art institution.',
      date: DateTime.now().subtract(const Duration(days: 300)),
      icon: Icons.account_balance,
    ),
    Achievement(
      title: 'Small Collector',
      description: 'Collect 5 art pieces.',
      date: DateTime.now().subtract(const Duration(days: 270)),
      icon: Icons.collections,
    ),
    Achievement(
      title: 'Critic',
      description: 'Leave 10 reviews on artworks.',
      date: DateTime.now().subtract(const Duration(days: 240)),
      icon: Icons.rate_review,
    ),
    Achievement(
      title: '5k Walker',
      description: 'Walk for 5 kilometers.',
      date: DateTime.now().subtract(const Duration(days: 210)),
      icon: Icons.directions_walk,
    ),
    Achievement(
      title: 'Explorer',
      description: 'Visit artworks in 5 different cities.',
      date: DateTime.now().subtract(const Duration(days: 180)),
      icon: Icons.explore,
    ),
    Achievement(
      title: 'History Rulz',
      description: 'Visit 3 historical art pieces.',
      date: DateTime.now().subtract(const Duration(days: 150)),
      icon: Icons.history,
    ),
    Achievement(
      title: 'Small Contributor',
      description: 'Donate to 5 art projects.',
      date: DateTime.now().subtract(const Duration(days: 120)),
      icon: Icons.volunteer_activism,
    ),
    Achievement(
      title: 'Scan Scan',
      description: 'Scan 50 artworks.',
      date: DateTime.now().subtract(const Duration(days: 90)),
      icon: Icons.camera_alt,
    ),
    Achievement(
      title: 'Marathon',
      description: 'Visit 20 artworks in one day.',
      date: DateTime.now().subtract(const Duration(days: 60)),
      icon: Icons.directions_run,
    ),
    Achievement(
      title: 'In Love with Art',
      description: 'Spend 100 hours visiting artworks.',
      date: DateTime.now().subtract(const Duration(days: 30)),
      icon: Icons.access_time,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
      ),
      body: ListView.builder(
        itemCount: achievements.length,
        itemBuilder: (context, index) {
          final achievement = achievements[index];
          return Card(
            child: ListTile(
              leading: Icon(achievement.icon, color: Theme.of(context).colorScheme.secondary),
              title: Text(
                achievement.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(achievement.description),
              trailing: Text(
                '${achievement.date.day}/${achievement.date.month}/${achievement.date.year}',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }
}