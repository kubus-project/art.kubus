part of 'kubus_marker_overlay_card.dart';

extension _KubusMarkerOverlayCardMediaParts on KubusMarkerOverlayCard {
  Widget _buildImage({
    required Color baseColor,
    required ColorScheme scheme,
    required ArtMarker marker,
    required String? imageUrl,
    required String? imageVersion,
    required int cacheWidth,
    required int cacheHeight,
    required double imageHeight,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const coverAspectRatio = 16 / 9;
        final widthDerivedHeight = constraints.maxWidth.isFinite
            ? constraints.maxWidth / coverAspectRatio
            : imageHeight;
        final maxAllowedHeight = math.max(136.0, imageHeight);
        final resolvedHeight = widthDerivedHeight
            .clamp(136.0, maxAllowedHeight)
            .toDouble();
        return ClipRRect(
          borderRadius: BorderRadius.circular(KubusRadius.md),
          child: SizedBox(
            height: resolvedHeight,
            width: double.infinity,
            child: imageUrl != null
                ? KubusCachedImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    cacheWidth: cacheWidth,
                    cacheHeight: cacheHeight,
                    maxDisplayWidth: cacheWidth,
                    cacheVersion: imageVersion,
                    placeholderBuilder: (context) => Container(
                      color: baseColor.withValues(alpha: 0.12),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorBuilder: (_, __, ___) => _imageFallback(
                      baseColor,
                      scheme,
                      marker,
                    ),
                  )
                : _imageFallback(
                    baseColor,
                    scheme,
                    marker,
                  ),
          ),
        );
      },
    );
  }

  static Widget _imageFallback(
    Color baseColor,
    ColorScheme scheme,
    ArtMarker marker,
  ) {
    final hasExhibitions =
        marker.isExhibitionMarker || marker.exhibitionSummaries.isNotEmpty;
    final icon =
        hasExhibitions ? AppColorUtils.exhibitionIcon : Icons.auto_awesome;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            baseColor.withValues(alpha: 0.25),
            baseColor.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        icon,
        color: scheme.onPrimary,
        size: 42,
      ),
    );
  }
}
