import 'dart:convert';

import 'package:art_kubus/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Review 5 residual: a walletless account restored from the persisted user
// cache must keep its account identity, otherwise a queued follow falls back
// to the profile UUID and replays against the account-id endpoint.
const _accountUuid = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _profileUuid = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const _wallet = 'So11111111111111111111111111111111111111112';

Map<String, Object?> _entry(Map<String, Object?> extra) => {
      'id': _profileUuid,
      'name': 'City Museum',
      'username': 'citymuseum',
      'bio': '',
      'followersCount': 0,
      'followingCount': 0,
      'postsCount': 0,
      'isFollowing': false,
      'coverImageUrl': null,
      'cachedAt': DateTime.now().millisecondsSinceEpoch,
      ...extra,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(UserService.clearCache);

  test('a cached walletless account keeps its userId and follows by it',
      () async {
    SharedPreferences.setMockInitialValues({
      'user_cache_v1': jsonEncode({
        _profileUuid: _entry({'userId': _accountUuid, 'allowsMessages': false}),
      }),
    });
    await UserService.initialize();
    final user = UserService.getCachedUser(_profileUuid);
    expect(user, isNotNull);
    expect(user!.userId, _accountUuid);
    expect(user.followTargetId, _accountUuid);
    expect(user.allowsMessages, isFalse);
    expect(user.supportsMessaging, isFalse);
  });

  test('a cached wallet is restored only when it is wallet-shaped', () async {
    SharedPreferences.setMockInitialValues({
      'user_cache_v1': jsonEncode({
        _profileUuid: _entry({'walletAddress': _wallet}),
        'other': _entry({'id': 'other', 'walletAddress': 'not a wallet'}),
      }),
    });
    await UserService.initialize();
    expect(UserService.getCachedUser(_profileUuid)!.messagingWallet, _wallet);
    expect(UserService.getCachedUser('other')!.walletAddress, isNull);
  });

  test('entries cached before this change still load (legacy defaults)',
      () async {
    SharedPreferences.setMockInitialValues({
      'user_cache_v1': jsonEncode({_profileUuid: _entry({})}),
    });
    await UserService.initialize();
    final user = UserService.getCachedUser(_profileUuid)!;
    expect(user.userId, isNull);
    expect(user.allowsMessages, isTrue);
    expect(user.followTargetId, isNull, reason: 'a UUID id is never a wallet');
  });
}
