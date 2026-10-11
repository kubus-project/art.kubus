import 'dart:ui' as ui;

import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/community_subject_provider.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/community/community_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  VoidCallback? onShowLikes,
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
              onShowLikes: onShowLikes,
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
    expect(like.label, 'Like, 12 likes, liked');
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

  testWidgets(
      'post actions meet the 48 px mobile target and fire their callbacks',
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
      expect(size.height, greaterThanOrEqualTo(48), reason: '$icon');
      expect(size.width, greaterThanOrEqualTo(48), reason: '$icon');
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

  testWidgets('each action is a focusable button named with its count or state',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _post());

    for (final label in [
      'Like, 12 likes, not liked',
      'Comment, 3 comments',
      'Save, not saved',
    ]) {
      final data =
          tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue, reason: label);
      expect(data.hasAction(SemanticsAction.focus), isTrue, reason: label);
      expect(data.hasAction(SemanticsAction.tap), isTrue, reason: label);
    }
    handle.dispose();
  });

  testWidgets('a liked post names its like as liked', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _post(liked: true, saved: true));

    expect(find.bySemanticsLabel('Like, 12 likes, liked'), findsOneWidget);
    expect(find.bySemanticsLabel('Save, saved'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a focused action activates on Enter and on Space',
      (tester) async {
    final handle = tester.ensureSemantics();
    var liked = 0;
    await _pump(tester, _post(), onLike: () => liked++);

    final like = tester.getSemantics(
      find.bySemanticsLabel('Like, 12 likes, not liked'),
    );
    // The finders read this owner; the rootPipelineOwner is a different tree here.
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!
        .performAction(like.id, SemanticsAction.focus);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(liked, 2);
    handle.dispose();
  });

  testWidgets('a count that opens its own list is a separate labeled button',
      (tester) async {
    final handle = tester.ensureSemantics();
    var liked = 0;
    var listed = 0;
    await _pump(
      tester,
      _post(liked: true),
      onLike: () => liked++,
      onShowLikes: () => listed++,
    );

    final toggle =
        tester.getSemantics(find.bySemanticsLabel('Like, 12 likes, liked'));
    expect(toggle.flagsCollection.isToggled, ui.Tristate.isTrue);
    final count = tester.getSemantics(find.bySemanticsLabel('12 likes'));
    expect(count.flagsCollection.isButton, isTrue);
    expect(count.flagsCollection.isToggled, ui.Tristate.none);
    // A count with no list of its own stays plain text, not a button.
    expect(find.bySemanticsLabel('3 comments'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('3 comments'))
          .flagsCollection
          .isButton,
      isFalse,
    );

    tester.semantics.tap(find.semantics.byLabel('12 likes'));
    tester.semantics.tap(find.semantics.byLabel('Like, 12 likes, liked'));
    expect([liked, listed], [1, 1]);
    handle.dispose();
  });

  for (final width in <double>[320, 360, 390]) {
    testWidgets('actions and counts fit a $width px card without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(
        tester,
        _post(liked: true, saved: true),
        onShowLikes: () {},
      );
      expect(tester.takeException(), isNull);
    });
  }
}
