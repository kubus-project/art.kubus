import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/models/profile_package.dart';
import 'package:art_kubus/services/profile_package_service.dart';
import 'package:art_kubus/providers/cache_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/settings_service.dart';
import 'package:art_kubus/services/account_cache_store.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/push_notification_service.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise storage failures at the real preferences platform boundary.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const accountA = '11111111-1111-4111-8111-111111111111';
const accountB = '22222222-2222-4222-8222-222222222222';
const _secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

String token(String account) => 'e30.${base64Url.encode(utf8.encode(jsonEncode({
          'id': account,
          'exp': DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
        }))).replaceAll('=', '')}.synthetic';

class _Wallet implements WalletProvider {
  @override
  Future<void> disconnectWallet(
      {bool preserveAuthenticatedWallet = true}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FaultStore extends InMemorySharedPreferencesStore {
  _FaultStore() : super.withData(<String, Object>{});
  bool failRead = false;
  bool failWrite = false;
  bool failRemove = false;
  bool holdWrite = false;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<Map<String, Object>> getAll() async {
    if (failRead) throw StateError('synthetic unavailable read');
    return super.getAll();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.contains('account_cache_v1.')) {
      if (failWrite) throw StateError('synthetic unavailable write');
      if (holdWrite) {
        holdWrite = false;
        entered.complete();
        await release.future;
      }
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (failRemove && key.contains('account_cache_v1.')) {
      throw StateError('synthetic unavailable deletion');
    }
    return super.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService backend;
  final push = PushNotificationService();

  setUp(() async {
    backend = BackendApiService();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AccountCacheStore.resetForTesting();
    backend.setAuthTokenForTesting(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secure, (_) async => null);
  });

  tearDown(() async {
    await AccountCacheStore.resetForTesting();
    backend.setAuthTokenForTesting(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secure, null);
  });

  test('A logout B and fresh providers cannot restore A profile or history',
      () async {
    backend.setAuthTokenForTesting(token(accountA));
    final cache = CacheProvider();
    addTearDown(cache.dispose);
    await cache.setDisplayName('synthetic-wallet', 'Synthetic A');
    await cache.setAvatar('synthetic-wallet', '/synthetic-a.png');
    UserService.setUsersInCache([
      const User(
          id: 'synthetic-person',
          name: 'Synthetic A',
          username: 'a',
          bio: '',
          followersCount: 0,
          followingCount: 0,
          postsCount: 0,
          isFollowing: false,
          isVerified: false,
          isArtist: false,
          joinedDate: '')
    ]);
    await push.storeInAppNotificationForTesting('Synthetic A notification');
    expect((await push.getInAppNotifications()).single['title'],
        'Synthetic A notification');
    expect(UserService.getCachedUser('synthetic-person'), isNotNull);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', 'Synthetic A');
    await prefs.setString('user_profile', 'Synthetic A profile');

    await SettingsService.logout(
        walletProvider: _Wallet(), backendApi: backend);
    expect(cache.displayNameSnapshot, isEmpty);
    expect(UserService.getCachedUser('synthetic-person'), isNull);
    expect(await push.getInAppNotifications(), isEmpty);
    expect(prefs.getString('username'), isNull);
    expect(prefs.getString('user_profile'), isNull);
    backend.setAuthTokenForTesting(token(accountB));
    final restartedCache = CacheProvider();
    addTearDown(restartedCache.dispose);
    await restartedCache.initialize();
    await UserService.initialize();
    expect(restartedCache.avatarSnapshot, isEmpty);
    expect(restartedCache.displayNameSnapshot, isEmpty);
    expect(UserService.getCachedUser('synthetic-person'), isNull);
    expect(await push.getInAppNotifications(), isEmpty);
    for (final key in prefs
        .getKeys()
        .where((key) => key.startsWith('account_cache_v1.'))) {
      final record = jsonDecode(prefs.getString(key)!);
      expect(record['owner'], accountB);
      expect(record['data'], isEmpty);
    }
  });

  test(
      'fresh instance restores same account but rejects different account without logout',
      () async {
    await backend.setAuthToken(token(accountA));
    final cache = CacheProvider();
    addTearDown(cache.dispose);
    await cache.setDisplayName('person', 'Synthetic A');
    final restarted = CacheProvider();
    addTearDown(restarted.dispose);
    await restarted.initialize();
    expect(restarted.getDisplayName('person'), 'Synthetic A');
    await backend.setAuthToken(token(accountB));
    expect(cache.getDisplayName('person'), isNull);
    final next = CacheProvider();
    addTearDown(next.dispose);
    await next.initialize();
    expect(next.displayNameSnapshot, isEmpty);
  });

  test('profile packages isolate memory and persisted restart by account',
      () async {
    const wallet = '4Nd1mYbF7kYgU7kD3bcd1q2w4gS7y8Z9xKLMNPQRSTU';
    final package = ProfileCriticalPackage(
      user: const User(
          id: wallet,
          name: 'Synthetic A',
          username: 'a',
          bio: '',
          followersCount: 0,
          followingCount: 0,
          postsCount: 0,
          isFollowing: true,
          isVerified: false,
          joinedDate: ''),
      achievementProgress: const [],
      achievementDefinitions: const [],
      publicStats: const {},
      fetchedAt: DateTime.now(),
      isComplete: true,
    );
    backend.setAuthTokenForTesting(token(accountA));
    ProfilePackageService.setCachedCriticalPackageForTesting(package);
    await AccountCacheStore.write(
        'profile_critical_cache_v3', {wallet: package.toJson()},
        account: accountA, generation: AccountCacheStore.generation);
    ProfilePackageService.clearMemoryCacheForTesting();
    expect(
        (await ProfilePackageService.loadPublicProfileCriticalPackage(wallet))
            ?.user
            .isFollowing,
        isTrue);
    backend.setAuthTokenForTesting(token(accountB));
    expect(ProfilePackageService.getCachedCriticalPackage(wallet), isNull);
    expect(await AccountCacheStore.read('profile_critical_cache_v3'), isNull);
  });

  test('held A participant lookup cannot merge into B cache', () async {
    backend.setAuthTokenForTesting(token(accountA));
    final cache = CacheProvider();
    addTearDown(cache.dispose);
    await cache.initialize();
    final scope = AccountCacheScope.capture();
    final response = Completer<Map<String, String?>>();
    final pending = response.future.then(
        (names) => cache.mergeProfiles(displayNames: names, scope: scope));
    await backend.clearAuth();
    backend.setAuthTokenForTesting(token(accountB));
    await cache.setDisplayName('person-b', 'Synthetic B');
    response.complete({'person-a': 'Synthetic A'});
    await pending;
    expect(cache.getDisplayName('person-a'), isNull);
    expect(cache.getDisplayName('person-b'), 'Synthetic B');
    expect(await AccountCacheStore.read('cache_provider_display_names_v1'),
        {'person-b': 'Synthetic B'});
  });

  test(
      'legacy and expired records never hydrate, guest public cache still works',
      () async {
    SharedPreferences.setMockInitialValues({
      'cache_provider_display_names_v1': jsonEncode({'person': 'unowned'}),
      'in_app_notifications': ['unowned text'],
      'account_cache_v1.cache_provider_avatars_v1': jsonEncode({
        'owner': '',
        'expiresAt': 1,
        'data': {'person': '/expired.png'},
      }),
    });
    final cache = CacheProvider();
    addTearDown(cache.dispose);
    await cache.initialize();
    expect(cache.displayNameSnapshot, isEmpty);
    expect(cache.avatarSnapshot, isEmpty);
    expect(await push.getInAppNotifications(), isEmpty);
    await cache.setDisplayName('public-person', 'Public name');
    expect(cache.getDisplayName('public-person'), 'Public name');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('cache_provider_display_names_v1'), isFalse);
    await AccountIdentity.notifyChanged();
    expect(prefs.containsKey('in_app_notifications'), isFalse);
  });

  test(
      'delayed A disk write finishes before logout purge and cannot survive restart B',
      () async {
    final store = _FaultStore()..holdWrite = true;
    SharedPreferencesStorePlatform.instance = store;
    backend.setAuthTokenForTesting(token(accountA));
    final write = AccountCacheStore.write('synthetic', {'name': 'A'},
        account: accountA, generation: AccountCacheStore.generation);
    await store.entered.future;
    final logout = backend.clearAuth();
    backend.setAuthTokenForTesting(token(accountB));
    store.release.complete();
    await write;
    await logout;
    await AccountCacheStore.resetForTesting();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('account_cache_v1.synthetic'), isNull);
    expect(await AccountCacheStore.read('synthetic'), isNull);
  });

  test('in-flight A following response cannot populate B relationship cache',
      () async {
    backend.setAuthTokenForTesting(token(accountA));
    final response = Completer<http.Response>();
    final entered = Completer<void>();
    backend.setHttpClient(MockClient((_) {
      entered.complete();
      return response.future;
    }));
    final request =
        UserService.getKnownFollowingUsers(walletAddress: 'synthetic-wallet');
    await entered.future;
    await backend.clearAuth();
    backend.setAuthTokenForTesting(token(accountB));
    response.complete(http.Response(
        jsonEncode({
          'data': [
            {'walletAddress': 'synthetic-followed'}
          ]
        }),
        200));
    expect(await request, isNull);
    expect(await AccountCacheStore.read('following_users_synthetic-wallet'),
        isNull);
  });

  test('failed deletion leaves durable restart fence and B cannot read A bytes',
      () async {
    final store = _FaultStore();
    SharedPreferencesStorePlatform.instance = store;
    backend.setAuthTokenForTesting(token(accountA));
    await AccountCacheStore.write('synthetic', 'A',
        account: accountA, generation: AccountCacheStore.generation);
    store.failRemove = true;
    await backend.clearAuth();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getBool('account_cache_purge_pending_v1'), isTrue);
    await AccountCacheStore.resetForTesting();
    backend.setAuthTokenForTesting(token(accountB));
    expect(await AccountCacheStore.read('synthetic'), isNull);
    await AccountCacheStore.write('synthetic', 'B',
        account: accountB, generation: AccountCacheStore.generation);
    await prefs.reload();
    expect(jsonDecode(prefs.getString('account_cache_v1.synthetic')!)['data'],
        'A');
    store.failRemove = false;
    await AccountCacheStore.purge();
    expect(prefs.getBool('account_cache_purge_pending_v1'), isNull);
  });

  test('read and write errors fail closed without crashing the cache caller',
      () async {
    final store = _FaultStore()..failWrite = true;
    SharedPreferencesStorePlatform.instance = store;
    backend.setAuthTokenForTesting(token(accountA));
    await AccountCacheStore.write('synthetic', 'A',
        account: accountA, generation: AccountCacheStore.generation);
    expect(await AccountCacheStore.read('synthetic'), isNull);
    await AccountCacheStore.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SharedPreferencesStorePlatform.instance = _FaultStore()..failRead = true;
    expect(await AccountCacheStore.read('synthetic'), isNull);
  });
}
