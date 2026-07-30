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
    // The height already comes from the shared composition resolver, which
    // reserves the matching space in the overlay. Re-clamping here is what
    // previously let the media collapse whenever `maxHeight` was present.
    final resolvedHeight = imageHeight
        .clamp(
          MarkerOverlayCardMetrics.mediaHeightMinimum,
          MarkerOverlayCardMetrics.mediaHeightRegular,
        )
        .toDouble();
    return ClipRRect(
      key: const ValueKey<String>('marker_overlay_media'),
      borderRadius: BorderRadius.circular(KubusRadius.md),
      child: SizedBox(
        height: resolvedHeight,
        width: double.infinity,
        child: imageUrl != null
            ? KubusCachedImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: resolvedHeight,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                maxDisplayWidth: cacheWidth,
                cacheVersion: imageVersion,
                placeholderBuilder: (context) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        baseColor.withValues(alpha: 0.10),
                        baseColor.withValues(alpha: 0.22),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: InlineLoading(
                        tileSize: 4,
                        color: baseColor.withValues(alpha: 0.85),
                      ),
                    ),
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
