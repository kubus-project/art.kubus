// ignore_for_file: kubus_no_inline_google_fonts
// Grandfathered kubus design-token violations. Remove this header
// when migrating this file to tokens (see docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../models/art_marker.dart';
import '../../models/artwork.dart';

/// Attribution block rendered below a description: artwork artist, photo
/// author/licence, and data source.
///
/// Used by the marker "more info" dialogs (via [MarkerAttributionSection.fromMarker])
/// and the artwork detail screens (via [MarkerAttributionSection.fromArtwork]).
/// Works for open-data seeded markers (attribution from `/api/public-markers`
/// metadata or `artworks.image_*` columns) and manually created ones.
class MarkerAttributionSection extends StatelessWidget {
  const MarkerAttributionSection({
    super.key,
    this.artist,
    this.imageAttribution,
    this.imageAuthor,
    this.imageLicense,
    this.sourceAttribution,
  });

  /// Attribution resolved from an [ArtMarker]'s metadata.
  factory MarkerAttributionSection.fromMarker(
    ArtMarker marker, {
    Key? key,
    String? artistNameOverride,
  }) {
    return MarkerAttributionSection(
      key: key,
      artist: artistNameOverride ?? marker.artistName,
      imageAttribution: marker.imageAttribution,
      imageAuthor: marker.imageAuthor,
      imageLicense: marker.imageLicense,
      sourceAttribution: marker.sourceAttribution,
    );
  }

  /// Attribution resolved from an [Artwork]'s image attribution metadata.
  factory MarkerAttributionSection.fromArtwork(
    Artwork artwork, {
    Key? key,
  }) {
    return MarkerAttributionSection(
      key: key,
      // Detail screens already render the artist byline prominently, so only
      // photo/source credit rows are added here.
      imageAttribution: artwork.imageAttribution,
      imageAuthor: artwork.imageAuthor,
      imageLicense: artwork.imageLicense,
    );
  }

  final String? artist;
  final String? imageAttribution;
  final String? imageAuthor;
  final String? imageLicense;
  final String? sourceAttribution;

  static String? _clean(String? value) {
    final v = (value ?? '').trim();
    return v.isEmpty ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final artistValue = _clean(artist);
    // Prefer the display-ready line; otherwise compose from author/licence.
    final photoLine = _clean(imageAttribution) ??
        [
          _clean(imageAuthor),
          _clean(imageLicense),
        ].whereType<String>().join(' / ');
    final source = _clean(sourceAttribution);

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

    if (artistValue != null &&
        !RegExp(r'^unknown$', caseSensitive: false).hasMatch(artistValue)) {
      addRow(Icons.brush_outlined, l10n.markerAttributionArtistLabel, artistValue);
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
