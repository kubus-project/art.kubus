import 'dart:ui' as ui;

import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/community_subject_provider.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/community/community_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

CommunityPost _post({bool liked = false, bool saved = false}) => CommunityPost(
      id: 'post-1',
      authorName: 'Ana Umetnica',
      authorUsername: 'ana',
      content: 'A mural on the riverside wall.',
      timestamp: DateTime(2026, 9, 27, 12),
      likeCount: 12,
      commentCount: 3,
      shareCount: 1,
      isLiked: liked,
      isBookmarked: saved,
    );

Future<void> _pump(
  WidgetTester tester,
  CommunityPost post, {
  VoidCallback? onLike,
  VoidCallback? onSave,
  VoidCallback? onShare,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<CommunitySubjectProvider>(
      create: (_) => CommunitySubjectProvider(),
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(extensions: const [KubusColorRoles.light]),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CommunityPostCard(
              post: post,
              accentColor: KubusColorRoles.light.active,
              onOpenPostDetail: (_) {},
              onToggleLike: onLike ?? () {},
              onOpenComments: () {},
              onRepost: () {},
              onShare: onShare ?? () {},
              onToggleBookmark: onSave ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

SemanticsNode _node(WidgetTester tester, String label) =>
    tester.getSemantics(find.bySemanticsLabel(RegExp('^$label')));

void main() {
  testWidgets('like and save are toggles; comment, repost and share are not',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _post(liked: true));

    final like = _node(tester, 'Like');
    expect(like.label, 'Like, 12');
    expect(like.flagsCollection.isButton, isTrue);
    expect(like.flagsCollection.isToggled, ui.Tristate.isTrue);

    final save = _node(tester, 'Save');
    expect(save.flagsCollection.isToggled, ui.Tristate.isFalse);

    for (final oneShot in ['Comment', 'Repost', 'Share']) {
      final node = _node(tester, oneShot);
      expect(node.flagsCollection.isButton, isTrue, reason: oneShot);
      expect(node.flagsCollection.isToggled, ui.Tristate.none, reason: oneShot);
    }
    handle.dispose();
  });

  testWidgets('post actions meet the 44 px target and fire their callbacks',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var liked = 0;
    var saved = 0;
    var shared = 0;
    await _pump(
      tester,
      _post(),
      onLike: () => liked++,
      onSave: () => saved++,
      onShare: () => shared++,
    );
    expect(tester.takeException(), isNull);

    for (final icon in [
      Icons.favorite_border,
      Icons.share_outlined,
      Icons.bookmark_border,
    ]) {
      final target = find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(InkWell),
      );
      final size = tester.getSize(target.first);
      expect(size.height, greaterThanOrEqualTo(44), reason: '$icon');
      expect(size.width, greaterThanOrEqualTo(44), reason: '$icon');
    }

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.tap(find.byIcon(Icons.share_outlined));
    expect([liked, saved, shared], [1, 1, 1]);
  });

  testWidgets('the post surface is flat (no glass panel)', (tester) async {
    await _pump(tester, _post());
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
