import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/viewport_visibility.dart';
import 'community_video_controls.dart';
import 'community_video_fullscreen.dart';

/// Keeps at most one feed video playing. Starting another video pauses the
/// previous one, so a scrolled feed never plays two clips at once.
class CommunityVideoPlaybackCoordinator {
  CommunityVideoPlaybackCoordinator._();

  static VideoPlayerController? _active;

  static void claim(VideoPlayerController controller) {
    final previous = _active;
    if (previous != null && !identical(previous, controller)) {
      unawaited(previous.pause());
    }
    _active = controller;
  }

  static void release(VideoPlayerController? controller) {
    if (controller != null && identical(_active, controller)) {
      _active = null;
    }
  }
}

/// A playable video inside the media carousel.
///
/// The player is created on first play, not when the page is built, so a feed
/// does not download every clip. Playback starts from the viewer's own tap, so
/// it starts with sound at the volume they last chose; if the browser refuses
/// sound anyway the clip plays muted and says so. It stops at the end with a
/// replay control instead of looping, and is released as soon as its page is no
/// longer the active one. While playing it also pauses itself when the post
/// scrolls out of view, another route covers it, the tab is hidden, or the app
/// goes to the background.
class CommunityPostVideoSlide extends StatefulWidget {
  const CommunityPostVideoSlide({
    super.key,
    required this.url,
    required this.isActive,
  });

  final String url;
  final bool isActive;

  /// How often a playing clip checks whether it is still on screen.
  @visibleForTesting
  static Duration guardInterval = const Duration(milliseconds: 400);

  @visibleForTesting
  static int activeVisibilityGuards = 0;

  @override
  State<CommunityPostVideoSlide> createState() =>
      _CommunityPostVideoSlideState();
}

class _CommunityPostVideoSlideState extends State<CommunityPostVideoSlide>
    with WidgetsBindingObserver {
  /// A playing clip pauses once less than this share of it is on screen.
  static const double _minVisibleFraction = 0.4;

  final CommunityVideoAudio _audio = CommunityVideoAudio();
  VideoPlayerController? _controller;
  Timer? _guard;
  bool _initializing = false;
  bool _failed = false;
  bool _fullscreen = false;
  bool _inlineVideoHidden = false;
  bool _retriedMuted = false;
  bool _tickersEnabled = true;
  int _generation = 0;
  Route<void>? _fullscreenRoute;
  NavigatorState? _fullscreenNavigator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio.addListener(_applyVolume);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // An IndexedStack or offstage tab turns tickers off for pages it hides.
    final enabled = TickerMode.valuesOf(context).enabled;
    if (_tickersEnabled && !enabled && !_fullscreen) {
      // The controller notifies its listeners, which must not happen mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _pauseIfPlaying());
    }
    _tickersEnabled = enabled;
  }

  @override
  void didUpdateWidget(covariant CommunityPostVideoSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive && _controller != null) {
      setState(_releaseController);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pauseIfPlaying();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final route = _fullscreenRoute;
    if (route != null && route.isActive) {
      _fullscreenNavigator?.removeRoute(route);
    }
    _audio.removeListener(_applyVolume);
    _audio.dispose();
    _releaseController();
    super.dispose();
  }

  void _releaseController() {
    _generation++;
    _stopGuard();
    final controller = _controller;
    controller?.removeListener(_syncGuard);
    controller?.removeListener(_recoverBlockedSound);
    _controller = null;
    CommunityVideoPlaybackCoordinator.release(controller);
    unawaited(controller?.dispose());
  }

  void _stopGuard() {
    if (_guard == null) return;
    _guard!.cancel();
    _guard = null;
    CommunityPostVideoSlide.activeVisibilityGuards--;
  }

  void _syncGuard() {
    if (!mounted || _controller?.value.isPlaying != true) {
      _stopGuard();
    } else if (_guard == null) {
      CommunityPostVideoSlide.activeVisibilityGuards++;
      _guard = Timer.periodic(
        CommunityPostVideoSlide.guardInterval,
        (_) => _guardTick(),
      );
    }
  }

  /// Browsers word the refusal differently; none of them put a code in the
  /// message `video_player` keeps.
  static final RegExp _blockedSound = RegExp(
    r"interact|not allowed|user denied|gesture|NotAllowed",
    caseSensitive: false,
  );

  /// The browser refused to start the clip with sound (strict autoplay policy,
  /// or the tap's user activation expired while the clip loaded). Reload it
  /// muted, once, instead of showing a broken player.
  void _recoverBlockedSound() {
    final controller = _controller;
    if (controller == null || _retriedMuted || _audio.effectiveVolume <= 0) {
      return;
    }
    final value = controller.value;
    if (!value.hasError || !_blockedSound.hasMatch(value.errorDescription!)) {
      return;
    }
    _retriedMuted = true;
    _audio.muteForBrowserPolicy();
    // The controller notifies from inside its own update; restart afterwards.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_controller, controller)) return;
      setState(_releaseController);
      unawaited(_startPlayback(afterBlockedSound: true));
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _pauseIfPlaying() {
    final controller = _controller;
    if (controller != null && controller.value.isPlaying) {
      unawaited(controller.pause());
    }
  }

  void _applyVolume() {
    unawaited(_controller?.setVolume(_audio.effectiveVolume));
  }

  void _guardTick() {
    final controller = _controller;
    if (controller == null || !mounted || !controller.value.isPlaying) return;
    // The expanded view sits in a route of its own; that is not "covered".
    if (_fullscreen) return;
    final route = ModalRoute.of(context);
    final covered = route != null && !route.isCurrent;
    final ticking = TickerMode.getValuesNotifier(context).value.enabled;
    if (!ticking ||
        covered ||
        widgetVisibleFraction(context) < _minVisibleFraction) {
      unawaited(controller.pause());
    }
  }

  Future<void> _startPlayback({bool afterBlockedSound = false}) async {
    if (_initializing) return;
    if (!afterBlockedSound) _retriedMuted = false;
    final generation = ++_generation;
    setState(() {
      _initializing = true;
      _failed = false;
    });

    VideoPlayerController? controller;
    try {
      final url = MediaUrlResolver.resolveDisplayUrl(widget.url) ?? widget.url;
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(_audio.effectiveVolume);
    } catch (_) {
      await controller?.dispose();
      if (!mounted || generation != _generation) return;
      setState(() {
        _initializing = false;
        _failed = true;
      });
      return;
    }
    if (!mounted || !widget.isActive || generation != _generation) {
      await controller.dispose();
      if (mounted && generation == _generation) {
        setState(() => _initializing = false);
      }
      return;
    }
    CommunityVideoPlaybackCoordinator.claim(controller);
    setState(() {
      _controller = controller;
      _initializing = false;
    });
    controller.addListener(_syncGuard);
    controller.addListener(_recoverBlockedSound);
    await controller.play();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) {
      await _startPlayback();
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
      return;
    }
    if (controller.value.isCompleted) await controller.seekTo(Duration.zero);
    CommunityVideoPlaybackCoordinator.claim(controller);
    await controller.play();
  }

  Future<void> _replay() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.seekTo(Duration.zero);
    CommunityVideoPlaybackCoordinator.claim(controller);
    await controller.play();
  }

  Future<void> _retry() async {
    if (_controller != null) setState(_releaseController);
    await _startPlayback();
  }

  Future<void> _toggleFullscreen() async {
    final controller = _controller;
    if (controller == null || _fullscreen) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final wasPlaying = controller.value.isPlaying;
    var retryAfterClose = false;
    final route = communityVideoFullscreenRoute(
      animate: !MediaQuery.disableAnimationsOf(context),
      controller: controller,
      audio: _audio,
      onTogglePlayback: _togglePlayback,
      onReplay: _replay,
      onRetry: () {
        retryAfterClose = true;
        navigator.pop();
      },
    );
    _fullscreenRoute = route;
    _fullscreenNavigator = navigator;
    setState(() {
      _fullscreen = true;
      _inlineVideoHidden = true;
    });
    // Unmount the inline platform view before the new route can build its view.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !identical(_controller, controller)) return;
    final popped = navigator.push<void>(route);
    await WidgetsBinding.instance.endOfFrame;
    // Web platform views attach after the framework frame. Allow the next
    // composited frame (and its queued media pause event) before restoring play.
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;
    if (mounted &&
        identical(_controller, controller) &&
        route.isCurrent &&
        wasPlaying &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      // Reattaching a web video element may pause it without changing position.
      CommunityVideoPlaybackCoordinator.claim(controller);
      await controller.play();
    }
    await popped;
    final resume = controller.value.isPlaying;
    // push completes at pop, but completed waits for the reverse animation and
    // overlay removal. The fullscreen view must be gone before inline remounts.
    await route.completed;
    _fullscreenRoute = null;
    _fullscreenNavigator = null;
    if (!mounted || !identical(_controller, controller)) return;
    setState(() {
      _inlineVideoHidden = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !identical(_controller, controller)) return;
    if (retryAfterClose) {
      await _retry();
    } else if (resume &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      // Web pauses a detached video element; retain the user's playback state.
      CommunityVideoPlaybackCoordinator.claim(controller);
      await controller.play();
    }
    if (mounted) setState(() => _fullscreen = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = _controller;
    return Semantics(
      container: true,
      label: l10n.communityMediaVideoControls,
      child: controller == null
          ? _buildIdle(context, l10n)
          : CommunityVideoPlayerSurface(
              controller: controller,
              audio: _audio,
              showVideo: !_inlineVideoHidden,
              onTogglePlayback: _togglePlayback,
              onReplay: _replay,
              onRetry: _retry,
              onToggleFullscreen: _toggleFullscreen,
            ),
    );
  }

  Widget _buildIdle(BuildContext context, AppLocalizations l10n) {
    final Widget content;
    if (_failed) {
      content = CommunityVideoErrorBlock(onRetry: _retry);
    } else if (_initializing) {
      content = Semantics(
        container: true,
        liveRegion: true,
        label: l10n.communityMediaVideoLoading,
        child: const CommunityVideoBusyIndicator(),
      );
    } else {
      content = CommunityVideoLargeButton(
        icon: Icons.play_arrow_rounded,
        tooltip: l10n.communityMediaVideoPlay,
        onPressed: _startPlayback,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _failed ? null : _startPlayback,
      // Before the clip loads its shape is unknown, so there is no player to
      // frame yet: the slide shows the same neutral stage an image would.
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(child: content),
      ),
    );
  }
}
