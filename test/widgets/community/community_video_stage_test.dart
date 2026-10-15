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
        expect(_stageHeight(tester),
            closeTo(math.min(600 / c.$2, 900 * 0.72), 0.6));
      });
    }

    testWidgets('an ultrawide clip stays inside the same stable stage',
        (tester) async {
      CommunityPostVideoSlide.knownAspects[url] = 32 / 9;
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: [url]),
      ));
      await tester.pumpAndSettle();
      expect(_stageHeight(tester), closeTo(600 * 9 / 32, 0.6));
    });

    testWidgets('a narrow mobile stage uses available height, not a minimum',
        (tester) async {
      CommunityPostVideoSlide.knownAspects[url] = 32 / 9;
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: [url]),
        width: 160,
      ));
      await tester.pumpAndSettle();
      expect(_stageHeight(tester), closeTo(kCommunityVideoStageMinHeight, 0.6));
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

  group('usable mobile viewport in feed and detail', () {
    const url = 'https://example.test/uploads/portrait.mp4';
    for (final viewport in <Size>[
      const Size(360, 780),
      const Size(390, 844),
      const Size(430, 932),
      const Size(844, 390),
    ]) {
      for (final detail in <bool>[false, true]) {
        for (final aspect in <double?>[9 / 16, 16 / 9, 1, 21 / 9, null]) {
          testWidgets('$viewport detail=$detail aspect=$aspect stays stable',
              (tester) async {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            if (aspect != null) {
              CommunityPostVideoSlide.knownAspects[url] = aspect;
            }
            const topInset = 24.0;
            const bottomInset = 20.0;
            const chromeHeight = 64.0;
            await tester.pumpWidget(MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: MediaQueryData(
                  size: viewport,
                  padding:
                      const EdgeInsets.only(top: topInset, bottom: bottomInset),
                ),
                child: Scaffold(
                  appBar: detail ? AppBar() : null,
                  bottomNavigationBar:
                      const SizedBox(height: chromeHeight + bottomInset),
                  body: SafeArea(
                    bottom: false,
                    child: CommunityMediaViewport(
                      child: SingleChildScrollView(
                        child:
                            const CommunityPostMediaCarousel(mediaUrls: [url]),
                      ),
                    ),
                  ),
                ),
              ),
            ));
            await tester.pumpAndSettle();
            final usable = viewport.height -
                topInset -
                chromeHeight -
                bottomInset -
                (detail ? kToolbarHeight : 0);
            final expected =
                math.min(viewport.width / (aspect ?? 16 / 9), usable);
            final before = tester.getRect(find.byType(ClipRRect).first);
            expect(before.height, closeTo(expected, 0.6));
            expect(
                before.bottom,
                lessThanOrEqualTo(
                    viewport.height - chromeHeight - bottomInset));
            // Rebuild after a metadata cache update: no height/anchor change.
            CommunityPostVideoSlide.knownAspects[url] = 9 / 16;
            tester
                .element(find.byType(CommunityPostMediaCarousel))
                .markNeedsBuild();
            await tester.pump();
            expect(tester.getRect(find.byType(ClipRRect).first), before);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
