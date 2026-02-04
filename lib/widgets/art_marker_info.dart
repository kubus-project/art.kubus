import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';
import '../models/artwork.dart';
import '../utils/app_color_utils.dart';
import '../utils/artwork_media_resolver.dart';
import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';
import 'glass_components.dart';

Future<void> showArtMarkerInfoDialog({
  required BuildContext context,
  required ArtMarker marker,
  Artwork? artwork,
  LatLng? userPosition,
}) {
  final scheme = Theme.of(context).colorScheme;
  final roles = KubusColorRoles.of(context);
  final baseColor = AppColorUtils.markerSubjectColor(
    markerType: marker.type.name,
    metadata: marker.metadata,
    scheme: scheme,
    roles: roles,
  );
  final hasExhibitions = marker.isExhibitionMarker || marker.exhibitionSummaries.isNotEmpty;
  final primaryExhibition = marker.resolvedExhibitionSummary;
  final displayTitle = hasExhibitions && (primaryExhibition?.title ?? '').isNotEmpty
      ? primaryExhibition!.title!
      : (artwork?.title ?? marker.name);
  final coverUrl = ArtworkMediaResolver.resolveCover(
    artwork: artwork,
    metadata: marker.metadata,
  );

  final distanceText = () {
    if (userPosition == null) return null;
    const distance = Distance();
    final meters = distance.as(LengthUnit.Meter, userPosition, marker.position);
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km away';
    }
    return '${meters.round()} m away';
  }();

  final poapCount = (marker.metadata?['poapCount'] as num?)?.toInt() ?? 0;
  final badgeCount = (marker.metadata?['badgeCount'] as num?)?.toInt() ?? 0;

  return showKubusDialog(
    context: context,
    builder: (dialogContext) => KubusAlertDialog(
      title: Row(
        children: [
          LiquidGlassPanel(
            padding: const EdgeInsets.all(KubusSpacing.sm),
            margin: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(KubusRadius.sm),
            blurSigma: KubusGlassEffects.blurSigmaLight,
            showBorder: false,
            backgroundColor: baseColor.withValues(alpha: 0.14),
            child: Icon(
              hasExhibitions ? AppColorUtils.exhibitionIcon : Icons.location_on,
              color: baseColor,
              size: KubusSizes.sidebarActionIcon,
            ),
          ),
          const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasExhibitions) ...[
                  Text(
                    'Exhibition',
                    style:
                        KubusTextStyles.detailLabel.copyWith(color: baseColor),
                  ),
                ],
                Text(
                  displayTitle,
                  style: KubusTextStyles.detailCardTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: KubusSizes.dialogWidthMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverUrl != null && coverUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(KubusRadius.md),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imageFallback(baseColor, scheme, marker),
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(KubusRadius.md),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _imageFallback(baseColor, scheme, marker),
                ),
              ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
            if (artwork != null && !hasExhibitions)
              Text(
                artwork.title,
                style: KubusTextStyles.detailCardTitle.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            if (artwork?.description.isNotEmpty == true) ...[
              const SizedBox(height: KubusSpacing.xs),
              Text(
                artwork!.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: KubusTextStyles.detailLabel.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (marker.description.isNotEmpty) ...[
              const SizedBox(height: KubusSpacing.sm),
              Text(
                marker.description,
                style: KubusTextStyles.detailCaption.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ],
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xxs),
            Wrap(
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.sm,
              children: [
                if (distanceText != null)
                  _chip(scheme, Icons.near_me, distanceText, baseColor),
                if (hasExhibitions)
                  _chip(scheme, Icons.verified_outlined, 'POAP', baseColor),
                _chip(
                  scheme,
                  Icons.category_outlined,
                  marker.category.isNotEmpty ? marker.category : marker.type.name,
                  baseColor,
                ),
                if (artwork != null && artwork.rewards > 0)
                  _chip(
                    scheme,
                    Icons.card_giftcard,
                    '+${artwork.rewards}',
                    baseColor,
                  ),
                if (poapCount > 0 || badgeCount > 0)
                  _chip(
                    scheme,
                    Icons.emoji_events_outlined,
                    '$poapCount POAP • $badgeCount badges',
                    baseColor,
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(
            'Close',
            style: KubusTextStyles.detailButton.copyWith(color: scheme.primary),
          ),
        ),
      ],
    ),
  );
}

Widget _imageFallback(Color baseColor, ColorScheme scheme, ArtMarker marker) {
  final hasExhibitions = marker.isExhibitionMarker || marker.exhibitionSummaries.isNotEmpty;
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
    child: Center(
      child: Icon(
        hasExhibitions ? AppColorUtils.exhibitionIcon : Icons.auto_awesome,
        color: scheme.onPrimary,
        size: 48,
      ),
    ),
  );
}

Widget _chip(ColorScheme scheme, IconData icon, String label, Color accentColor) {
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(KubusRadius.xl),
      border: Border.all(color: accentColor.withValues(alpha: 0.25)),
    ),
    child: FrostedContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm + KubusSpacing.xxs,
        vertical: KubusSpacing.xs + KubusSpacing.xxs,
      ),
      borderRadius: BorderRadius.circular(KubusRadius.xl),
      showBorder: false,
      backgroundColor: accentColor.withValues(alpha: 0.12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: KubusSizes.trailingChevron, color: accentColor),
          const SizedBox(width: KubusSpacing.xs + KubusSpacing.xxs),
          Text(
            label,
            style:
                KubusTextStyles.detailLabel.copyWith(color: scheme.onSurface),
          ),
        ],
      ),
    ),
  );
}
