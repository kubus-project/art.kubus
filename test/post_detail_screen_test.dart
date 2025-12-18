import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/community/post_detail_screen.dart';
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

  Widget wrapWithApp(Widget child) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routes: {
          '/artwork': (_) => const Scaffold(body: Text('Artwork Route')),
        },
        home: child,
      ),
    );
  }

  CommunityPost basePost({
    required String id,
    required String authorWallet,
    bool authorIsArtist = false,
    CommunityArtworkReference? artwork,
  }) {
    return CommunityPost(
      id: id,
      authorId: authorWallet,
      authorWallet: authorWallet,
      authorName: 'Alice',
      content: 'Hello',
      timestamp: DateTime(2025, 1, 1),
      likeCount: 0,
      commentCount: 0,
      shareCount: 0,
      comments: const [],
      artwork: artwork,
      authorIsArtist: authorIsArtist,
    );
  }

  testWidgets('Post detail shows tagged artwork and navigates on tap', (tester) async {
    final post = basePost(
      id: 'post-1',
      authorWallet: 'unknown',
      artwork: const CommunityArtworkReference(
        id: 'art-1',
        title: 'Artwork One',
      ),
    );

    await tester.pumpWidget(wrapWithApp(PostDetailScreen(post: post)));

    expect(find.text('Artwork One'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('post_detail_artwork_card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Artwork Route'), findsOneWidget);
  });

  testWidgets('Long-press like opens likes list and fetches once', (tester) async {
    var calls = 0;
    final post = basePost(id: 'post-1', authorWallet: 'unknown');

    Future<List<CommunityLikeUser>> loader(String postId) async {
      calls += 1;
      return const [
        CommunityLikeUser(
          userId: 'unknown',
          displayName: 'Bob',
        ),
      ];
    }

    await tester.pumpWidget(
      wrapWithApp(
        PostDetailScreen(
          post: post,
          postLikesLoader: loader,
        ),
      ),
    );

    await tester.longPress(find.byKey(const ValueKey('post_detail_like_action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(calls, 1);
    expect(find.text('Post likes'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('Three-dots menu shows Report for non-owner', (tester) async {
    final post = basePost(id: 'post-1', authorWallet: 'unknown');

    await tester.pumpWidget(
      wrapWithApp(
        PostDetailScreen(
          post: post,
          currentWalletAddressOverride: 'someone-else',
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('post_detail_more_menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('Three-dots menu shows Edit/Delete for owner', (tester) async {
    final post = basePost(id: 'post-1', authorWallet: 'unknown');

    await tester.pumpWidget(
      wrapWithApp(
        PostDetailScreen(
          post: post,
          currentWalletAddressOverride: 'unknown',
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('post_detail_more_menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Report'), findsNothing);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('Role badge appears next to poster name', (tester) async {
    final post = basePost(
      id: 'post-1',
      authorWallet: 'unknown',
      authorIsArtist: true,
    );

    await tester.pumpWidget(wrapWithApp(PostDetailScreen(post: post)));

    expect(find.byType(ArtistBadge), findsOneWidget);
  });
}
