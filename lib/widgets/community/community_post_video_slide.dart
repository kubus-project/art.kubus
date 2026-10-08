import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/media_url_resolver.dart';
import '../inline_loading.dart';

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
/// does not download every clip. It starts muted, and it is released as soon as
/// its page is no longer the active one.
class CommunityPostVideoSlide extends StatefulWidget {
  const CommunityPostVideoSlide({
    super.key,
    required this.url,
    required this.isActive,
  });

  final String url;
  final bool isActive;

  @override
  State<CommunityPostVideoSlide> createState() =>
      _CommunityPostVideoSlideState();
}

class _CommunityPostVideoSlideState extends State<CommunityPostVideoSlide> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _failed = false;
  bool _muted = true;

  @override
  void didUpdateWidget(covariant CommunityPostVideoSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive && _controller != null) {
      setState(_releaseController);
    }
  }

  @override
  void dispose() {
    _releaseController();
    super.dispose();
  }

  void _releaseController() {
    final controller = _controller;
    _controller = null;
    CommunityVideoPlaybackCoordinator.release(controller);
    unawaited(controller?.dispose());
  }

  Future<void> _handleTap() async {
    final controller = _controller;
    if (controller != null) {
      await _togglePlayback(controller);
      return;
    }
    if (_initializing) return;
    await _startPlayback();
  }

  Future<void> _startPlayback() async {
    setState(() {
      _initializing = true;
      _failed = false;
    });
    final url = MediaUrlResolver.resolveDisplayUrl(widget.url) ?? widget.url;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _failed = true;
      });
      return;
    }
    if (!mounted || !widget.isActive) {
      await controller.dispose();
      if (mounted) setState(() => _initializing = false);
      return;
    }
    CommunityVideoPlaybackCoordinator.claim(controller);
    setState(() {
      _controller = controller;
      _initializing = false;
    });
    await controller.play();
  }

  Future<void> _togglePlayback(VideoPlayerController controller) async {
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      CommunityVideoPlaybackCoordinator.claim(controller);
      await controller.play();
    }
  }

  Future<void> _toggleMute(VideoPlayerController controller) async {
    setState(() => _muted = !_muted);
    await controller.setVolume(_muted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final controller = _controller;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            if (controller == null)
              Center(child: _buildPlaceholder(l10n, scheme)),
            if (controller != null)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  if (value.isPlaying) return const SizedBox.shrink();
                  return Center(
                    child: _VideoRoundButton(
                      icon: Icons.play_arrow_rounded,
                      tooltip: l10n.communityMediaVideoPlay,
                      onPressed: () => _togglePlayback(controller),
                    ),
                  );
                },
              ),
            if (controller != null)
              Positioned(
                right: KubusSpacing.sm,
                bottom: KubusSpacing.sm,
                child: _VideoRoundButton(
                  icon: _muted ? Icons.volume_off_outlined : Icons.volume_up,
                  tooltip: _muted
                      ? l10n.communityMediaVideoUnmute
                      : l10n.communityMediaVideoMute,
                  onPressed: () => _toggleMute(controller),
                  size: 32,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(AppLocalizations l10n, ColorScheme scheme) {
    if (_failed) {
      return Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined,
                color: scheme.onSurfaceVariant, size: 32),
            const SizedBox(height: KubusSpacing.xs),
            Text(
              l10n.communityMediaVideoUnavailable,
              textAlign: TextAlign.center,
              style: KubusTypography.inter(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    if (_initializing) {
      return SizedBox(
        width: 36,
        height: 36,
        child: InlineLoading(expand: true, shape: BoxShape.circle, tileSize: 4),
      );
    }
    return _VideoRoundButton(
      icon: Icons.play_arrow_rounded,
      tooltip: l10n.communityMediaVideoPlay,
      onPressed: _handleTap,
      size: 48,
    );
  }
}

class _VideoRoundButton extends StatelessWidget {
  const _VideoRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 40,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surface.withValues(alpha: 0.85),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.55, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
