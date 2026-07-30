import 'package:flutter/foundation.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../../../models/event.dart';
import '../../../models/exhibition.dart';
import '../../../utils/artwork_media_resolver.dart';
import '../shared/map_marker_overlay_presentation.dart';

/// Everything the generic marker-detail surface renders.
///
/// Resolved once from the marker (plus whatever canonical entity is available)
/// so the desktop side panel and the mobile full-detail page present identical
/// content. This is the single detail model for markers whose linked
/// event/exhibition/institution entity is absent, orphaned, or returned 404 —
/// it deliberately presents *marker information* rather than pretending a
/// canonical entity exists.
@immutable
class MarkerInfoDetail {
  const MarkerInfoDetail({
    required this.marker,
    required this.title,
    required this.kicker,
    required this.description,
    required this.linkedKind,
    required this.linkedSubjectUnavailable,
    this.subjectTypeLabel,
    this.coverUrl,
    this.coverUpdatedAt,
    this.locationLabel,
    this.dateRangeLabel,
    this.categoryLabel,
    this.distanceLabel,
  });

  final ArtMarker marker;

  /// Best available title: canonical subject title, else the marker's name.
  final String title;

  /// Localized eyebrow line ("Marker information").
  final String kicker;

  /// Marker or canonical-subject description; empty when neither has one.
  final String description;

  final MapMarkerOverlayLinkedSubjectKind linkedKind;

  /// True when the marker declares a linked subject that could not be resolved.
  final bool linkedSubjectUnavailable;

  /// Localized label for the declared subject type, when there is one.
  final String? subjectTypeLabel;

  final String? coverUrl;
  final DateTime? coverUpdatedAt;
  final String? locationLabel;
  final String? dateRangeLabel;
  final String? categoryLabel;
  final String? distanceLabel;

  bool get hasDescription => description.trim().isNotEmpty;
}

/// Builds the generic marker-detail model.
///
/// [linkedSubjectUnavailable] is set by the caller when a hydration attempt
/// resolved to nothing (missing subject id, 404, or a failed fetch), so the
/// surface can say so instead of silently presenting partial data as canonical.
MarkerInfoDetail resolveMarkerInfoDetail({
  required ArtMarker marker,
  required AppLocalizations l10n,
  Artwork? artwork,
  KubusEvent? event,
  Exhibition? exhibition,
  String? distanceLabel,
  bool linkedSubjectUnavailable = false,
}) {
  final presentation = resolveMarkerOverlayPresentation(
    marker: marker,
    artwork: artwork,
    event: event,
    exhibition: exhibition,
  );

  final cover = _firstNonEmpty(<String?>[
    presentation.mediaUrl,
    ArtworkMediaResolver.resolveCover(
      artwork: artwork,
      metadata: marker.metadata,
    ),
  ]);

  final location = _firstNonEmpty(<String?>[
    event?.locationName,
    exhibition?.locationName,
    marker.locationName,
  ]);

  final dateRange = ArtMarker.formatMarkerDateRange(
        event?.startsAt ?? exhibition?.startsAt,
        event?.endsAt ?? exhibition?.endsAt,
      ) ??
      marker.subjectDateRangeLabel;

  final category = _firstNonEmpty(<String?>[
    marker.subjectCategory,
    artwork?.category == 'General' ? null : artwork?.category,
    marker.category == 'General' ? null : marker.category,
  ]);

  return MarkerInfoDetail(
    marker: marker,
    title: presentation.title,
    kicker: l10n.markerInfoDetailKicker,
    description: presentation.description.trim().isNotEmpty
        ? presentation.description.trim()
        : marker.description.trim(),
    linkedKind: presentation.linkedSubject.kind,
    linkedSubjectUnavailable: linkedSubjectUnavailable,
    subjectTypeLabel: markerInfoSubjectTypeLabel(
      l10n,
      presentation.linkedSubject.kind,
    ),
    coverUrl: cover,
    coverUpdatedAt: presentation.mediaUpdatedAt ??
        artwork?.updatedAt ??
        marker.updatedAt ??
        marker.createdAt,
    locationLabel: location,
    dateRangeLabel: dateRange,
    categoryLabel: category,
    distanceLabel: _normalize(distanceLabel),
  );
}

/// Localized label for a linked-subject kind, or `null` when there is none.
String? markerInfoSubjectTypeLabel(
  AppLocalizations l10n,
  MapMarkerOverlayLinkedSubjectKind kind,
) {
  switch (kind) {
    case MapMarkerOverlayLinkedSubjectKind.artwork:
      return l10n.commonArtwork;
    case MapMarkerOverlayLinkedSubjectKind.exhibition:
      return l10n.commonExhibition;
    case MapMarkerOverlayLinkedSubjectKind.event:
      return l10n.mapMarkerSubjectTypeEvent;
    case MapMarkerOverlayLinkedSubjectKind.institution:
      return l10n.commonInstitution;
    case MapMarkerOverlayLinkedSubjectKind.group:
      return l10n.mapMarkerSubjectTypeGroup;
    case MapMarkerOverlayLinkedSubjectKind.misc:
    case MapMarkerOverlayLinkedSubjectKind.none:
      return null;
  }
}

String? _firstNonEmpty(List<String?> candidates) {
  for (final candidate in candidates) {
    final normalized = _normalize(candidate);
    if (normalized != null) return normalized;
  }
  return null;
}

String? _normalize(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}
