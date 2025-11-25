import '../models/artwork.dart';
import '../models/institution.dart';
import '../models/dao.dart';
import '../models/map_marker_subject.dart';

bool artworkSupportsAR(Artwork artwork) {
  if (!artwork.arEnabled) return false;
  final hasCid = (artwork.model3DCID?.isNotEmpty ?? false);
  final hasUrl = (artwork.model3DURL?.isNotEmpty ?? false);
  return hasCid || hasUrl;
}

Artwork? findArtworkById(List<Artwork> artworks, String? artworkId) {
  if (artworkId == null) return null;
  try {
    return artworks.firstWhere((artwork) => artwork.id == artworkId);
  } catch (_) {
    return null;
  }
}

String formatEventDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

List<MarkerSubjectOption> buildSubjectOptions({
  required MarkerSubjectType type,
  required List<Artwork> artworks,
  required List<Institution> institutions,
  required List<Event> events,
  required List<Delegate> delegates,
}) {
  switch (type) {
    case MarkerSubjectType.artwork:
      return artworks
          .where(artworkSupportsAR)
          .map(
            (artwork) => MarkerSubjectOption(
              type: MarkerSubjectType.artwork,
              id: artwork.id,
              title: artwork.title,
              subtitle: artwork.description,
              metadata: {'artist': artwork.artist},
            ),
          )
          .toList();
    case MarkerSubjectType.institution:
      return institutions
          .map(
            (institution) => MarkerSubjectOption(
              type: type,
              id: institution.id,
              title: institution.name,
              subtitle: institution.address,
              metadata: {'institutionType': institution.type},
            ),
          )
          .toList();
    case MarkerSubjectType.event:
      return events
          .map(
            (event) => MarkerSubjectOption(
              type: type,
              id: event.id,
              title: event.title,
              subtitle:
                  '${event.location} • ${formatEventDate(event.startDate)}',
              metadata: {'institutionId': event.institutionId},
            ),
          )
          .toList();
    case MarkerSubjectType.group:
      return delegates
          .map(
            (delegate) => MarkerSubjectOption(
              type: type,
              id: delegate.id,
              title: delegate.name,
              subtitle: delegate.description,
              metadata: {'address': delegate.address},
            ),
          )
          .toList();
    case MarkerSubjectType.misc:
      return const [];
  }
}
