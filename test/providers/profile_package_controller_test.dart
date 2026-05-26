import 'dart:convert';
import 'dart:async';

import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/achievement_preview_data_state.dart';
import 'package:art_kubus/models/achievement_progress.dart';
import 'package:art_kubus/models/achievements.dart' as achievements;
import 'package:art_kubus/models/profile_package.dart';
import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/providers/profile_package_controller.dart';
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

  const wallet = 'profile_controller_wallet';

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

  test('controller starts in loading state', () {
    final controller = ProfilePackageController(walletAddress: wallet);

    expect(controller.isLoadingCritical, isTrue);
    expect(controller.user, isNull);

    controller.dispose();
  });

  test('controller applies critical before extended package', () {
    final controller = ProfilePackageController(walletAddress: wallet);
    final critical = _critical(wallet: wallet, title: 'Backend Milestone');
    final post = _post(wallet: wallet);

    controller.applyCritical(critical);

    expect(controller.isLoadingCritical, isFalse);
    expect(controller.user!.id, wallet);
    expect(controller.posts, isEmpty);
    expect(controller.achievementPreviewDataState,
        AchievementPreviewDataState.ready);

    controller.applyExtended(
      ProfileExtendedPackage(
        initialPosts: <CommunityPost>[post],
        artistArtworks: const <Map<String, dynamic>>[
          <String, dynamic>{'id': 'artwork-1', 'title': 'Work'}
        ],
        fetchedAt: DateTime.now(),
      ),
    );

    expect(controller.posts.single.id, post.id);
    expect(controller.artistArtworks.single['id'], 'artwork-1');
    expect(controller.package!.achievementDefinitions.single.title,
        'Backend Milestone');

    controller.dispose();
  });

  test('background refresh replaces critical package atomically', () async {
    final cached = _critical(wallet: wallet, title: 'Old Backend Milestone');
    final controller = ProfilePackageController(
      walletAddress: wallet,
      initialCriticalPackage: cached,
    );
    controller.applyCritical(cached);

    BackendApiService().setHttpClient(MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return _mockProfilePackageResponse(
        request,
        wallet: wallet,
        achievementTitle: 'Fresh Backend Milestone',
      );
    }));

    final refresh = controller.refresh();
    expect(controller.package!.achievementDefinitions.single.title,
        'Old Backend Milestone');

    await refresh;

    expect(controller.package!.achievementDefinitions.single.title,
        'Fresh Backend Milestone');

    controller.dispose();
  });

  test('follow patch preserves achievement definitions', () {
    final controller = ProfilePackageController(walletAddress: wallet);
    controller.applyCritical(
      _critical(wallet: wallet, title: 'Backend Milestone'),
    );

    controller.patchUser(
      (current) => current.copyWith(isFollowing: true, followersCount: 42),
    );

    expect(controller.user!.isFollowing, isTrue);
    expect(controller.user!.followersCount, 42);
    expect(controller.package!.achievementDefinitions.single.title,
        'Backend Milestone');

    controller.dispose();
  });

  test('posts patch preserves achievement definitions', () {
    final controller = ProfilePackageController(walletAddress: wallet);
    controller.applyCritical(
      _critical(wallet: wallet, title: 'Backend Milestone'),
    );

    controller.patchPosts(<CommunityPost>[_post(wallet: wallet)]);

    expect(controller.posts.single.id, 'post-1');
    expect(controller.package!.achievementDefinitions.single.title,
        'Backend Milestone');

    controller.dispose();
  });

  test('stale async critical result is ignored after newer refresh', () async {
    final oldCritical =
        _critical(wallet: wallet, title: 'Old Backend Milestone');
    final pendingInitial = Completer<ProfileCriticalPackage?>();
    final controller = ProfilePackageController(
      walletAddress: wallet,
      initialCriticalPackageFuture: pendingInitial.future,
    );

    BackendApiService().setHttpClient(MockClient((request) async {
      return _mockProfilePackageResponse(
        request,
        wallet: wallet,
        achievementTitle: 'Fresh Backend Milestone',
      );
    }));

    final initialLoad = controller.load();
    final refresh = controller.refresh();
    await refresh;
    pendingInitial.complete(oldCritical);
    await initialLoad;

    expect(controller.package!.achievementDefinitions.single.title,
        'Fresh Backend Milestone');

    controller.dispose();
  });

  test('stale async extended result is ignored after newer extended load',
      () async {
    final staleExtended = ProfileExtendedPackage(
      initialPosts: <CommunityPost>[_post(wallet: wallet)],
      fetchedAt: DateTime.now(),
    );
    final pendingInitial = Completer<ProfileExtendedPackage?>();
    final controller = ProfilePackageController(
      walletAddress: wallet,
      initialExtendedPackageFuture: pendingInitial.future,
    );
    controller.applyCritical(
      _critical(wallet: wallet, title: 'Backend Milestone'),
    );

    BackendApiService().setHttpClient(MockClient((request) async {
      return _mockProfilePackageResponse(
        request,
        wallet: wallet,
        achievementTitle: 'Backend Milestone',
      );
    }));

    final firstLoad = controller.loadExtended();
    await Future<void>.delayed(Duration.zero);
    await controller.loadExtended(forceRefresh: true);
    pendingInitial.complete(staleExtended);
    await firstLoad;

    expect(controller.posts, isEmpty);
    expect(controller.package!.achievementDefinitions.single.title,
        'Backend Milestone');

    controller.dispose();
  });

  test('extended failure does not clear critical package', () async {
    final controller = ProfilePackageController(walletAddress: wallet);
    controller.applyCritical(
      _critical(wallet: wallet, title: 'Backend Milestone'),
    );
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path.contains('/api/community/posts')) {
        return http.Response('failed', 500);
      }
      return _mockProfilePackageResponse(
        request,
        wallet: wallet,
        achievementTitle: 'Backend Milestone',
      );
    }));

    await controller.loadExtended(forceRefresh: true);

    expect(controller.isLoadingExtended, isFalse);
    expect(controller.package!.achievementDefinitions.single.title,
        'Backend Milestone');

    controller.dispose();
  });
}

ProfileCriticalPackage _critical({
  required String wallet,
  required String title,
}) {
  final definition = achievements.AchievementDefinition(
    code: 'backend_milestone',
    title: title,
    description: 'Backend-owned definition',
    category: 'community',
    rarity: 'rare',
    requiredCount: 1,
    kub8Reward: 4,
  );
  const progress = AchievementProgress(
    achievementId: 'backend_milestone',
    currentProgress: 1,
    isCompleted: true,
  );
  final user = User(
    id: wallet,
    name: 'Controller Profile',
    username: 'controller.profile',
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

  return ProfileCriticalPackage(
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

CommunityPost _post({required String wallet}) {
  return CommunityPost(
    id: 'post-1',
    authorId: wallet,
    authorWallet: wallet,
    authorName: 'Controller Profile',
    content: 'Post',
    timestamp: DateTime.now(),
  );
}

http.Response _mockProfilePackageResponse(
  http.Request request, {
  required String wallet,
  required String achievementTitle,
}) {
  final path = request.url.path;
  if (path.contains('/api/profiles/')) {
    return _jsonResponse(<String, Object?>{
      'data': <String, Object?>{
        'walletAddress': wallet,
        'username': 'controller.profile',
        'displayName': 'Controller Profile',
        'bio': 'Controller fixture.',
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
          'posts': 4,
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
