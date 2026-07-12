// ignore_for_file: kubus_no_raw_progress_indicator
// Grandfathered kubus design-token violations. Remove this header
// when migrating this file to tokens (see docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md).
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          baseColor.withValues(alpha: 0.85),
                        ),
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
