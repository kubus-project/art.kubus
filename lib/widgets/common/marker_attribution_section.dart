import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../models/art_marker.dart';
import '../../models/artwork.dart';
import '../../utils/artwork_media_resolver.dart';

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

  /// Attribution resolved from a linked artwork and its map marker.
  ///
  /// Attribution follows the same source precedence as the rendered cover:
  /// artwork media first, then marker media when the artwork has no cover.
  factory MarkerAttributionSection.fromMarkerAndArtwork(
    ArtMarker? marker,
    Artwork? artwork, {
    Key? key,
  }) {
    final values = _resolveMarkerAndArtworkValues(marker, artwork);
    final hasStructuredPhotoCredit =
        _clean(values.imageAuthor) != null &&
            _clean(values.imageLicense) != null;
    return MarkerAttributionSection(
      key: key,
      // Linked-artwork surfaces already render the artwork creator byline.
      artist: values.artist,
      imageAttribution:
          hasStructuredPhotoCredit ? null : values.imageAttribution,
      imageAuthor: values.imageAuthor,
      imageLicense: values.imageLicense,
      sourceAttribution: values.sourceAttribution,
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

  static bool _rendersArtist(String? artist) {
    final value = _clean(artist);
    if (value == null) return false;
    return !RegExp(r'^unknown$', caseSensitive: false).hasMatch(value);
  }

  static String _photoLine({
    String? imageAttribution,
    String? imageAuthor,
    String? imageLicense,
  }) {
    return _clean(imageAttribution) ??
        <String?>[
          _clean(imageAuthor),
          _clean(imageLicense),
        ].whereType<String>().join(' / ');
  }

  /// How many credit rows this section renders for the given values.
  ///
  /// Exposed so the marker quick card's height estimator reserves exactly the
  /// space the section will occupy instead of guessing.
  static int rowCountFrom({
    String? artist,
    String? imageAttribution,
    String? imageAuthor,
    String? imageLicense,
    String? sourceAttribution,
  }) {
    var rows = 0;
    if (_rendersArtist(artist)) rows++;
    if (_photoLine(
      imageAttribution: imageAttribution,
      imageAuthor: imageAuthor,
      imageLicense: imageLicense,
    ).isNotEmpty) {
      rows++;
    }
    if (_clean(sourceAttribution) != null) rows++;
    return rows;
  }

  /// Row count for the marker + linked artwork combination rendered by
  /// [MarkerAttributionSection.fromMarkerAndArtwork].
  static int rowCountForMarkerAndArtwork(ArtMarker? marker, Artwork? artwork) {
    return rowValuesForMarkerAndArtwork(marker, artwork).length;
  }

  /// The credit values this section renders, in render order.
  ///
  /// Exposed so the marker quick card's height estimator can predict which rows
  /// wrap onto a second line (each row renders up to [rowMaxLines]) instead of
  /// assuming every credit fits on one line — long artist/photo/source credits
  /// are common on open-data markers.
  static List<String> rowValuesForMarkerAndArtwork(
    ArtMarker? marker,
    Artwork? artwork,
  ) {
    final section = MarkerAttributionSection.fromMarkerAndArtwork(
      marker,
      artwork,
    );
    final values = <String>[];
    if (_rendersArtist(section.artist)) {
      values.add(_clean(section.artist)!);
    }
    final photoLine = _photoLine(
      imageAttribution: section.imageAttribution,
      imageAuthor: section.imageAuthor,
      imageLicense: section.imageLicense,
    );
    if (photoLine.isNotEmpty) values.add(photoLine);
    final source = _clean(section.sourceAttribution);
    if (source != null) values.add(source);
    return values;
  }

  /// Maximum lines one credit row renders (see the `Text` below).
  static const int rowMaxLines = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final artistValue = _clean(artist);
    // Prefer the display-ready line; otherwise compose from author/licence.
    final photoLine = _photoLine(
      imageAttribution: imageAttribution,
      imageAuthor: imageAuthor,
      imageLicense: imageLicense,
    );
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
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTypography.outfit(
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

    if (_rendersArtist(artistValue)) {
      addRow(Icons.brush_outlined, l10n.markerAttributionArtistLabel,
          artistValue!);
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

class _MarkerAttributionValues {
  const _MarkerAttributionValues({
    required this.artist,
    required this.imageAttribution,
    required this.imageAuthor,
    required this.imageLicense,
    required this.sourceAttribution,
  });

  final String? artist;
  final String? imageAttribution;
  final String? imageAuthor;
  final String? imageLicense;
  final String? sourceAttribution;
}
