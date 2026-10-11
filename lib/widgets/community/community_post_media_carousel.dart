import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../community/community_post_media.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/media_url_resolver.dart';
import '../inline_loading.dart';
import 'community_post_video_slide.dart';

/// Shared stage proportion for feed and detail carousels. Every page uses the
/// same stage, so changing slides never moves the feed.
const double kCommunityMediaStageAspect = 4 / 3;

/// Quoted posts show one compact preview at this proportion.
const double kCommunityMediaCompactAspect = 16 / 9;

/// An image whose shape is within this factor of the stage fills it (cover).
/// Anything further from the stage shape is fitted whole (contain), so tall
/// portraits and wide panoramas are not cropped away.
const double _coverTolerance = 1.25;

/// The ordered media of one Community post, shown as a swipeable carousel.
///
/// One item renders as a plain stage with no page indicators. Several items
/// add swipe, a `1 / N` counter, dots, hover arrows on pointer devices and
/// left/right keys when focused. Compact mode shows the first item with a
/// `+N` badge, for quoted posts.
class CommunityPostMediaCarousel extends StatefulWidget {
  const CommunityPostMediaCarousel({
    super.key,
    required this.mediaUrls,
    this.onOpenMedia,
    this.compact = false,
  });

  final List<String> mediaUrls;

  /// Called when an image is tapped. Video taps control playback instead.
  final VoidCallback? onOpenMedia;

  final bool compact;

  @override
  State<CommunityPostMediaCarousel> createState() =>
      _CommunityPostMediaCarouselState();
}

class _CommunityPostMediaCarouselState
    extends State<CommunityPostMediaCarousel> {
  final PageController _pages = PageController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'community-media');
  final Map<int, _NaturalSizeProbe> _probes = <int, _NaturalSizeProbe>{};
  final Map<int, double> _naturalAspects = <int, double>{};
  int _index = 0;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _probeImages();
  }

  @override
  void didUpdateWidget(covariant CommunityPostMediaCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameMedia(oldWidget.mediaUrls, widget.mediaUrls)) {
      _disposeProbes();
      _naturalAspects.clear();
      _index = math.min(_index, math.max(0, widget.mediaUrls.length - 1));
      _probeImages();
    }
  }

  @override
  void dispose() {
    _disposeProbes();
    _pages.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _sameMedia(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _probeImages() {
    for (var i = 0; i < widget.mediaUrls.length; i++) {
      final index = i;
      final url = widget.mediaUrls[index];
      if (communityMediaUrlIsVideo(url)) continue;
      final resolved = MediaUrlResolver.resolveDisplayUrl(url) ?? url;
      _probes[index] = _NaturalSizeProbe(
        NetworkImage(resolved),
        onSize: (aspect) {
          if (!mounted) return;
          setState(() => _naturalAspects[index] = aspect);
        },
      );
    }
  }

  void _disposeProbes() {
    for (final probe in _probes.values) {
      probe.dispose();
    }
    _probes.clear();
  }

  BoxFit _fitFor(int index) {
    final aspect = _naturalAspects[index];
    if (aspect == null) return BoxFit.contain;
    final ratio = aspect / kCommunityMediaStageAspect;
    final near = ratio <= _coverTolerance && ratio >= 1 / _coverTolerance;
    return near ? BoxFit.cover : BoxFit.contain;
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.mediaUrls.length) return;
    // Keep arrow-key navigation available after using an arrow control.
    _focusNode.requestFocus();
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goTo(_index - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _goTo(_index + 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaUrls.isEmpty) return const SizedBox.shrink();
    if (widget.compact) return _buildCompact(context);
    return _buildCarousel(context);
  }

  Widget _buildCompact(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final extra = widget.mediaUrls.length - 1;
    final first = widget.mediaUrls.first;
    return AspectRatio(
      aspectRatio: kCommunityMediaCompactAspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KubusRadius.md),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onOpenMedia,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // A quoted preview shows a video's poster but never autoplays.
              _buildSlide(0, first,
                  fit: BoxFit.cover,
                  onTap: widget.onOpenMedia,
                  autoplay: false),
              if (extra > 0)
                Positioned(
                  right: KubusSpacing.sm,
                  bottom: KubusSpacing.sm,
                  child: Semantics(
                    label: l10n.communityMediaCarouselPosition(1, extra + 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KubusSpacing.sm,
                        vertical: KubusSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(KubusRadius.pill),
                      ),
                      child: Text(
                        '+$extra',
                        style: KubusTypography.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarousel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final count = widget.mediaUrls.length;
    final multiple = count > 1;

    final stage = AspectRatio(
      aspectRatio: kCommunityMediaStageAspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KubusRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Focus(
              focusNode: _focusNode,
              onKeyEvent: _handleKey,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: const <PointerDeviceKind>{
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: PageView.builder(
                  controller: _pages,
                  itemCount: count,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) {
                    final url = widget.mediaUrls[index];
                    return Semantics(
                      label: l10n.communityMediaCarouselPosition(
                        index + 1,
                        count,
                      ),
                      child: _buildSlide(
                        index,
                        url,
                        fit: _fitFor(index),
                        onTap: widget.onOpenMedia,
                        isActive: index == _index,
                      ),
                    );
                  },
                ),
              ),
            ),
            if (multiple)
              Positioned(
                top: KubusSpacing.sm,
                right: KubusSpacing.sm,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KubusSpacing.sm,
                      vertical: KubusSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(KubusRadius.pill),
                    ),
                    child: Text(
                      '${_index + 1} / $count',
                      style: KubusTypography.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            if (multiple)
              Positioned(
                left: KubusSpacing.xs,
                top: 0,
                bottom: 0,
                child: _ArrowButton(
                  visible: _hovering && _index > 0,
                  icon: Icons.chevron_left,
                  tooltip: l10n.communityMediaPrevious,
                  onPressed: () => _goTo(_index - 1),
                ),
              ),
            if (multiple)
              Positioned(
                right: KubusSpacing.xs,
                top: 0,
                bottom: 0,
                child: _ArrowButton(
                  visible: _hovering && _index < count - 1,
                  icon: Icons.chevron_right,
                  tooltip: l10n.communityMediaNext,
                  onPressed: () => _goTo(_index + 1),
                ),
              ),
          ],
        ),
      ),
    );

    final stageWithHover = MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: stage,
    );

    if (!multiple) return stageWithHover;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        stageWithHover,
        const SizedBox(height: KubusSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.xxs,
                ),
                width: i == _index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _index
                      ? scheme.onSurface
                      : scheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(KubusRadius.pill),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlide(
    int index,
    String url, {
    required BoxFit fit,
    VoidCallback? onTap,
    bool isActive = true,
    bool autoplay = true,
  }) {
    if (communityMediaUrlIsVideo(url)) {
      return CommunityPostVideoSlide(
        key: ValueKey<String>('video-$url'),
        url: url,
        isActive: isActive,
        autoplay: autoplay,
      );
    }
    return _CommunityMediaImageSlide(
      url: url,
      fit: fit,
      onTap: onTap,
    );
  }
}

class _CommunityMediaImageSlide extends StatelessWidget {
  const _CommunityMediaImageSlide({
    required this.url,
    required this.fit,
    this.onTap,
  });

  final String url;
  final BoxFit fit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final resolved = MediaUrlResolver.resolveDisplayUrl(url) ?? url;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Image.network(
          resolved,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: InlineLoading(
                  expand: true,
                  shape: BoxShape.circle,
                  tileSize: 4,
                  progress: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Center(
            child: Tooltip(
              message: l10n.communityMediaImageUnavailable,
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 40,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.visible,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final bool visible;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: Material(
            color: scheme.surface.withValues(alpha: 0.9),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              tooltip: tooltip,
              onPressed: onPressed,
              icon: Icon(icon, color: scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolves an image's natural size once, through the same provider the stage
/// uses, so the bitmap is not downloaded twice.
class _NaturalSizeProbe {
  _NaturalSizeProbe(ImageProvider provider, {required this.onSize}) {
    _stream = provider.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener(
      (info, _) {
        final height = info.image.height;
        if (height > 0) {
          onSize(info.image.width / height);
        }
        _detach();
      },
      onError: (_, __) => _detach(),
    );
    _stream.addListener(_listener);
  }

  final void Function(double aspect) onSize;
  late final ImageStream _stream;
  late final ImageStreamListener _listener;
  bool _attached = true;

  void _detach() {
    if (!_attached) return;
    _attached = false;
    _stream.removeListener(_listener);
  }

  void dispose() => _detach();
}
