import 'dart:convert';

import 'package:art_kubus/models/achievement_progress.dart';
import 'package:art_kubus/models/achievements.dart' as achievements;
import 'package:art_kubus/models/profile_package.dart';
import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/profile_package_service.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const wallet = 'profile_package_wallet';

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ProfilePackageService.clearMemoryCacheForTesting();
    await UserService.clearCache();
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() async {
    ProfilePackageService.clearMemoryCacheForTesting();
    await UserService.clearCache();
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('critical package loads profile, stats, and achievements without posts',
      () async {
    final requests = <String>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request.url.path);
      return _mockProfilePackageResponse(request, wallet: wallet);
    }));

    final critical =
        await ProfilePackageService.loadPublicProfileCriticalPackage(
      wallet,
      forceRefresh: true,
    );

    expect(critical, isNotNull);
    expect(critical!.isComplete, isTrue);
    expect(critical.user.id, wallet);
    expect(critical.user.followersCount, 12);
    expect(critical.achievementDefinitions.single.title, 'Backend Milestone');
    expect(
        critical.achievementProgress.single.achievementId, 'backend_milestone');
    expect(requests.any((path) => path.contains('/api/profiles/')), isTrue);
    expect(
      requests.any((path) => path.contains('/api/achievements/users/')),
      isTrue,
    );
    expect(
      requests.any((path) => path.contains('/api/community/posts')),
      isFalse,
    );
  });

  test('extended package loads posts separately', () async {
    final requests = <String>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request.url.path);
      return _mockProfilePackageResponse(request, wallet: wallet);
    }));

    final extended =
        await ProfilePackageService.loadPublicProfileExtendedPackage(
      wallet,
      forceRefresh: true,
      includePosts: true,
      includeShowcase: false,
    );

    expect(extended, isNotNull);
    expect(extended!.initialPosts, isEmpty);
    expect(
      requests.any((path) => path.contains('/api/community/posts')),
      isTrue,
    );
    expect(requests.any((path) => path.contains('/api/profiles/')), isFalse);
    expect(
      requests.any((path) => path.contains('/api/achievements/users/')),
      isFalse,
    );
  });

  test('failed extended package does not fail critical package', () async {
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path.contains('/api/community/posts')) {
        return http.Response('Post load failed', 500);
      }
      return _mockProfilePackageResponse(request, wallet: wallet);
    }));

    final critical =
        await ProfilePackageService.loadPublicProfileCriticalPackage(
      wallet,
      forceRefresh: true,
    );
    final extended =
        await ProfilePackageService.loadPublicProfileExtendedPackage(
      wallet,
      forceRefresh: true,
      includePosts: true,
      includeShowcase: false,
      user: critical!.user,
    );

    expect(critical.isComplete, isTrue);
    expect(critical.achievementDefinitions.single.title, 'Backend Milestone');
    expect(extended, isNotNull);
    expect(extended!.initialPosts, isEmpty);
  });

  test('marks package complete when achievements are explicitly unavailable',
      () async {
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path.contains('/api/achievements/users/')) {
        return http.Response('Unavailable', 503);
      }
      return _mockProfilePackageResponse(request, wallet: wallet);
    }));

    final package = await ProfilePackageService.loadPublicProfilePackage(
      wallet,
      forceRefresh: true,
      includePosts: false,
      includeShowcase: false,
    );

    expect(package, isNotNull);
    expect(package!.isComplete, isTrue);
    expect(package.achievementsUnavailable, isTrue);
    expect(package.achievementDefinitions, isEmpty);
  });

  test('returns complete cached package without rendering a shell as complete',
      () async {
    final cached = _cachedPackage(
      wallet: wallet,
      title: 'Cached Backend Milestone',
    );
    ProfilePackageService.setCachedPackageForTesting(cached);

    var networkCalls = 0;
    BackendApiService().setHttpClient(MockClient((request) async {
      networkCalls += 1;
      return http.Response('Unexpected', 500);
    }));

    final package = await ProfilePackageService.loadPublicProfilePackage(
      wallet,
      includePosts: false,
      includeShowcase: false,
    );

    expect(package!.achievementDefinitions.single.title,
        'Cached Backend Milestone');
    expect(networkCalls, 0);
  });

  test('invalidating achievements forces achievement reload', () async {
    ProfilePackageService.setCachedPackageForTesting(
      _cachedPackage(wallet: wallet, title: 'Old Backend Milestone'),
    );
    ProfilePackageService.invalidateAchievements(wallet);

    final requests = <String>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request.url.path);
      return _mockProfilePackageResponse(
        request,
        wallet: wallet,
        achievementTitle: 'Reloaded Backend Milestone',
      );
    }));

    final critical =
        await ProfilePackageService.loadPublicProfileCriticalPackage(wallet);

    expect(critical!.achievementDefinitions.single.title,
        'Reloaded Backend Milestone');
    expect(
      requests.any((path) => path.contains('/api/achievements/users/')),
      isTrue,
    );
  });

  test('invalidating posts does not invalidate achievements', () async {
    ProfilePackageService.setCachedPackageForTesting(
      _cachedPackage(wallet: wallet, title: 'Cached Backend Milestone'),
    );
    ProfilePackageService.invalidatePosts(wallet);

    var networkCalls = 0;
    BackendApiService().setHttpClient(MockClient((request) async {
      networkCalls += 1;
      return _mockProfilePackageResponse(request, wallet: wallet);
    }));

    final critical =
        await ProfilePackageService.loadPublicProfileCriticalPackage(wallet);

    expect(critical!.achievementDefinitions.single.title,
        'Cached Backend Milestone');
    expect(networkCalls, 0);
  });

  test('patching follow state preserves achievement definitions', () async {
    ProfilePackageService.setCachedPackageForTesting(
      _cachedPackage(wallet: wallet, title: 'Cached Backend Milestone'),
    );

    ProfilePackageService.patchUser(
      wallet,
      (current) => current.copyWith(isFollowing: true, followersCount: 8),
    );

    final critical = ProfilePackageService.getCachedCriticalPackage(wallet)!;
    expect(critical.user.isFollowing, isTrue);
    expect(critical.user.followersCount, 8);
    expect(critical.achievementDefinitions.single.title,
        'Cached Backend Milestone');
  });

  test('background refresh replaces cached package atomically', () async {
    ProfilePackageService.setCachedPackageForTesting(
      _cachedPackage(wallet: wallet, title: 'Old Backend Milestone'),
    );

    BackendApiService().setHttpClient(MockClient((request) async {
      return _mockProfilePackageResponse(
        request,
        wallet: wallet,
        achievementTitle: 'Fresh Backend Milestone',
      );
    }));

    final refresh = ProfilePackageService.loadPublicProfilePackage(
      wallet,
      forceRefresh: true,
      includePosts: false,
      includeShowcase: false,
    );

    expect(
      ProfilePackageService.getCachedPackage(wallet)!
          .achievementDefinitions
          .single
          .title,
      'Old Backend Milestone',
    );

    final fresh = await refresh;

    expect(
        fresh!.achievementDefinitions.single.title, 'Fresh Backend Milestone');
    expect(
      ProfilePackageService.getCachedPackage(wallet)!
          .achievementDefinitions
          .single
          .title,
      'Fresh Backend Milestone',
    );
  });
}

http.Response _mockProfilePackageResponse(
  http.Request request, {
  required String wallet,
  String achievementTitle = 'Backend Milestone',
}) {
  final path = request.url.path;
  if (path.contains('/api/profiles/')) {
    return _jsonResponse(<String, Object?>{
      'data': <String, Object?>{
        'walletAddress': wallet,
        'username': 'profile.package',
        'displayName': 'Profile Package',
        'bio': 'Complete profile package fixture.',
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
          'code': 'backend_milestone',
          'title': achievementTitle,
          'description': 'Backend-owned definition',
          'category': 'community',
          'rarity': 'rare',
          'requiredCount': 1,
          'kub8Reward': 4,
        },
      ],
      'progress': <Map<String, Object?>>[
        <String, Object?>{
          'achievementCode': 'backend_milestone',
          'currentProgress': 1,
          'requiredCount': 1,
          'isCompleted': true,
        },
      ],
      'unlocked': <Object?>[],
      'totalKub8Earned': 4,
    });
  }

  if (path.contains('/api/stats/user/')) {
    return _jsonResponse(<String, Object?>{
      'data': <String, Object?>{
        'entityType': 'user',
        'entityId': wallet,
        'scope': 'public',
        'metrics': <String>['posts', 'followers', 'following'],
        'counters': <String, int>{
          'posts': 3,
          'followers': 12,
          'following': 5,
          'publicStreetArtAdded': 2,
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

ProfilePackage _cachedPackage({
  required String wallet,
  required String title,
}) {
  final definition = achievements.AchievementDefinition(
    code: 'cached_milestone',
    title: title,
    description: 'Cached backend-owned definition',
    category: 'community',
    rarity: 'rare',
    requiredCount: 1,
    kub8Reward: 3,
  );
  const progress = AchievementProgress(
    achievementId: 'cached_milestone',
    currentProgress: 1,
    isCompleted: true,
  );
  final user = User(
    id: wallet,
    name: 'Cached Profile',
    username: 'cached.profile',
    bio: '',
    followersCount: 1,
    followingCount: 2,
    postsCount: 3,
    isFollowing: false,
    isVerified: false,
    joinedDate: 'Joined 5/2026',
    achievementProgress: const <AchievementProgress>[progress],
    achievementDefinitions: <achievements.AchievementDefinition>[definition],
  );

  return ProfilePackage(
    user: user,
    achievementProgress: const <AchievementProgress>[progress],
    achievementDefinitions: <achievements.AchievementDefinition>[definition],
    publicStats: const <String, int>{
      'posts': 3,
      'followers': 1,
      'following': 2,
    },
    fetchedAt: DateTime.now(),
    isComplete: true,
  );
}
