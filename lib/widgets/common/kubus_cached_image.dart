import 'package:flutter/material.dart';

import '../../utils/media_url_resolver.dart';

typedef KubusImageErrorBuilder = Widget Function(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
);

/// Shared network image widget for stable URL normalization and cache-friendly
/// rendering across map + creator surfaces.
class KubusCachedImage extends StatelessWidget {
  const KubusCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.cacheWidth,
    this.cacheHeight,
    this.maxDisplayWidth,
    this.cacheVersion,
    this.icon = Icons.image_outlined,
    this.iconSize = 22,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.placeholderBuilder,
    this.errorBuilder,
  }) : assert(
          semanticLabel == null || !excludeFromSemantics,
          'semanticLabel cannot be provided when excludeFromSemantics is true.',
        );

  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final int? cacheWidth;
  final int? cacheHeight;
  final int? maxDisplayWidth;
  final String? cacheVersion;
  final IconData icon;
  final double iconSize;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final WidgetBuilder? placeholderBuilder;
  final KubusImageErrorBuilder? errorBuilder;

  static String? versionTokenFromDate(DateTime? value) {
    if (value == null) return null;
    return value.millisecondsSinceEpoch.toString();
  }

  static String? resolveImageUrl(
    String? raw, {
    int? maxDisplayWidth,
  }) {
    final resolved = MediaUrlResolver.resolveDisplayUrl(
          raw,
          maxWidth: maxDisplayWidth,
        ) ??
        MediaUrlResolver.resolveDisplayUrl(raw);
    if (resolved == null || resolved.trim().isEmpty) return null;
    return resolved.trim();
  }

  static String? withStableVersion(String? url, String? version) {
    if (url == null || url.isEmpty) return null;
    final token = (version ?? '').trim();
    if (token.isEmpty) return url;
    final parsed = Uri.tryParse(url);
    if (parsed == null ||
        !parsed.hasScheme ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      return url;
    }
    final isMediaProxyRequest = parsed.path.contains('/api/media/proxy') &&
        parsed.queryParameters.containsKey('url');
    if (isMediaProxyRequest) {
      // Keep proxy URLs stable so proxy-side caching (including cached 4xx/5xx)
      // works as intended.
      return url;
    }
    if (parsed.queryParameters.isNotEmpty) {
      // Keep externally parameterized URLs stable (signed URLs, transform
      // directives, redirector-style endpoints) by not appending a second
      // cache-busting query token.
      return url;
    }
    final params = Map<String, String>.from(parsed.queryParameters);
    params['v'] = token;
    return parsed.replace(queryParameters: params).toString();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedSemanticLabel = _normalizedSemanticLabel;
    final resolved = resolveImageUrl(
      imageUrl,
      maxDisplayWidth: maxDisplayWidth,
    );
    final urlWithVersion = withStableVersion(resolved, cacheVersion);
    if (urlWithVersion == null || urlWithVersion.isEmpty) {
      return _withFallbackSemantics(
        _buildFallback(context),
        resolvedSemanticLabel,
      );
    }

    // Providing BOTH cacheWidth and cacheHeight forces Flutter to decode the
    // bitmap to exactly those pixel dimensions, ignoring the source aspect
    // ratio. That squishes/stretches the image *before* [fit] can act, so even
    // BoxFit.cover ends up rendering a distorted bitmap (it has nothing left to
    // crop). For any aspect-preserving fit we therefore decode with a single
    // constraint — keeping the larger target axis for resolution and dropping
    // the other — so the decoded bitmap keeps its native aspect ratio and [fit]
    // does the cropping. BoxFit.fill is the one case that intentionally
    // distorts, so it keeps both dimensions.
    int? effectiveCacheWidth = cacheWidth;
    int? effectiveCacheHeight = cacheHeight;
    if (fit != BoxFit.fill &&
        effectiveCacheWidth != null &&
        effectiveCacheHeight != null) {
      if (effectiveCacheWidth >= effectiveCacheHeight) {
        effectiveCacheHeight = null;
      } else {
        effectiveCacheWidth = null;
      }
    }

    return Image.network(
      urlWithVersion,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      gaplessPlayback: true,
      cacheWidth: effectiveCacheWidth,
      cacheHeight: effectiveCacheHeight,
      semanticLabel: resolvedSemanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      errorBuilder: (context, error, stackTrace) {
        late final Widget fallback;
        if (errorBuilder != null) {
          fallback = errorBuilder!(context, error, stackTrace);
        } else {
          fallback = _buildFallback(context, icon: Icons.broken_image_outlined);
        }
        return _withFallbackSemantics(fallback, resolvedSemanticLabel);
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _withFallbackSemantics(
          placeholderBuilder?.call(context) ?? _buildFallback(context),
          resolvedSemanticLabel,
        );
      },
    );
  }

  String? get _normalizedSemanticLabel {
    final trimmed = semanticLabel?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Widget _withFallbackSemantics(Widget child, String? resolvedLabel) {
    if (excludeFromSemantics) return ExcludeSemantics(child: child);
    if (resolvedLabel == null) return child;
    return Semantics(
      image: true,
      label: resolvedLabel,
      child: ExcludeSemantics(child: child),
    );
  }

  Widget _buildFallback(BuildContext context, {IconData? icon}) {
    if (placeholderBuilder != null) return placeholderBuilder!(context);
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Center(
        child: Icon(
          icon ?? this.icon,
          size: iconSize,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
