// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// One player created through [FakeVideoPlayerPlatform].
class FakeVideoPlayer {
  FakeVideoPlayer(this.id, this.uri);

  final int id;
  final String uri;
  final StreamController<VideoEvent> events = StreamController<VideoEvent>();
  Duration position = Duration.zero;
  bool playing = false;
  bool looping = false;
  bool disposed = false;
  double volume = 1;
  int viewsBuilt = 0;
  final List<Duration> seeks = <Duration>[];
}

/// A scriptable `video_player` backend, so the real [VideoPlayerController]
/// runs in widget tests with no network and no HTMLVideoElement.
///
/// Playback is simulated: [play] flips the playing flag and emits the state
/// event; tests advance [FakeVideoPlayer.position] and emit buffering, completion
/// and error events themselves.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  FakeVideoPlayerPlatform({
    this.duration = const Duration(seconds: 34),
    this.size = const Size(640, 360),
  });

  Duration duration;
  Size size;

  /// Gives each clip its own size, keyed by its URL. Falls back to [size].
  Size Function(String uri)? sizeFor;

  /// Makes the next `initialize()` fail, like an unreachable or invalid file.
  bool failInitialize = false;

  /// Refuses to start a clip whose volume is above zero, the way a browser
  /// with a strict autoplay policy rejects `play()` with sound.
  bool blockSoundedPlay = false;

  /// Rejects every `play()` call, muted or not, the way a browser or a decoder
  /// can refuse playback outright.
  bool rejectAllPlay = false;

  /// Calls to `play()` so far, per player id.
  final Map<int, int> playCalls = <int, int>{};

  final Map<int, FakeVideoPlayer> players = <int, FakeVideoPlayer>{};
  int _nextId = 1;

  Iterable<FakeVideoPlayer> get live =>
      players.values.where((player) => !player.disposed);

  Iterable<FakeVideoPlayer> get playingNow =>
      live.where((player) => player.playing);

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final player = FakeVideoPlayer(_nextId++, options.dataSource.uri ?? '');
    players[player.id] = player;
    scheduleMicrotask(() {
      if (failInitialize) {
        player.events.addError(PlatformException(
          code: 'VideoError',
          message: 'fake initialize failure',
        ));
        return;
      }
      player.events.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: duration,
        size: sizeFor?.call(player.uri) ?? size,
      ));
    });
    return player.id;
  }

  @override
  Future<int?> create(DataSource dataSource) =>
      createWithOptions(VideoCreationOptions(
        dataSource: dataSource,
        viewType: VideoViewType.platformView,
      ));

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      players[playerId]!.events.stream;

  @override
  Future<void> dispose(int playerId) async {
    final player = players[playerId];
    if (player == null) return;
    player.disposed = true;
    player.playing = false;
    await player.events.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    players[playerId]!.looping = looping;
  }

  @override
  Future<void> play(int playerId) async {
    final player = players[playerId]!;
    playCalls[playerId] = (playCalls[playerId] ?? 0) + 1;
    if (rejectAllPlay) {
      throw PlatformException(
        code: 'NotSupportedError',
        message: 'play() was refused by the test platform.',
      );
    }
    if (blockSoundedPlay && player.volume > 0) {
      if (!player.events.isClosed) {
        player.events.addError(PlatformException(
          code: 'NotAllowedError',
          message: "play() failed because the user didn't interact with the "
              'document first.',
        ));
      }
      return;
    }
    player.playing = true;
    if (!player.events.isClosed) {
      player.events.add(VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ));
    }
  }

  @override
  Future<void> pause(int playerId) async {
    final player = players[playerId]!;
    player.playing = false;
    if (!player.events.isClosed) {
      player.events.add(VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ));
    }
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    players[playerId]!.volume = volume;
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    final player = players[playerId]!;
    player.position = position;
    player.seeks.add(position);
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async =>
      players[playerId]!.position;

  @override
  Widget buildView(int playerId) {
    players[playerId]!.viewsBuilt++;
    return SizedBox.expand(key: ValueKey<String>('fake-video-view-$playerId'));
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      buildView(options.playerId);

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setWebOptions(
      int playerId, VideoPlayerWebOptions options) async {}
}
