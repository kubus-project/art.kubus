import 'package:flutter/material.dart';

import '../utils/media_url_resolver.dart';

Future<void> prefetchDiskCachedArtworkImage(String url) async {}

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
    final errorColor =
        errorIconColor ?? scheme.outline.withValues(alpha: 0.8);
    final resolvedUrl = MediaUrlResolver.resolveDisplayUrl(url) ??
        MediaUrlResolver.resolve(url) ??
        url;
    return Image.network(
      resolvedUrl,
      fit: fit,
      errorBuilder: (_, __, ___) => Center(
        child: Icon(Icons.image_not_supported, color: errorColor),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        if (!showProgress) return child;
        return Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
          ),
        );
      },
    );
  }
}
