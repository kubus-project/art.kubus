import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../models/art_marker.dart';

/// Attribution block for the marker info card ("more info"), rendered below
/// the description: artwork artist, photo author/licence, and data source.
///
/// Reads the attribution metadata surfaced by `/api/public-markers`
/// (`artistName`, `imageAuthor`, `imageLicense`, `imageAttribution`,
/// `sourceAttribution`) via the [ArtMarker] getters, so it works for both
/// open-data seeded markers and manually created ones.
class MarkerAttributionSection extends StatelessWidget {
  const MarkerAttributionSection({
    super.key,
    required this.marker,
    this.artistNameOverride,
  });

  final ArtMarker marker;

  /// Optional artist override (e.g. from a linked [Artwork.artistName]).
  final String? artistNameOverride;

  static String? _clean(String? value) {
    final v = (value ?? '').trim();
    return v.isEmpty ? null : v;
  }

  /// Whether the marker carries any attribution worth rendering.
  static bool hasAttribution(ArtMarker marker, {String? artistNameOverride}) {
    return _clean(artistNameOverride ?? marker.artistName) != null ||
        _clean(marker.imageAttribution) != null ||
        _clean(marker.imageAuthor) != null ||
        _clean(marker.sourceAttribution) != null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final artist = _clean(artistNameOverride ?? marker.artistName);
    // Prefer the display-ready line; otherwise compose from author/licence.
    final photoLine = _clean(marker.imageAttribution) ??
        [
          _clean(marker.imageAuthor),
          _clean(marker.imageLicense),
        ].whereType<String>().join(' / ');
    final source = _clean(marker.sourceAttribution);

    final rows = <Widget>[];
    void addRow(IconData icon, String label, String value) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$label: $value',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (artist != null && !RegExp(r'^unknown$', caseSensitive: false).hasMatch(artist)) {
      addRow(Icons.brush_outlined, l10n.markerAttributionArtistLabel, artist);
    }
    if (photoLine.isNotEmpty) {
      addRow(
        Icons.photo_camera_outlined,
        l10n.markerAttributionPhotoLabel,
        photoLine.replaceFirst(RegExp(r'^Photo:\s*', caseSensitive: false), ''),
      );
    }
    if (source != null) {
      addRow(Icons.public_outlined, l10n.markerAttributionSourceLabel, source);
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Divider(
          height: 1,
          thickness: 0.5,
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 6),
        ...rows,
      ],
    );
  }
}
