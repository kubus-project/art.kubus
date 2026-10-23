import 'dart:convert';
import 'dart:async';

import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/achievement_preview_data_state.dart';
import 'package:art_kubus/models/achievement_progress.dart';
import 'package:art_kubus/models/achievements.dart' as achievements;
import 'package:art_kubus/models/profile_package.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/providers/profile_package_controller.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/profile_package_service.dart';
import 'package:art_kubus/services/public_entity_load_outcome.dart';
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
    final pendingInitial =
        Completer<PublicEntityLoadOutcome<ProfileCriticalPackage>>();
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
    pendingInitial.complete(PublicEntityFound(oldCritical));
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

  group('profile posts query', () {
    const accountUuid = '3f2b9c1e-7a4d-4e8b-9c2a-1d2e3f4a5b6c';
    const foreignUuid = '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d';

    test('wallet profile sends authorWallet for its posts', () async {
      final controller = ProfilePackageController(walletAddress: wallet);
      controller.applyCritical(_critical(wallet: wallet, title: 'Milestone'));
      final requests = <Uri>[];
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path.contains('/api/community/posts')) {
          requests.add(request.url);
          return _jsonResponse(<String, Object?>{'data': <Object?>[]});
        }
        return http.Response('Not found', 404);
      }));

      await controller.loadPosts();

      expect(requests, hasLength(1));
      expect(requests.single.queryParameters['authorWallet'], wallet);
      expect(
          requests.single.queryParameters.containsKey('authorUserId'), isFalse);
      expect(controller.postsError, isNull);

      controller.dispose();
    });

    test('walletless profile sends authorUserId and drops foreign posts',
        () async {
      final controller = ProfilePackageController(walletAddress: accountUuid);
      controller
          .applyCritical(_critical(wallet: accountUuid, title: 'Milestone'));
      final requests = <Uri>[];
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path.contains('/api/community/posts')) {
          requests.add(request.url);
          // An older backend ignores authorUserId and returns the global feed.
          return _jsonResponse(<String, Object?>{
            'data': <Object?>[
              _postJson(id: 'own-post', authorUserId: accountUuid),
              _postJson(id: 'foreign-post', authorUserId: foreignUuid),
            ],
          });
        }
        return http.Response('Not found', 404);
      }));

      await controller.loadPosts();

      expect(requests.single.queryParameters['authorUserId'], accountUuid);
      expect(
          requests.single.queryParameters.containsKey('authorWallet'), isFalse);
      expect(controller.posts.map((post) => post.id), <String>['own-post']);
      expect(controller.postsError, isNull);

      controller.dispose();
    });

    test('a linked_auth placeholder is never the wallet key; the account id is',
        () async {
      final controller = ProfilePackageController(walletAddress: accountUuid);
      controller.applyCritical(
          _critical(wallet: 'linked_auth:$accountUuid', title: 'Milestone'));
      final requests = <Uri>[];
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path.contains('/api/community/posts')) {
          requests.add(request.url);
          return _jsonResponse(<String, Object?>{
            'data': <Object?>[
              _postJson(id: 'own-post', authorUserId: accountUuid),
            ],
          });
        }
        return http.Response('Not found', 404);
      }));

      await controller.loadPosts();

      expect(requests.single.queryParameters['authorUserId'], accountUuid);
      expect(
          requests.single.queryParameters.containsKey('authorWallet'), isFalse);
      expect(controller.posts.map((post) => post.id), <String>['own-post']);

      controller.dispose();
    });

    test('failed posts request surfaces postsError, not an empty feed',
        () async {
      final controller = ProfilePackageController(walletAddress: accountUuid);
      controller
          .applyCritical(_critical(wallet: accountUuid, title: 'Milestone'));
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path.contains('/api/community/posts')) {
          return http.Response('failed', 500);
        }
        return http.Response('Not found', 404);
      }));

      await controller.loadPosts(errorMessage: 'posts failed');

      expect(controller.postsLoading, isFalse);
      expect(controller.postsError, 'posts failed');
      expect(controller.posts, isEmpty);

      controller.dispose();
    });

    test('wallet profile shows its wallet-authored posts', () async {
      final controller = ProfilePackageController(walletAddress: wallet);
      controller.applyCritical(_critical(wallet: wallet, title: 'Milestone'));
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path.contains('/api/community/posts')) {
          return _jsonResponse(<String, Object?>{
            'data': <Object?>[
              _walletPostJson(id: 'wallet-post', wallet: wallet),
            ],
          });
        }
        return http.Response('Not found', 404);
      }));

      await controller.loadPosts();

      expect(controller.posts.map((post) => post.id), <String>['wallet-post']);
      expect(controller.postsError, isNull);

      controller.dispose();
    });

    test(
        'account-uuid profile resolving to a wallet sends only authorWallet '
        'and keeps legacy wallet-authored posts', () async {
      // The account UUID is the route key, while the loaded user id is the
      // wallet: both identifiers are known, but only the wallet is sent.
      final controller = ProfilePackageController(walletAddress: accountUuid);
      controller.applyCritical(_critical(wallet: wallet, title: 'Milestone'));
      final requests = <Uri>[];
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path.contains('/api/community/posts')) {
          requests.add(request.url);
          // Legacy posts carry only the wallet, with no author userId.
          return _jsonResponse(<String, Object?>{
            'data': <Object?>[
              _walletPostJson(id: 'legacy-post', wallet: wallet),
            ],
          });
        }
        return http.Response('Not found', 404);
      }));

      await controller.loadPosts();

      expect(requests, hasLength(1));
      expect(requests.single.queryParameters['authorWallet'], wallet);
      expect(
          requests.single.queryParameters.containsKey('authorUserId'), isFalse);
      expect(controller.posts.map((post) => post.id), <String>['legacy-post']);
      expect(controller.postsError, isNull);

      controller.dispose();
    });

    test('profile with no posts yields an empty list without error', () async {
      final controller = ProfilePackageController(walletAddress: wallet);
      controller.applyCritical(_critical(wallet: wallet, title: 'Milestone'));
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path.contains('/api/community/posts')) {
          return _jsonResponse(<String, Object?>{'data': <Object?>[]});
        }
        return http.Response('Not found', 404);
      }));

      await controller.loadPosts();

      expect(controller.posts, isEmpty);
      expect(controller.postsError, isNull);
      expect(controller.postsLoading, isFalse);
      expect(controller.isLastPage, isTrue);

      controller.dispose();
    });

    test('loadMorePosts reuses the single author key on page two', () async {
      final controller = ProfilePackageController(walletAddress: wallet);
      controller.applyCritical(_critical(wallet: wallet, title: 'Milestone'));
      final requests = <Uri>[];
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path.contains('/api/community/posts')) {
          requests.add(request.url);
          final page = request.url.queryParameters['page'];
          final ids = page == '2'
              ? <String>['page-2-a', 'page-2-b', 'page-2-c']
              : List<String>.generate(20, (i) => 'page-1-$i');
          return _jsonResponse(<String, Object?>{
            'data': <Object?>[
              for (final id in ids) _walletPostJson(id: id, wallet: wallet),
            ],
          });
        }
        return http.Response('Not found', 404);
      }));

      await controller.loadPosts();

      expect(controller.posts, hasLength(20));
      expect(controller.isLastPage, isFalse);

      await controller.loadMorePosts();

      expect(requests, hasLength(2));
      expect(requests.last.queryParameters['page'], '2');
      for (final request in requests) {
        expect(request.queryParameters['authorWallet'], wallet);
        expect(request.queryParameters.containsKey('authorUserId'), isFalse);
      }
      expect(controller.posts, hasLength(23));
      expect(controller.posts.last.id, 'page-2-c');
      // Fewer than pageSize returned on page two: the list is complete.
      expect(controller.isLastPage, isTrue);
      expect(controller.postsError, isNull);

      controller.dispose();
    });
  });
  group('public profile entry under a failed lookup', () {
    test('a rate-limited profile is a transient failure, never not found',
        () async {
      const limitedWallet = 'profile_controller_rate_limited_wallet';
      BackendApiService().setHttpClient(MockClient((request) async {
        return http.Response('{"error":"Too many requests"}', 429);
      }));

      final outcome =
          await ProfilePackageService.loadPublicProfileCriticalOutcome(
        limitedWallet,
      );
      expect(
          outcome, isA<PublicEntityTransientFailure<ProfileCriticalPackage>>());

      final controller = ProfilePackageController(walletAddress: limitedWallet);
      await controller.load();
      expect(controller.criticalLoadFailedTransiently, isTrue);
      expect(controller.criticalLoadNotFound, isFalse,
          reason: 'a failed lookup is never the not-found answer');
      expect(controller.user, isNull);
      expect(controller.isLoadingCritical, isFalse);
      controller.dispose();
    });

    test('a missing profile (404) is not found, not a transient failure',
        () async {
      const missingWallet = 'profile_controller_missing_wallet';
      BackendApiService().setHttpClient(MockClient((request) async {
        return http.Response('{"error":"Not found"}', 404);
      }));

      final outcome =
          await ProfilePackageService.loadPublicProfileCriticalOutcome(
        missingWallet,
      );
      expect(outcome, isA<PublicEntityNotFound<ProfileCriticalPackage>>());

      final controller = ProfilePackageController(walletAddress: missingWallet);
      await controller.load();
      expect(controller.criticalLoadFailedTransiently, isFalse);
      // The answer resolves a pending takeover; it is not a failure.
      expect(controller.criticalLoadNotFound, isTrue);
      expect(controller.user, isNull);
      controller.dispose();
    });

    test('a prefetched transient failure reaches the controller as a failure',
        () async {
      final controller = ProfilePackageController(
        walletAddress: 'profile_controller_prefetch_wallet',
        initialCriticalPackageFuture:
            Future<PublicEntityLoadOutcome<ProfileCriticalPackage>>.value(
          const PublicEntityTransientFailure<ProfileCriticalPackage>(
            reason: 'rate limited',
            statusCode: 429,
          ),
        ),
      );
      await controller.load();
      expect(controller.criticalLoadFailedTransiently, isTrue);
      expect(controller.user, isNull);
      expect(controller.isLoadingCritical, isFalse);
      controller.dispose();
    });

    test('a prefetched not-found answer reaches the controller as not found',
        () async {
      final controller = ProfilePackageController(
        walletAddress: 'profile_controller_prefetch_missing_wallet',
        initialCriticalPackageFuture:
            Future<PublicEntityLoadOutcome<ProfileCriticalPackage>>.value(
          const PublicEntityNotFound<ProfileCriticalPackage>(),
        ),
      );
      await controller.load();
      expect(controller.criticalLoadNotFound, isTrue);
      expect(controller.criticalLoadFailedTransiently, isFalse);
      expect(controller.user, isNull);
      expect(controller.isLoadingCritical, isFalse);
      controller.dispose();
    });
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
    authorIdentityData: ProfileIdentityData.fromCompactAuthor(
      {
        'walletAddress': wallet,
        'displayName': 'Controller Profile',
      },
      fallbackLabel: 'Unknown author',
    ),
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

Map<String, Object?> _postJson({
  required String id,
  required String authorUserId,
}) {
  return <String, Object?>{
    'id': id,
    'content': 'Post $id',
    'createdAt': '2026-05-25T00:00:00.000Z',
    'author': <String, Object?>{
      'userId': authorUserId,
      'displayName': 'Author $authorUserId',
    },
  };
}

Map<String, Object?> _walletPostJson({
  required String id,
  required String wallet,
}) {
  return <String, Object?>{
    'id': id,
    'content': 'Post $id',
    'createdAt': '2026-05-25T00:00:00.000Z',
    'author': <String, Object?>{
      'walletAddress': wallet,
      'displayName': 'Controller Profile',
    },
  };
}

http.Response _jsonResponse(Map<String, Object?> payload) {
  return http.Response(
    jsonEncode(payload),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}
