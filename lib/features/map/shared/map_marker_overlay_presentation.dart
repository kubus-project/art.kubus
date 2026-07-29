import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../../../models/event.dart';
import '../../../models/exhibition.dart';

enum MapMarkerOverlayLinkedSubjectKind {
  none,
  artwork,
  exhibition,
  event,
  institution,
  group,
  misc,
}

enum MapMarkerOverlayPrimaryTarget {
  markerInfo,
  artwork,
  exhibition,
  event,
  institution,
}

class MapMarkerOverlayLinkedSubjectContext {
  const MapMarkerOverlayLinkedSubjectContext({
    required this.kind,
    this.id,
    this.title,
    this.subtitle,
  });

  final MapMarkerOverlayLinkedSubjectKind kind;
  final String? id;
  final String? title;
  final String? subtitle;

  bool get hasContent =>
      (title ?? '').trim().isNotEmpty || (subtitle ?? '').trim().isNotEmpty;
}

class MapMarkerOverlayPresentation {
  const MapMarkerOverlayPresentation({
    required this.title,
    required this.description,
    required this.linkedSubject,
    required this.primaryTarget,
    this.mediaUrl,
    this.mediaUpdatedAt,
  });

  final String title;
  final String description;
  final MapMarkerOverlayLinkedSubjectContext linkedSubject;
  final MapMarkerOverlayPrimaryTarget primaryTarget;
  final String? mediaUrl;
  final DateTime? mediaUpdatedAt;
}

MapMarkerOverlayPresentation resolveMarkerOverlayPresentation({
  required ArtMarker marker,
  Artwork? artwork,
  KubusEvent? event,
  Exhibition? exhibition,
}) {
  final linkedKind = resolveMarkerOverlayLinkedSubjectKind(marker);
  final linkedId = _resolveLinkedSubjectId(
    marker: marker,
    artwork: artwork,
    kind: linkedKind,
  );
  final linkedTitle = _resolveLinkedSubjectTitle(
    marker: marker,
    artwork: artwork,
    event: event,
    exhibition: exhibition,
    kind: linkedKind,
  );
  final linkedSubtitle = _resolveLinkedSubjectSubtitle(
    marker: marker,
    event: event,
    exhibition: exhibition,
    kind: linkedKind,
  );

  final markerTitle = marker.name.trim();
  final canonicalSubjectTitle =
      linkedKind == MapMarkerOverlayLinkedSubjectKind.event ||
              linkedKind == MapMarkerOverlayLinkedSubjectKind.exhibition
          ? linkedTitle?.trim()
          : null;
  final title = canonicalSubjectTitle?.isNotEmpty == true
      ? canonicalSubjectTitle!
      : markerTitle.isNotEmpty
          ? markerTitle
          : (linkedTitle?.trim().isNotEmpty == true
              ? linkedTitle!.trim()
              : 'Marker');

  final markerDescription = marker.description.trim();
  final subjectDescription = _resolveFallbackDescription(
    artwork: artwork,
    event: event,
    exhibition: exhibition,
    kind: linkedKind,
  );
  final preferCanonicalSubject =
      linkedKind == MapMarkerOverlayLinkedSubjectKind.event ||
          linkedKind == MapMarkerOverlayLinkedSubjectKind.exhibition;
  final description = preferCanonicalSubject && subjectDescription.isNotEmpty
      ? subjectDescription
      : markerDescription.isNotEmpty
          ? markerDescription
          : subjectDescription;

  return MapMarkerOverlayPresentation(
    title: title,
    description: description,
    linkedSubject: MapMarkerOverlayLinkedSubjectContext(
      kind: linkedKind,
      id: linkedId,
      title: linkedTitle,
      subtitle: linkedSubtitle,
    ),
    primaryTarget: _resolvePrimaryTarget(
      marker: marker,
      artwork: artwork,
      linkedKind: linkedKind,
      linkedSubjectId: linkedId,
    ),
    mediaUrl: switch (linkedKind) {
      MapMarkerOverlayLinkedSubjectKind.event => event?.coverUrl,
      MapMarkerOverlayLinkedSubjectKind.exhibition => exhibition?.coverUrl,
      _ => null,
    },
    mediaUpdatedAt: switch (linkedKind) {
      MapMarkerOverlayLinkedSubjectKind.event =>
        event?.updatedAt ?? event?.createdAt,
      MapMarkerOverlayLinkedSubjectKind.exhibition =>
        exhibition?.updatedAt ?? exhibition?.createdAt,
      _ => null,
    },
  );
}

MapMarkerOverlayLinkedSubjectKind resolveMarkerOverlayLinkedSubjectKind(
  ArtMarker marker,
) {
  final subjectType = (marker.subjectType ?? '').trim().toLowerCase();
  if (subjectType.contains('exhibition')) {
    return MapMarkerOverlayLinkedSubjectKind.exhibition;
  }
  if (subjectType.contains('event')) {
    return MapMarkerOverlayLinkedSubjectKind.event;
  }
  if (subjectType.contains('institution') ||
      subjectType.contains('museum') ||
      subjectType.contains('gallery')) {
    return MapMarkerOverlayLinkedSubjectKind.institution;
  }
  if (subjectType.contains('group') || subjectType.contains('dao')) {
    return MapMarkerOverlayLinkedSubjectKind.group;
  }
  if (subjectType.contains('artwork') ||
      (marker.artworkId ?? '').trim().isNotEmpty) {
    return MapMarkerOverlayLinkedSubjectKind.artwork;
  }
  if (subjectType.contains('misc') || subjectType.contains('other')) {
    return MapMarkerOverlayLinkedSubjectKind.misc;
  }
  if (marker.resolvedExhibitionSummary != null) {
    return MapMarkerOverlayLinkedSubjectKind.exhibition;
  }
  return MapMarkerOverlayLinkedSubjectKind.none;
}

String? _resolveLinkedSubjectId({
  required ArtMarker marker,
  required Artwork? artwork,
  required MapMarkerOverlayLinkedSubjectKind kind,
}) {
  switch (kind) {
    case MapMarkerOverlayLinkedSubjectKind.artwork:
      return (artwork?.id ?? marker.artworkId ?? marker.subjectId)?.trim();
    case MapMarkerOverlayLinkedSubjectKind.exhibition:
      return (marker.resolvedExhibitionSummary?.id ?? marker.subjectId)?.trim();
    case MapMarkerOverlayLinkedSubjectKind.event:
    case MapMarkerOverlayLinkedSubjectKind.institution:
    case MapMarkerOverlayLinkedSubjectKind.group:
    case MapMarkerOverlayLinkedSubjectKind.misc:
      return marker.subjectId?.trim();
    case MapMarkerOverlayLinkedSubjectKind.none:
      return null;
  }
}

String? _resolveLinkedSubjectTitle({
  required ArtMarker marker,
  required Artwork? artwork,
  required KubusEvent? event,
  required Exhibition? exhibition,
  required MapMarkerOverlayLinkedSubjectKind kind,
}) {
  switch (kind) {
    case MapMarkerOverlayLinkedSubjectKind.artwork:
      return _normalizeText(artwork?.title) ??
          _normalizeText(marker.subjectTitle);
    case MapMarkerOverlayLinkedSubjectKind.exhibition:
      return _normalizeText(exhibition?.title) ??
          _normalizeText(marker.resolvedExhibitionSummary?.title) ??
          _normalizeText(marker.subjectTitle);
    case MapMarkerOverlayLinkedSubjectKind.event:
      return _normalizeText(event?.title) ??
          _normalizeText(marker.subjectTitle);
    case MapMarkerOverlayLinkedSubjectKind.institution:
    case MapMarkerOverlayLinkedSubjectKind.group:
    case MapMarkerOverlayLinkedSubjectKind.misc:
      return _normalizeText(marker.subjectTitle);
    case MapMarkerOverlayLinkedSubjectKind.none:
      return null;
  }
}

String? _resolveLinkedSubjectSubtitle({
  required ArtMarker marker,
  required KubusEvent? event,
  required Exhibition? exhibition,
  required MapMarkerOverlayLinkedSubjectKind kind,
}) {
  final metadataSubtitle = _readMetadataString(marker.metadata, const <String>[
    'subjectSubtitle',
    'subject_subtitle',
  ]);
  switch (kind) {
    case MapMarkerOverlayLinkedSubjectKind.event:
      final eventSubtitle = _buildEventSubtitle(event);
      return eventSubtitle ?? metadataSubtitle;
    case MapMarkerOverlayLinkedSubjectKind.exhibition:
      final exhibitionSubtitle = _buildExhibitionSubtitle(exhibition);
      return exhibitionSubtitle ?? metadataSubtitle;
    case MapMarkerOverlayLinkedSubjectKind.institution:
    case MapMarkerOverlayLinkedSubjectKind.group:
    case MapMarkerOverlayLinkedSubjectKind.misc:
      return metadataSubtitle;
    case MapMarkerOverlayLinkedSubjectKind.artwork:
    case MapMarkerOverlayLinkedSubjectKind.none:
      return null;
  }
}

String _resolveFallbackDescription({
  required Artwork? artwork,
  required KubusEvent? event,
  required Exhibition? exhibition,
  required MapMarkerOverlayLinkedSubjectKind kind,
}) {
  switch (kind) {
    case MapMarkerOverlayLinkedSubjectKind.artwork:
      return (artwork?.description ?? '').trim();
    case MapMarkerOverlayLinkedSubjectKind.event:
      return (event?.description ?? '').trim();
    case MapMarkerOverlayLinkedSubjectKind.exhibition:
      return (exhibition?.description ?? '').trim();
    case MapMarkerOverlayLinkedSubjectKind.institution:
    case MapMarkerOverlayLinkedSubjectKind.group:
    case MapMarkerOverlayLinkedSubjectKind.misc:
    case MapMarkerOverlayLinkedSubjectKind.none:
      return '';
  }
}

MapMarkerOverlayPrimaryTarget _resolvePrimaryTarget({
  required ArtMarker marker,
  required Artwork? artwork,
  required MapMarkerOverlayLinkedSubjectKind linkedKind,
  required String? linkedSubjectId,
}) {
  switch (linkedKind) {
    case MapMarkerOverlayLinkedSubjectKind.exhibition:
      if ((linkedSubjectId ?? '').isNotEmpty) {
        return MapMarkerOverlayPrimaryTarget.exhibition;
      }
      break;
    case MapMarkerOverlayLinkedSubjectKind.event:
      if ((linkedSubjectId ?? '').isNotEmpty) {
        return MapMarkerOverlayPrimaryTarget.event;
      }
      break;
    case MapMarkerOverlayLinkedSubjectKind.artwork:
      if ((artwork?.id ?? marker.artworkId ?? '').trim().isNotEmpty) {
        return MapMarkerOverlayPrimaryTarget.artwork;
      }
      break;
    case MapMarkerOverlayLinkedSubjectKind.institution:
      if ((linkedSubjectId ?? '').isNotEmpty) {
        return MapMarkerOverlayPrimaryTarget.institution;
      }
      break;
    case MapMarkerOverlayLinkedSubjectKind.group:
    case MapMarkerOverlayLinkedSubjectKind.misc:
    case MapMarkerOverlayLinkedSubjectKind.none:
      break;
  }
  return MapMarkerOverlayPrimaryTarget.markerInfo;
}

String? _buildEventSubtitle(KubusEvent? event) {
  if (event == null) return null;
  return _buildLocationAndDateSubtitle(
    locationParts: <String?>[event.locationName, event.city, event.country],
    startsAt: event.startsAt,
    endsAt: event.endsAt,
  );
}

String? _buildExhibitionSubtitle(Exhibition? exhibition) {
  if (exhibition == null) return null;
  return _buildLocationAndDateSubtitle(
    locationParts: <String?>[exhibition.locationName],
    startsAt: exhibition.startsAt,
    endsAt: exhibition.endsAt,
  );
}

String? _buildLocationAndDateSubtitle({
  required Iterable<String?> locationParts,
  required DateTime? startsAt,
  required DateTime? endsAt,
}) {
  final parts = <String>[];
  final location =
      locationParts.map(_normalizeText).whereType<String>().toSet().join(', ');
  if (location.isNotEmpty) {
    parts.add(location);
  }
  final range = _formatEventRange(startsAt, endsAt);
  if (range != null) {
    parts.add(range);
  }
  if (parts.isEmpty) return null;
  return parts.join(' - ');
}

String? _formatEventRange(DateTime? startsAt, DateTime? endsAt) {
  String formatDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  if (startsAt == null && endsAt == null) return null;
  if (startsAt != null && endsAt != null) {
    return '${formatDate(startsAt)} -> ${formatDate(endsAt)}';
  }
  if (startsAt != null) return formatDate(startsAt);
  return formatDate(endsAt!);
}

String? _readMetadataString(Map<String, dynamic>? metadata, List<String> keys) {
  if (metadata == null) return null;
  for (final key in keys) {
    final raw = metadata[key];
    final normalized = _normalizeText(raw);
    if (normalized != null) return normalized;
  }
  final nested = metadata['metadata'] ?? metadata['meta'];
  if (nested is Map) {
    return _readMetadataString(Map<String, dynamic>.from(nested), keys);
  }
  return null;
}

String? _normalizeText(dynamic raw) {
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) return null;
  return value;
}
