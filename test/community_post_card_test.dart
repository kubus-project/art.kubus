import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/widgets/community/community_post_card.dart';
import 'package:art_kubus/widgets/artist_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('CommunityPostCard renders tags, mentions, and role badge', (tester) async {
    final post = CommunityPost(
      id: 'post-1',
      authorId: 'unknown',
      authorName: 'Alice',
      content: 'Hello world',
      timestamp: DateTime(2025, 1, 1),
      tags: const ['topic'],
      mentions: const ['bob'],
      authorIsArtist: true,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              child: CommunityPostCard(
                post: post,
                accentColor: Colors.teal,
                onOpenPostDetail: (_) {},
                onOpenAuthorProfile: () {},
                onToggleLike: () {},
                onOpenComments: () {},
                onRepost: () {},
                onShare: () {},
                onToggleBookmark: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('#topic'), findsOneWidget);
    expect(find.text('@bob'), findsOneWidget);
    expect(find.byType(ArtistBadge), findsOneWidget);
  });

  testWidgets('CommunityPostCard renders repost preview when present', (tester) async {
    final original = CommunityPost(
      id: 'original-1',
      authorId: 'unknown',
      authorName: 'Original Author',
      content: 'Original content',
      timestamp: DateTime(2025, 1, 1),
    );

    final repost = CommunityPost(
      id: 'repost-1',
      authorId: 'unknown',
      authorName: 'Reposter',
      content: 'Repost comment',
      timestamp: DateTime(2025, 1, 1),
      postType: 'repost',
      originalPost: original,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              child: CommunityPostCard(
                post: repost,
                accentColor: Colors.teal,
                onOpenPostDetail: (_) {},
                onOpenAuthorProfile: () {},
                onToggleLike: () {},
                onOpenComments: () {},
                onRepost: () {},
                onShare: () {},
                onToggleBookmark: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Repost comment'), findsOneWidget);
    expect(find.text('Original content'), findsOneWidget);
    expect(find.text('Original Author'), findsOneWidget);
  });
}
