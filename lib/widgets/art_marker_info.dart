import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';
import '../models/artwork.dart';

Future<void> showArtMarkerInfoDialog({
  required BuildContext context,
  required ArtMarker marker,
  Artwork? artwork,
  LatLng? userPosition,
}) {
  final scheme = Theme.of(context).colorScheme;
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
          Icon(Icons.location_on, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              marker.name,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
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
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (artwork != null)
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
                  _chip(scheme, Icons.near_me, distanceText),
                _chip(
                  scheme,
                  Icons.category_outlined,
                  marker.category.isNotEmpty ? marker.category : marker.type.name,
                ),
                if (artwork != null)
                  _chip(
                    scheme,
                    Icons.military_tech_outlined,
                    artwork.rarity.name,
                  ),
                _chip(scheme, Icons.card_giftcard, '${artwork?.rewards ?? 0} POAP'),
                if (poapCount > 0 || badgeCount > 0)
                  _chip(
                    scheme,
                    Icons.emoji_events_outlined,
                    '$poapCount POAP • $badgeCount badges',
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

Widget _chip(ColorScheme scheme, IconData icon, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12),
        ),
      ],
    ),
  );
}
