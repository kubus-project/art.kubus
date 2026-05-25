import 'package:art_kubus/models/achievements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserAchievementsSummary parses backend definitions and progress', () {
    final summary = UserAchievementsSummary.fromJson({
      'success': true,
      'definitions': [
        {
          'code': 'first_post',
          'title': 'First Post',
          'description': 'Created your first community post',
          'category': 'community',
          'rarity': 'common',
          'requiredCount': 1,
          'kub8Reward': '5.000000',
        }
      ],
      'progress': [
        {
          'achievementCode': 'first_post',
          'currentProgress': 1,
          'requiredCount': 1,
          'isCompleted': true,
          'completedAt': '2026-05-25T00:00:00.000Z',
        }
      ],
      'unlocked': [
        {
          'code': 'first_post',
          'title': 'First Post',
          'description': 'Created your first community post',
          'category': 'community',
          'rarity': 'common',
          'kub8Reward': '5.000000',
          'rewardCurrency': 'KUB8',
          'unlockedAt': '2026-05-25T00:00:00.000Z',
        }
      ],
      'totalKub8Earned': '5.000000',
    });

    expect(summary.definitions.single.code, 'first_post');
    expect(summary.definitions.single.kub8Reward, 5);
    expect(summary.progress.single.isCompleted, isTrue);
    expect(summary.unlocked.single.rewardCurrency, 'KUB8');
    expect(summary.totalKub8Earned, 5);
  });
}
