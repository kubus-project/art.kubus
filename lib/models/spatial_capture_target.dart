import 'package:flutter/foundation.dart';

import 'art_marker.dart';
import 'artwork.dart';

/// The artwork (and optionally the marker) a spatial capture belongs to.
///
/// A capture may only begin once the user has named this target explicitly.
/// There is deliberately no "current selection" fallback: associating a
/// capture with whichever artwork happened to be first in a provider list
/// silently files a scan under someone else's work.
///
/// The identity is always the pair of ids. The snapshot fields exist purely so
/// an offline device can still render a readable label; they are never the
/// authority and must never be used for lookup or comparison.
@immutable
class SpatialCaptureTarget {
  const SpatialCaptureTarget({
    required this.artworkId,
    this.markerId,
    this.artworkTitleSnapshot,
    this.artistNameSnapshot,
    this.markerLabelSnapshot,
  }) : assert(artworkId != '', 'A spatial capture target needs an artwork id.');

  /// Durable authority for the artwork association.
  final String artworkId;

  /// Durable authority for the marker association, when the capture was
  /// started from a specific marker.
  final String? markerId;

  /// Display-only fallbacks. Never used to resolve or match a record.
  final String? artworkTitleSnapshot;
  final String? artistNameSnapshot;
  final String? markerLabelSnapshot;

  bool get hasMarker => (markerId ?? '').isNotEmpty;

  /// Builds a target from resolved domain objects, capturing display
  /// snapshots at the moment the user made the choice.
  factory SpatialCaptureTarget.fromArtwork(
    Artwork artwork, {
    ArtMarker? marker,
  }) =>
      SpatialCaptureTarget(
        artworkId: artwork.id,
        markerId: marker?.id,
        artworkTitleSnapshot: _clean(artwork.title),
        artistNameSnapshot: _clean(artwork.artist),
        markerLabelSnapshot: marker == null ? null : _clean(marker.name),
      );

  SpatialCaptureTarget copyWith({
    String? artworkId,
    Object? markerId = _unset,
    Object? artworkTitleSnapshot = _unset,
    Object? artistNameSnapshot = _unset,
    Object? markerLabelSnapshot = _unset,
  }) =>
      SpatialCaptureTarget(
        artworkId: artworkId ?? this.artworkId,
        markerId:
            identical(markerId, _unset) ? this.markerId : markerId as String?,
        artworkTitleSnapshot: identical(artworkTitleSnapshot, _unset)
            ? this.artworkTitleSnapshot
            : artworkTitleSnapshot as String?,
        artistNameSnapshot: identical(artistNameSnapshot, _unset)
            ? this.artistNameSnapshot
            : artistNameSnapshot as String?,
        markerLabelSnapshot: identical(markerLabelSnapshot, _unset)
            ? this.markerLabelSnapshot
            : markerLabelSnapshot as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'artworkId': artworkId,
        if (markerId != null) 'markerId': markerId,
        if (artworkTitleSnapshot != null) 'artworkTitle': artworkTitleSnapshot,
        if (artistNameSnapshot != null) 'artistName': artistNameSnapshot,
        if (markerLabelSnapshot != null) 'markerLabel': markerLabelSnapshot,
      };

  /// Returns null rather than throwing for a payload with no artwork id: an
  /// unusable target must not be silently replaced by a guessed one.
  static SpatialCaptureTarget? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final artworkId = _clean(value['artworkId']?.toString());
    if (artworkId == null) return null;
    return SpatialCaptureTarget(
      artworkId: artworkId,
      markerId: _clean(value['markerId']?.toString()),
      artworkTitleSnapshot: _clean(value['artworkTitle']?.toString()),
      artistNameSnapshot: _clean(value['artistName']?.toString()),
      markerLabelSnapshot: _clean(value['markerLabel']?.toString()),
    );
  }

  static String? _clean(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  @override
  bool operator ==(Object other) =>
      other is SpatialCaptureTarget &&
      other.artworkId == artworkId &&
      other.markerId == markerId &&
      other.artworkTitleSnapshot == artworkTitleSnapshot &&
      other.artistNameSnapshot == artistNameSnapshot &&
      other.markerLabelSnapshot == markerLabelSnapshot;

  @override
  int get hashCode => Object.hash(
        artworkId,
        markerId,
        artworkTitleSnapshot,
        artistNameSnapshot,
        markerLabelSnapshot,
      );

  @override
  String toString() =>
      'SpatialCaptureTarget(artworkId: $artworkId, markerId: $markerId)';
}

const Object _unset = Object();
