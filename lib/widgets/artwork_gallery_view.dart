import 'dart:async';

import 'package:flutter/material.dart';

import 'disk_cached_artwork_image.dart';

class ArtworkGalleryView extends StatefulWidget {
  final List<String> imageUrls;
  final double height;

  const ArtworkGalleryView({
    super.key,
    required this.imageUrls,
    this.height = 260,
  });

  @override
  State<ArtworkGalleryView> createState() => _ArtworkGalleryViewState();
}

class _ArtworkGalleryViewState extends State<ArtworkGalleryView> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchAround(_index);
    });
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
      unawaited(prefetchDiskCachedArtworkImage(urls[i]));
    }
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
      ),
    );
  }

  Widget _imageFrame({
    required String url,
    required double height,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
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
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls.where((u) => u.trim().isNotEmpty).toList(growable: false);
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
                setState(() => _index = idx);
                _prefetchAround(idx);
              },
              itemBuilder: (context, idx) => _imageFrame(
                url: urls[idx],
                height: height,
                onTap: () => _openLightbox(idx),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              urls.length,
              (idx) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: idx == _index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
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
          onTap: () => _openLightbox(_index),
        ),
        if (urls.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final url = urls[idx];
                final selected = idx == _index;
                return GestureDetector(
                  onTap: () => setState(() => _index = idx),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: _DiskCachedArtworkImage(
                        url: url,
                        fit: BoxFit.cover,
                        showProgress: false,
                        errorIconColor:
                            Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
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

  const _ArtworkLightboxDialog({
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<_ArtworkLightboxDialog> createState() => _ArtworkLightboxDialogState();
}

class _ArtworkLightboxDialogState extends State<_ArtworkLightboxDialog> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: widget.initialIndex.clamp(0, widget.urls.length - 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchAround(widget.initialIndex);
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
      unawaited(prefetchDiskCachedArtworkImage(urls[i]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: urls.length,
            onPageChanged: _prefetchAround,
            itemBuilder: (context, idx) {
              final url = urls[idx];
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: _DiskCachedArtworkImage(
                    url: url,
                    fit: BoxFit.contain,
                    showProgress: true,
                    errorIconColor: scheme.outline.withValues(alpha: 0.8),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context).pop(),
              icon: Container(
                padding: const EdgeInsets.all(6),
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
    );
  }
}

class _DiskCachedArtworkImage extends StatelessWidget {
  const _DiskCachedArtworkImage({
    required this.url,
    required this.fit,
    required this.showProgress,
    required this.errorIconColor,
  });

  final String url;
  final BoxFit fit;
  final bool showProgress;
  final Color errorIconColor;

  @override
  Widget build(BuildContext context) {
    return DiskCachedArtworkImage(
      url: url,
      fit: fit,
      showProgress: showProgress,
      errorIconColor: errorIconColor,
    );
  }
}
