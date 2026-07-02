import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';
import 'disk_cached_artwork_image.dart';

class ArtworkGalleryView extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final String? semanticLabel;

  const ArtworkGalleryView({
    super.key,
    required this.imageUrls,
    this.height = 260,
    this.semanticLabel,
  });

  @override
  State<ArtworkGalleryView> createState() => _ArtworkGalleryViewState();
}

class _ArtworkGalleryViewState extends State<ArtworkGalleryView>
    with AutomaticKeepAliveClientMixin {
  late final PageController _pageController;
  int _index = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchAround(_index);
    });
  }

  @override
  void didUpdateWidget(ArtworkGalleryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clamp the selected index when the image list changes (e.g. async load).
    final urls = widget.imageUrls
        .where((u) => u.trim().isNotEmpty)
        .toList(growable: false);
    if (urls.isNotEmpty && _index >= urls.length) {
      _index = urls.length - 1;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _prefetchAround(int index) {
    final urls = widget.imageUrls
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) return;

    final candidates = <int>{
      index.clamp(0, urls.length - 1),
      (index - 1).clamp(0, urls.length - 1),
      (index + 1).clamp(0, urls.length - 1),
    };
    for (final i in candidates) {
      unawaited(prefetchDiskCachedArtworkImage(urls[i]).catchError((_) {}));
    }
  }

  void _selectImage(int index) {
    setState(() => _index = index);
    _prefetchAround(index);
  }

  String get _semanticSubject {
    final label = widget.semanticLabel?.trim();
    if (label == null || label.isEmpty) return 'Artwork image';
    return label;
  }

  String _imageSemanticLabel(int index, int total) {
    final clampedTotal = total < 1 ? 1 : total;
    final ordinal = (index + 1).clamp(1, clampedTotal);
    if (clampedTotal == 1) return _semanticSubject;
    return '$_semanticSubject $ordinal of $clampedTotal';
  }

  String _thumbnailSemanticLabel(int index, int total, bool selected) {
    final label = '${_imageSemanticLabel(index, total)} thumbnail';
    return selected ? '$label, selected' : label;
  }

  void _openLightbox(int initialIndex) {
    final urls = widget.imageUrls;
    if (urls.isEmpty) return;

    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      barrierColor: scheme.scrim.withValues(alpha: 0.92),
      builder: (context) => _ArtworkLightboxDialog(
        urls: urls,
        initialIndex: initialIndex,
        semanticLabel: _semanticSubject,
      ),
    );
  }

  Widget _imageFrame({
    required String url,
    required double height,
    required int index,
    required int total,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final label = _imageSemanticLabel(index, total);
    return Semantics(
      button: true,
      image: true,
      label: 'Open $label',
      onTap: onTap,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KubusRadius.lg),
          child: Material(
            color: scheme.surfaceContainerHighest,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: height,
                width: double.infinity,
                child: _DiskCachedArtworkImage(
                  url: url,
                  fit: BoxFit.cover,
                  showProgress: true,
                  errorIconColor: scheme.outline.withValues(alpha: 0.8),
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    final urls = widget.imageUrls
        .where((u) => u.trim().isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    final height = widget.height;

    if (!isWide && urls.length > 1) {
      return Column(
        children: [
          SizedBox(
            height: height,
            child: PageView.builder(
              controller: _pageController,
              itemCount: urls.length,
              onPageChanged: (idx) {
                _selectImage(idx);
              },
              itemBuilder: (context, idx) => _imageFrame(
                url: urls[idx],
                height: height,
                index: idx,
                total: urls.length,
                onTap: () => _openLightbox(idx),
              ),
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Semantics(
            label: '${_imageSemanticLabel(_index, urls.length)}, selected',
            liveRegion: true,
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  urls.length,
                  (idx) => Container(
                    width: KubusSpacing.sm,
                    height: KubusSpacing.sm,
                    margin: const EdgeInsets.symmetric(
                      horizontal: KubusSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: idx == _index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Desktop / wide layout: main image + thumbnail strip.
    final mainUrl = urls[_index.clamp(0, urls.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _imageFrame(
          url: mainUrl,
          height: height,
          index: _index,
          total: urls.length,
          onTap: () => _openLightbox(_index),
        ),
        if (urls.length > 1) ...[
          const SizedBox(height: KubusSpacing.sm),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: KubusSpacing.sm),
              itemBuilder: (context, idx) {
                final url = urls[idx];
                final selected = idx == _index;
                void select() => _selectImage(idx);
                return Semantics(
                  button: true,
                  image: true,
                  selected: selected,
                  label: _thumbnailSemanticLabel(idx, urls.length, selected),
                  onTap: select,
                  child: ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: select,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.18),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: _DiskCachedArtworkImage(
                              url: url,
                              fit: BoxFit.cover,
                              showProgress: false,
                              errorIconColor: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.6),
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _ArtworkLightboxDialog extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  final String semanticLabel;

  const _ArtworkLightboxDialog({
    required this.urls,
    required this.initialIndex,
    required this.semanticLabel,
  });

  @override
  State<_ArtworkLightboxDialog> createState() => _ArtworkLightboxDialogState();
}

class _ArtworkLightboxDialogState extends State<_ArtworkLightboxDialog> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _controller = PageController(
      initialPage: _index,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchAround(_index);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _prefetchAround(int index) {
    final urls =
        widget.urls.map((u) => u.trim()).where((u) => u.isNotEmpty).toList();
    if (urls.isEmpty) return;
    final candidates = <int>{
      index.clamp(0, urls.length - 1),
      (index - 1).clamp(0, urls.length - 1),
      (index + 1).clamp(0, urls.length - 1),
    };
    for (final i in candidates) {
      unawaited(prefetchDiskCachedArtworkImage(urls[i]).catchError((_) {}));
    }
  }

  String _imageSemanticLabel(int index, int total) {
    final clampedTotal = total < 1 ? 1 : total;
    final ordinal = (index + 1).clamp(1, clampedTotal);
    if (clampedTotal == 1) return widget.semanticLabel;
    return '${widget.semanticLabel} $ordinal of $clampedTotal';
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      namesRoute: true,
      label: 'Viewing ${_imageSemanticLabel(_index, urls.length)}',
      child: Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: urls.length,
              onPageChanged: (idx) {
                setState(() => _index = idx);
                _prefetchAround(idx);
              },
              itemBuilder: (context, idx) {
                final url = urls[idx];
                return Semantics(
                  image: true,
                  label: _imageSemanticLabel(idx, urls.length),
                  child: ExcludeSemantics(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: Center(
                        child: _DiskCachedArtworkImage(
                          url: url,
                          fit: BoxFit.contain,
                          showProgress: true,
                          errorIconColor: scheme.outline.withValues(alpha: 0.8),
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: KubusSpacing.sm,
              right: KubusSpacing.sm,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(KubusSpacing.xs + 2),
                  decoration: BoxDecoration(
                    color: scheme.inverseSurface.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: scheme.onInverseSurface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiskCachedArtworkImage extends StatelessWidget {
  const _DiskCachedArtworkImage({
    required this.url,
    required this.fit,
    required this.showProgress,
    required this.errorIconColor,
    this.excludeFromSemantics = false,
  });

  final String url;
  final BoxFit fit;
  final bool showProgress;
  final Color errorIconColor;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    return DiskCachedArtworkImage(
      url: url,
      fit: fit,
      showProgress: showProgress,
      errorIconColor: errorIconColor,
      excludeFromSemantics: excludeFromSemantics,
    );
  }
}
