import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../../models/art_marker.dart';
import '../../models/artwork.dart';
import '../../services/spatial_library_store.dart';

/// How one record should be labelled, resolved from that record's own ids.
///
/// Every field here comes from `record.artworkId` / `record.markerId` and the
/// entities looked up for *those* ids. Nothing reads a "current" or "selected"
/// artwork, because a shared resolver is exactly how every card in a list ends
/// up wearing the same name.
@immutable
class SpatialRecordDisplay {
  const SpatialRecordDisplay({
    required this.title,
    required this.artworkLabel,
    required this.artworkResolved,
    required this.markerResolved,
    this.subtitle,
    this.markerLabel,
    this.thumbnailPath,
  });

  /// What to show as the record's name: the user's own name if they set one,
  /// otherwise the artwork it belongs to.
  final String title;

  /// The artwork's own label, independent of any user-chosen capture name.
  final String artworkLabel;

  /// The artist line, or null when the artwork could not be resolved.
  final String? subtitle;

  /// Whether the artwork reference resolved to a real artwork.
  ///
  /// False renders as "Artwork unavailable" — never as a raw id, and never by
  /// quietly attaching the capture to something else.
  final bool artworkResolved;

  /// The marker's label, or null when the record has no marker at all.
  final String? markerLabel;

  /// False when the record names a marker that could not be resolved.
  final bool markerResolved;

  final String? thumbnailPath;

  /// Resolves display copy for [record] from entities looked up by its ids.
  ///
  /// [artwork] must be the result of looking up `record.artworkId`, and
  /// [marker] the result of looking up `record.markerId`. Passing anything
  /// else is the bug this type exists to make obvious.
  static SpatialRecordDisplay resolve(
    AppLocalizations l10n,
    SpatialLibraryRecord record, {
    required Artwork? artwork,
    required ArtMarker? marker,
  }) {
    assert(
      artwork == null || artwork.id == record.artworkId,
      'Display must be resolved from the record\'s own artworkId.',
    );
    assert(
      marker == null || marker.id == record.markerId,
      'Display must be resolved from the record\'s own markerId.',
    );

    final liveTitle = artwork?.title.trim();
    final snapshotTitle = record.artworkTitleSnapshot?.trim();
    final artworkLabel = (liveTitle != null && liveTitle.isNotEmpty)
        ? liveTitle
        // The snapshot is a display fallback for an offline device, not an
        // identity. It is used only when the live lookup found nothing.
        : (snapshotTitle != null && snapshotTitle.isNotEmpty)
            ? snapshotTitle
            : l10n.spatialLibraryArtworkUnavailable;

    final liveArtist = artwork?.artist.trim();
    final snapshotArtist = record.artistNameSnapshot?.trim();
    final subtitle = (liveArtist != null && liveArtist.isNotEmpty)
        ? liveArtist
        : (snapshotArtist != null && snapshotArtist.isNotEmpty)
            ? snapshotArtist
            : null;

    final displayName = record.displayName?.trim();

    final hasMarkerReference = (record.markerId ?? '').trim().isNotEmpty;
    final liveMarker = marker?.name.trim();
    final snapshotMarker = record.markerLabelSnapshot?.trim();
    final String? markerLabel;
    final bool markerResolved;
    if (!hasMarkerReference) {
      markerLabel = null;
      markerResolved = true;
    } else if (liveMarker != null && liveMarker.isNotEmpty) {
      markerLabel = liveMarker;
      markerResolved = true;
    } else if (snapshotMarker != null && snapshotMarker.isNotEmpty) {
      markerLabel = snapshotMarker;
      markerResolved = false;
    } else {
      markerLabel = l10n.spatialLibraryMarkerUnavailable;
      markerResolved = false;
    }

    return SpatialRecordDisplay(
      title: displayName != null && displayName.isNotEmpty
          ? displayName
          : artworkLabel,
      artworkLabel: artworkLabel,
      subtitle: subtitle,
      artworkResolved: artwork != null,
      markerLabel: markerLabel,
      markerResolved: markerResolved,
      thumbnailPath: record.thumbnailPath,
    );
  }
}
