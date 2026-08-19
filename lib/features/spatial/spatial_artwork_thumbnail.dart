import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/artwork.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/disk_cached_artwork_image.dart';

/// The image shown for a spatial capture or its artwork.
///
/// Prefers the capture's own thumbnail — that is what the user actually
/// recorded — and falls back to the artwork cover, then to a neutral
/// placeholder. It never renders an id or a broken image box.
class SpatialArtworkThumbnail extends StatelessWidget {
  const SpatialArtworkThumbnail({
    super.key,
    this.capturePath,
    this.artwork,
    this.size = KubusSizes.listThumbnail,
    this.radius = KubusRadius.sm,
    this.semanticLabel,
  });

  /// Local path of the capture thumbnail, if one was produced.
  final String? capturePath;

  /// The linked artwork, when it still resolves.
  final Artwork? artwork;

  final double size;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final path = capturePath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: (size * 3).round(),
          semanticLabel: semanticLabel,
          errorBuilder: (context, _, __) => _placeholder(context),
        );
      }
    }
    final cover = ArtworkMediaResolver.resolveCover(artwork: artwork);
    if (cover != null && cover.isNotEmpty) {
      return DiskCachedArtworkImage(
        url: cover,
        fit: BoxFit.cover,
        showProgress: false,
        semanticLabel: semanticLabel,
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.view_in_ar_outlined,
        color: scheme.onSurfaceVariant,
        size: size / 2.5,
      ),
    );
  }
}
