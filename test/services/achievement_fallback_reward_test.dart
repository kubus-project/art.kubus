import 'package:art_kubus/services/achievement_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The local achievement catalogue carries configured `tokenReward` numbers
/// (10, 50, 200 …). Those are not backend facts. When the backend list is
/// unavailable, the fallback definitions must carry NO KUB8 reward, so an
/// unlocked achievement reads "Unlocked", never an invented "+50 KUB8".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline fallback definitions carry no KUB8 reward', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // flutter_test answers every HTTP request with 400, so the backend list
    // is unavailable and the fallback path runs.
    final definitions = await AchievementService().getAllAchievements();
    expect(definitions, isNotEmpty);
    expect(
      definitions.where((d) => d.kub8Reward != 0).map((d) => d.code),
      isEmpty,
    );
    // Guard the premise: the local catalogue does configure rewards.
    expect(
      AchievementService.achievementDefinitions.values
          .any((d) => d.tokenReward > 0),
      isTrue,
    );
  });
}
