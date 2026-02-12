import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/media_url_resolver.dart';
import 'common/kubus_cached_image.dart';

final Map<String, Future<void>> _prefetchInFlight = <String, Future<void>>{};

Future<void> prefetchDiskCachedArtworkImage(String url) {
  final resolvedUrl = MediaUrlResolver.resolveDisplayUrl(url) ??
      MediaUrlResolver.resolve(url) ??
      url;
  final normalized = resolvedUrl.trim();
  if (normalized.isEmpty) return Future<void>.value();

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

class DiskCachedArtworkImage extends StatelessWidget {
  const DiskCachedArtworkImage({
    super.key,
    required this.url,
    required this.fit,
    this.showProgress = true,
    this.errorIconColor,
  });

  final String url;
  final BoxFit fit;
  final bool showProgress;
  final Color? errorIconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final errorColor = errorIconColor ?? scheme.outline.withValues(alpha: 0.8);
    return KubusCachedImage(
      imageUrl: url,
      fit: fit,
      placeholderBuilder: (context) {
        if (!showProgress) return const SizedBox.shrink();
        return Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Center(
        child: Icon(Icons.image_not_supported, color: errorColor),
      ),
    );
  }
}
