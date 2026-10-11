import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../community/community_post_media.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/viewport_visibility.dart';
import 'community_video_autoplay.dart';
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
/// does not download every clip. The poster, when the post carries one, is the
/// still shown until then. Playback starts from the viewer's own tap, so it
/// starts with sound at the volume they last chose; if the browser refuses
/// sound anyway the clip plays muted and says so. It stops at the end with a
/// replay control instead of looping, and is released as soon as its page is no
/// longer the active one. While playing it also pauses itself when the post
/// scrolls out of view, another route covers it, the tab is hidden, or the app
/// goes to the background.
///
/// A feed clip may also start by itself, muted, once it is clearly on screen
/// (see [CommunityVideoAutoplay]). The first tap on such a clip brings its sound
/// on the same player; no second player is created.
class CommunityPostVideoSlide extends StatefulWidget {
  const CommunityPostVideoSlide({
    super.key,
    required this.url,
    required this.isActive,
    this.autoplay = true,
  });

  final String url;
  final bool isActive;

  /// False for previews that never autoplay (quoted posts).
  final bool autoplay;

  /// References the viewer paused by hand. A paused clip does not restart by
  /// itself while it stays on screen. Only the viewer's own pause adds to it,
  /// and playing again removes it.
  static final Set<String> _stickyPaused = <String>{};

  @visibleForTesting
  static Set<String> get stickyPausedReferences =>
      Set<String>.unmodifiable(_stickyPaused);

  @visibleForTesting
  static void clearStickyPauses() => _stickyPaused.clear();

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
    with WidgetsBindingObserver
    implements CommunityVideoAutoplayCandidate {
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

  /// The current controller was started by autoplay and is muted on its element.
  /// The viewer's sound choice is untouched until they take the sound.
  bool _autoMuted = false;

  /// An autoplay is starting: the controller exists, play() has not settled.
  bool _autoPlayPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio.addListener(_applyVolume);
    CommunityVideoAutoplay.register(this);
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
    CommunityVideoAutoplay.unregister(this);
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
    controller?.removeListener(_autoplayErrored);
    _controller = null;
    _autoMuted = false;
    _autoPlayPending = false;
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
    // This clip's sound changes only through its own controls (the mute button,
    // the volume track, the M key), so a notification is the viewer's choice.
    // It ends a muted autoplay and is applied to this same controller. Nothing
    // else here changes the element's volume, so autoplay stays silent until
    // then.
    _autoMuted = false;
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

  /// The playable URL of this clip, without its hints. Fails closed: an unsafe or
  /// unresolvable reference throws, and the caller shows the unavailable state.
  String _playableUrl() {
    final url = MediaUrlResolver.resolveDisplayUrl(
      communityMediaVideoSourceUrl(widget.url),
    );
    if (url == null) {
      throw const FormatException('Video reference is not a safe URL.');
    }
    return url;
  }

  Future<void> _startPlayback({bool afterBlockedSound = false}) async {
    if (_initializing) return;
    if (!afterBlockedSound) _retriedMuted = false;
    CommunityPostVideoSlide._stickyPaused.remove(widget.url);
    final generation = ++_generation;
    setState(() {
      _initializing = true;
      _failed = false;
    });

    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.networkUrl(Uri.parse(_playableUrl()));
      await controller.initialize();
      await controller.setLooping(false);
      // A blocked-sound retry keeps the browser's mute; every explicit play
      // starts from the viewer's current choice, not this slide's older copy.
      if (!afterBlockedSound) _audio.adoptSessionChoice();
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
    if (_autoMuted) {
      await _takeSoundFromAutoplay(controller);
      return;
    }
    if (controller.value.isPlaying) {
      CommunityPostVideoSlide._stickyPaused.add(widget.url);
      await controller.pause();
      return;
    }
    CommunityPostVideoSlide._stickyPaused.remove(widget.url);
    if (controller.value.isCompleted) await controller.seekTo(Duration.zero);
    CommunityVideoPlaybackCoordinator.claim(controller);
    await controller.play();
  }

  /// The viewer's first gesture on an autoplaying clip: it asks for sound. The
  /// same controller takes the session's choice (unmuted if the viewer had
  /// muted), and plays on if autoplay had paused it. No second player is made.
  Future<void> _takeSoundFromAutoplay(VideoPlayerController controller) async {
    CommunityPostVideoSlide._stickyPaused.remove(widget.url);
    _autoMuted = false;
    _audio.adoptSessionChoice();
    if (_audio.muted) _audio.toggleMute();
    await controller.setVolume(_audio.effectiveVolume);
    CommunityVideoPlaybackCoordinator.claim(controller);
    if (controller.value.isCompleted) await controller.seekTo(Duration.zero);
    if (!controller.value.isPlaying) await controller.play();
  }

  Future<void> _replay() async {
    final controller = _controller;
    if (controller == null) return;
    CommunityPostVideoSlide._stickyPaused.remove(widget.url);
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
    // A muted autoplay that was playing resumes on exit even where the browser
    // paused the detached element; the viewer's own pause never reaches here
    // muted, because a tap in the expanded view takes the sound instead.
    final resume = controller.value.isPlaying || (wasPlaying && _autoMuted);
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

  // ---- Muted autoplay (CommunityVideoAutoplayCandidate) ------------------

  @override
  double get autoplayVisibleFraction =>
      mounted ? widgetVisibleFraction(context) : 0;

  @override
  bool get autoplayAllowed {
    if (!mounted || !widget.autoplay || !widget.isActive) return false;
    if (CommunityPostVideoSlide._stickyPaused.contains(widget.url)) {
      return false;
    }
    // Reduced motion turns autoplay off; the poster and Play stay available.
    return !MediaQuery.disableAnimationsOf(context);
  }

  @override
  bool get autoplayMayStart {
    if (!autoplayAllowed || _failed || _fullscreen || _initializing) {
      return false;
    }
    // A clip that already holds a player (the viewer's, or a running autoplay)
    // has nothing to start.
    if (_controller != null) return false;
    if (!TickerMode.valuesOf(context).enabled) return false;
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  @override
  bool get playingWithSound =>
      _controller != null && !_autoMuted && _controller!.value.isPlaying;

  @override
  bool get autoplayOwned =>
      _autoPlayPending || (_autoMuted && _controller != null);

  @override
  bool get autoplayPlaying {
    if (_autoPlayPending) return true;
    // In the expanded view the inline element is detached, and some browsers
    // pause a detached media element. The clip still belongs to the viewer's
    // expanded view and resumes on exit, so the scheduler must not release it.
    if (_fullscreen) return true;
    return _autoMuted && (_controller?.value.isPlaying ?? false);
  }

  /// Starts this clip muted. The element is muted with volume 0 before play, so
  /// the viewer's sound choice is neither read nor written. A refused or failed
  /// start is silent: the poster or the neutral stage stays, with Play.
  @override
  Future<bool> startAutoplay() async {
    if (!mounted || !widget.isActive) return false;
    if (_controller != null || _initializing || _failed) return false;
    final generation = ++_generation;
    _autoPlayPending = true;
    setState(() => _initializing = true);

    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.networkUrl(Uri.parse(_playableUrl()));
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
    } catch (_) {
      await controller?.dispose();
      _autoPlayPending = false;
      if (mounted && generation == _generation) {
        setState(() => _initializing = false);
      }
      return false;
    }
    if (!mounted ||
        generation != _generation ||
        !widget.isActive ||
        CommunityVideoAutoplay.soundPlayingElsewhere(this)) {
      await controller.dispose();
      _autoPlayPending = false;
      if (mounted && generation == _generation) {
        setState(() => _initializing = false);
      }
      return false;
    }

    _autoMuted = true;
    CommunityVideoPlaybackCoordinator.claim(controller);
    setState(() {
      _controller = controller;
      _initializing = false;
    });
    controller.addListener(_syncGuard);
    controller.addListener(_autoplayErrored);
    try {
      await controller.play();
    } catch (_) {
      _autoPlayPending = false;
      if (mounted && identical(_controller, controller)) {
        setState(_releaseController);
      }
      return false;
    }
    _autoPlayPending = false;
    return mounted && identical(_controller, controller);
  }

  @override
  void stopAutoplay() {
    // Only an autoplay this clip owns is released. A clip the viewer took the
    // sound of keeps its player.
    if (!mounted || !autoplayOwned) return;
    _autoPlayPending = false;
    setState(_releaseController);
  }

  /// A muted autoplay that errors is released quietly. The viewer's Play then
  /// starts the clip with the usual error handling.
  void _autoplayErrored() {
    final controller = _controller;
    if (controller == null || !_autoMuted) return;
    if (!controller.value.hasError) return;
    // The controller notifies from inside its own update; release afterwards.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_controller, controller)) return;
      setState(_releaseController);
    });
    WidgetsBinding.instance.scheduleFrame();
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
      // frame yet. The still is the post's poster when it has one, and the
      // neutral stage otherwise, labelled as an unavailable preview.
      child: _CommunityVideoStill(
        posterUrl: _failed ? null : _posterDisplayUrl(),
        showUnavailable: !_failed && !_initializing,
        unavailableLabel: l10n.communityMediaVideoPreviewUnavailable,
        child: content,
      ),
    );
  }

  /// The poster's display URL, or null when the post has none or it cannot be
  /// resolved safely. Null means the unavailable preview, never a broken frame.
  String? _posterDisplayUrl() {
    final reference = communityMediaPosterReference(widget.url);
    if (reference == null) return null;
    return MediaUrlResolver.resolveDisplayUrl(reference);
  }
}

/// The still behind a video that has not started: the poster at its own shape
/// (contain, so nothing is cropped), or the neutral stage with a label when
/// there is no poster or it failed to load. The [child] is the play, busy or
/// retry control, centred over it.
class _CommunityVideoStill extends StatefulWidget {
  const _CommunityVideoStill({
    required this.posterUrl,
    required this.showUnavailable,
    required this.unavailableLabel,
    required this.child,
  });

  final String? posterUrl;
  final bool showUnavailable;
  final String unavailableLabel;
  final Widget child;

  @override
  State<_CommunityVideoStill> createState() => _CommunityVideoStillState();
}

class _CommunityVideoStillState extends State<_CommunityVideoStill> {
  bool _posterFailed = false;

  @override
  void didUpdateWidget(covariant _CommunityVideoStill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.posterUrl != widget.posterUrl) _posterFailed = false;
  }

  void _markPosterFailed() {
    // Image error builders run during build; state changes wait for the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_posterFailed) setState(() => _posterFailed = true);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final posterUrl = _posterFailed ? null : widget.posterUrl;
    final unavailable =
        widget.showUnavailable && (posterUrl == null || _posterFailed);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (posterUrl != null)
            Image.network(
              posterUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                _markPosterFailed();
                return const SizedBox.shrink();
              },
            ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.child,
                if (unavailable) ...[
                  const SizedBox(height: KubusSpacing.xs),
                  Text(
                    widget.unavailableLabel,
                    textAlign: TextAlign.center,
                    style: KubusTypography.textTheme.bodySmall!.copyWith(
                      color: roles.foregroundMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
