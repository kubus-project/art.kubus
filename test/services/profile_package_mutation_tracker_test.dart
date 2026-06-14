import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/achievement_progress.dart' as legacy_progress;
import 'package:art_kubus/models/achievements.dart' as achievements;
import 'package:art_kubus/models/profile_package.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/services/profile_package_mutation_tracker.dart';
import 'package:art_kubus/services/profile_package_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const wallet = 'tracker_wallet';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ProfilePackageService.clearMemoryCacheForTesting();
    ProfilePackageMutationTracker.clearDebugEventsForTesting();
  });

  tearDown(() {
    ProfilePackageService.clearMemoryCacheForTesting();
    ProfilePackageMutationTracker.clearDebugEventsForTesting();
  });

  test('profileChanged invalidates full package', () {
    ProfilePackageService.setCachedPackageForTesting(_package(wallet));

    ProfilePackageMutationTracker.profileChanged(wallet);

    expect(ProfilePackageService.getCachedPackage(wallet), isNull);
    expect(
      ProfilePackageMutationTracker.debugEvents.single.kind,
      ProfilePackageMutationKind.profileChanged,
    );
  });

  test('profileMediaChanged invalidates full package', () {
    ProfilePackageService.setCachedPackageForTesting(_package(wallet));

    ProfilePackageMutationTracker.profileMediaChanged(wallet);

    expect(ProfilePackageService.getCachedPackage(wallet), isNull);
    expect(
      ProfilePackageMutationTracker.debugEvents.single.kind,
      ProfilePackageMutationKind.profileMediaChanged,
    );
  });

  test('followStateChanged patches target user and preserves achievements', () {
    ProfilePackageService.setCachedPackageForTesting(_package(wallet));

    ProfilePackageMutationTracker.followStateChanged(
      targetWallet: wallet,
      isFollowing: true,
      followersCount: 9,
    );

    final critical = ProfilePackageService.getCachedCriticalPackage(wallet)!;
    expect(critical.user.isFollowing, isTrue);
    expect(critical.user.followersCount, 9);
    expect(critical.achievementDefinitions.single.title, 'Backend title');
  });

  test('postCreated invalidates posts and patches achievement result', () {
    ProfilePackageService.setCachedPackageForTesting(_package(wallet));
    ProfilePackageService.setCachedExtendedPackageForTesting(
      wallet,
      ProfileExtendedPackage(
        initialPosts: <CommunityPost>[_post(wallet)],
        fetchedAt: DateTime.now(),
      ),
    );

    ProfilePackageMutationTracker.postCreated(
      post: _post(wallet),
      achievementResult: _achievementResult(),
    );

    expect(ProfilePackageService.getCachedExtendedPackage(wallet), isNull);
    final critical = ProfilePackageService.getCachedCriticalPackage(wallet)!;
    expect(
      critical.achievementProgress
          .firstWhere((item) => item.achievementId == 'backend_milestone')
          .currentProgress,
      2,
    );
    expect(
        ProfilePackageMutationTracker.debugEvents.single.hasAchievementResult,
        isTrue);
  });

  test('postDeleted invalidates posts only', () {
    ProfilePackageService.setCachedPackageForTesting(_package(wallet));
    ProfilePackageService.setCachedExtendedPackageForTesting(
      wallet,
      ProfileExtendedPackage(
        initialPosts: <CommunityPost>[_post(wallet)],
        fetchedAt: DateTime.now(),
      ),
    );

    ProfilePackageMutationTracker.postDeleted(authorWallet: wallet);

    expect(ProfilePackageService.getCachedExtendedPackage(wallet), isNull);
    expect(
      ProfilePackageService.getCachedCriticalPackage(wallet)!
          .achievementDefinitions
          .single
          .title,
      'Backend title',
    );
  });

  test('showcaseChanged invalidates extended package only', () {
    ProfilePackageService.setCachedPackageForTesting(_package(wallet));
    ProfilePackageService.setCachedExtendedPackageForTesting(
      wallet,
      ProfileExtendedPackage(
        artistArtworks: const <Map<String, dynamic>>[
          <String, dynamic>{'id': 'artwork-1'},
        ],
        fetchedAt: DateTime.now(),
      ),
    );

    ProfilePackageMutationTracker.showcaseChanged(wallet);

    expect(ProfilePackageService.getCachedExtendedPackage(wallet), isNull);
    expect(ProfilePackageService.getCachedCriticalPackage(wallet), isNotNull);
  });

  test('achievementResult patches progress and preserves definitions', () {
    ProfilePackageService.setCachedPackageForTesting(_package(wallet));

    ProfilePackageMutationTracker.achievementResult(
      wallet: wallet,
      result: _achievementResult(),
    );

    final critical = ProfilePackageService.getCachedCriticalPackage(wallet)!;
    expect(critical.achievementDefinitions.single.title, 'Backend title');
    expect(
      critical.achievementProgress
          .firstWhere((item) => item.achievementId == 'backend_milestone')
          .currentProgress,
      2,
    );
    expect(
        ProfilePackageMutationTracker.debugEvents.single.hasAchievementResult,
        isTrue);
  });

  test('debug sink receives compact mutation events', () {
    final events = <ProfilePackageMutationEvent>[];
    ProfilePackageMutationTracker.setDebugSink(events.add);

    ProfilePackageMutationTracker.showcaseChanged(wallet);

    expect(events, hasLength(1));
    expect(events.single.kind, ProfilePackageMutationKind.showcaseChanged);
    expect(events.single.wallet, wallet);
  });
}

ProfilePackage _package(String wallet) {
  final definition = achievements.AchievementDefinition(
    code: 'backend_milestone',
    title: 'Backend title',
    description: 'Backend definition',
    category: 'community',
    rarity: 'common',
    requiredCount: 3,
  );
  final progress = legacy_progress.AchievementProgress(
    achievementId: 'backend_milestone',
    currentProgress: 1,
    isCompleted: false,
  );
  final user = User(
    id: wallet,
    name: 'Tracker User',
    username: 'tracker',
    bio: '',
    followersCount: 1,
    followingCount: 2,
    postsCount: 1,
    isFollowing: false,
    isVerified: false,
    joinedDate: 'Joined 5/2026',
    achievementProgress: <legacy_progress.AchievementProgress>[progress],
    achievementDefinitions: <achievements.AchievementDefinition>[definition],
  );

  return ProfilePackage.fromParts(
    critical: ProfileCriticalPackage(
      user: user,
      achievementProgress: <legacy_progress.AchievementProgress>[progress],
      achievementDefinitions: <achievements.AchievementDefinition>[definition],
      publicStats: const <String, int>{'followers': 1, 'posts': 1},
      fetchedAt: DateTime.now(),
      isComplete: true,
    ),
    extended: ProfileExtendedPackage(
      initialPosts: <CommunityPost>[_post(wallet)],
      fetchedAt: DateTime.now(),
    ),
  );
}

CommunityPost _post(String wallet) {
  return CommunityPost(
    id: 'post-1',
    authorIdentityData: ProfileIdentityData.fromCompactAuthor(
      {
        'walletAddress': wallet,
        'displayName': 'Tracker User',
      },
      fallbackLabel: 'Unknown author',
    ),
    content: 'Profile package mutation tracker test post',
    timestamp: DateTime.now(),
  );
}

achievements.AchievementEventResult _achievementResult() {
  return achievements.AchievementEventResult(
    progress: const <achievements.AchievementProgress>[
      achievements.AchievementProgress(
        achievementCode: 'backend_milestone',
        currentProgress: 2,
        requiredCount: 3,
        isCompleted: false,
      ),
    ],
  );
}
