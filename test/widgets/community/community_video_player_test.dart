import 'dart:ui' show PointerDeviceKind;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/community/community_post_media_carousel.dart';
import 'package:art_kubus/widgets/community/community_post_video_slide.dart';
import 'package:art_kubus/widgets/community/community_video_controls.dart';
import 'package:art_kubus/widgets/community/community_video_fullscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/fake_video_player_platform.dart';

// ignore_for_file: depend_on_referenced_packages

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));
const String _clip = 'https://example.test/uploads/clip.mp4';
const String _otherClip = 'https://example.test/uploads/other.mp4';

Widget _app(
  Widget child, {
  ThemeMode mode = ThemeMode.light,
  double textScale = 1,
}) {
  return MaterialApp(
    builder: (context, page) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: page!,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    themeMode: mode,
    theme: ThemeData(brightness: Brightness.light),
    darkTheme: ThemeData(brightness: Brightness.dark),
    home: Scaffold(body: child),
  );
}

Widget _stage(Widget child, {double width = 540}) => Center(
      child: SizedBox(
        width: width,
        child: AspectRatio(aspectRatio: 4 / 3, child: child),
      ),
    );

/// Lets frames, timers and the controller's async work (which resolves on the
/// real event loop, outside the fake clock) all run.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 12)),
    );
  }
}

/// Runs the guard timer: fake time for the timer itself, real turns so the
/// controller's async work in between can finish.
Future<void> _realWait(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
}

/// A widget test that always tears the player down before it ends, so the
/// controller's position timer is cancelled before the framework checks.
@isTest
void testPlayer(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await _settle(tester);
  });
}

/// Moves a mouse over [finder] so the control strip is shown.
Future<TestGesture> _hover(WidgetTester tester, Finder finder) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pump();
  return gesture;
}

void main() {
  late FakeVideoPlayerPlatform platform;
  late VideoPlayerPlatform previous;

  setUp(() {
    CommunityPostVideoSlide.guardInterval = const Duration(milliseconds: 20);
    previous = VideoPlayerPlatform.instance;
    platform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(() {
    CommunityPostVideoSlide.guardInterval = const Duration(milliseconds: 400);
    VideoPlayerPlatform.instance = previous;
  });

  Future<void> startPlayback(WidgetTester tester) async {
    await tester.tap(find.byTooltip(_l10n.communityMediaVideoPlay));
    await _settle(tester);
  }

  group('formatCommunityVideoTime', () {
    test('formats minutes, hours and negative values consistently', () {
      expect(formatCommunityVideoTime(Duration.zero), '0:00');
      expect(formatCommunityVideoTime(const Duration(seconds: 12)), '0:12');
      expect(formatCommunityVideoTime(const Duration(seconds: 34)), '0:34');
      expect(formatCommunityVideoTime(const Duration(minutes: 9, seconds: 5)),
          '9:05');
      expect(
        formatCommunityVideoTime(
            const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
      expect(formatCommunityVideoTime(const Duration(seconds: -5)), '0:00');
    });
  });

  group('lifecycle', () {
    testPlayer('creates no player until the user asks to play', (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clip, isActive: true),
      )));
      await _settle(tester);

      expect(platform.players, isEmpty);
      expect(find.byTooltip(_l10n.communityMediaVideoPlay), findsOneWidget);
      expect(find.byType(CommunityVideoTimeline), findsNothing);
    });

    testPlayer('starts muted, without looping, on the first play',
        (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clip, isActive: true),
      )));
      await startPlayback(tester);

      final player = platform.players.values.single;
      expect(player.uri, endsWith('/uploads/clip.mp4'));
      expect(player.playing, isTrue);
      expect(player.volume, 0);
      expect(player.looping, isFalse);
    });

    testPlayer('releases the player when its slide stops being active',
        (tester) async {
      Widget build(bool active) => _app(_stage(
            CommunityPostVideoSlide(url: _clip, isActive: active),
          ));
      await tester.pumpWidget(build(true));
      await startPlayback(tester);
      expect(platform.live, hasLength(1));

      await tester.pumpWidget(build(false));
      await _settle(tester);

      expect(platform.live, isEmpty);
      // Returning to the slide does not start playback on its own.
      await tester.pumpWidget(build(true));
      await _settle(tester);
      expect(platform.live, isEmpty);
      expect(find.byTooltip(_l10n.communityMediaVideoPlay), findsOneWidget);
    });

    testPlayer('disposes the player with its widget', (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clip, isActive: true),
      )));
      await startPlayback(tester);
      expect(platform.live, hasLength(1));

      await tester.pumpWidget(_app(const SizedBox()));
      await _settle(tester);

      expect(platform.live, isEmpty);
    });

    testPlayer('only one video plays at a time', (tester) async {
      await tester.pumpWidget(_app(Column(children: [
        Expanded(
          child: _stage(
            const CommunityPostVideoSlide(url: _clip, isActive: true),
            width: 300,
          ),
        ),
        Expanded(
          child: _stage(
            const CommunityPostVideoSlide(url: _otherClip, isActive: true),
            width: 300,
          ),
        ),
      ])));
      final plays = find.byTooltip(_l10n.communityMediaVideoPlay);
      await tester.tap(plays.first);
      await _settle(tester);
      await tester.tap(plays.last);
      await _settle(tester);

      expect(platform.live, hasLength(2));
      expect(platform.playingNow.single.uri, endsWith('/uploads/other.mp4'));
    });

    testPlayer('a theme change keeps the same controller', (tester) async {
      const slide = CommunityPostVideoSlide(url: _clip, isActive: true);
      await tester.pumpWidget(_app(_stage(slide)));
      await startPlayback(tester);
      final id = platform.players.values.single.id;

      await tester.pumpWidget(_app(_stage(slide), mode: ThemeMode.dark));
      await _settle(tester);

      expect(platform.players.keys, <int>[id]);
      expect(platform.live, hasLength(1));
      expect(platform.players[id]!.playing, isTrue);
    });
  });

  group('pausing by itself', () {
    testPlayer('pauses when the post scrolls out of view', (tester) async {
      await tester.pumpWidget(_app(
        ListView(children: [
          SizedBox(
            height: 300,
            child: _stage(
              const CommunityPostVideoSlide(url: _clip, isActive: true),
              width: 300,
            ),
          ),
          const SizedBox(height: 2400),
        ]),
      ));
      await startPlayback(tester);
      expect(platform.playingNow, hasLength(1));

      await tester.drag(find.byType(ListView), const Offset(0, -240));
      await tester.pump();
      await _realWait(tester);

      expect(platform.playingNow, isEmpty);
    });

    testPlayer('pauses when another route covers it', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: _stage(
            const CommunityPostVideoSlide(url: _clip, isActive: true),
          ),
        ),
      ));
      await startPlayback(tester);
      expect(platform.playingNow, hasLength(1));

      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _realWait(tester);

      expect(platform.playingNow, isEmpty);
    });

    testPlayer('pauses when the app is backgrounded', (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clip, isActive: true),
      )));
      await startPlayback(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(platform.playingNow, isEmpty);

      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testPlayer('pauses when its tab stops ticking', (tester) async {
      Widget build(bool enabled) => _app(TickerMode(
            enabled: enabled,
            child: _stage(
              const CommunityPostVideoSlide(url: _clip, isActive: true),
            ),
          ));
      await tester.pumpWidget(build(true));
      await startPlayback(tester);

      await tester.pumpWidget(build(false));
      await tester.pump();

      expect(platform.playingNow, isEmpty);
    });
  });

  group('controls', () {
    Future<Finder> playing(WidgetTester tester, {double width = 540}) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clip, isActive: true),
        width: width,
      )));
      await startPlayback(tester);
      final surface = find.byType(CommunityVideoPlayerSurface);
      await _hover(tester, surface);
      return surface;
    }

    testPlayer('shows elapsed time and total duration', (tester) async {
      await playing(tester);

      expect(find.text('0:00 / 0:34'), findsOneWidget);

      platform.players.values.single.position = const Duration(seconds: 12);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(find.text('0:12 / 0:34'), findsOneWidget);
    });

    testPlayer('pause and play buttons drive the controller', (tester) async {
      await playing(tester);
      final player = platform.players.values.single;

      await tester.tap(find.byTooltip(_l10n.communityMediaVideoPause));
      await _settle(tester);
      expect(player.playing, isFalse);
      // A paused clip shows the large play control as well as the strip one.
      expect(find.byTooltip(_l10n.communityMediaVideoPlay), findsNWidgets(2));

      await tester.tap(find.byTooltip(_l10n.communityMediaVideoPlay).last);
      await _settle(tester);
      expect(player.playing, isTrue);
    });

    testPlayer('tapping the timeline seeks the real controller',
        (tester) async {
      await playing(tester);
      final player = platform.players.values.single;
      final rect = tester.getRect(find.byType(CommunityVideoTimeline));

      await tester.tapAt(Offset(rect.left + rect.width / 2, rect.center.dy));
      await _settle(tester);

      expect(player.seeks, isNotEmpty);
      final target = player.seeks.last.inMilliseconds;
      expect(target, closeTo(17000, 1500));
    });

    testPlayer('dragging pauses, previews the time, then resumes at the end',
        (tester) async {
      await playing(tester);
      final player = platform.players.values.single;
      final rect = tester.getRect(find.byType(CommunityVideoTimeline));

      final gesture = await tester.startGesture(
        Offset(rect.left + 6, rect.center.dy),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture
          .moveTo(Offset(rect.left + rect.width * 0.75, rect.center.dy));
      await tester.pump();

      expect(player.playing, isFalse, reason: 'scrubbing pauses playback');
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text && (w.data == '0:25 / 0:34' || w.data == '0:26 / 0:34'),
        ),
        findsOneWidget,
        reason: 'the label follows the handle while scrubbing',
      );

      await gesture.up();
      await _settle(tester);

      expect(player.playing, isTrue, reason: 'it resumes after the drag');
      expect(player.seeks.last.inSeconds, inInclusiveRange(24, 26));
    });

    testPlayer('arrow keys step the timeline by five seconds', (tester) async {
      await playing(tester);
      final player = platform.players.values.single;

      // Focus the timeline with a click, then park the clip at 10 s.
      await tester.tap(find.byType(CommunityVideoTimeline));
      await _settle(tester);
      player.position = const Duration(seconds: 10);
      await tester.pump(const Duration(milliseconds: 300));
      player.seeks.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);

      expect(player.seeks.last, const Duration(seconds: 15));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await _settle(tester);
      expect(player.seeks.last, const Duration(seconds: 10));
    });

    testPlayer('exposes the position as an accessible slider', (tester) async {
      final semantics = tester.ensureSemantics();
      await playing(tester);
      platform.players.values.single.position = const Duration(seconds: 12);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      final node = tester.getSemantics(find.byType(CommunityMediaSlider).first);
      expect(node.label, _l10n.communityMediaVideoSeek);
      expect(node.value, _l10n.communityMediaVideoTime('0:12', '0:34'));
      expect(node.flagsCollection.isSlider, isTrue);
      semantics.dispose();
    });

    testPlayer('mute and unmute change the player volume', (tester) async {
      await playing(tester);
      final player = platform.players.values.single;
      expect(player.volume, 0);

      await tester.tap(find.byTooltip(_l10n.communityMediaVideoUnmute));
      await _settle(tester);
      expect(player.volume, 1);

      await tester.tap(find.byTooltip(_l10n.communityMediaVideoMute));
      await _settle(tester);
      expect(player.volume, 0);
    });

    testPlayer('a mouse gets a volume track that keeps its level',
        (tester) async {
      await playing(tester);
      final player = platform.players.values.single;
      final volume = find.byWidgetPredicate(
        (w) =>
            w is CommunityMediaSlider &&
            w.semanticLabel == _l10n.communityMediaVideoVolume,
      );
      expect(volume, findsOneWidget);

      final rect = tester.getRect(volume);
      await tester.tapAt(Offset(rect.left + rect.width * 0.5, rect.center.dy));
      await _settle(tester);
      expect(player.volume, closeTo(0.5, 0.15));

      // Mute and unmute return to the chosen level, not full volume.
      final level = player.volume;
      await tester.tap(find.byTooltip(_l10n.communityMediaVideoMute));
      await _settle(tester);
      expect(player.volume, 0);
      await tester.tap(find.byTooltip(_l10n.communityMediaVideoUnmute));
      await _settle(tester);
      expect(player.volume, closeTo(level, 0.001));
    });

    testPlayer('there is no volume track without a mouse', (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clip, isActive: true),
        width: 320,
      )));
      await startPlayback(tester);
      await tester.pump(const Duration(seconds: 4));

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CommunityMediaSlider &&
              w.semanticLabel == _l10n.communityMediaVideoVolume,
        ),
        findsNothing,
      );
      expect(find.byTooltip(_l10n.communityMediaVideoUnmute), findsOneWidget);
    });

    testPlayer('space on the player toggles playback', (tester) async {
      await playing(tester);
      final player = platform.players.values.single;
      // Click the surface (a mouse tap pauses) to focus it, then use the key.
      await tester.tapAt(
          tester.getTopLeft(find.byType(CommunityVideoPlayerSurface)) +
              const Offset(20, 20));
      await _settle(tester);
      expect(player.playing, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _settle(tester);
      expect(player.playing, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _settle(tester);
      expect(player.playing, isFalse);
    });

    testPlayer('a finished clip stops and offers a replay', (tester) async {
      await playing(tester);
      final player = platform.players.values.single;
      expect(player.looping, isFalse);

      player.position = const Duration(seconds: 34);
      player.playing = false;
      player.events.add(VideoEvent(eventType: VideoEventType.completed));
      await _settle(tester);

      final replay = find.byTooltip(_l10n.communityMediaVideoReplay);
      expect(replay, findsOneWidget);

      await tester.tap(replay);
      await _settle(tester);
      expect(player.seeks.last, Duration.zero);
      expect(player.playing, isTrue);
    });

    testPlayer('shows buffering while a playing clip stalls', (tester) async {
      final semantics = tester.ensureSemantics();
      await playing(tester);
      final player = platform.players.values.single;

      player.events.add(VideoEvent(eventType: VideoEventType.bufferingStart));
      await _settle(tester);

      expect(find.bySemanticsLabel(_l10n.communityMediaVideoBuffering),
          findsOneWidget);

      player.events.add(VideoEvent(eventType: VideoEventType.bufferingEnd));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel(_l10n.communityMediaVideoBuffering),
          findsNothing);
      semantics.dispose();
    });

    testPlayer('paints the buffered range from the controller', (tester) async {
      await playing(tester);
      final player = platform.players.values.single;
      player.events.add(VideoEvent(
        eventType: VideoEventType.bufferingUpdate,
        buffered: <DurationRange>[
          DurationRange(Duration.zero, const Duration(seconds: 17)),
        ],
      ));
      await tester.pump(const Duration(milliseconds: 100));

      final slider = tester.widget<CommunityMediaSlider>(
        find.byType(CommunityMediaSlider).first,
      );
      expect(slider.buffered, closeTo(0.5, 0.01));
    });

    testPlayer('unknown duration disables the timeline', (tester) async {
      platform.duration = Duration.zero;
      await playing(tester);

      expect(find.text('0:00 / --:--'), findsOneWidget);
      final slider = tester.widget<CommunityMediaSlider>(
        find.byType(CommunityMediaSlider).first,
      );
      expect(slider.enabled, isFalse);
    });
  });

  group('control visibility', () {
    double stripOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(find.ancestor(
          of: find.byTooltip(_l10n.communityMediaVideoFullscreen),
          matching: find.byType(AnimatedOpacity),
        ))
        .opacity;

    testPlayer('controls show briefly after starting, then fade while playing',
        (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clip, isActive: true),
      )));
      await startPlayback(tester);
      expect(stripOpacity(tester), 1);

      await tester.pump(const Duration(seconds: 4));
      expect(stripOpacity(tester), 0);
    });

    testPlayer('the first touch on a playing clip only reveals the controls',
        (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clip, isActive: true),
      )));
      await startPlayback(tester);
      await tester.pump(const Duration(seconds: 4));
      expect(stripOpacity(tester), 0);

      final corner =
          tester.getTopLeft(find.byType(CommunityVideoPlayerSurface)) +
              const Offset(20, 20);
      await tester.tapAt(corner);
      await _settle(tester);
      expect(platform.playingNow, hasLength(1), reason: 'still playing');
      expect(stripOpacity(tester), 1);

      await tester.tapAt(corner);
      await _settle(tester);
      expect(platform.playingNow, isEmpty, reason: 'the second touch pauses');
    });

    testPlayer('a paused clip keeps its controls', (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clip, isActive: true),
      )));
      await startPlayback(tester);
      await tester.pump(const Duration(seconds: 4));
      expect(stripOpacity(tester), 0);

      // A mouse tap on the surface pauses it; the strip must come back and stay.
      await tester.tapAt(
        tester.getTopLeft(find.byType(CommunityVideoPlayerSurface)) +
            const Offset(20, 20),
        kind: PointerDeviceKind.mouse,
      );
      await _settle(tester);
      await tester.pump(const Duration(seconds: 4));
      expect(platform.playingNow, isEmpty);
      expect(stripOpacity(tester), 1);
    });
  });

  group('failure', () {
    testPlayer('an unplayable clip shows the error and can retry',
        (tester) async {
      platform.failInitialize = true;
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clip, isActive: true),
      )));
      await startPlayback(tester);

      expect(find.text(_l10n.communityMediaVideoUnavailable), findsOneWidget);
      expect(platform.live, isEmpty, reason: 'a failed controller is disposed');

      platform.failInitialize = false;
      await tester.tap(find.text(_l10n.communityMediaVideoRetry));
      await _settle(tester);

      expect(find.text(_l10n.communityMediaVideoUnavailable), findsNothing);
      expect(platform.playingNow, hasLength(1));
    });

    testPlayer('a playback error mid-clip offers a retry', (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clip, isActive: true),
      )));
      await startPlayback(tester);
      final first = platform.players.values.single;

      first.events.addError(PlatformException(code: 'x', message: 'decode'));
      await _settle(tester);
      expect(find.text(_l10n.communityMediaVideoUnavailable), findsOneWidget);

      await tester.tap(find.text(_l10n.communityMediaVideoRetry));
      await _settle(tester);

      expect(first.disposed, isTrue);
      expect(platform.playingNow, hasLength(1));
      expect(platform.live.single.id, isNot(first.id));
    });
  });

  group('fullscreen', () {
    testPlayer('expands the same player, keeps playing, and returns',
        (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clip, isActive: true),
      )));
      await startPlayback(tester);
      final player = platform.players.values.single;
      player.position = const Duration(seconds: 8);
      await _hover(tester, find.byType(CommunityVideoPlayerSurface));

      await tester.tap(find.byTooltip(_l10n.communityMediaVideoFullscreen));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CommunityVideoFullscreenPage), findsOneWidget);
      expect(platform.players, hasLength(1), reason: 'no second player');
      expect(player.playing, isTrue, reason: 'entering does not pause');
      expect(find.byKey(ValueKey<String>('fake-video-view-${player.id}')),
          findsOneWidget,
          reason: 'one platform view is mounted at a time');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CommunityVideoFullscreenPage), findsNothing);
      expect(platform.players, hasLength(1));
      expect(player.playing, isTrue, reason: 'leaving does not restart');
      expect(player.seeks, isEmpty, reason: 'and does not seek');
      expect(find.byKey(ValueKey<String>('fake-video-view-${player.id}')),
          findsOneWidget);
    });

    testPlayer('the fullscreen strip exposes the exit control', (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clip, isActive: true),
      )));
      await startPlayback(tester);
      await _hover(tester, find.byType(CommunityVideoPlayerSurface));
      await tester.tap(find.byTooltip(_l10n.communityMediaVideoFullscreen));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip(_l10n.communityMediaVideoExitFullscreen),
          findsWidgets);
      await tester
          .tap(find.byTooltip(_l10n.communityMediaVideoExitFullscreen).first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CommunityVideoFullscreenPage), findsNothing);
    });
  });

  group('inside the carousel', () {
    const urls = <String>[_clip, 'https://example.test/uploads/b.jpg'];

    Widget carousel() => _app(Center(
          child: SizedBox(
            width: 540,
            child: CommunityPostMediaCarousel(mediaUrls: urls),
          ),
        ));

    testPlayer('scrubbing the timeline does not swipe to the next slide',
        (tester) async {
      await tester.pumpWidget(carousel());
      await startPlayback(tester);
      final stage = find.byType(CommunityVideoPlayerSurface);
      await _hover(tester, stage);
      final rect = tester.getRect(find.byType(CommunityVideoTimeline));

      final gesture = await tester.startGesture(
        Offset(rect.left + rect.width * 0.8, rect.center.dy),
      );
      await gesture.moveBy(const Offset(-80, 0));
      await gesture.moveBy(const Offset(-80, 0));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('1 / 2'), findsOneWidget);
    });

    testPlayer(
        'swiping elsewhere on the video still changes the slide and '
        'stops playback', (tester) async {
      await tester.pumpWidget(carousel());
      await startPlayback(tester);
      final player = platform.players.values.single;

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await _settle(tester);

      expect(find.text('2 / 2'), findsOneWidget);
      expect(player.disposed, isTrue);
      expect(platform.playingNow, isEmpty);
    });

    testPlayer('left and right keys on the player still move the carousel',
        (tester) async {
      await tester.pumpWidget(carousel());
      await startPlayback(tester);
      // Focus the player surface itself (not the timeline).
      await tester.tapAt(
          tester.getTopLeft(find.byType(CommunityVideoPlayerSurface)) +
              const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('2 / 2'), findsOneWidget);
    });
  });

  group('small stages and large text', () {
    for (final scale in <double>[1, 1.5, 2]) {
      testPlayer('a 320 px stage with an hour-long clip fits at ${scale}x text',
          (tester) async {
        platform.duration = const Duration(hours: 1, minutes: 2, seconds: 3);
        await tester.pumpWidget(_app(
          _stage(
            const CommunityPostVideoSlide(url: _clip, isActive: true),
            width: 320,
          ),
          textScale: scale,
        ));
        await startPlayback(tester);

        // No RenderFlex overflow is reported as a test exception.
        expect(tester.takeException(), isNull);
        expect(find.text('0:00 / 1:02:03'), findsOneWidget);
        for (final tooltip in <String>[
          _l10n.communityMediaVideoPause,
          _l10n.communityMediaVideoUnmute,
          _l10n.communityMediaVideoFullscreen,
        ]) {
          final rect = tester.getRect(find.byTooltip(tooltip));
          expect(
              rect.right,
              lessThanOrEqualTo(tester
                      .getRect(
                        find.byType(CommunityVideoPlayerSurface),
                      )
                      .right +
                  0.5),
              reason: '$tooltip stays inside the stage');
          expect(rect.width, KubusSizes.mediaControlTarget);
        }
      });
    }
  });

  group('tokens', () {
    testPlayer('the strip is built from kubus tokens, not arbitrary values',
        (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clip, isActive: true),
      )));
      await startPlayback(tester);
      await _hover(tester, find.byType(CommunityVideoPlayerSurface));

      final button = tester.getSize(
        find.byTooltip(_l10n.communityMediaVideoPause),
      );
      expect(button.width, KubusSizes.mediaControlTarget);
      expect(button.height, KubusSizes.mediaControlTarget);
    });
  });
}
