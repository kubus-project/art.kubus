import 'dart:ui' show PointerDeviceKind;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/community/community_post_media_carousel.dart';
import 'package:art_kubus/widgets/community/community_post_video_slide.dart';
import 'package:art_kubus/widgets/community/community_video_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/fake_video_player_platform.dart';

// ignore_for_file: depend_on_referenced_packages

/// Audio and geometry of the Community video player, against the real
/// `VideoPlayerController` and a scripted platform. These prove state and
/// layout; whether sound leaves a speaker is checked in a browser, separately.

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));
const ValueKey<String> _frameKey = ValueKey<String>('community-video-frame');
const String _clipA = 'https://example.test/uploads/a.mp4';
const String _clipB = 'https://example.test/uploads/b.mp4';
const String _image = 'https://example.test/uploads/c.jpg';

Widget _app(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    themeMode: mode,
    theme: ThemeData(brightness: Brightness.light),
    darkTheme: ThemeData(brightness: Brightness.dark),
    home: Scaffold(body: child),
  );
}

Widget _stage(Widget child, {required double width}) => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        child: AspectRatio(aspectRatio: 4 / 3, child: child),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 12)),
    );
  }
}

@isTest
void _testPlayer(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await _settle(tester);
    expect(CommunityPostVideoSlide.activeVisibilityGuards, 0);
  });
}

Future<TestGesture> _hoverFrame(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  await gesture.moveTo(tester.getCenter(find.byKey(_frameKey).last));
  await tester.pump();
  return gesture;
}

void main() {
  late FakeVideoPlayerPlatform platform;
  late VideoPlayerPlatform previous;

  setUp(() {
    CommunityVideoAudio.resetSession();
    CommunityPostVideoSlide.guardInterval = const Duration(milliseconds: 20);
    previous = VideoPlayerPlatform.instance;
    platform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(() {
    CommunityVideoAudio.resetSession();
    CommunityPostVideoSlide.guardInterval = const Duration(milliseconds: 400);
    VideoPlayerPlatform.instance = previous;
  });

  Future<void> play(WidgetTester tester) async {
    await tester.tap(find.byTooltip(_l10n.communityMediaVideoPlay).first);
    await _settle(tester);
  }

  group('audio', () {
    _testPlayer('plays with sound at full volume after an explicit play',
        (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clipA, isActive: true),
        width: 540,
      )));
      expect(platform.players, isEmpty, reason: 'nothing loads before the tap');
      await play(tester);

      final player = platform.live.single;
      expect(player.playing, isTrue);
      expect(player.volume, 1);
      await _hoverFrame(tester);
      expect(find.byTooltip(_l10n.communityMediaVideoMute), findsOneWidget,
          reason: 'the control offers mute because the clip is audible');
      expect(find.byTooltip(_l10n.communityMediaVideoUnmute), findsNothing);
    });

    _testPlayer('mute, unmute and volume always match the player',
        (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clipA, isActive: true),
        width: 540,
      )));
      await play(tester);
      await _hoverFrame(tester);
      final player = platform.live.single;

      Future<void> expectIcon({required bool muted}) async {
        expect(
          find.byTooltip(muted
              ? _l10n.communityMediaVideoUnmute
              : _l10n.communityMediaVideoMute),
          findsOneWidget,
        );
      }

      await tester.tap(find.byTooltip(_l10n.communityMediaVideoMute));
      await _settle(tester);
      expect(player.volume, 0);
      await expectIcon(muted: true);

      await tester.tap(find.byTooltip(_l10n.communityMediaVideoUnmute));
      await _settle(tester);
      expect(player.volume, 1);
      await expectIcon(muted: false);

      // Dragging the track to a level plays at that level and unmutes.
      final track = find.byWidgetPredicate((w) =>
          w is CommunityMediaSlider &&
          w.semanticLabel == _l10n.communityMediaVideoVolume);
      final rect = tester.getRect(track);
      await tester.tapAt(Offset(rect.left + rect.width * 0.4, rect.center.dy));
      await _settle(tester);
      expect(player.volume, inInclusiveRange(0.25, 0.55));
      await expectIcon(muted: false);

      // Dragging it to zero is a mute; unmuting afterwards is audible again.
      await tester.tapAt(Offset(rect.left, rect.center.dy));
      await _settle(tester);
      expect(player.volume, 0);
      await expectIcon(muted: true);
      await tester.tap(find.byTooltip(_l10n.communityMediaVideoUnmute));
      await _settle(tester);
      expect(player.volume, 1);
    });

    _testPlayer('the M key toggles sound on the focused player',
        (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clipA, isActive: true),
        width: 540,
      )));
      await play(tester);
      await _hoverFrame(tester);
      final player = platform.live.single;
      await tester.tapAt(
        tester.getTopLeft(find.byKey(_frameKey)) + const Offset(20, 20),
        kind: PointerDeviceKind.mouse,
      );
      await _settle(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await _settle(tester);
      expect(player.volume, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await _settle(tester);
      expect(player.volume, 1);
    });

    _testPlayer('a viewer who muted keeps the next clip muted', (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clipA, isActive: true),
        width: 540,
      )));
      await play(tester);
      await _hoverFrame(tester);
      await tester.tap(find.byTooltip(_l10n.communityMediaVideoMute));
      await _settle(tester);

      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clipB, isActive: true),
        width: 540,
      )));
      await play(tester);
      expect(platform.live.single.uri, endsWith('/uploads/b.mp4'));
      expect(platform.live.single.volume, 0);
    });

    _testPlayer('a viewer who chose a level keeps it for the next clip',
        (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clipA, isActive: true),
        width: 540,
      )));
      await play(tester);
      await _hoverFrame(tester);
      final track = find.byWidgetPredicate((w) =>
          w is CommunityMediaSlider &&
          w.semanticLabel == _l10n.communityMediaVideoVolume);
      final rect = tester.getRect(track);
      await tester.tapAt(Offset(rect.left + rect.width * 0.5, rect.center.dy));
      await _settle(tester);
      final chosen = platform.live.single.volume;
      expect(chosen, inInclusiveRange(0.3, 0.7));

      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clipB, isActive: true),
        width: 540,
      )));
      await play(tester);
      expect(platform.live.single.volume, closeTo(chosen, 0.001));
    });

    _testPlayer(
        'a clip mounted before the viewer muted another clip starts '
        'muted after its own explicit play', (tester) async {
      // Both slides are mounted up front, as cached feed items are, so the
      // second one captured the session's sound before the first was muted.
      await tester.pumpWidget(_app(Column(
        children: [
          _stage(
            const CommunityPostVideoSlide(url: _clipA, isActive: true),
            width: 300,
          ),
          _stage(
            const CommunityPostVideoSlide(url: _clipB, isActive: true),
            width: 300,
          ),
        ],
      )));
      await tester.tap(find.byTooltip(_l10n.communityMediaVideoPlay).first);
      await _settle(tester);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byKey(_frameKey).first));
      await tester.pump();
      await tester.tap(find.byTooltip(_l10n.communityMediaVideoMute));
      await _settle(tester);
      await gesture.removePointer();

      await tester.tap(find.byTooltip(_l10n.communityMediaVideoPlay).first);
      await _settle(tester);
      final second = platform.live.singleWhere(
        (player) => player.uri.endsWith('/uploads/b.mp4'),
      );
      expect(second.playing, isTrue);
      expect(second.volume, 0,
          reason: 'the viewer muted, so the next clip must not sound');
    });

    _testPlayer(
        'a browser that refuses sound gets the clip muted, once, and says so',
        (tester) async {
      platform.blockSoundedPlay = true;
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clipA, isActive: true),
        width: 540,
      )));
      await play(tester);
      await _settle(tester);

      expect(platform.players, hasLength(2),
          reason: 'the refused player is replaced by a muted one');
      expect(platform.players.values.first.disposed, isTrue);
      final player = platform.live.single;
      expect(player.playing, isTrue);
      expect(player.volume, 0);
      await _hoverFrame(tester);
      expect(find.byTooltip(_l10n.communityMediaVideoUnmute), findsOneWidget,
          reason: 'the player shows it is muted rather than a broken video');
      expect(find.text(_l10n.communityMediaVideoUnavailable), findsNothing);

      // One refusal is not the viewer's choice: the next clip tries sound.
      expect(CommunityVideoAudio().muted, isFalse);

      // Unmuting is a gesture, so sound follows.
      await tester.tap(find.byTooltip(_l10n.communityMediaVideoUnmute));
      await _settle(tester);
      expect(player.volume, 1);
    });

    _testPlayer('an unrelated playback error is not mistaken for a block',
        (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clipA, isActive: true),
        width: 540,
      )));
      await play(tester);
      platform.live.single.events.addError(PlatformException(
        code: 'MEDIA_ERR_NETWORK',
        message: 'A network error caused the media download to fail.',
      ));
      await _settle(tester);

      expect(platform.players, hasLength(1), reason: 'no silent re-create');
      expect(find.text(_l10n.communityMediaVideoUnavailable), findsOneWidget);
    });
  });

  group('geometry', () {
    // Every shape named in the brief, at a phone, tablet and desktop feed.
    const shapes = <String, Size>{
      '16:9': Size(1280, 720),
      '9:16': Size(720, 1280),
      '1:1': Size(1000, 1000),
      '4:3': Size(1024, 768),
      'ultrawide 21:9': Size(2520, 1080),
    };
    const widths = <double>[358, 640, 788];

    test('communityVideoFrameSize contains, never crops or distorts', () {
      expect(communityVideoFrameSize(const Size(400, 300), 16 / 9),
          const Size(400, 225));
      expect(communityVideoFrameSize(const Size(400, 300), 9 / 16),
          const Size(168.75, 300));
      expect(communityVideoFrameSize(const Size(400, 300), 1),
          const Size(300, 300));
      expect(communityVideoFrameSize(const Size(400, 300), 4 / 3),
          const Size(400, 300));
      expect(communityVideoFrameSize(const Size(400, 300), 21 / 9).height,
          closeTo(171.43, 0.01));
      expect(communityVideoFrameSize(const Size(400, double.infinity), 2),
          const Size(400, 200));
      expect(communityVideoFrameSize(const Size(double.infinity, 300), 2),
          const Size(600, 300));
      expect(communityVideoFrameSize(const Size(400, 300), double.nan),
          const Size(400, 225),
          reason: 'an unusable aspect falls back to 16:9');
      expect(communityVideoFrameSize(Size.zero, 1.5), Size.zero);
    });

    for (final theme in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      for (final entry in shapes.entries) {
        for (final width in widths) {
          _testPlayer(
              '${entry.key} clip in a ${width.round()} px stage, ${theme.name}: '
              'one frame, controls inside it', (tester) async {
            platform.size = entry.value;
            final ratio = entry.value.width / entry.value.height;
            await tester.pumpWidget(_app(
              _stage(
                const CommunityPostVideoSlide(url: _clipA, isActive: true),
                width: width,
              ),
              mode: theme,
            ));
            final idleStage = tester.getRect(find.byType(AspectRatio).first);
            await play(tester);
            await _hoverFrame(tester);
            expect(tester.takeException(), isNull, reason: 'no overflow');

            final stage =
                tester.getRect(find.byType(CommunityVideoPlayerSurface));
            expect(stage, idleStage, reason: 'playing does not move the stage');
            final frame = tester.getRect(find.byKey(_frameKey));
            final expected = communityVideoFrameSize(stage.size, ratio);
            expect(frame.width, closeTo(expected.width, 0.5));
            expect(frame.height, closeTo(expected.height, 0.5));
            expect(frame.width / frame.height, closeTo(ratio, 0.01),
                reason: 'the frame has the clip\'s own shape');
            expect(frame.center.dx, closeTo(stage.center.dx, 0.5));
            expect(frame.center.dy, closeTo(stage.center.dy, 0.5));
            // Maximised: it touches the stage on at least one axis.
            expect(
              (frame.width - stage.width).abs() < 0.5 ||
                  (frame.height - stage.height).abs() < 0.5,
              isTrue,
              reason: 'the video is as large as the stage allows',
            );

            // The picture fills the frame exactly: no bars, no crop.
            final player = platform.live.single;
            final view = tester.getRect(
              find.byKey(ValueKey<String>('fake-video-view-${player.id}')),
            );
            expect(view.left, closeTo(frame.left, 0.5));
            expect(view.top, closeTo(frame.top, 0.5));
            expect(view.width, closeTo(frame.width, 0.5));
            expect(view.height, closeTo(frame.height, 0.5));

            // Seek bar and buttons live inside the video's visible frame.
            final timeline =
                tester.getRect(find.byType(CommunityVideoTimeline));
            expect(timeline.left, greaterThanOrEqualTo(frame.left));
            expect(timeline.right, lessThanOrEqualTo(frame.right));
            expect(timeline.width,
                greaterThanOrEqualTo(frame.width - KubusSpacing.sm * 2 - 0.5),
                reason: 'the seek bar spans the video, not the stage');
            expect(timeline.left - frame.left,
                closeTo(frame.right - timeline.right, 0.5),
                reason: 'and is centred on it');
            expect(timeline.bottom, lessThanOrEqualTo(frame.bottom));
            for (final tooltip in <String>[
              _l10n.communityMediaVideoPause,
              _l10n.communityMediaVideoMute,
              _l10n.communityMediaVideoFullscreen,
            ]) {
              final rect = tester.getRect(find.byTooltip(tooltip));
              expect(rect.left, greaterThanOrEqualTo(frame.left - 0.5),
                  reason: tooltip);
              expect(rect.right, lessThanOrEqualTo(frame.right + 0.5),
                  reason: tooltip);
              expect(rect.bottom, lessThanOrEqualTo(frame.bottom + 0.5),
                  reason: tooltip);
              expect(rect.width, KubusSizes.mediaControlTarget);
              expect(rect.height, KubusSizes.mediaControlTarget);
            }

            // The strip is attached to the video, not to the stage.
            expect(find.text('0:00 / 0:34'), findsOneWidget);
          });
        }
      }
    }

    for (final entry in shapes.entries) {
      _testPlayer(
          'paused ${entry.key} clip on a phone: the centre play control sits '
          'above the strip, not under it', (tester) async {
        platform.size = entry.value;
        await tester.pumpWidget(_app(_stage(
          const CommunityPostVideoSlide(url: _clipA, isActive: true),
          width: 358,
        )));
        await play(tester);
        await _hoverFrame(tester);
        await tester.tap(find.byTooltip(_l10n.communityMediaVideoPause));
        await _settle(tester);

        final centre = tester.getRect(find.byType(CommunityVideoLargeButton));
        final timeline = tester.getRect(find.byType(CommunityVideoTimeline));
        final frame = tester.getRect(find.byKey(_frameKey));
        expect(centre.bottom, lessThanOrEqualTo(timeline.top + 0.5));
        expect(centre.top, greaterThanOrEqualTo(frame.top - 0.5));
        expect(centre.center.dx, closeTo(frame.center.dx, 0.5));
      });
    }

    _testPlayer('before play there is no player to frame, only a neutral stage',
        (tester) async {
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clipA, isActive: true),
        width: 358,
      )));
      expect(find.byKey(_frameKey), findsNothing);
      expect(find.byType(CommunityVideoPlayerSurface), findsNothing);
      expect(find.byTooltip(_l10n.communityMediaVideoPlay), findsOneWidget);
    });

    _testPlayer('the full screen frame fits the screen and carries the strip',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      platform.size = const Size(720, 1280);
      await tester.pumpWidget(_app(_stage(
        const CommunityPostVideoSlide(url: _clipA, isActive: true),
        width: 358,
      )));
      await play(tester);
      await _hoverFrame(tester);
      await tester.tap(find.byTooltip(_l10n.communityMediaVideoFullscreen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      final frame = tester.getRect(find.byKey(_frameKey).last);
      expect(frame.height, lessThanOrEqualTo(600));
      expect(frame.width / frame.height, closeTo(9 / 16, 0.01));
      expect(frame.height, closeTo(600 - 2 * 0, 80),
          reason: 'a portrait clip uses the height of a landscape screen');
      final timeline = tester.getRect(find.byType(CommunityVideoTimeline).last);
      expect(timeline.left, greaterThanOrEqualTo(frame.left));
      expect(timeline.right, lessThanOrEqualTo(frame.right));
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('carousel lifecycle', () {
    const urls = <String>[_clipA, _clipB, _image];

    Widget carousel({double width = 390}) => _app(Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: const CommunityPostMediaCarousel(mediaUrls: urls),
          ),
        ));

    Future<void> swipe(WidgetTester tester, {bool forward = true}) async {
      await tester.drag(
        find.byType(PageView),
        Offset(forward ? -500 : 500, 0),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await _settle(tester);
    }

    _testPlayer(
        'consecutive videos: the first is silenced and released before the '
        'second can sound', (tester) async {
      await tester.pumpWidget(carousel());
      await play(tester);
      final first = platform.live.single;
      expect(first.playing, isTrue);

      await swipe(tester);
      expect(first.disposed, isTrue);
      expect(first.playing, isFalse);
      expect(platform.playingNow, isEmpty,
          reason: 'nothing makes sound while the next clip is idle');

      await play(tester);
      final second = platform.live.single;
      expect(second.uri, endsWith('/uploads/b.mp4'));
      expect(second.playing, isTrue);
      expect(second.volume, 1);
      expect(platform.playingNow, hasLength(1));
    });

    _testPlayer('returning to a video starts a fresh, audible player',
        (tester) async {
      await tester.pumpWidget(carousel());
      await play(tester);
      final first = platform.live.single;
      first.position = const Duration(seconds: 12);

      await swipe(tester);
      await swipe(tester, forward: false);
      expect(first.disposed, isTrue);
      expect(find.byType(CommunityVideoPlayerSurface), findsNothing,
          reason: 'back on the clip it waits for a tap again');

      await play(tester);
      final again = platform.live.single;
      expect(again.id, isNot(first.id));
      expect(again.playing, isTrue);
      expect(again.volume, 1);
      expect(again.seeks, isEmpty);
      expect(platform.live, hasLength(1));
    });

    _testPlayer('image to video to image keeps the stage still and silent',
        (tester) async {
      await tester.pumpWidget(carousel());
      final stage = tester.getRect(find.byType(PageView));
      await swipe(tester);
      await swipe(tester);
      expect(find.text('3 / 3'), findsOneWidget);
      expect(tester.getRect(find.byType(PageView)), stage);
      expect(platform.players, isEmpty, reason: 'images never create a player');

      await swipe(tester, forward: false);
      await play(tester);
      expect(tester.getRect(find.byType(PageView)), stage);
      final player = platform.live.single;
      await swipe(tester);
      expect(player.disposed, isTrue);
      expect(platform.playingNow, isEmpty);
      expect(tester.getRect(find.byType(PageView)), stage);
    });

    _testPlayer('portrait to landscape and back reshapes only the player',
        (tester) async {
      platform.sizeFor = (uri) => uri.endsWith('/a.mp4')
          ? const Size(720, 1280)
          : const Size(1280, 720);
      await tester.pumpWidget(carousel());
      final stage = tester.getRect(find.byType(PageView));

      await play(tester);
      var frame = tester.getRect(find.byKey(_frameKey));
      expect(frame.width / frame.height, closeTo(9 / 16, 0.01));
      expect(frame.height, closeTo(stage.height, 0.5));

      await swipe(tester);
      await play(tester);
      frame = tester.getRect(find.byKey(_frameKey));
      expect(frame.width / frame.height, closeTo(16 / 9, 0.01));
      expect(frame.width, closeTo(stage.width, 0.5));
      expect(tester.getRect(find.byType(PageView)), stage,
          reason: 'the outer carousel does not change with the clip');

      await swipe(tester, forward: false);
      await play(tester);
      frame = tester.getRect(find.byKey(_frameKey));
      expect(frame.width / frame.height, closeTo(9 / 16, 0.01));
    });

    _testPlayer('a playing clip pauses off screen and its sound stops',
        (tester) async {
      await tester.pumpWidget(_app(ListView(
        children: const [
          SizedBox(height: 40),
          CommunityPostMediaCarousel(mediaUrls: <String>[_clipA]),
          SizedBox(height: 2400),
        ],
      )));
      await play(tester);
      final player = platform.live.single;
      expect(player.playing, isTrue);

      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);

      expect(player.playing, isFalse);
      expect(platform.playingNow, isEmpty);
    });

    _testPlayer('seeking keeps the player and its volume', (tester) async {
      await tester.pumpWidget(carousel());
      await play(tester);
      await _hoverFrame(tester);
      final player = platform.live.single;
      final timeline = tester.getRect(find.byType(CommunityVideoTimeline));

      await tester.tapAt(Offset(
        timeline.left + timeline.width * 0.75,
        timeline.center.dy,
      ));
      await _settle(tester);

      expect(player.seeks, isNotEmpty);
      expect(player.seeks.last.inSeconds, inInclusiveRange(20, 30));
      expect(player.playing, isTrue);
      expect(player.volume, 1);
      expect(platform.live, hasLength(1));
    });
  });
}
