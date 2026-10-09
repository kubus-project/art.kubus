import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../inline_loading.dart';

/// `m:ss`, or `h:mm:ss` from one hour up. Negative values read as zero.
String formatCommunityVideoTime(Duration value) {
  final total = value.isNegative ? 0 : value.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}

/// Sound state of one Community video, shared between the feed player and its
/// expanded view so toggling in one is reflected in the other.
///
/// Players start muted. Dragging the volume to zero mutes; unmuting after that
/// restores full volume instead of staying silent.
class CommunityVideoAudio extends ChangeNotifier {
  double _volume = 1;
  bool _muted = true;

  double get volume => _volume;
  bool get muted => _muted;

  /// What the controller should be set to.
  double get effectiveVolume => _muted ? 0 : _volume;

  void toggleMute() {
    _muted = !_muted;
    if (!_muted && _volume <= 0) _volume = 1;
    notifyListeners();
  }

  void setVolume(double value) {
    final next = value.clamp(0.0, 1.0);
    _volume = next;
    _muted = next <= 0;
    notifyListeners();
  }
}

/// The playable face of a Community video once its controller is ready: the
/// frame, the centred play / replay / loading / error state, and a control
/// strip with a real timeline.
///
/// It owns presentation only. Playback commands go back through callbacks so
/// the owning slide keeps the single-active-player rule and the controller
/// lifecycle.
class CommunityVideoPlayerSurface extends StatefulWidget {
  const CommunityVideoPlayerSurface({
    super.key,
    required this.controller,
    required this.audio,
    required this.onTogglePlayback,
    required this.onReplay,
    required this.onRetry,
    this.onToggleFullscreen,
    this.isFullscreen = false,
    this.showVideo = true,
    this.autofocus = false,
  });

  final VideoPlayerController controller;
  final CommunityVideoAudio audio;
  final VoidCallback onTogglePlayback;
  final VoidCallback onReplay;
  final VoidCallback onRetry;
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;

  /// False while the same controller is shown in the expanded view, so the
  /// platform view is never mounted twice.
  final bool showVideo;
  final bool autofocus;

  @override
  State<CommunityVideoPlayerSurface> createState() =>
      _CommunityVideoPlayerSurfaceState();
}

class _CommunityVideoPlayerSurfaceState
    extends State<CommunityVideoPlayerSurface> {
  static const Duration _revealFor = Duration(seconds: 3);

  final FocusNode _surfaceFocus = FocusNode(debugLabel: 'community-video');
  final ValueNotifier<Duration?> _scrubPosition =
      ValueNotifier<Duration?>(null);
  Timer? _hideTimer;
  bool _hovering = false;
  bool _hasMouse = false;
  bool _focusWithin = false;
  bool _scrubbing = false;
  bool _revealed = false;
  bool _stripVisible = true;

  @override
  void dispose() {
    _hideTimer?.cancel();
    _scrubPosition.dispose();
    _surfaceFocus.dispose();
    super.dispose();
  }

  void _reveal() {
    _hideTimer?.cancel();
    if (!_revealed) setState(() => _revealed = true);
    _hideTimer = Timer(_revealFor, () {
      if (mounted) setState(() => _revealed = false);
    });
  }

  void _handleTapUp(TapUpDetails details) {
    _surfaceFocus.requestFocus();
    final value = widget.controller.value;
    final touch = details.kind == PointerDeviceKind.touch;
    if (touch && value.isPlaying && !_stripVisible) {
      // First touch on a playing clip only reveals the controls.
      _reveal();
      return;
    }
    _reveal();
    widget.onTogglePlayback();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if ((key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) &&
        node.hasPrimaryFocus) {
      _reveal();
      widget.onTogglePlayback();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      _reveal();
      widget.audio.toggleMute();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF && widget.onToggleFullscreen != null) {
      widget.onToggleFullscreen!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final controller = widget.controller;
    final fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 150);

    return Focus(
      focusNode: _surfaceFocus,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKey,
      onFocusChange: (focused) {
        if (_focusWithin != focused) setState(() => _focusWithin = focused);
      },
      child: MouseRegion(
        onEnter: (_) => setState(() {
          _hasMouse = true;
          _hovering = true;
        }),
        onExit: (_) => setState(() => _hovering = false),
        child: DecoratedBox(
          decoration: communityVideoStageDecoration(roles),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.showVideo)
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    if (!value.isInitialized) return const SizedBox.shrink();
                    return Center(
                      child: AspectRatio(
                        aspectRatio: value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                    );
                  },
                ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _handleTapUp,
                ),
              ),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final visible = !value.isPlaying ||
                      _hovering ||
                      _focusWithin ||
                      _scrubbing ||
                      _revealed;
                  _stripVisible = visible;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildCentre(context, value),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          ignoring: !visible,
                          child: AnimatedOpacity(
                            duration: fade,
                            opacity: visible ? 1 : 0,
                            child: _buildStrip(context),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCentre(BuildContext context, VideoPlayerValue value) {
    final l10n = AppLocalizations.of(context)!;
    if (value.hasError) {
      return Center(
        child: CommunityVideoErrorBlock(onRetry: widget.onRetry),
      );
    }
    if (!value.isInitialized) {
      return const Center(child: CommunityVideoBusyIndicator());
    }
    // While the handle is being dragged the clip is paused on purpose; a big
    // play control over the frame the viewer is searching for would be noise.
    if (_scrubbing) return const SizedBox.shrink();
    if (value.isCompleted && !value.isPlaying) {
      return Center(
        child: CommunityVideoLargeButton(
          icon: Icons.replay_rounded,
          tooltip: l10n.communityMediaVideoReplay,
          onPressed: () {
            _reveal();
            widget.onReplay();
          },
        ),
      );
    }
    if (value.isBuffering && value.isPlaying) {
      return Center(
        child: Semantics(
          container: true,
          liveRegion: true,
          label: l10n.communityMediaVideoBuffering,
          child: const IgnorePointer(child: CommunityVideoBusyIndicator()),
        ),
      );
    }
    if (!value.isPlaying) {
      return Center(
        child: CommunityVideoLargeButton(
          icon: Icons.play_arrow_rounded,
          tooltip: l10n.communityMediaVideoPlay,
          onPressed: () {
            _reveal();
            widget.onTogglePlayback();
          },
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildStrip(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: roles.surfaceOverlay,
        border: Border(
          top: BorderSide(color: roles.rule, width: KubusSizes.hairline),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 480;
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.sm,
              vertical: KubusSpacing.xxs,
            ),
            child: wide ? _wideRow(context) : _narrowColumn(context),
          );
        },
      ),
    );
  }

  Widget _timeline() => CommunityVideoTimeline(
        controller: widget.controller,
        scrubPosition: _scrubPosition,
        onScrubbingChanged: (scrubbing) {
          if (_scrubbing == scrubbing) return;
          setState(() => _scrubbing = scrubbing);
          if (!scrubbing) _reveal();
        },
        onResume: widget.onTogglePlayback,
      );

  Widget _playPause(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final playing = value.isPlaying;
        return CommunityVideoControlButton(
          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: playing
              ? l10n.communityMediaVideoPause
              : l10n.communityMediaVideoPlay,
          onPressed: () {
            _reveal();
            widget.onTogglePlayback();
          },
        );
      },
    );
  }

  Widget _fullscreenButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final toggle = widget.onToggleFullscreen;
    if (toggle == null) return const SizedBox.shrink();
    return CommunityVideoControlButton(
      icon: widget.isFullscreen
          ? Icons.fullscreen_exit_rounded
          : Icons.fullscreen_rounded,
      tooltip: widget.isFullscreen
          ? l10n.communityMediaVideoExitFullscreen
          : l10n.communityMediaVideoFullscreen,
      onPressed: toggle,
    );
  }

  Widget _timeLabel() => CommunityVideoTimeLabel(
        controller: widget.controller,
        scrubPosition: _scrubPosition,
      );

  Widget _wideRow(BuildContext context) {
    return Row(
      children: [
        _playPause(context),
        const SizedBox(width: KubusSpacing.xs),
        _timeLabel(),
        const SizedBox(width: KubusSpacing.sm),
        Expanded(child: _timeline()),
        const SizedBox(width: KubusSpacing.sm),
        CommunityVideoVolumeControl(
          audio: widget.audio,
          showSlider: _hasMouse,
        ),
        _fullscreenButton(context),
      ],
    );
  }

  Widget _narrowColumn(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _timeline(),
        Row(
          children: [
            _playPause(context),
            const SizedBox(width: KubusSpacing.xs),
            // Large text or an hour-long clip shrinks the label rather than
            // pushing the buttons off the strip.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _timeLabel(),
                ),
              ),
            ),
            CommunityVideoVolumeControl(
              audio: widget.audio,
              showSlider: false,
            ),
            _fullscreenButton(context),
          ],
        ),
      ],
    );
  }
}

/// The media stage: the page ground, so a clip that has not loaded still reads
/// as a stage inside its card, with the structural hairline around it.
BoxDecoration communityVideoStageDecoration(KubusColorRoles roles) =>
    BoxDecoration(
      color: roles.ground,
      border: Border.all(color: roles.rule, width: KubusSizes.hairline),
    );

/// Loading and buffering mark, on the overlay surface so it reads over any
/// frame, light or dark.
class CommunityVideoBusyIndicator extends StatelessWidget {
  const CommunityVideoBusyIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: roles.surfaceOverlay,
        borderRadius: BorderRadius.circular(KubusRadius.sm),
        border: Border.all(color: roles.ruleStrong, width: KubusSizes.hairline),
      ),
      child: const SizedBox(
        width: KubusSizes.mediaPlayLarge,
        height: KubusSizes.mediaPlayLarge,
        child: Padding(
          padding: EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
          child: InlineLoading(
            expand: true,
            shape: BoxShape.circle,
            tileSize: 4,
          ),
        ),
      ),
    );
  }
}

/// Elapsed time and total duration, in the structural register.
class CommunityVideoTimeLabel extends StatelessWidget {
  const CommunityVideoTimeLabel({
    super.key,
    required this.controller,
    required this.scrubPosition,
  });

  final VideoPlayerController controller;
  final ValueNotifier<Duration?> scrubPosition;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<Duration?>(
      valueListenable: scrubPosition,
      builder: (context, scrub, _) {
        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final known = value.isInitialized && value.duration > Duration.zero;
            final position = formatCommunityVideoTime(scrub ?? value.position);
            final duration =
                known ? formatCommunityVideoTime(value.duration) : '--:--';
            return Semantics(
              container: true,
              label: l10n.communityMediaVideoTime(position, duration),
              excludeSemantics: true,
              child: Text(
                '$position / $duration',
                maxLines: 1,
                softWrap: false,
                style: KubusTypography.machine(
                  fontSize: 12,
                  color: roles.foreground,
                ).copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures()
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// A seekable timeline bound to the real controller: tap or drag to seek,
/// arrow keys to step, buffered range painted behind the played range.
class CommunityVideoTimeline extends StatefulWidget {
  const CommunityVideoTimeline({
    super.key,
    required this.controller,
    required this.scrubPosition,
    required this.onScrubbingChanged,
    required this.onResume,
  });

  final VideoPlayerController controller;

  /// Position under the handle while dragging, for the time label.
  final ValueNotifier<Duration?> scrubPosition;
  final ValueChanged<bool> onScrubbingChanged;

  /// Resumes playback through the owner, which keeps the single-player rule.
  final VoidCallback onResume;

  @override
  State<CommunityVideoTimeline> createState() => _CommunityVideoTimelineState();
}

class _CommunityVideoTimelineState extends State<CommunityVideoTimeline> {
  static const Duration _step = Duration(seconds: 5);
  static const Duration _largeStep = Duration(seconds: 10);
  static const Duration _liveSeekEvery = Duration(milliseconds: 120);

  bool _wasPlaying = false;
  DateTime _lastLiveSeek = DateTime.fromMillisecondsSinceEpoch(0);

  Duration _at(double fraction) {
    final total = widget.controller.value.duration;
    return Duration(
      microseconds: (total.inMicroseconds * fraction.clamp(0.0, 1.0)).round(),
    );
  }

  void _seek(Duration to) {
    final total = widget.controller.value.duration;
    final clamped = Duration(
      microseconds: to.inMicroseconds.clamp(0, total.inMicroseconds),
    );
    unawaited(widget.controller.seekTo(clamped));
  }

  void _scrubStart() {
    final value = widget.controller.value;
    _wasPlaying = value.isPlaying;
    if (_wasPlaying) unawaited(widget.controller.pause());
    widget.onScrubbingChanged(true);
  }

  void _scrub(double fraction) {
    final target = _at(fraction);
    widget.scrubPosition.value = target;
    final now = DateTime.now();
    if (now.difference(_lastLiveSeek) >= _liveSeekEvery) {
      _lastLiveSeek = now;
      _seek(target);
    }
  }

  void _scrubEnd(double fraction) {
    _seek(_at(fraction));
    widget.scrubPosition.value = null;
    widget.onScrubbingChanged(false);
    if (_wasPlaying) widget.onResume();
    _wasPlaying = false;
  }

  void _nudge(int direction, bool large) {
    final value = widget.controller.value;
    final delta = large ? _largeStep : _step;
    _seek(value.position + (direction < 0 ? -delta : delta));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final total = value.duration.inMicroseconds;
        final enabled = value.isInitialized && total > 0 && !value.hasError;
        final played = enabled
            ? (value.position.inMicroseconds / total).clamp(0.0, 1.0)
            : 0.0;
        var buffered = 0.0;
        if (enabled) {
          for (final range in value.buffered) {
            buffered = math.max(buffered, range.end.inMicroseconds / total);
          }
        }
        final position = formatCommunityVideoTime(value.position);
        final duration =
            enabled ? formatCommunityVideoTime(value.duration) : '--:--';
        return CommunityMediaSlider(
          value: played.toDouble(),
          buffered: buffered.clamp(0.0, 1.0).toDouble(),
          enabled: enabled,
          semanticLabel: l10n.communityMediaVideoSeek,
          semanticValue: l10n.communityMediaVideoTime(position, duration),
          semanticIncreased: l10n.communityMediaVideoTime(
            formatCommunityVideoTime(value.position + _step),
            duration,
          ),
          semanticDecreased: l10n.communityMediaVideoTime(
            formatCommunityVideoTime(value.position - _step),
            duration,
          ),
          onSeek: (fraction) => _seek(_at(fraction)),
          onScrubStart: _scrubStart,
          onScrub: _scrub,
          onScrubEnd: _scrubEnd,
          onNudge: _nudge,
        );
      },
    );
  }
}

/// Horizontal track with a handle, used for the video timeline and the volume.
///
/// Tap seeks, drag scrubs, and the arrow, page and home/end keys step it. The
/// drag recognizer sits below the carousel's, so scrubbing never swipes the
/// post to another slide.
class CommunityMediaSlider extends StatefulWidget {
  const CommunityMediaSlider({
    super.key,
    required this.value,
    required this.enabled,
    required this.semanticLabel,
    required this.semanticValue,
    required this.semanticIncreased,
    required this.semanticDecreased,
    required this.onSeek,
    this.buffered = 0,
    this.onScrubStart,
    this.onScrub,
    this.onScrubEnd,
    this.onNudge,
  });

  /// 0..1 position of the handle.
  final double value;

  /// 0..1 end of the loaded range, painted behind [value].
  final double buffered;
  final bool enabled;
  final String semanticLabel;
  final String semanticValue;

  /// What [semanticValue] becomes after one step either way. A slider that
  /// announces `increase` / `decrease` needs both, or none.
  final String semanticIncreased;
  final String semanticDecreased;

  /// Tap, Home and End.
  final ValueChanged<double> onSeek;
  final VoidCallback? onScrubStart;
  final ValueChanged<double>? onScrub;
  final ValueChanged<double>? onScrubEnd;

  /// Arrow and page keys, and the screen reader increase / decrease actions.
  final void Function(int direction, bool large)? onNudge;

  @override
  State<CommunityMediaSlider> createState() => _CommunityMediaSliderState();
}

class _CommunityMediaSliderState extends State<CommunityMediaSlider> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'community-media-slider');
  bool _hovering = false;
  bool _focused = false;
  bool _dragging = false;
  double _dragFraction = 0;
  double _width = 0;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  double _fractionAt(double dx) {
    final inset = KubusSizes.mediaTimelineHandle / 2;
    final span = math.max(1.0, _width - inset * 2);
    return ((dx - inset) / span).clamp(0.0, 1.0);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final nudge = widget.onNudge;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      nudge?.call(-1, HardwareKeyboard.instance.isShiftPressed);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      nudge?.call(1, HardwareKeyboard.instance.isShiftPressed);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      nudge?.call(-1, true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      nudge?.call(1, true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      widget.onSeek(0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      widget.onSeek(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final enabled = widget.enabled;
    final keyboardFocus = _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final shown = _dragging ? _dragFraction : widget.value;

    return Semantics(
      container: true,
      slider: true,
      enabled: enabled,
      label: widget.semanticLabel,
      value: widget.semanticValue,
      increasedValue: widget.semanticIncreased,
      decreasedValue: widget.semanticDecreased,
      onIncrease: enabled ? () => widget.onNudge?.call(1, false) : null,
      onDecrease: enabled ? () => widget.onNudge?.call(-1, false) : null,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: enabled,
        onKeyEvent: _handleKey,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: enabled
                    ? (details) {
                        _focusNode.requestFocus();
                        widget.onSeek(_fractionAt(details.localPosition.dx));
                      }
                    : null,
                onHorizontalDragStart: enabled
                    ? (details) {
                        _focusNode.requestFocus();
                        setState(() {
                          _dragging = true;
                          _dragFraction = _fractionAt(details.localPosition.dx);
                        });
                        widget.onScrubStart?.call();
                        widget.onScrub?.call(_dragFraction);
                      }
                    : null,
                onHorizontalDragUpdate: enabled
                    ? (details) {
                        setState(() {
                          _dragFraction = _fractionAt(details.localPosition.dx);
                        });
                        widget.onScrub?.call(_dragFraction);
                      }
                    : null,
                onHorizontalDragEnd: enabled ? (_) => _finishDrag() : null,
                onHorizontalDragCancel: enabled ? _finishDrag : null,
                child: SizedBox(
                  height: KubusSizes.mediaTimelineHitHeight,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _SliderPainter(
                      value: shown,
                      buffered: widget.buffered,
                      enabled: enabled,
                      emphasised: _hovering || _dragging || keyboardFocus,
                      focusRing: keyboardFocus,
                      trackColor: roles.rule,
                      bufferedColor: roles.ruleStrong,
                      playedColor: enabled ? roles.active : roles.ruleStrong,
                      handleRing: roles.surfaceOverlay,
                      focusColor: roles.focus,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _finishDrag() {
    if (!_dragging) return;
    final fraction = _dragFraction;
    setState(() => _dragging = false);
    widget.onScrubEnd?.call(fraction);
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.value,
    required this.buffered,
    required this.enabled,
    required this.emphasised,
    required this.focusRing,
    required this.trackColor,
    required this.bufferedColor,
    required this.playedColor,
    required this.handleRing,
    required this.focusColor,
  });

  final double value;
  final double buffered;
  final bool enabled;
  final bool emphasised;
  final bool focusRing;
  final Color trackColor;
  final Color bufferedColor;
  final Color playedColor;
  final Color handleRing;
  final Color focusColor;

  @override
  void paint(Canvas canvas, Size size) {
    final handle = KubusSizes.mediaTimelineHandle;
    final inset = handle / 2;
    final thickness = emphasised
        ? KubusSizes.mediaTimelineTrackActive
        : KubusSizes.mediaTimelineTrack;
    final cy = size.height / 2;
    final left = inset;
    final span = math.max(1.0, size.width - inset * 2);
    final radius = Radius.circular(KubusRadius.xs / 2);

    RRect bar(double from, double to) => RRect.fromLTRBR(
          left + from * span,
          cy - thickness / 2,
          left + to * span,
          cy + thickness / 2,
          radius,
        );

    if (focusRing) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          left - 4,
          cy - handle / 2 - 4,
          left + span + 4,
          cy + handle / 2 + 4,
          Radius.circular(KubusRadius.control),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = focusColor,
      );
    }
    canvas.drawRRect(bar(0, 1), Paint()..color = trackColor);
    if (buffered > 0) {
      canvas.drawRRect(bar(0, buffered), Paint()..color = bufferedColor);
    }
    final played = value.clamp(0.0, 1.0);
    if (played > 0) {
      canvas.drawRRect(bar(0, played), Paint()..color = playedColor);
    }
    if (enabled) {
      final centre = Offset(left + played * span, cy);
      final r = emphasised ? handle / 2 : handle / 2 - 1;
      canvas.drawCircle(centre, r + 2, Paint()..color = handleRing);
      canvas.drawCircle(centre, r, Paint()..color = playedColor);
    }
  }

  @override
  bool shouldRepaint(covariant _SliderPainter old) =>
      old.value != value ||
      old.buffered != buffered ||
      old.enabled != enabled ||
      old.emphasised != emphasised ||
      old.focusRing != focusRing ||
      old.trackColor != trackColor ||
      old.bufferedColor != bufferedColor ||
      old.playedColor != playedColor ||
      old.handleRing != handleRing ||
      old.focusColor != focusColor;
}

/// Mute toggle, plus a volume track when a pointer is present.
class CommunityVideoVolumeControl extends StatelessWidget {
  const CommunityVideoVolumeControl({
    super.key,
    required this.audio,
    required this.showSlider,
  });

  final CommunityVideoAudio audio;
  final bool showSlider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final muted = audio.muted;
        final percent = (audio.effectiveVolume * 100).round();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CommunityVideoControlButton(
              icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              tooltip: muted
                  ? l10n.communityMediaVideoUnmute
                  : l10n.communityMediaVideoMute,
              onPressed: audio.toggleMute,
            ),
            if (showSlider)
              SizedBox(
                width: KubusSizes.mediaVolumeTrackWidth,
                child: CommunityMediaSlider(
                  value: audio.effectiveVolume,
                  enabled: true,
                  semanticLabel: l10n.communityMediaVideoVolume,
                  semanticValue: '$percent%',
                  semanticIncreased: '${math.min(100, percent + 5)}%',
                  semanticDecreased: '${math.max(0, percent - 5)}%',
                  onSeek: audio.setVolume,
                  onScrub: audio.setVolume,
                  onScrubEnd: audio.setVolume,
                  onNudge: (direction, large) => audio.setVolume(
                    audio.effectiveVolume + direction * (large ? 0.2 : 0.05),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Compact icon control on the player strip.
class CommunityVideoControlButton extends StatelessWidget {
  const CommunityVideoControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Tooltip(
      message: tooltip,
      // The icon carries the accessible name; the tooltip would repeat it.
      excludeFromSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: KubusSizes.mediaControlIcon,
          semanticLabel: tooltip,
        ),
        style: IconButton.styleFrom(
          foregroundColor: roles.foreground,
          disabledForegroundColor: roles.foregroundSubtle,
          hoverColor: roles.foreground.withValues(alpha: 0.08),
          highlightColor: roles.foreground.withValues(alpha: 0.14),
          focusColor: roles.foreground.withValues(alpha: 0.08),
          fixedSize: const Size.square(KubusSizes.mediaControlTarget),
          minimumSize: const Size.square(KubusSizes.mediaControlTarget),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KubusRadius.control),
          ),
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: roles.focus, width: 2)
                : null,
          ),
        ),
      ),
    );
  }
}

/// The large initial play and replay control.
class CommunityVideoLargeButton extends StatelessWidget {
  const CommunityVideoLargeButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: KubusSizes.mediaPlayLargeIcon,
          semanticLabel: tooltip,
        ),
        style: IconButton.styleFrom(
          foregroundColor: roles.active,
          backgroundColor: roles.surfaceOverlay,
          hoverColor: roles.active.withValues(alpha: 0.12),
          highlightColor: roles.active.withValues(alpha: 0.2),
          focusColor: roles.active.withValues(alpha: 0.12),
          fixedSize: const Size.square(KubusSizes.mediaPlayLarge),
          minimumSize: const Size.square(KubusSizes.mediaPlayLarge),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KubusRadius.sm),
            side: BorderSide(color: roles.ruleStrong),
          ),
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? roles.focus
                  : roles.ruleStrong,
              width: states.contains(WidgetState.focused) ? 2 : 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when a clip cannot be loaded or fails mid-playback.
class CommunityVideoErrorBlock extends StatelessWidget {
  const CommunityVideoErrorBlock({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(KubusSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_outlined, color: roles.error, size: 32),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            l10n.communityMediaVideoUnavailable,
            textAlign: TextAlign.center,
            style: KubusTypography.textTheme.bodySmall!.copyWith(
              color: roles.foregroundMuted,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.communityMediaVideoRetry),
            style: TextButton.styleFrom(
              foregroundColor: roles.active,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KubusRadius.control),
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? BorderSide(color: roles.focus, width: 2)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
