import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/services/user_service.dart';

const _wallet = '0xAbCdEf0000000000000000000000000000001234';
const _account = 'acct-7f3c2d10-0000-4000-8000-000000000001';
const _oldUrl = 'https://api.kubus.site/uploads/avatars/old-owner.png';
const _newUrl = 'https://api.kubus.site/uploads/avatars/new-owner.png';

User _user(String id, String? avatar) => User(
      id: id,
      name: 'Owner',
      username: 'owner',
      bio: '',
      profileImageUrl: avatar,
      followersCount: 0,
      followingCount: 0,
      postsCount: 0,
      isFollowing: false,
      isVerified: false,
      joinedDate: '2026-01-01T00:00:00.000Z',
      achievementProgress: const [],
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await UserService.clearCache();
  });

  test('a saved avatar updates wallet and account keys and bumps revision', () {
    UserService.setUsersInCacheAuthoritative([_user(_wallet, _oldUrl)]);
    final before = UserService.profileMediaRevisionFor(_wallet);

    UserService.setUsersInCacheAuthoritative([
      _user(_wallet, _newUrl),
      _user(_account, _newUrl),
    ]);
    UserService.markProfileMediaChanged([_wallet, _account]);

    expect(UserService.profileMediaRevisionFor(_wallet), greaterThan(before));
    expect(UserService.profileMediaRevisionFor(_account), greaterThan(0));
    final walletResolved = UserService.resolveAvatarUrl(wallet: _wallet);
    final accountResolved = UserService.resolveAvatarUrl(wallet: _account);
    expect(walletResolved, startsWith(_newUrl));
    expect(walletResolved, contains('v='));
    expect(accountResolved, startsWith(_newUrl));
    expect(UserService.getCachedUser(_wallet)?.profileImageUrl, _newUrl);
  });

  test('resolver prefers the cached avatar over a stale payload snapshot', () {
    UserService.setUsersInCacheAuthoritative([_user(_wallet, _newUrl)]);
    expect(
      UserService.resolveAvatarUrl(wallet: _wallet, payloadUrl: _oldUrl),
      _newUrl,
    );
  });

  test('resolver falls back to the payload when the cache has no avatar', () {
    UserService.setUsersInCacheAuthoritative([_user(_wallet, null)]);
    expect(
      UserService.resolveAvatarUrl(wallet: _wallet, payloadUrl: _oldUrl),
      _oldUrl,
    );
    expect(UserService.resolveAvatarUrl(wallet: 'unknown-wallet'), isNull);
  });

  test('placeholder or identicon payloads never win over a missing avatar', () {
    expect(
      UserService.resolveAvatarUrl(
        wallet: 'unknown-wallet',
        payloadUrl: 'https://api.dicebear.com/7.x/identicon/png?seed=x',
      ),
      isNull,
    );
  });

  test('unchanged URLs get no cache-busting parameter until a local save', () {
    UserService.setUsersInCacheAuthoritative([_user(_wallet, _oldUrl)]);
    expect(UserService.resolveAvatarUrl(wallet: _wallet), _oldUrl);
  });

  test('saving the same URL still cache-busts rendered avatars', () {
    UserService.setUsersInCacheAuthoritative([_user(_wallet, _oldUrl)]);
    UserService.markProfileMediaChanged([_wallet]);
    final resolved = UserService.resolveAvatarUrl(wallet: _wallet);
    expect(resolved, isNot(_oldUrl));
    expect(resolved, startsWith(_oldUrl));
  });
}
