import 'package:flutter/material.dart';

import '../../utils/media_failure_registry.dart';
import '../../utils/media_url_resolver.dart';

typedef KubusImageErrorBuilder = Widget Function(
    BuildContext context, Object error, StackTrace? stackTrace);

/// Shared network image widget for stable URL normalization and cache-friendly
/// rendering across map + creator surfaces.
class KubusCachedImage extends StatefulWidget {
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
    this.decodeToDisplaySize = false,
    this.maxDisplayWidth,
    this.cacheVersion,
    this.icon = Icons.image_outlined,
    this.iconSize = 22,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.placeholderBuilder,
    this.errorBuilder,
    this.skipRecentlyFailed = false,
  }) : assert(
          semanticLabel == null || !excludeFromSemantics,
          'semanticLabel cannot be provided when excludeFromSemantics is true.',
        );

  @override
  State<KubusCachedImage> createState() => _KubusCachedImageState();

  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final int? cacheWidth;
  final int? cacheHeight;

  /// Decode at the laid-out size in physical pixels, capped to keep large
  /// source images from becoming oversized decoded card/search bitmaps.
  /// Explicit [cacheWidth]/[cacheHeight] always take precedence.
  final bool decodeToDisplaySize;

  static const int maxDisplayDecodeDimension = 1440;

  /// Converts a logical layout extent into a bounded physical decode extent.
  @visibleForTesting
  static int? displayDecodeDimension(
    double logicalExtent,
    double devicePixelRatio,
  ) {
    if (!logicalExtent.isFinite ||
        logicalExtent <= 0 ||
        !devicePixelRatio.isFinite ||
        devicePixelRatio <= 0) {
      return null;
    }
    final physicalExtent = (logicalExtent * devicePixelRatio).ceil();
    return physicalExtent.clamp(1, maxDisplayDecodeDimension);
  }

  final int? maxDisplayWidth;
  final String? cacheVersion;
  final IconData icon;
  final double iconSize;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final WidgetBuilder? placeholderBuilder;
  final KubusImageErrorBuilder? errorBuilder;

  /// Show the fallback without a request when this URL failed moments ago
  /// (here or as a map marker cover, see [KubusMediaFailureRegistry]).
  ///
  /// For surfaces that rebuild continuously while open, such as the map
  /// marker card following its marker; Flutter's image cache keeps no failed
  /// loads, so each rebuild would otherwise request the dead URL again. Off by
  /// default: elsewhere one failure must not hide the next attempt.
  final bool skipRecentlyFailed;

  static String? versionTokenFromDate(DateTime? value) {
    if (value == null) return null;
    return value.millisecondsSinceEpoch.toString();
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

  /// Builds the image for [state]'s current gateway candidate.
  ///
  /// Candidates come from the canonical resolver: an IPFS reference yields one
  /// URL per configured gateway, and a failed candidate advances to the next.
  Widget _buildImage(
    BuildContext context,
    _KubusCachedImageState state, {
    int? displayCacheWidth,
    int? displayCacheHeight,
  }) {
    final resolvedSemanticLabel = _normalizedSemanticLabel;
    final candidates = MediaUrlResolver.resolveDisplayCandidates(
      imageUrl,
      maxWidth: maxDisplayWidth,
    );
    var candidateIndex = candidates.isEmpty
        ? 0
        : state._candidateIndex.clamp(0, candidates.length - 1);
    if (candidates.isEmpty) state._hasDecodedFrame = false;
    if (skipRecentlyFailed && candidates.isNotEmpty) {
      // A candidate that failed moments ago is passed over, not retried: the
      // next eligible gateway is tried, and only when none is left does the
      // fallback show (no request is made, so nothing can loop).
      while (candidateIndex < candidates.length &&
          KubusMediaFailureRegistry.shared.hasRecentlyFailed(
            withStableVersion(candidates[candidateIndex], cacheVersion),
          )) {
        candidateIndex++;
      }
      if (candidateIndex >= candidates.length) {
        state._hasDecodedFrame = false;
        return _withFallbackSemantics(
          errorBuilder?.call(context, const _KubusRecentImageFailure(), null) ??
              _buildFallback(context),
          resolvedSemanticLabel,
        );
      }
    }
    final resolved = candidates.isEmpty ? null : candidates[candidateIndex];
    final urlWithVersion = withStableVersion(resolved, cacheVersion);
    if (urlWithVersion == null || urlWithVersion.isEmpty) {
      state._hasDecodedFrame = false;
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
    int? effectiveCacheWidth = cacheWidth ?? displayCacheWidth;
    int? effectiveCacheHeight = cacheHeight ?? displayCacheHeight;
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
      gaplessPlayback: state._preserveDecodedFrame,
      cacheWidth: effectiveCacheWidth,
      cacheHeight: effectiveCacheHeight,
      semanticLabel: resolvedSemanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) {
          state._hasDecodedFrame = true;
        }
        return child;
      },
      errorBuilder: (context, error, stackTrace) {
        state._hasDecodedFrame = false;
        KubusMediaFailureRegistry.shared.markFailed(urlWithVersion);
        if (candidateIndex + 1 < candidates.length) {
          state._advanceCandidate(candidateIndex);
          return _withFallbackSemantics(
            _buildFallback(context),
            resolvedSemanticLabel,
          );
        }
        // Every candidate failed: show the placeholder, never a broken-image
        // glyph. Callers that want their own error widget pass errorBuilder.
        late final Widget fallback;
        if (errorBuilder != null) {
          fallback = errorBuilder!(context, error, stackTrace);
        } else {
          fallback = _buildFallback(context);
        }
        return _withFallbackSemantics(fallback, resolvedSemanticLabel);
      },
      loadingBuilder: (context, child, progress) {
        // Image.network keeps its last decoded frame when gaplessPlayback is
        // enabled. Keep that painted child during a URL refresh; the fallback
        // is only for the initial load before any frame has decoded.
        if (state._hasDecodedFrame) return child;
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

class _KubusCachedImageState extends State<KubusCachedImage> {
  int _candidateIndex = 0;
  bool _advancePending = false;
  bool _hasDecodedFrame = false;
  bool _preserveDecodedFrame = true;

  @override
  void didUpdateWidget(covariant KubusCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _preserveDecodedFrame = oldWidget.imageUrl == widget.imageUrl;
    if (!_preserveDecodedFrame) {
      _candidateIndex = 0;
      _hasDecodedFrame = false;
    }
  }

  void _advanceCandidate(int failedIndex) {
    if (_advancePending) return;
    _advancePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _advancePending = false;
      if (!mounted || _candidateIndex > failedIndex) return;
      setState(() => _candidateIndex = failedIndex + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.decodeToDisplaySize ||
        widget.cacheWidth != null ||
        widget.cacheHeight != null) {
      return widget._buildImage(context, this);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        return widget._buildImage(
          context,
          this,
          displayCacheWidth: KubusCachedImage.displayDecodeDimension(
            constraints.maxWidth,
            devicePixelRatio,
          ),
          displayCacheHeight: KubusCachedImage.displayDecodeDimension(
            constraints.maxHeight,
            devicePixelRatio,
          ),
        );
      },
    );
  }
}

/// Error handed to [KubusCachedImage.errorBuilder] when the image was not
/// requested because the same URL failed moments ago.
class _KubusRecentImageFailure implements Exception {
  const _KubusRecentImageFailure();

  @override
  String toString() => 'Image recently failed to load; not retried yet.';
}
