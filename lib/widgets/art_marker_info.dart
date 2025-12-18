import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';
import '../models/artwork.dart';
import '../utils/app_color_utils.dart';

Future<void> showArtMarkerInfoDialog({
  required BuildContext context,
  required ArtMarker marker,
  Artwork? artwork,
  LatLng? userPosition,
}) {
  final scheme = Theme.of(context).colorScheme;
  final baseColor = AppColorUtils.markerSubjectColor(
    markerType: marker.type.name,
    metadata: marker.metadata,
    scheme: scheme,
  );
  final hasExhibitions = marker.exhibitionSummaries.isNotEmpty;
  final primaryExhibition = marker.primaryExhibitionSummary;
  final displayTitle = hasExhibitions && (primaryExhibition?.title ?? '').isNotEmpty
      ? primaryExhibition!.title!
      : (artwork?.title ?? marker.name);

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

  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: scheme.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              hasExhibitions ? AppColorUtils.exhibitionIcon : Icons.location_on,
              color: baseColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasExhibitions) ...[
                  Text(
                    'Exhibition',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: baseColor,
                    ),
                  ),
                ],
                Text(
                  displayTitle,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (artwork?.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    artwork!.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imageFallback(baseColor, scheme, marker),
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _imageFallback(baseColor, scheme, marker),
                ),
              ),
            const SizedBox(height: 12),
            if (artwork != null && !hasExhibitions)
              Text(
                artwork.title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            if (artwork?.description.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                artwork!.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (marker.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                marker.description,
                style: GoogleFonts.outfit(fontSize: 13),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                if (artwork != null)
                  _chip(
                    scheme,
                    Icons.military_tech_outlined,
                    artwork.rarity.name,
                    baseColor,
                  ),
                if (artwork != null && artwork.rewards > 0)
                  _chip(scheme, Icons.card_giftcard, '+${artwork.rewards}', baseColor),
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
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close', style: GoogleFonts.outfit()),
        ),
      ],
    ),
  );
}

Widget _imageFallback(Color baseColor, ColorScheme scheme, ArtMarker marker) {
  final hasExhibitions = marker.exhibitionSummaries.isNotEmpty;
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
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: accentColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: accentColor.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: accentColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}
