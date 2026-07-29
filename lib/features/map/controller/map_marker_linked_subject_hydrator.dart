import '../../../config/config.dart';
import '../../../models/art_marker.dart';
import '../../../models/event.dart';
import '../../../models/exhibition.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/exhibitions_provider.dart';
import '../shared/map_marker_overlay_presentation.dart';

class MapMarkerLinkedSubjectSnapshot {
  const MapMarkerLinkedSubjectSnapshot({this.event, this.exhibition});

  final KubusEvent? event;
  final Exhibition? exhibition;
}

/// Hydrates event and exhibition marker subjects for the shared quick card.
///
/// Both map screens own an instance so concurrent rebuilds and stacked-marker
/// paging do not duplicate detail requests for the same linked entity.
class MapMarkerLinkedSubjectHydrator {
  final Map<String, Future<bool>> _inFlight = <String, Future<bool>>{};

  MapMarkerLinkedSubjectSnapshot resolveCached({
    required ArtMarker marker,
    required EventsProvider eventsProvider,
    required ExhibitionsProvider exhibitionsProvider,
  }) {
    final kind = resolveMarkerOverlayLinkedSubjectKind(marker);
    switch (kind) {
      case MapMarkerOverlayLinkedSubjectKind.event:
        final id = (marker.subjectId ?? '').trim();
        return MapMarkerLinkedSubjectSnapshot(
          event: id.isEmpty ? null : eventsProvider.eventById(id),
        );
      case MapMarkerOverlayLinkedSubjectKind.exhibition:
        final id =
            (marker.resolvedExhibitionSummary?.id ?? marker.subjectId ?? '')
                .trim();
        return MapMarkerLinkedSubjectSnapshot(
          exhibition: id.isEmpty
              ? null
              : exhibitionsProvider.exhibitionById(id),
        );
      case MapMarkerOverlayLinkedSubjectKind.none:
      case MapMarkerOverlayLinkedSubjectKind.artwork:
      case MapMarkerOverlayLinkedSubjectKind.institution:
      case MapMarkerOverlayLinkedSubjectKind.group:
      case MapMarkerOverlayLinkedSubjectKind.misc:
        return const MapMarkerLinkedSubjectSnapshot();
    }
  }

  Future<bool> hydrate({
    required ArtMarker marker,
    required EventsProvider eventsProvider,
    required ExhibitionsProvider exhibitionsProvider,
  }) {
    final kind = resolveMarkerOverlayLinkedSubjectKind(marker);
    final String id;
    final Future<bool> Function() load;

    switch (kind) {
      case MapMarkerOverlayLinkedSubjectKind.event:
        id = (marker.subjectId ?? '').trim();
        if (id.isEmpty ||
            !AppConfig.isFeatureEnabled('events') ||
            eventsProvider.eventById(id) != null) {
          return Future<bool>.value(false);
        }
        load = () async => await eventsProvider.fetchEvent(id) != null;
      case MapMarkerOverlayLinkedSubjectKind.exhibition:
        id = (marker.resolvedExhibitionSummary?.id ?? marker.subjectId ?? '')
            .trim();
        if (id.isEmpty ||
            !AppConfig.isFeatureEnabled('exhibitions') ||
            exhibitionsProvider.exhibitionById(id) != null) {
          return Future<bool>.value(false);
        }
        load = () async =>
            await exhibitionsProvider.fetchExhibition(id) != null;
      case MapMarkerOverlayLinkedSubjectKind.none:
      case MapMarkerOverlayLinkedSubjectKind.artwork:
      case MapMarkerOverlayLinkedSubjectKind.institution:
      case MapMarkerOverlayLinkedSubjectKind.group:
      case MapMarkerOverlayLinkedSubjectKind.misc:
        return Future<bool>.value(false);
    }

    final key = '${kind.name}:$id';
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = () async {
      try {
        return await load();
      } catch (_) {
        return false;
      } finally {
        _inFlight.remove(key);
      }
    }();
    _inFlight[key] = future;
    return future;
  }
}
