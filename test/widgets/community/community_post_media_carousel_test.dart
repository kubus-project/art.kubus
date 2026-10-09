import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/community/community_post_media.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/community/community_post_caption.dart';
import 'package:art_kubus/widgets/community/community_post_media_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

CommunityPost _post({List<String> mediaUrls = const [], String? imageUrl}) =>
    CommunityPost(
      id: 'post-media',
      authorName: 'Ana Umetnica',
      content: 'A mural on the riverside wall.',
      timestamp: DateTime(2026, 10, 1, 12),
      mediaUrls: mediaUrls,
      imageUrl: imageUrl,
    );

Widget _harness(Widget child, {double width = 360, double textScale = 1}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    builder: (context, page) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: page!,
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

const _images = <String>[
  'https://example.test/uploads/a.jpg',
  'https://example.test/uploads/b.jpg',
  'https://example.test/uploads/c.jpg',
];

void main() {
  group('media helpers', () {
    test('recognises video files by extension, ignoring query strings', () {
      expect(communityMediaUrlIsVideo('/uploads/clip.mp4'), isTrue);
      expect(
          communityMediaUrlIsVideo('https://x.test/v/CLIP.MOV?sig=1'), isTrue);
      expect(communityMediaUrlIsVideo('https://x.test/a.webm#t=2'), isTrue);
      expect(communityMediaUrlIsVideo('/uploads/photo.jpg'), isFalse);
      expect(communityMediaUrlIsVideo('https://ipfs.io/ipfs/bafy'), isFalse);
    });

    test('uses mediaUrls in order and drops empty values', () {
      final urls = communityPostMediaUrls(
        _post(
          mediaUrls: const ['/uploads/1.jpg', '  ', '/uploads/2.mp4'],
          imageUrl: '/uploads/legacy.jpg',
        ),
        multiMediaEnabled: true,
      );
      expect(urls, ['/uploads/1.jpg', '/uploads/2.mp4']);
    });

    test('falls back to the single legacy imageUrl', () {
      expect(
        communityPostMediaUrls(_post(imageUrl: '/uploads/legacy.jpg')),
        ['/uploads/legacy.jpg'],
      );
      expect(communityPostMediaUrls(_post()), isEmpty);
    });
  });

  group('carousel', () {
    testWidgets('a single item has no counter, dots or arrows', (tester) async {
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(
            mediaUrls: ['https://example.test/uploads/a.jpg']),
      ));
      await tester.pump();

      expect(find.text('1 / 1'), findsNothing);
      expect(find.byTooltip(_l10n.communityMediaNext), findsNothing);
      expect(find.byTooltip(_l10n.communityMediaPrevious), findsNothing);
    });

    testWidgets('several items show the 1 / N counter and advance on swipe',
        (tester) async {
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: _images),
      ));
      await tester.pump();

      expect(find.text('1 / 3'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('focused arrow controls share carousel keyboard navigation',
        (tester) async {
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: _images),
      ));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(0, 0));
      await mouse.moveTo(tester.getCenter(find.byType(PageView)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_l10n.communityMediaNext));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      await mouse.removePointer();
    });

    testWidgets('tapping an image opens the post, swiping does not',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(_harness(
        CommunityPostMediaCarousel(
          mediaUrls: _images,
          onOpenMedia: () => opened++,
        ),
      ));
      await tester.pump();

      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(opened, 0, reason: 'a swipe must not open the post');

      await tester.tap(find.byType(PageView));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('a video item shows a play control and does not start a player',
        (tester) async {
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(
          mediaUrls: ['https://example.test/uploads/clip.mp4'],
        ),
      ));
      await tester.pump();

      expect(find.byTooltip(_l10n.communityMediaVideoPlay), findsOneWidget);
      expect(find.byTooltip(_l10n.communityMediaVideoMute), findsNothing);
    });

    testWidgets('compact mode shows the first item with a +N badge',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(_harness(
        CommunityPostMediaCarousel(
          mediaUrls: _images,
          compact: true,
          onOpenMedia: () => opened++,
        ),
      ));
      await tester.pump();

      expect(find.text('+2'), findsOneWidget);
      expect(find.text('1 / 3'), findsNothing);
      await tester.tap(find.text('+2'));
      expect(opened, 1);
    });
  });

  group('adaptive caption', () {
    const style = TextStyle(fontSize: 14, height: 1.5);
    // Ahem (the test font) draws each glyph one font-size wide, so at 360 px and
    // 14 px a line holds about 25 characters. 28 five-letter words make six
    // lines: past the four-line media preview, within the eight-line text one.
    final mediumText = List<String>.filled(28, 'abcd').join(' ');

    testWidgets('a short caption shows neither more nor less', (tester) async {
      await tester.pumpWidget(_harness(
        const CommunityPostCaption(text: 'A short caption.', style: style),
      ));
      await tester.pump();

      expect(find.text(_l10n.communityPostShowMore), findsNothing);
      expect(find.text(_l10n.communityPostShowLess), findsNothing);
    });

    testWidgets('a text-only caption collapses past eight lines, then toggles',
        (tester) async {
      final longText = List<String>.generate(
        12,
        (i) => 'Paragraph ${i + 1} of the long caption.',
      ).join('\n');
      await tester.pumpWidget(_harness(
        CommunityPostCaption(text: longText, style: style),
      ));
      await tester.pump();

      expect(find.text(_l10n.communityPostShowMore), findsOneWidget);
      await tester.tap(find.text(_l10n.communityPostShowMore));
      await tester.pump();
      expect(find.text(_l10n.communityPostShowLess), findsOneWidget);
      expect(find.text(_l10n.communityPostShowMore), findsNothing);

      await tester.tap(find.text(_l10n.communityPostShowLess));
      await tester.pump();
      expect(find.text(_l10n.communityPostShowMore), findsOneWidget);
    });

    testWidgets('media captions collapse sooner than text-only captions',
        (tester) async {
      await tester.pumpWidget(_harness(
        CommunityPostCaption(text: mediumText, style: style),
      ));
      await tester.pump();
      expect(find.text(_l10n.communityPostShowMore), findsNothing,
          reason: 'this caption fits the eight-line text preview');

      await tester.pumpWidget(_harness(
        CommunityPostCaption(
          text: mediumText,
          style: style,
          hasMedia: true,
        ),
      ));
      await tester.pump();
      expect(find.text(_l10n.communityPostShowMore), findsOneWidget,
          reason: 'the same caption exceeds the four-line media preview');
    });

    testWidgets('larger text scale makes the same caption collapse',
        (tester) async {
      await tester.pumpWidget(_harness(
        CommunityPostCaption(text: mediumText, style: style),
      ));
      await tester.pump();
      expect(find.text(_l10n.communityPostShowMore), findsNothing);

      await tester.pumpWidget(_harness(
        CommunityPostCaption(text: mediumText, style: style),
        textScale: 2,
      ));
      await tester.pump();
      expect(find.text(_l10n.communityPostShowMore), findsOneWidget);
    });

    testWidgets('an initially expanded caption shows the full text',
        (tester) async {
      await tester.pumpWidget(_harness(
        CommunityPostCaption(
          text: mediumText,
          style: style,
          hasMedia: true,
          initiallyExpanded: true,
        ),
      ));
      await tester.pump();

      expect(find.text(_l10n.communityPostShowLess), findsOneWidget);
      final body = tester.widget<Text>(find.text(mediumText));
      expect(body.maxLines, isNull);
    });
  });
}
