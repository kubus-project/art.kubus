import 'dart:ui' as ui;

import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/community/community_comment_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Comment _comment({bool liked = false, int likes = 0, String? parent}) =>
    Comment(
      id: parent == null ? 'c1' : 'c1r1',
      parentCommentId: parent,
      authorName: 'Ana Kovač',
      authorId: 'ana',
      content: 'Thank you! It took three weekends.',
      timestamp: DateTime(2026, 9, 20, 16),
      likeCount: likes,
      isLiked: liked,
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(extensions: const [KubusColorRoles.light]),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Like is a toggle; the likes count and Reply are buttons',
      (tester) async {
    final handle = tester.ensureSemantics();
    var likes = 0;
    var replies = 0;
    var lists = 0;
    await _pump(
      tester,
      CommunityCommentRow(
        comment: _comment(liked: true, likes: 3),
        isReply: false,
        timeLabel: '2h ago',
        onToggleLike: () => likes++,
        onShowLikes: () => lists++,
        onReply: () => replies++,
      ),
    );

    final like = tester.getSemantics(find.bySemanticsLabel('Like'));
    expect(like.flagsCollection.isToggled, ui.Tristate.isTrue);
    expect(like.flagsCollection.isButton, isTrue);

    final count = tester.getSemantics(find.bySemanticsLabel('3 likes'));
    expect(count.flagsCollection.isButton, isTrue);
    expect(count.flagsCollection.isToggled, ui.Tristate.none);

    await tester.tap(find.bySemanticsLabel('Like'));
    await tester.tap(find.bySemanticsLabel('3 likes'));
    await tester.tap(find.bySemanticsLabel('Reply'));
    expect((likes, lists, replies), (1, 1, 1));

    for (final label in <String>['Like', '3 likes', 'Reply']) {
      final size = tester.getSize(find.bySemanticsLabel(label));
      expect(size.height, greaterThanOrEqualTo(44), reason: label);
      expect(size.width, greaterThanOrEqualTo(44), reason: label);
    }
    handle.dispose();
  });

  testWidgets('no likes count is shown when a comment has no likes',
      (tester) async {
    await _pump(
      tester,
      CommunityCommentRow(
        comment: _comment(),
        isReply: false,
        timeLabel: 'now',
        onToggleLike: () {},
      ),
    );
    expect(find.textContaining('like'), findsNothing);
  });

  testWidgets('replies use one fixed offset and fit at 320 px', (tester) async {
    await _pump(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommunityCommentRow(
            key: const ValueKey('root'),
            comment: _comment(),
            isReply: false,
            timeLabel: '2h ago',
            onReply: () {},
          ),
          CommunityCommentRow(
            key: const ValueKey('reply'),
            comment: _comment(parent: 'c1'),
            isReply: true,
            timeLabel: '1h ago',
            onReply: () {},
          ),
        ],
      ),
      width: 320,
    );
    expect(tester.takeException(), isNull);
    final root = tester.getTopLeft(find.byKey(const ValueKey('root')));
    final replyText = tester.getTopLeft(
      find.descendant(
        of: find.byKey(const ValueKey('reply')),
        matching: find.text('Thank you! It took three weekends.'),
      ),
    );
    // Offset is bounded (fixed rule + inset), not cumulative indentation.
    expect(replyText.dx - root.dx, lessThanOrEqualTo(80));
  });
}
