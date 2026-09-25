import 'package:art_kubus/utils/reward_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic recognition amounts do not imply KUB8', () {
    expect(
      hasExplicitKub8ActivityAmount(
        <String, dynamic>{'amount': 5, 'reason': 'Artwork discovered'},
        isAchievement: false,
      ),
      isFalse,
    );
  });

  test('explicit KUB8 currency remains displayable', () {
    expect(
      hasExplicitKub8ActivityAmount(
        <String, dynamic>{'amount': 10, 'currency': 'kub8'},
        isAchievement: false,
      ),
      isTrue,
    );
  });

  test('explicit KUB8 event type remains displayable', () {
    expect(
      hasExplicitKub8ActivityAmount(
        const <String, dynamic>{'amount': 3},
        isAchievement: false,
        activityType: 'kub8',
      ),
      isTrue,
    );
    expect(
      hasExplicitKub8ActivityAmount(
        const <String, dynamic>{'amount': 3},
        isAchievement: false,
        activityType: 'token',
      ),
      isFalse,
    );
  });

  test('legacy rewardTokens are KUB8 only in achievement context', () {
    const activity = <String, dynamic>{'rewardTokens': 7};
    expect(
      hasExplicitKub8ActivityAmount(activity, isAchievement: true),
      isTrue,
    );
    expect(
      hasExplicitKub8ActivityAmount(activity, isAchievement: false),
      isFalse,
    );
  });

  test('generic reward field is not an explicit currency', () {
    expect(isExplicitKub8Currency('reward'), isFalse);
    expect(isExplicitKub8Currency('KUB8'), isTrue);
  });
}
