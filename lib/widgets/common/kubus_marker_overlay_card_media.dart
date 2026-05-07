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
    final resolvedHeight = imageHeight.clamp(132.0, 180.0).toDouble();
    return ClipRRect(
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
