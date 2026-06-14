import 'package:art_kubus/models/promotion.dart';
import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/community_subject_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/profile_package_service.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:art_kubus/utils/profile_package_prefetcher.dart';
import 'package:art_kubus/widgets/avatar_widget.dart';
import 'package:art_kubus/widgets/community/community_post_card.dart';
import 'package:art_kubus/widgets/community/community_likes_sheet.dart';
import 'package:art_kubus/widgets/profile_identity_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Widget communityHarness(Widget child) {
    return ChangeNotifierProvider(
      create: (_) => CommunitySubjectProvider(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  CommunityPost post({
    required String id,
    required String displayName,
    String content = 'Community payload',
    String? username,
    String? postType,
    CommunityPost? originalPost,
  }) {
    return CommunityPost(
      id: id,
      authorIdentityData: ProfileIdentityData.fromCompactAuthor(
        {
          'displayName': displayName,
          if (username != null) 'username': username,
          'walletAddress': '0x${id.padRight(40, '1')}',
        },
        fallbackLabel: 'Unknown author',
      ),
      content: content,
      timestamp: DateTime.utc(2026),
      postType: postType,
      originalPost: originalPost,
    );
  }

  test('fromProfileMap prefers explicit avatar fields and sanitized handle',
      () {
    final identity = ProfileIdentityData.fromProfileMap(
      <String, dynamic>{
        'id': 'wallet-artist-1',
        'displayName': 'Ada Lovelace',
        'username': '@ada',
        'avatar_url': '/uploads/ada-avatar.png',
        'cover_image_url': '/uploads/ada-cover.png',
      },
      fallbackLabel: 'Creator',
    );

    expect(identity.label, 'Ada Lovelace');
    expect(identity.handle, '@ada');
    expect(identity.username, 'ada');
    expect(identity.avatarUrl, '/uploads/ada-avatar.png');
    expect(identity.userId, 'wallet-artist-1');
  });

  test('fromHomeRailItem profile uses avatar fields instead of cover image',
      () {
    final item = HomeRailItem.fromJson(<String, dynamic>{
      'id': 'wallet-artist-1',
      'entityType': 'profile',
      'title': 'Ada Lovelace',
      'subtitle': '@ada',
      'imageUrl': '/uploads/ada-cover.png',
      'avatar_url': '/uploads/ada-avatar.png',
    });

    final identity = ProfileIdentityData.fromHomeRailItem(
      item,
      fallbackLabel: 'Creator',
    );

    expect(identity.label, 'Ada Lovelace');
    expect(identity.handle, '@ada');
    expect(identity.avatarUrl, '/uploads/ada-avatar.png');
    expect(identity.userId, 'wallet-artist-1');
  });

  testWidgets('community post card renders backend author display name',
      (tester) async {
    await tester.pumpWidget(
      communityHarness(
        CommunityPostCard(
          post: post(id: 'post1', displayName: 'Mina Creator'),
          accentColor: Colors.teal,
          onOpenPostDetail: (_) {},
        ),
      ),
    );

    expect(find.text('Mina Creator'), findsOneWidget);
  });

  testWidgets('ProfileIdentitySummary with explicit onTap is tappable',
      (tester) async {
    final requests = <String>[];
    var taps = 0;
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request.url.path);
      return http.Response('Unexpected profile fetch', 500);
    }));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileIdentitySummary(
            identity: ProfileIdentityData.fromValues(
              fallbackLabel: 'Unknown author',
              displayName: 'Tappable Author',
              username: 'tap-author',
              userId: '0x${'a'.padRight(40, 'a')}',
              wallet: '0x${'a'.padRight(40, 'a')}',
            ),
            fetchMissingAvatar: false,
            onTap: () => taps += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tappable Author'));
    await tester.pump();

    expect(taps, 1);
    expect(requests, isEmpty);
  });

  testWidgets('community post author tap invokes profile identity callback',
      (tester) async {
    ProfileIdentityData? tappedIdentity;

    await tester.pumpWidget(
      communityHarness(
        CommunityPostCard(
          post: post(
            id: 'tap-post',
            displayName: 'Mina Creator',
            username: 'mina',
          ),
          accentColor: Colors.teal,
          onOpenPostDetail: (_) {},
          onOpenProfileIdentity: (identity) => tappedIdentity = identity,
        ),
      ),
    );

    await tester.tap(find.text('Mina Creator'));
    await tester.pump();

    expect(tappedIdentity?.label, 'Mina Creator');
    expect(tappedIdentity?.username, 'mina');
  });

  testWidgets(
      'community post card renders feed payload like and bookmark state',
      (tester) async {
    await tester.pumpWidget(
      communityHarness(
        CommunityPostCard(
          post: post(
            id: 'postpayload',
            displayName: 'Mina Creator',
          ).copyWith(
            isLiked: true,
            isBookmarked: true,
          ),
          accentColor: Colors.teal,
          onOpenPostDetail: (_) {},
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byIcon(Icons.bookmark_border), findsNothing);
  });

  testWidgets('feed byline does not prefetch profile package before paint',
      (tester) async {
    final requests = <String>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request.url.path);
      return http.Response('Unexpected profile prefetch', 500);
    }));

    await tester.pumpWidget(
      communityHarness(
        CommunityPostCard(
          post: post(
            id: 'post2',
            displayName: 'Mina Creator',
          ),
          accentColor: Colors.teal,
          onOpenPostDetail: (_) {},
          onOpenAuthorProfile: () {},
        ),
      ),
    );

    expect(requests, isEmpty);
    expect(
      ProfilePackageService.getCachedCriticalPackage(
        '0xpost211111111111111111111111111111111111',
      ),
      isNull,
    );
  });

  testWidgets('repost inner card renders original author display name',
      (tester) async {
    final original = post(
      id: 'orig1',
      displayName: 'Original Artist',
      content: 'Original post',
    );
    final repost = post(
      id: 'repost1',
      displayName: 'Reposting Curator',
      content: 'Shared this',
      postType: 'repost',
      originalPost: original,
    );

    await tester.pumpWidget(
      communityHarness(
        CommunityPostCard(
          post: repost,
          accentColor: Colors.teal,
          onOpenPostDetail: (_) {},
        ),
      ),
    );

    expect(find.text('Reposting Curator'), findsOneWidget);
    expect(find.text('Original Artist'), findsOneWidget);
  });

  testWidgets('repost original author tap invokes profile identity callback',
      (tester) async {
    final original = post(
      id: 'orig2',
      displayName: 'Original Artist',
      content: 'Original post',
      username: 'original',
    );
    final repost = post(
      id: 'repost2',
      displayName: 'Reposting Curator',
      content: 'Shared this',
      postType: 'repost',
      originalPost: original,
    );
    ProfileIdentityData? tappedIdentity;

    await tester.pumpWidget(
      communityHarness(
        CommunityPostCard(
          post: repost,
          accentColor: Colors.teal,
          onOpenPostDetail: (_) {},
          onOpenProfileIdentity: (identity) => tappedIdentity = identity,
        ),
      ),
    );

    await tester.tap(find.text('Original Artist'));
    await tester.pump();

    expect(tappedIdentity?.label, 'Original Artist');
    expect(tappedIdentity?.username, 'original');
  });

  testWidgets('comment author renders unified identity display name',
      (tester) async {
    final comment = Comment(
      id: 'comment1',
      content: 'Looks good',
      timestamp: DateTime.utc(2026),
      authorIdentityData: ProfileIdentityData.fromCompactAuthor(
        {
          'displayName': 'Comment Author',
          'username': 'commenter',
          'walletAddress': '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
        },
        fallbackLabel: 'Unknown author',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileIdentitySummary(
            identity: comment.authorIdentityData,
            fetchMissingAvatar: false,
          ),
        ),
      ),
    );

    expect(find.text('Comment Author'), findsOneWidget);
    final avatar = tester.widget<AvatarWidget>(find.byType(AvatarWidget).first);
    expect(avatar.fetchMissingAvatar, isFalse);
    expect(avatar.enableProfileNavigation, isFalse);
  });

  testWidgets('inline comment author tap invokes profile identity callback',
      (tester) async {
    var tapped = false;
    final commentIdentity = ProfileIdentityData.fromCompactAuthor(
      {
        'displayName': 'Comment Author',
        'username': 'commenter',
        'walletAddress': '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
      },
      fallbackLabel: 'Unknown author',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileIdentitySummary(
            identity: commentIdentity,
            fetchMissingAvatar: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Comment Author'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('art-feed author tap invokes profile identity callback',
      (tester) async {
    var tapped = false;
    final artFeedIdentity = ProfileIdentityData.fromCompactAuthor(
      {
        'displayName': 'Art Feed Artist',
        'username': 'art-feed',
        'walletAddress': '0x1234512345123451234512345123451234512345',
      },
      fallbackLabel: 'Unknown author',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileIdentitySummary(
            identity: artFeedIdentity,
            fetchMissingAvatar: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Art Feed Artist'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('comment author render does not prefetch profile package',
      (tester) async {
    final requests = <String>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request.url.path);
      return http.Response('Unexpected profile prefetch', 500);
    }));
    final commentIdentity = ProfileIdentityData.fromCompactAuthor(
      {
        'displayName': 'Quiet Comment Author',
        'username': 'quiet-commenter',
        'walletAddress': '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
      },
      fallbackLabel: 'Unknown author',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileIdentitySummary(
            identity: commentIdentity,
            fetchMissingAvatar: false,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(requests, isEmpty);
    final avatar = tester.widget<AvatarWidget>(find.byType(AvatarWidget).first);
    expect(avatar.enableProfileNavigation, isFalse);
  });

  testWidgets('like list actor tap invokes profile identity callback',
      (tester) async {
    final tapped = <ProfileIdentityData>[];
    final likedAt = DateTime.utc(2026, 1, 2);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showCommunityLikesSheet(
                    context: context,
                    title: 'Likes',
                    loader: () async => <CommunityLikeUser>[
                      CommunityLikeUser(
                        userId: 'user_like_1',
                        walletAddress: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
                        displayName: 'Like Actor',
                        username: 'like-actor',
                        likedAt: likedAt,
                      ),
                    ],
                    formatTimeAgo: (_) => 'now',
                    errorMessage: 'Failed',
                    unnamedUserLabel: 'Unnamed',
                    onOpenProfileIdentity: tapped.add,
                  );
                },
                child: const Text('open likes'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open likes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Like Actor'));
    await tester.pump();

    expect(tapped, hasLength(1));
    expect(tapped.single.userId, 'user_like_1');
    expect(tapped.single.username, 'like-actor');
    final avatar = tester.widget<AvatarWidget>(find.byType(AvatarWidget).first);
    expect(avatar.enableProfileNavigation, isFalse);
  });

  testWidgets('avatar tap and name tap resolve to the same identity',
      (tester) async {
    final tapped = <ProfileIdentityData>[];
    final identity = ProfileIdentityData.fromCompactAuthor(
      {
        'id': 'same-identity',
        'displayName': 'Same Actor',
        'username': 'same-actor',
        'walletAddress': '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
      },
      fallbackLabel: 'Unknown author',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileIdentitySummary(
            identity: identity,
            fetchMissingAvatar: false,
            onTap: () => tapped.add(identity),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AvatarWidget));
    await tester.pump();
    await tester.tap(find.text('Same Actor'));
    await tester.pump();

    expect(tapped, hasLength(2));
    expect(tapped.every((value) => value.userId == 'same-identity'), isTrue);
    expect(tapped.every((value) => value.username == 'same-actor'), isTrue);
  });

  test('repost/share list actor payload normalizes to profile identity', () {
    final identity = communityRepostIdentityDataFromPayload(
      <String, dynamic>{
        'id': 'repost-user-1',
        'walletAddress': '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
        'displayName': 'Repost Actor',
        'username': 'repost-actor',
        'avatar': '/uploads/repost.png',
      },
      fallbackLabel: 'Unknown user',
    );

    expect(identity.userId, 'repost-user-1');
    expect(identity.label, 'Repost Actor');
    expect(identity.username, 'repost-actor');
    expect(identity.avatarUrl, '/uploads/repost.png');
  });
}
