import 'package:art_kubus/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfilePreferences showAchievements', () {
    test('defaults to true when absent', () {
      final prefs = ProfilePreferences.fromJson(const <String, dynamic>{});
      expect(prefs.showAchievements, isTrue);
    });

    test('parses both camelCase and snake_case payload keys', () {
      final snakeCase = ProfilePreferences.fromJson(
        const <String, dynamic>{
          'show_achievements': false,
        },
      );
      final camelCase = ProfilePreferences.fromJson(
        const <String, dynamic>{
          'showAchievements': true,
        },
      );

      expect(snakeCase.showAchievements, isFalse);
      expect(camelCase.showAchievements, isTrue);
    });

    test('copyWith and toJson preserve showAchievements', () {
      final base = ProfilePreferences(showAchievements: true);
      final updated = base.copyWith(showAchievements: false);

      expect(updated.showAchievements, isFalse);
      expect(updated.toJson()['showAchievements'], isFalse);
    });
  });
}
