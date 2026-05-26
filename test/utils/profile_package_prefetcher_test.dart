import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/profile_package_service.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:art_kubus/utils/profile_package_prefetcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const wallet = 'PrefetchWallet111111111111111111111111';

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ProfilePackagePrefetcher.resetForTesting();
    ProfilePackageService.clearMemoryCacheForTesting();
    await UserService.clearCache();
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() async {
    ProfilePackagePrefetcher.resetForTesting();
    ProfilePackageService.clearMemoryCacheForTesting();
    await UserService.clearCache();
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('dedupes repeated visible prefetches', () async {
    var profileRequests = 0;
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path.contains('/api/profiles/')) {
        profileRequests += 1;
      }
      return _mockResponse(request, wallet: wallet);
    }));

    ProfilePackagePrefetcher.prefetchVisible(wallet);
    ProfilePackagePrefetcher.prefetchVisible(wallet);
    ProfilePackagePrefetcher.prefetchVisible(wallet);

    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(profileRequests, 1);
    expect(ProfilePackageService.getCachedCriticalPackage(wallet), isNotNull);
  });

  test('high-intent prefetch loads extended package after critical', () async {
    final requests = <String>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request.url.path);
      return _mockResponse(request, wallet: wallet);
    }));

    ProfilePackagePrefetcher.prefetchHighIntent(wallet);

    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(ProfilePackageService.getCachedCriticalPackage(wallet), isNotNull);
    expect(ProfilePackageService.getCachedExtendedPackage(wallet), isNotNull);
    expect(
      requests.any((path) => path.contains('/api/community/posts')),
      isTrue,
    );
  });

  test('invalid wallet is skipped', () async {
    var requests = 0;
    BackendApiService().setHttpClient(MockClient((request) async {
      requests += 1;
      return _mockResponse(request, wallet: wallet);
    }));

    ProfilePackagePrefetcher.prefetchVisible('not-a-wallet');
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(requests, 0);
  });

  test('self wallet is skipped', () async {
    var requests = 0;
    BackendApiService().setHttpClient(MockClient((request) async {
      requests += 1;
      return _mockResponse(request, wallet: wallet);
    }));

    ProfilePackagePrefetcher.prefetchVisible(wallet, selfWallet: wallet);
    ProfilePackagePrefetcher.prefetchHighIntent(wallet, selfWallet: wallet);
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(requests, 0);
  });

  test('recent-window duplicate is skipped', () async {
    var profileRequests = 0;
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path.contains('/api/profiles/')) {
        profileRequests += 1;
      }
      return _mockResponse(request, wallet: wallet);
    }));

    ProfilePackagePrefetcher.prefetchVisible(wallet);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    ProfilePackageService.clearMemoryCacheForTesting();
    ProfilePackagePrefetcher.prefetchVisible(wallet);
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(profileRequests, 1);
  });
}

http.Response _mockResponse(http.Request request, {required String wallet}) {
  final path = request.url.path;
  if (path.contains('/api/profiles/')) {
    return _jsonResponse(<String, Object?>{
      'data': <String, Object?>{
        'walletAddress': wallet,
        'username': 'prefetch.profile',
        'displayName': 'Prefetch Profile',
        'bio': '',
        'isArtist': false,
        'isInstitution': false,
        'createdAt': '2026-05-25T00:00:00.000Z',
      },
    });
  }

  if (path.contains('/api/community/follow/') && path.endsWith('/status')) {
    return _jsonResponse(<String, Object?>{
      'success': true,
      'isFollowing': false,
    });
  }

  if (path.contains('/api/achievements/users/')) {
    return _jsonResponse(<String, Object?>{
      'success': true,
      'definitions': <Map<String, Object?>>[
        <String, Object?>{
          'code': 'prefetch_milestone',
          'title': 'Prefetch Milestone',
          'description': '',
          'category': 'community',
          'rarity': 'common',
          'requiredCount': 1,
          'kub8Reward': 1,
        },
      ],
      'progress': <Map<String, Object?>>[],
      'unlocked': <Object?>[],
    });
  }

  if (path.contains('/api/stats/user/')) {
    return _jsonResponse(<String, Object?>{
      'data': <String, Object?>{
        'entityType': 'user',
        'entityId': wallet,
        'scope': 'public',
        'counters': <String, int>{
          'posts': 0,
          'followers': 0,
          'following': 0,
        },
      },
    });
  }

  if (path.contains('/api/community/posts')) {
    return _jsonResponse(<String, Object?>{'data': <Object?>[]});
  }

  return http.Response('Not found', 404);
}

http.Response _jsonResponse(Map<String, Object?> payload) {
  return http.Response(
    jsonEncode(payload),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}
