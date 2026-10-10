import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/media_url_resolver.dart';
import 'package:art_kubus/widgets/community/community_post_media_carousel.dart';
import 'package:art_kubus/widgets/community/community_post_video_slide.dart';
import 'package:art_kubus/widgets/community/community_video_autoplay.dart';
import 'package:art_kubus/widgets/community/community_video_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/fake_video_player_platform.dart';

// ignore_for_file: depend_on_referenced_packages

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));
const String _clip = 'https://example.test/uploads/clip.mp4';
const String _otherClip = 'https://example.test/uploads/other.mp4';
const String _poster = 'https://example.test/uploads/clip-still.jpg';
const ValueKey<String> _frameKey = ValueKey<String>('community-video-frame');

/// The hinted form a video takes when it carries [poster].
String _hinted(String video, String poster) =>
    '$video#kubus-media=video&kubus-poster=${Uri.encodeComponent(poster)}';

/// The stage height of a carousel that is 540 wide (4:3).
const double _stageHeight = 405;

/// Viewport height of the test surface.
const double _viewHeight = 600;

/// Top offset that leaves [fraction] of a [height]-tall stage on screen, from
/// the bottom edge of the 600 px test view.
double _offsetFor(double fraction, {double height = _stageHeight}) =>
    _viewHeight - height * fraction;

Widget _app(Widget child, {bool reducedMotion = false}) {
  return MaterialApp(
    builder: (context, page) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
      child: page!,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: ThemeData(brightness: Brightness.light),
    home: Scaffold(body: child),
  );
}

/// A stage moved vertically so that a chosen share of it is on screen.
class _Shift extends StatelessWidget {
  const _Shift({required this.top, required this.child});

  final ValueNotifier<double> top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: top,
      builder: (context, dy, _) => Transform.translate(
        offset: Offset(0, dy),
        child: child,
      ),
    );
  }
}

Widget _carouselAt(
  ValueNotifier<double> top,
  List<String> mediaUrls, {
  double width = 540,
  bool compact = false,
}) {
  return _Shift(
    top: top,
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        child: CommunityPostMediaCarousel(
          mediaUrls: mediaUrls,
          compact: compact,
        ),
      ),
    ),
  );
}

/// Pumps frames and real event-loop turns, so the clip's async start (which
/// resolves outside the fake clock) can finish alongside the autoplay timer.
Future<void> _advance(WidgetTester tester, int milliseconds) async {
  final steps = (milliseconds / 50).ceil();
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 4)),
    );
  }
}

/// Tears the tree down so the scheduler's timer and every player are released
/// before the test framework checks for pending timers.
Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await _advance(tester, 50);
}

@isTest
void testAutoplay(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await _dispose(tester);
    expect(CommunityVideoAutoplay.candidateCount, 0);
    expect(CommunityVideoAutoplay.timerRunning, isFalse);
  });
}

void main() {
  late FakeVideoPlayerPlatform platform;
  late VideoPlayerPlatform previous;

  setUp(() {
    CommunityVideoAudio.resetSession();
    CommunityPostVideoSlide.clearStickyPauses();
    CommunityPostVideoSlide.guardInterval = const Duration(milliseconds: 20);
    CommunityVideoAutoplay.enabledOverride = true;
    previous = VideoPlayerPlatform.instance;
    platform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(() {
    CommunityVideoAudio.resetSession();
    CommunityPostVideoSlide.clearStickyPauses();
    CommunityPostVideoSlide.guardInterval = const Duration(milliseconds: 400);
    CommunityVideoAutoplay.enabledOverride = null;
    VideoPlayerPlatform.instance = previous;
  });

  group('muted autoplay', () {
    testAutoplay('a clip clearly on screen starts muted, without a tap',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(_app(_carouselAt(top, [_clip])));
      await _advance(tester, 900);

      expect(platform.playingNow.length, 1);
      final player = platform.playingNow.single;
      expect(player.volume, 0, reason: 'the element is muted');
      expect(player.playing, isTrue);
      expect(find.byTooltip(_l10n.communityMediaVideoPlay), findsNothing);
    });

    testAutoplay('the viewer sound choice is neither read nor written',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(_app(_carouselAt(top, [_clip])));
      await _advance(tester, 900);

      expect(platform.playingNow.length, 1);
      final session = CommunityVideoAudio();
      expect(session.muted, isFalse);
      expect(session.volume, 1);
    });

    testAutoplay('a clip must dwell on screen before it starts',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(_app(_carouselAt(top, [_clip])));
      await _advance(tester, 200);
      expect(platform.live, isEmpty, reason: 'no tick has passed the dwell');

      await _advance(tester, 800);
      expect(platform.playingNow.length, 1);
    });

    testAutoplay('reduced motion turns autoplay off; the poster and Play stay',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(
        _app(_carouselAt(top, [_clip]), reducedMotion: true),
      );
      await _advance(tester, 1500);

      expect(platform.live, isEmpty);
      expect(find.byTooltip(_l10n.communityMediaVideoPlay), findsOneWidget);
    });

    testAutoplay(
        'a compact quoted preview shows its poster but never autoplays',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(
        _app(_carouselAt(top, [_clip], compact: true, width: 320)),
      );
      await _advance(tester, 1500);

      expect(platform.live, isEmpty);
    });

    testAutoplay('the feature switch off means no autoplay at all',
        (tester) async {
      CommunityVideoAutoplay.enabledOverride = false;
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(_app(_carouselAt(top, [_clip])));
      await _advance(tester, 1500);

      expect(platform.live, isEmpty);
    });

    testAutoplay(
        'a clip that fails to load stays silent, with its Play control',
        (tester) async {
      platform.failInitialize = true;
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(_app(_carouselAt(top, [_clip])));
      await _advance(tester, 1500);

      expect(find.byTooltip(_l10n.communityMediaVideoPlay), findsOneWidget);
      expect(find.text(_l10n.communityMediaVideoRetry), findsNothing);
    });

    testAutoplay('a play refused during autoplay is silent and never retried',
        (tester) async {
      platform.rejectAllPlay = true;
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(_app(_carouselAt(top, [_clip])));
      await _advance(tester, 4000);

      final attempts = platform.playCalls.values.fold<int>(0, (a, b) => a + b);
      expect(attempts, 1, reason: 'one attempt per visit, no retry loop');
      expect(find.text(_l10n.communityMediaVideoRetry), findsNothing);
      expect(find.byTooltip(_l10n.communityMediaVideoPlay), findsOneWidget);
    });

    testAutoplay('leaving the screen pauses and releases the clip',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(_app(_carouselAt(top, [_clip])));
      await _advance(tester, 900);
      expect(platform.playingNow.length, 1);

      top.value = _offsetFor(0);
      await _advance(tester, 600);
      expect(platform.playingNow, isEmpty);
      expect(platform.live, isEmpty, reason: 'the player is released');
    });

    testAutoplay('boundary scrolling between 0.4 and 0.6 does not flap',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(_app(_carouselAt(top, [_clip])));
      await _advance(tester, 900);
      expect(platform.playCalls.values.fold<int>(0, (a, b) => a + b), 1);

      for (var i = 0; i < 40; i++) {
        top.value = _offsetFor(i.isEven ? 0.55 : 0.45);
        await _advance(tester, 250);
        expect(platform.playingNow.length, 1, reason: 'step $i keeps playing');
      }
      expect(platform.playCalls.values.fold<int>(0, (a, b) => a + b), 1,
          reason: 'no restart while oscillating inside the band');
    });

    testAutoplay('only one of two visible clips plays at a time',
        (tester) async {
      final topA = ValueNotifier<double>(0);
      final topB = ValueNotifier<double>(0);
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              _carouselAt(topA, [_clip], width: 300),
              _carouselAt(topB, [_otherClip], width: 300),
            ],
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await _advance(tester, 250);
        expect(platform.playingNow.length, lessThanOrEqualTo(1));
      }
      await _advance(tester, 500);
      expect(platform.playingNow.length, 1);
    });

    testAutoplay('a slide change pauses the previous clip and starts the next',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(_app(_carouselAt(top, [_clip, _otherClip])));
      await _advance(tester, 900);
      expect(platform.playingNow.single.uri, contains('clip.mp4'));

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await _advance(tester, 1200);

      expect(platform.playingNow.length, 1);
      expect(platform.playingNow.single.uri, contains('other.mp4'));
    });

    testAutoplay(
        'a tap on an autoplaying clip brings its sound on the same player',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(_app(_carouselAt(top, [_clip])));
      await _advance(tester, 900);
      final before = platform.players.keys.toList();

      await tester.tap(find.byKey(_frameKey));
      await _advance(tester, 300);

      expect(platform.players.keys.toList(), before,
          reason: 'no second player is created');
      expect(platform.playingNow.single.volume, 1);
      expect(CommunityVideoAudio().muted, isFalse,
          reason: 'the session choice is the viewer’s, not autoplay’s');
    });

    testAutoplay(
        'a paused clip stays paused while visible, and after returning',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(_app(_carouselAt(top, [_clip])));
      await _advance(tester, 900);
      await tester.tap(find.byKey(_frameKey)); // sound on
      await _advance(tester, 300);
      await tester.tap(find.byKey(_frameKey)); // pause by hand
      await _advance(tester, 300);
      expect(platform.playingNow, isEmpty);
      expect(
        CommunityPostVideoSlide.stickyPausedReferences,
        contains(_clip),
      );

      await _advance(tester, 2000);
      expect(platform.playingNow, isEmpty, reason: 'it stays paused');

      top.value = _offsetFor(0);
      await _advance(tester, 600);
      top.value = _offsetFor(1);
      await _advance(tester, 2000);
      expect(platform.playingNow, isEmpty,
          reason: 'a manual pause survives scrolling away and back');
    });

    testAutoplay('playing again clears the manual pause', (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(_app(_carouselAt(top, [_clip])));
      await _advance(tester, 900);
      await tester.tap(find.byKey(_frameKey));
      await _advance(tester, 300);
      await tester.tap(find.byKey(_frameKey));
      await _advance(tester, 300);
      expect(CommunityPostVideoSlide.stickyPausedReferences, contains(_clip));

      await tester.tap(find.byKey(_frameKey));
      await _advance(tester, 300);
      expect(platform.playingNow.length, 1);
      expect(CommunityPostVideoSlide.stickyPausedReferences, isEmpty);
    });

    testAutoplay('backgrounding the app pauses and releases an autoplay',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(_app(_carouselAt(top, [_clip])));
      await _advance(tester, 900);
      expect(platform.playingNow.length, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await _advance(tester, 600);
      expect(platform.playingNow, isEmpty);
      expect(platform.live, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testAutoplay('a clip the viewer started with sound is never interrupted',
        (tester) async {
      final topA = ValueNotifier<double>(0);
      final topB = ValueNotifier<double>(0);
      Widget page({required bool reduced}) => _app(
            Column(
              children: [
                _carouselAt(topA, [_clip], width: 300),
                _carouselAt(topB, [_otherClip], width: 300),
              ],
            ),
            reducedMotion: reduced,
          );

      await tester.pumpWidget(page(reduced: true));
      await _advance(tester, 900);
      expect(platform.live, isEmpty);

      await tester.tap(find.byTooltip(_l10n.communityMediaVideoPlay).first);
      await _advance(tester, 300);
      expect(platform.playingNow.single.uri, contains('clip.mp4'));

      await tester.pumpWidget(page(reduced: false));
      await _advance(tester, 2000);
      expect(platform.playingNow.length, 1);
      expect(platform.playingNow.single.uri, contains('clip.mp4'));
      expect(platform.playingNow.single.volume, greaterThan(0),
          reason: 'the viewer’s own playback keeps its sound');
    });

    testAutoplay('dispose releases every player and the scheduler',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(_app(_carouselAt(top, [_clip])));
      await _advance(tester, 900);
      expect(platform.live, isNotEmpty);

      await tester.pumpWidget(const SizedBox());
      await _advance(tester, 100);
      expect(platform.live, isEmpty);
      expect(CommunityVideoAutoplay.candidateCount, 0);
      expect(CommunityVideoAutoplay.timerRunning, isFalse);
    });
  });

  group('poster and preview', () {
    testAutoplay('a post poster is the still before playback', (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(
        _app(
          _carouselAt(top, [_hinted(_clip, _poster)]),
          reducedMotion: true,
        ),
      );
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<NetworkImage>());
      expect(
        (image.image as NetworkImage).url,
        MediaUrlResolver.resolveDisplayUrl(_poster),
        reason: 'the still is the resolved poster reference',
      );
      expect(platform.live, isEmpty, reason: 'the still shows before a player');
    });

    testAutoplay('a video without a poster shows the unavailable preview label',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester.pumpWidget(
        _app(_carouselAt(top, [_clip]), reducedMotion: true),
      );
      await tester.pump();

      expect(find.text(_l10n.communityMediaVideoPreviewUnavailable),
          findsOneWidget);
    });

    testAutoplay('an unresolvable poster falls back to the unavailable label',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      // An unsafe poster is refused at parse time, so the reference carries none.
      final unsafe = _hinted(_clip, 'https://localhost/clip-still.jpg');
      await tester.pumpWidget(
        _app(_carouselAt(top, [unsafe]), reducedMotion: true),
      );
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(find.text(_l10n.communityMediaVideoPreviewUnavailable),
          findsOneWidget);
    });

    testAutoplay('a poster that fails to load does not stop the clip playing',
        (tester) async {
      final top = ValueNotifier<double>(_offsetFor(1));
      await tester
          .pumpWidget(_app(_carouselAt(top, [_hinted(_clip, _poster)])));
      // Test images fail to load with a 400, which takes the error path.
      await _advance(tester, 1500);

      expect(
          find.text(_l10n.communityMediaVideoPreviewUnavailable), findsNothing,
          reason: 'the clip is playing over the poster area');
      expect(platform.playingNow.length, 1);
    });
  });
}
