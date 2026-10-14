// ignore_for_file: depend_on_referenced_packages

import 'dart:math' as math;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/community/community_post_media_carousel.dart';
import 'package:art_kubus/widgets/community/community_post_video_slide.dart';
import 'package:art_kubus/widgets/community/community_video_autoplay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/fake_video_player_platform.dart';

Widget _harness(
  Widget child, {
  double width = 600,
  double viewportHeight = 900,
}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(size: Size(width, viewportHeight)),
          child: SingleChildScrollView(
            child: Center(child: SizedBox(width: width, child: child)),
          ),
        ),
      ),
    );

double _maximumStageHeight(double viewportHeight) =>
    math.max(kCommunityVideoStageMinHeight, viewportHeight * 0.72);

double _stageHeight(WidgetTester tester) =>
    tester.getSize(find.byType(ClipRRect).first).height;

void main() {
  setUp(() {
    CommunityPostVideoSlide.knownAspects.clear();
    CommunityVideoAutoplay.enabledOverride = false;
  });
  tearDown(() => CommunityVideoAutoplay.enabledOverride = null);

  group('communityVideoStageAspect', () {
    test('keeps ordinary clip shapes as they are', () {
      expect(communityVideoStageAspect(16 / 9), closeTo(16 / 9, 1e-9));
      expect(communityVideoStageAspect(4 / 3), closeTo(4 / 3, 1e-9));
      expect(communityVideoStageAspect(1), 1);
      expect(communityVideoStageAspect(21 / 9), closeTo(21 / 9, 1e-9));
      expect(communityVideoStageAspect(32 / 9), closeTo(32 / 9, 1e-9));
    });

    test('bounds the extremes and falls back to 16:9 when unknown', () {
      expect(communityVideoStageAspect(64 / 9), kCommunityVideoStageMaxAspect);
      expect(communityVideoStageAspect(9 / 16), kCommunityVideoStageMinAspect);
      expect(communityVideoStageAspect(null), 16 / 9);
      expect(communityVideoStageAspect(double.nan), 16 / 9);
      expect(communityVideoStageAspect(0), 16 / 9);
    });
  });

  group('single-video stage', () {
    const url = 'https://example.test/uploads/clip.mp4';

    for (final c in <(String, double)>[
      ('16:9', 16 / 9),
      ('21:9', 21 / 9),
      ('32:9', 32 / 9),
      ('4:3', 4 / 3),
      ('1:1', 1),
      ('9:16 portrait', 9 / 16),
    ]) {
      testWidgets('${c.$1} metadata never changes the stable stage height',
          (tester) async {
        CommunityPostVideoSlide.knownAspects[url] = c.$2;
        await tester.pumpWidget(_harness(
          const CommunityPostMediaCarousel(mediaUrls: [url]),
        ));
        await tester.pumpAndSettle();
        expect(_stageHeight(tester), closeTo(600 / 16 * 9, 0.6));
      });
    }

    testWidgets('an ultrawide clip stays inside the same stable stage',
        (tester) async {
      CommunityPostVideoSlide.knownAspects[url] = 32 / 9;
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: [url]),
      ));
      await tester.pumpAndSettle();
      expect(_stageHeight(tester), closeTo(600 * 9 / 16, 0.6));
    });

    testWidgets('the stage never drops below the controls minimum',
        (tester) async {
      CommunityPostVideoSlide.knownAspects[url] = 32 / 9;
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: [url]),
        width: 160,
      ));
      await tester.pumpAndSettle();
      expect(_stageHeight(tester), kCommunityVideoStageMinHeight);
    });

    testWidgets('an unknown clip starts at 16:9', (tester) async {
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: [url]),
      ));
      await tester.pumpAndSettle();
      expect(_stageHeight(tester), closeTo(600 * 9 / 16, 0.6));
    });

    testWidgets('portrait stage is capped by the available desktop viewport',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      CommunityPostVideoSlide.knownAspects[url] = 9 / 16;
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: [url]),
        width: 1200,
        viewportHeight: 700,
      ));
      await tester.pumpAndSettle();
      expect(_stageHeight(tester), closeTo(_maximumStageHeight(700), 0.6));
    });

    testWidgets('unavailable preview stays inside the capped desktop stage',
        (tester) async {
      const unavailableUrl = 'https://example.test/uploads/portrait.mp4';
      CommunityPostVideoSlide.knownAspects[unavailableUrl] = 9 / 16;
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: [unavailableUrl]),
        width: 1200,
        viewportHeight: 700,
      ));
      await tester.pumpAndSettle();

      final stage = tester.getRect(find.byType(ClipRRect).first);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CommunityPostMediaCarousel)),
      )!;
      expect(find.text(l10n.communityMediaVideoPreviewUnavailable),
          findsOneWidget);
      expect(stage.height, lessThanOrEqualTo(_maximumStageHeight(700) + 0.6));
      expect(stage.height, lessThan(700));
      final play = tester.getRect(
        find.byTooltip(l10n.communityMediaVideoPlay),
      );
      expect(play.top, greaterThanOrEqualTo(stage.top));
      expect(play.bottom, lessThanOrEqualTo(stage.bottom));
    });

    testWidgets('mixed media keeps the stable 4:3 stage on every page',
        (tester) async {
      CommunityPostVideoSlide.knownAspects[url] = 32 / 9;
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(
          mediaUrls: [url, 'https://example.test/uploads/a.jpg'],
        ),
      ));
      await tester.pumpAndSettle();
      expect(_stageHeight(tester), closeTo(450, 0.6));
    });

    testWidgets('loaded metadata does not change stage height or anchor',
        (tester) async {
      final previous = VideoPlayerPlatform.instance;
      final platform = FakeVideoPlayerPlatform(size: const Size(3200, 900));
      VideoPlayerPlatform.instance = platform;
      CommunityVideoAutoplay.enabledOverride = true;
      addTearDown(() {
        VideoPlayerPlatform.instance = previous;
        CommunityVideoAutoplay.enabledOverride = null;
      });
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: [url]),
      ));
      await tester.pump();
      final initialHeight = _stageHeight(tester);
      final initialTop = tester.getTopLeft(find.byType(ClipRRect).first).dy;
      expect(initialHeight, closeTo(600 * 9 / 16, 0.6),
          reason: 'unknown shape uses the stable fallback stage');
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 4)),
        );
      }
      await tester.pumpAndSettle();
      expect(_stageHeight(tester), closeTo(initialHeight, 0.6));
      expect(tester.getTopLeft(find.byType(ClipRRect).first).dy,
          closeTo(initialTop, 0.6));
      expect(CommunityPostVideoSlide.knownAspects[url], closeTo(32 / 9, 0.01));
    });
  });
}
