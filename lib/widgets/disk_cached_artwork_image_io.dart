import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'inline_loading.dart';
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

Future<void> prefetchDiskCachedArtworkImage(String url) async {
  final resolved = MediaUrlResolver.resolveDisplayUrl(url);
  if (resolved == null) return;
  await _KubusArtworkCacheManager.instance.downloadFile(resolved);
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
  Future<File?>? _fileFuture;
  // Null when the reference is not a safe media URL: nothing is fetched and
  // the widget renders its fallback icon.
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DiskCachedArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _load();
    }
  }

  void _load() {
    _resolvedUrl = MediaUrlResolver.resolveDisplayUrl(widget.url);
    final resolved = _resolvedUrl;
    _fileFuture = resolved == null
        ? Future<File?>.value(null)
        : _KubusArtworkCacheManager.instance.getSingleFile(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final errorColor =
        widget.errorIconColor ?? scheme.outline.withValues(alpha: 0.8);

    return FutureBuilder<File?>(
      future: _fileFuture,
      builder: (context, snap) {
        final resolvedSemanticLabel = _normalizedSemanticLabel;
        final file = snap.data;
        if (file != null) {
          return Image.file(
            file,
            fit: widget.fit,
            semanticLabel: resolvedSemanticLabel,
            excludeFromSemantics: widget.excludeFromSemantics,
            errorBuilder: (_, __, ___) => Center(
              child: _withFallbackSemantics(
                Icon(Icons.image_not_supported, color: errorColor),
                resolvedSemanticLabel,
              ),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting &&
            widget.showProgress) {
          return _withFallbackSemantics(
            Center(
              child: InlineLoading(tileSize: 4, color: scheme.primary),
            ),
            resolvedSemanticLabel,
          );
        }
        final networkUrl = _resolvedUrl;
        if (networkUrl == null) {
          return Center(
            child: _withFallbackSemantics(
              Icon(Icons.image_not_supported, color: errorColor),
              resolvedSemanticLabel,
            ),
          );
        }
        return Image.network(
          networkUrl,
          fit: widget.fit,
          semanticLabel: resolvedSemanticLabel,
          excludeFromSemantics: widget.excludeFromSemantics,
          errorBuilder: (_, __, ___) => Center(
            child: _withFallbackSemantics(
              Icon(Icons.image_not_supported, color: errorColor),
              resolvedSemanticLabel,
            ),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            if (!widget.showProgress) return child;
            return _withFallbackSemantics(
              Center(
                child: InlineLoading(tileSize: 4, color: scheme.primary),
              ),
              resolvedSemanticLabel,
            );
          },
        );
      },
    );
  }

  String? get _normalizedSemanticLabel {
    final trimmed = widget.semanticLabel?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Widget _withFallbackSemantics(Widget child, String? resolvedLabel) {
    if (widget.excludeFromSemantics) return ExcludeSemantics(child: child);
    if (resolvedLabel == null) return child;
    return Semantics(
      image: true,
      label: resolvedLabel,
      child: ExcludeSemantics(child: child),
    );
  }
}
