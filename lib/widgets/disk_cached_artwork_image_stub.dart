import 'dart:async';

import 'package:flutter/material.dart';
import 'inline_loading.dart';

import '../utils/media_url_resolver.dart';
import '../utils/image_variant_selector.dart';
import 'common/kubus_cached_image.dart';

final Map<String, Future<void>> _prefetchInFlight = <String, Future<void>>{};

Future<void> prefetchDiskCachedArtworkImage(String url) {
  final normalized = MediaUrlResolver.resolveDisplayUrl(url);
  if (normalized == null) return Future<void>.value();
  if (ImageVariantSelector.isRevocableDerivative(normalized)) {
    return Future<void>.value();
  }

  final existing = _prefetchInFlight[normalized];
  if (existing != null) return existing;

  final completer = Completer<void>();
  _prefetchInFlight[normalized] = completer.future;
  final timeoutTimer = Timer(const Duration(seconds: 20), () {
    _prefetchInFlight.remove(normalized);
    if (!completer.isCompleted) completer.complete();
  });

  final provider = NetworkImage(normalized);
  final stream = provider.resolve(const ImageConfiguration());
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo _, bool __) {
      timeoutTimer.cancel();
      stream.removeListener(listener);
      _prefetchInFlight.remove(normalized);
      if (!completer.isCompleted) completer.complete();
    },
    onError: (Object _, StackTrace? __) {
      timeoutTimer.cancel();
      stream.removeListener(listener);
      _prefetchInFlight.remove(normalized);
      if (!completer.isCompleted) completer.complete();
    },
  );
  stream.addListener(listener);
  return completer.future;
}

class DiskCachedArtworkImage extends StatefulWidget {
  const DiskCachedArtworkImage({
    super.key,
    required this.url,
    required this.fit,
    this.showProgress = true,
    this.errorIconColor,
    this.semanticLabel,
    this.excludeFromSemantics = false,
  }) : assert(
          semanticLabel == null || !excludeFromSemantics,
          'semanticLabel cannot be provided when excludeFromSemantics is true.',
        );

  final String url;
  final BoxFit fit;
  final bool showProgress;
  final Color? errorIconColor;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  @override
  State<DiskCachedArtworkImage> createState() => _DiskCachedArtworkImageState();
}

class _DiskCachedArtworkImageState extends State<DiskCachedArtworkImage> {
  void _evict(String raw) {
    final resolved = MediaUrlResolver.resolveDisplayUrl(raw);
    if (resolved != null &&
        ImageVariantSelector.isRevocableDerivative(resolved)) {
      unawaited(NetworkImage(resolved).evict());
    }
  }

  @override
  void didUpdateWidget(covariant DiskCachedArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _evict(oldWidget.url);
  }

  @override
  void dispose() {
    _evict(widget.url);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final errorColor =
        widget.errorIconColor ?? scheme.outline.withValues(alpha: 0.8);
    final resolved = MediaUrlResolver.resolveDisplayUrl(widget.url);
    if (resolved != null &&
        ImageVariantSelector.isRevocableDerivative(resolved)) {
      return Image.network(
        resolved,
        fit: widget.fit,
        semanticLabel: widget.semanticLabel,
        excludeFromSemantics: widget.excludeFromSemantics,
        errorBuilder: (_, __, ___) =>
            Center(child: Icon(Icons.image_not_supported, color: errorColor)),
        loadingBuilder: (context, child, progress) => progress == null ||
                !widget.showProgress
            ? child
            : Center(child: InlineLoading(tileSize: 4, color: scheme.primary)),
      );
    }
    return KubusCachedImage(
      imageUrl: widget.url,
      fit: widget.fit,
      placeholderBuilder: (context) {
        if (!widget.showProgress) return const SizedBox.shrink();
        return Center(
          child: InlineLoading(tileSize: 4, color: scheme.primary),
        );
      },
      errorBuilder: (_, __, ___) => Center(
        child: Icon(Icons.image_not_supported, color: errorColor),
      ),
      semanticLabel: widget.semanticLabel,
      excludeFromSemantics: widget.excludeFromSemantics,
    );
  }
}
