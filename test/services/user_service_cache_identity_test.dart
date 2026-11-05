import 'dart:convert';

import 'package:art_kubus/models/profile_package.dart';
import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/services/account_cache_store.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/profile_package_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

/// Seeds the persisted user cache the way the app writes it: through the
/// owner-bound [AccountCacheStore] envelope. A raw `user_cache_v1` value has no
/// trustworthy owner, so the store deliberately purges it instead of hydrating it.
Future<void> _seedUserCache(Map<String, Object?> entries) async {
  SharedPreferences.setMockInitialValues({});
  await AccountCacheStore.write(
    'user_cache_v1',
    entries,
    account: AccountCacheStore.owner,
    generation: AccountCacheStore.generation,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(UserService.clearCache);

  test('a cached walletless account keeps its userId and follows by it',
      () async {
    await _seedUserCache({
      _profileUuid: _entry({'userId': _accountUuid, 'allowsMessages': false}),
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
    await _seedUserCache({
      _profileUuid: _entry({'walletAddress': _wallet}),
      'other': _entry({'id': 'other', 'walletAddress': 'not a wallet'}),
    });
    await UserService.initialize();
    expect(UserService.getCachedUser(_profileUuid)!.messagingWallet, _wallet);
    expect(UserService.getCachedUser('other')!.walletAddress, isNull);
  });

  test('an unowned raw user cache is purged and never hydrated', () async {
    SharedPreferences.setMockInitialValues({
      'user_cache_v1': jsonEncode({
        _profileUuid: _entry({'userId': _accountUuid}),
      }),
    });
    await UserService.initialize();
    expect(UserService.getCachedUser(_profileUuid), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('user_cache_v1'), isFalse);
  });

  test('entries cached before this change still load (legacy defaults)',
      () async {
    await _seedUserCache({_profileUuid: _entry({})});
    await UserService.initialize();
    final user = UserService.getCachedUser(_profileUuid)!;
    expect(user.userId, isNull);
    expect(user.allowsMessages, isTrue);
    expect(user.followTargetId, isNull, reason: 'a UUID id is never a wallet');
  });

  User accountUser(
          {String? userId,
          String? walletAddress,
          bool allowsMessages = true,
          String name = 'City Museum',
          int followers = 3,
          bool following = false}) =>
      User(
        id: _profileUuid,
        userId: userId,
        walletAddress: walletAddress,
        allowsMessages: allowsMessages,
        name: name,
        username: 'citymuseum',
        bio: '',
        followersCount: followers,
        followingCount: 0,
        postsCount: 0,
        isFollowing: following,
        isVerified: false,
        joinedDate: 'Joined recently',
      );

  // Review thread 1: partial copies must not erase account identity.
  test(
      'a partial cache write keeps the cached account identity and messaging preference',
      () async {
    SharedPreferences.setMockInitialValues({});
    await UserService.initialize();
    UserService.setUsersInCacheAuthoritative([
      accountUser(
          userId: _accountUuid, walletAddress: _wallet, allowsMessages: false)
    ], sessionEpoch: BackendApiService().authSessionEpoch);
    // A profile-package patch rebuilds the user without identity fields.
    UserService.setUsersInCache([accountUser(name: 'City Museum (renamed)')],
        sessionEpoch: BackendApiService().authSessionEpoch);
    UserService.setUsersInCacheAuthoritative(
        [accountUser(name: 'City Museum (again)')],
        sessionEpoch: BackendApiService().authSessionEpoch);
    final cached = UserService.getCachedUser(_profileUuid)!;
    expect(cached.name, 'City Museum (again)');
    expect(cached.userId, _accountUuid);
    expect(cached.walletAddress, _wallet);
    expect(cached.allowsMessages, isFalse);
    expect(cached.followTargetId, _accountUuid);
  });

  test('the profile package round-trips account identity', () {
    final package = ProfileCriticalPackage.fromJson({
      'user': {
        'id': _profileUuid,
        'name': 'City Museum',
        'username': 'citymuseum',
        'userId': _accountUuid,
        'walletAddress': _wallet,
        'allowsMessages': false,
      },
      'fetchedAt': DateTime.now().toIso8601String(),
    });
    expect(package.user.userId, _accountUuid);
    expect(package.user.walletAddress, _wallet);
    expect(package.user.allowsMessages, isFalse);
    final again = ProfileCriticalPackage.fromJson(package.toJson());
    expect(again.user.userId, _accountUuid);
    expect(again.user.allowsMessages, isFalse);
  });

  // Review thread 2: account follows reconcile the shared caches like wallet follows.
  test('following by account id reconciles cached copies of that account',
      () async {
    SharedPreferences.setMockInitialValues({});
    await UserService.initialize();
    UserService.setUsersInCacheAuthoritative([
      accountUser(userId: _accountUuid, walletAddress: _wallet, followers: 3)
    ], sessionEpoch: BackendApiService().authSessionEpoch);
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path == '/api/community/follow/account/$_accountUuid') {
        return http.Response(
            jsonEncode({
              'success': true,
              'isFollowing': true,
              'changed': true,
              'followCreated': true,
              'targetUserId': _accountUuid,
              'followersCount': 4,
            }),
            200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(jsonEncode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }));
    try {
      final result = await UserService.setFollowStateByUserId(_accountUuid,
          shouldFollow: true);
      expect(result.isFollowing, isTrue);
      final cached = UserService.getCachedUser(_profileUuid)!;
      expect(cached.isFollowing, isTrue);
      expect(cached.followersCount, 4);
      expect(result.targetWallet, _wallet);
    } finally {
      BackendApiService().setHttpClient(createPlatformHttpClient());
    }
  });

  // Review thread (PR 394): a walletless target skipped the profile-package and
  // actor reconciliation entirely, so a cached public profile kept the old
  // follow state and the actor's following count stayed stale.
  test(
      'following a walletless account reconciles its profile package and the actor count',
      () async {
    const actorWallet = 'So22222222222222222222222222222222222222223';
    SharedPreferences.setMockInitialValues({'wallet_address': actorWallet});
    await UserService.initialize();
    final epoch = BackendApiService().authSessionEpoch;
    UserService.setUsersInCacheAuthoritative([
      accountUser(userId: _accountUuid, followers: 3),
      User(
        id: actorWallet,
        name: 'Actor',
        username: 'actor',
        bio: '',
        followersCount: 0,
        followingCount: 1,
        postsCount: 0,
        isFollowing: false,
        isVerified: false,
        joinedDate: 'Joined recently',
      ),
    ], sessionEpoch: epoch);
    final targetUser = accountUser(userId: _accountUuid, followers: 3)
        .copyWith(id: _accountUuid);
    ProfilePackageService.setCachedPackageForTesting(ProfilePackage.fromParts(
      critical: ProfileCriticalPackage(
        user: targetUser,
        achievementProgress: const [],
        achievementDefinitions: const [],
        publicStats: const <String, int>{'followers': 3},
        fetchedAt: DateTime.now(),
        isComplete: true,
      ),
    ));
    ProfilePackageService.aliasCriticalPackageForTesting(
        'username:citymuseum', _accountUuid);
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path == '/api/community/follow/account/$_accountUuid') {
        return http.Response(
            jsonEncode({
              'success': true,
              'isFollowing': true,
              'changed': true,
              'followCreated': true,
              'targetUserId': _accountUuid,
              'followersCount': 4,
              'actorFollowingCount': 5,
            }),
            200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(jsonEncode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }));
    try {
      final result = await UserService.setFollowStateByUserId(_accountUuid,
          shouldFollow: true);
      expect(result.isFollowing, isTrue);
      expect(result.targetWallet, isEmpty);
      for (final key in <String>[_accountUuid, 'username:citymuseum']) {
        final package = ProfilePackageService.getCachedCriticalPackage(key)!;
        expect(package.user.isFollowing, isTrue, reason: key);
        expect(package.user.followersCount, 4, reason: key);
      }
      expect(UserService.getCachedUser(actorWallet)!.followingCount, 5);
    } finally {
      BackendApiService().setHttpClient(createPlatformHttpClient());
      ProfilePackageService.clearMemoryCacheForTesting();
    }
  });
}
