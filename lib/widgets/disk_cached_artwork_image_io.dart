import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../utils/media_url_resolver.dart';

class _KubusArtworkCacheManager {
  const _KubusArtworkCacheManager._();

  static CacheManager get instance => _instance;
  static final CacheManager _instance = CacheManager(
    Config(
      'kubusArtworkImages',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 600,
    ),
  );
}

String _resolveArtworkImageUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  return MediaUrlResolver.resolveDisplayUrl(trimmed) ??
      MediaUrlResolver.resolve(trimmed) ??
      trimmed;
}

Future<void> prefetchDiskCachedArtworkImage(String url) async {
  final resolved = _resolveArtworkImageUrl(url);
  if (resolved.isEmpty) return;
  await _KubusArtworkCacheManager.instance.downloadFile(resolved);
}

class DiskCachedArtworkImage extends StatefulWidget {
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
  State<DiskCachedArtworkImage> createState() => _DiskCachedArtworkImageState();
}

class _DiskCachedArtworkImageState extends State<DiskCachedArtworkImage> {
  Future<File?>? _fileFuture;
  String _resolvedUrl = '';

  @override
  void initState() {
    super.initState();
    _resolvedUrl = _resolveArtworkImageUrl(widget.url);
    _fileFuture = _KubusArtworkCacheManager.instance.getSingleFile(_resolvedUrl);
  }

  @override
  void didUpdateWidget(covariant DiskCachedArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resolvedUrl = _resolveArtworkImageUrl(widget.url);
      _fileFuture = _KubusArtworkCacheManager.instance.getSingleFile(_resolvedUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final errorColor = widget.errorIconColor ??
        scheme.outline.withValues(alpha: 0.8);

    return FutureBuilder<File?>(
      future: _fileFuture,
      builder: (context, snap) {
        final file = snap.data;
        if (file != null) {
          return Image.file(
            file,
            fit: widget.fit,
            errorBuilder: (_, __, ___) => Center(
              child: Icon(Icons.image_not_supported, color: errorColor),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting &&
            widget.showProgress) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          );
        }
        return Image.network(
          _resolvedUrl.isNotEmpty ? _resolvedUrl : widget.url,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(Icons.image_not_supported, color: errorColor),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            if (!widget.showProgress) return child;
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            );
          },
        );
      },
    );
  }
}
