// ignore_for_file: depend_on_referenced_packages

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/community/community_post_media_carousel.dart';
import 'package:art_kubus/widgets/community/community_post_video_slide.dart';
import 'package:art_kubus/widgets/community/community_video_autoplay.dart';
import 'package:art_kubus/community/community_post_media.dart';
import 'package:art_kubus/utils/media_url_resolver.dart';
import 'package:flutter/foundation.dart';
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

const _frameKey = ValueKey<String>('community-video-frame');

VideoPlayerPlatform? _previousPlatform;

FakeVideoPlayerPlatform _installFake(Size size) {
  final platform = FakeVideoPlayerPlatform(size: size);
  _previousPlatform = VideoPlayerPlatform.instance;
  VideoPlayerPlatform.instance = platform;
  CommunityVideoAutoplay.enabledOverride = true;
  return platform;
}

void _restore(FakeVideoPlayerPlatform _) {
  final previous = _previousPlatform;
  if (previous != null) VideoPlayerPlatform.instance = previous;
  CommunityVideoAutoplay.enabledOverride = null;
}

/// Lets the autoplaying fake player initialize and the stage finish easing.
Future<void> _settleVideo(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 4)),
    );
  }
  await tester.pumpAndSettle();
}

/// Puts a decoded picture of [width] x [height] into the image cache under the
/// display URL of [url], so the carousel's poster probe resolves it offline.
Future<void> _preloadImage(
  WidgetTester tester,
  String url,
  int width,
  int height,
) async {
  final resolved = MediaUrlResolver.resolveDisplayUrl(url)!;
  final image = await tester.runAsync(() {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint(),
    );
    return recorder.endRecording().toImage(width, height);
  });
  PaintingBinding.instance.imageCache.putIfAbsent(
    NetworkImage(resolved),
    () => OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: image!)),
    ),
  );
}

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

    testWidgets('a multi-video carousel keeps one 4:3 stage on every page',
        (tester) async {
      const landscapeUrl = 'https://example.test/uploads/landscape.mp4';
      CommunityPostVideoSlide.knownAspects[url] = 9 / 16;
      CommunityPostVideoSlide.knownAspects[landscapeUrl] = 16 / 9;
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(
          mediaUrls: [url, landscapeUrl],
        ),
      ));
      await tester.pumpAndSettle();
      final first = tester.getRect(find.byType(ClipRRect).first);
      expect(first.height, closeTo(600 / kCommunityMediaStageAspect, 0.6));
      final play = tester.getRect(find.byTooltip('Play video').first);
      expect(play.top, greaterThanOrEqualTo(first.top));
      expect(play.bottom, lessThanOrEqualTo(first.bottom));

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      final second = tester.getRect(find.byTooltip('Play video').first);
      final landscapeStage = tester.getRect(find.byType(ClipRRect).first);
      expect(landscapeStage, first, reason: 'swiping never moves the feed');
      expect(second.bottom, lessThanOrEqualTo(landscapeStage.bottom));
      expect(find.text('2 / 2'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(ClipRRect).first), first);
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('a mixed image and portrait video carousel keeps one stage',
        (tester) async {
      const imageUrl = 'https://example.test/uploads/still.jpg';
      CommunityPostVideoSlide.knownAspects[url] = 9 / 16;
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: [imageUrl, url]),
      ));
      await tester.pumpAndSettle();
      final first = tester.getRect(find.byType(ClipRRect).first);
      expect(first.height, closeTo(600 / kCommunityMediaStageAspect, 0.6));

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(ClipRRect).first), first,
          reason: 'a tall clip is contained in the stage, not the stage in it');
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets(
        'player metadata corrects an unknown clip once and keeps the anchor',
        (tester) async {
      final platform = _installFake(const Size(1080, 1920));
      addTearDown(() => _restore(platform));
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: [url]),
        width: 390,
      ));
      await tester.pump();
      final initialHeight = _stageHeight(tester);
      final initialTop = tester.getTopLeft(find.byType(ClipRRect).first).dy;
      expect(initialHeight, closeTo(390 * 9 / 16, 0.6),
          reason: 'unknown shape starts at the 16:9 fallback');
      await _settleVideo(tester);
      // A 9:16 clip now has its own tall stage (capped by the 900 px viewport),
      // anchored at the same top, and the visible frame uses the whole width.
      expect(_stageHeight(tester), closeTo(math.min(390 * 16 / 9, 900), 0.6));
      expect(tester.getTopLeft(find.byType(ClipRRect).first).dy,
          closeTo(initialTop, 0.6));
      final frame = tester.getSize(find.byKey(_frameKey));
      expect(frame.width, closeTo(390, 1));
      expect(frame.height, closeTo(390 * 16 / 9, 1));
      expect(CommunityPostVideoSlide.knownAspects[url], closeTo(9 / 16, 0.01));
      // A second report of the same shape never resizes again.
      final settled = tester.getRect(find.byType(ClipRRect).first);
      await _settleVideo(tester);
      expect(tester.getRect(find.byType(ClipRRect).first), settled);
    });

    testWidgets('an ultrawide player report compacts a fallback stage once',
        (tester) async {
      final platform = _installFake(const Size(3200, 900));
      addTearDown(() => _restore(platform));
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: [url]),
      ));
      await tester.pump();
      expect(_stageHeight(tester), closeTo(600 * 9 / 16, 0.6));
      final top = tester.getTopLeft(find.byType(ClipRRect).first).dy;
      await _settleVideo(tester);
      expect(_stageHeight(tester), closeTo(600 * 900 / 3200, 0.6));
      expect(tester.getTopLeft(find.byType(ClipRRect).first).dy,
          closeTo(top, 0.6));
      expect(CommunityPostVideoSlide.knownAspects[url], closeTo(32 / 9, 0.01));
    });

    testWidgets(
        'a recorded aspect is used at once; the player may correct it once',
        (tester) async {
      const hinted =
          'https://example.test/uploads/hinted.mp4#kubus-aspect=0.5625';
      // The recorded hint says 9:16 but the file is really square.
      final platform = _installFake(const Size(1000, 1000));
      addTearDown(() => _restore(platform));
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: [hinted]),
      ));
      await tester.pump();
      expect(_stageHeight(tester),
          closeTo(math.min(600 / 0.5625, 900 * 0.72), 0.6));
      await _settleVideo(tester);
      expect(_stageHeight(tester), closeTo(600, 0.6));
    });

    testWidgets('metadata within the tolerance never resizes the stage',
        (tester) async {
      const hinted =
          'https://example.test/uploads/close.mp4#kubus-aspect=1.7778';
      final platform = _installFake(const Size(1920, 1080));
      addTearDown(() => _restore(platform));
      await tester.pumpWidget(_harness(
        const CommunityPostMediaCarousel(mediaUrls: [hinted]),
      ));
      await tester.pump();
      final before = tester.getRect(find.byType(ClipRRect).first);
      await _settleVideo(tester);
      expect(tester.getRect(find.byType(ClipRRect).first), before);
    });

    testWidgets(
        'a portrait poster gives an unknown clip a portrait stage before '
        'the player ever loads', (tester) async {
      const posterUrl = 'https://example.test/uploads/poster-portrait.jpg';
      final reference = communityMediaReferenceForPost(
        'https://example.test/uploads/legacy.mp4',
        isVideo: true,
        posterUrl: posterUrl,
      );
      await _preloadImage(tester, posterUrl, 90, 160);
      await tester.pumpWidget(_harness(
        CommunityPostMediaCarousel(mediaUrls: [reference]),
        width: 390,
      ));
      await tester.pumpAndSettle();
      expect(_stageHeight(tester), closeTo(math.min(390 * 16 / 9, 900), 0.6));
    });

    testWidgets('a poster never overrides a recorded aspect', (tester) async {
      const posterUrl = 'https://example.test/uploads/poster-square.jpg';
      final base = communityMediaReferenceForPost(
        'https://example.test/uploads/known.mp4',
        isVideo: true,
        posterUrl: posterUrl,
      );
      final reference = '$base&kubus-aspect=1.777778';
      await _preloadImage(tester, posterUrl, 100, 100);
      await tester.pumpWidget(_harness(
        CommunityPostMediaCarousel(mediaUrls: [reference]),
      ));
      await tester.pumpAndSettle();
      expect(_stageHeight(tester), closeTo(600 * 9 / 16, 0.6));
    });
  });

  group('visible video frame on phones and desktops', () {
    // The stage is only a container; what the viewer sees is the frame. For each
    // width and clip shape the frame must use at least 90% of the width the
    // viewport cap allows (the cap is the usable height on phones and 72% of it
    // on wide screens), with no overflow.
    const url = 'https://example.test/uploads/legacy-clip.mp4';
    for (final width in <double>[320, 390, 430, 768, 1440]) {
      for (final shape in <(String, Size)>[
        ('9:16', const Size(1080, 1920)),
        ('4:5', const Size(1080, 1350)),
        ('1:1', const Size(1000, 1000)),
        ('16:9', const Size(1920, 1080)),
        ('21:9', const Size(2100, 900)),
      ]) {
        testWidgets(
            'legacy ${shape.$1} clip at $width px fills its feasible width',
            (tester) async {
          final platform = _installFake(shape.$2);
          addTearDown(() => _restore(platform));
          const viewportHeight = 800.0;
          tester.view.physicalSize = Size(width, viewportHeight);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(_harness(
            const CommunityPostMediaCarousel(mediaUrls: [url]),
            width: width,
            viewportHeight: viewportHeight,
          ));
          await tester.pump();
          await _settleVideo(tester);
          final aspect = shape.$2.width / shape.$2.height;
          final cap = viewportHeight * (width < 600 ? 1 : 0.72);
          final feasibleWidth = math.min(width, cap * aspect);
          final frame = tester.getSize(find.byKey(_frameKey));
          expect(frame.width / feasibleWidth, greaterThanOrEqualTo(0.9),
              reason: '${shape.$1} at $width: frame ${frame.width}x'
                  '${frame.height}, feasible $feasibleWidth');
          expect(frame.width, lessThanOrEqualTo(width + 0.5));
          expect(tester.takeException(), isNull);
        });
      }
    }
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
