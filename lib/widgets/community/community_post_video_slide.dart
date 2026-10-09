import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/viewport_visibility.dart';
import '../inline_loading.dart';
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
/// does not download every clip. It starts muted, stops at the end with a
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
    _guard?.cancel();
    _guard = null;
    final controller = _controller;
    _controller = null;
    CommunityVideoPlaybackCoordinator.release(controller);
    unawaited(controller?.dispose());
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

  Future<void> _startPlayback() async {
    if (_initializing) return;
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
    _guard = Timer.periodic(
      CommunityPostVideoSlide.guardInterval,
      (_) => _guardTick(),
    );
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
    final route = communityVideoFullscreenRoute(
      animate: !MediaQuery.disableAnimationsOf(context),
      controller: controller,
      audio: _audio,
      onTogglePlayback: _togglePlayback,
      onReplay: _replay,
      onRetry: () {
        navigator.pop();
        unawaited(_retry());
      },
    );
    _fullscreenRoute = route;
    _fullscreenNavigator = navigator;
    setState(() => _fullscreen = true);
    await navigator.push<void>(route);
    _fullscreenRoute = null;
    _fullscreenNavigator = null;
    // The feed route is re-enabled on the frame after the pop. Until then it
    // still reads as covered, which the guard would take for navigating away.
    await WidgetsBinding.instance.endOfFrame;
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
              showVideo: !_fullscreen,
              onTogglePlayback: _togglePlayback,
              onReplay: _replay,
              onRetry: _retry,
              onToggleFullscreen: _toggleFullscreen,
            ),
    );
  }

  Widget _buildIdle(BuildContext context, AppLocalizations l10n) {
    final roles = KubusColorRoles.of(context);
    final Widget content;
    if (_failed) {
      content = CommunityVideoErrorBlock(onRetry: _retry);
    } else if (_initializing) {
      content = Semantics(
        container: true,
        liveRegion: true,
        label: l10n.communityMediaVideoLoading,
        child: const SizedBox(
          width: 36,
          height: 36,
          child:
              InlineLoading(expand: true, shape: BoxShape.circle, tileSize: 4),
        ),
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
      child: ColoredBox(
        color: roles.surface,
        child: Center(child: content),
      ),
    );
  }
}
