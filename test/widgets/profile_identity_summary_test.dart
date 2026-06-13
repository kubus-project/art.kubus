import 'package:art_kubus/models/promotion.dart';
import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/community_subject_provider.dart';
import 'package:art_kubus/widgets/avatar_widget.dart';
import 'package:art_kubus/widgets/community/community_post_card.dart';
import 'package:art_kubus/widgets/profile_identity_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
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
}
