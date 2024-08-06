import 'package:flutter/material.dart';
import 'dart:math';

class Achievement {
  final String title;
  final String description;
  final DateTime date;

  Achievement({required this.title, required this.description, required this.date});
}

class AchievementsPage extends StatelessWidget {
  AchievementsPage({super.key});

  final List<Achievement> achievements = List.generate(
    10,
    (index) => Achievement(
      title: 'Achievement ${index + 1}',
      description: 'Description for achievement ${index + 1}',
      date: DateTime.now().subtract(Duration(days: Random().nextInt(365))),
    ),
  );

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
              title: Text(achievement.title),
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