import 'dart:async';

import 'package:art_kubus/features/map/controller/map_marker_linked_subject_coordinator.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/event.dart';
import 'package:art_kubus/models/exhibition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

ArtMarker _marker({
  String id = 'marker-1',
  required String subjectType,
  required String subjectId,
}) {
  return ArtMarker(
    id: id,
    name: id,
    description: '',
    position: const LatLng(46.0569, 14.5058),
    type: ArtMarkerType.artwork,
    metadata: <String, dynamic>{
      'subjectType': subjectType,
      'subjectId': subjectId,
    },
    createdAt: DateTime(2024),
    createdBy: 'tester',
  );
}

KubusEvent _event({String id = 'event-1'}) {
  return KubusEvent(
    id: id,
    title: 'City Walk',
    description: 'Event description',
    startsAt: DateTime(2025, 5, 1),
    endsAt: DateTime(2025, 5, 3),
  );
}

Exhibition _exhibition({String id = 'exhibition-1'}) {
  return Exhibition(
    id: id,
    title: 'Group Show',
    description: 'Exhibition description',
  );
}

class _Harness {
  _Harness() {
    coordinator = MapMarkerLinkedSubjectCoordinator(
      cachedEvent: (id) => cachedEvents[id],
      cachedExhibition: (id) => cachedExhibitions[id],
      isEventDetailHydrated: hydratedEventIds.contains,
      isExhibitionDetailHydrated: hydratedExhibitionIds.contains,
      fetchEvent: (id) {
        fetchedEventIds.add(id);
        final pending = pendingEventFetch;
        if (pending != null) return pending.future;
        cachedEvents[id] = _event(id: id);
        hydratedEventIds.add(id);
        return Future<KubusEvent?>.value(cachedEvents[id]);
      },
      fetchExhibition: (id) {
        fetchedExhibitionIds.add(id);
        if (failExhibitionFetch) {
          return Future<Exhibition?>.error(StateError('detail failed'));
        }
        cachedExhibitions[id] = _exhibition(id: id);
        hydratedExhibitionIds.add(id);
        return Future<Exhibition?>.value(cachedExhibitions[id]);
      },
      selectedMarkerId: () => selectedMarkerId,
      onSubjectHydrated: () => rebuilds += 1,
    );
  }

  late final MapMarkerLinkedSubjectCoordinator coordinator;

  final Map<String, KubusEvent> cachedEvents = <String, KubusEvent>{};
  final Map<String, Exhibition> cachedExhibitions = <String, Exhibition>{};
  final Set<String> hydratedEventIds = <String>{};
  final Set<String> hydratedExhibitionIds = <String>{};
  final List<String> fetchedEventIds = <String>[];
  final List<String> fetchedExhibitionIds = <String>[];

  Completer<KubusEvent?>? pendingEventFetch;
  bool failExhibitionFetch = false;
  String? selectedMarkerId;
  int rebuilds = 0;
}

void main() {
  group('MapMarkerLinkedSubjectCoordinator', () {
    test('loads an event detail and requests one rebuild', () async {
      final harness = _Harness();
      final marker = _marker(subjectType: 'event', subjectId: 'event-1');
      harness.selectedMarkerId = marker.id;

      final hydrated = await harness.coordinator.hydrate(marker);

      expect(hydrated, isTrue);
      expect(harness.fetchedEventIds, <String>['event-1']);
      expect(harness.rebuilds, 1);
      expect(
        harness.coordinator.resolveCached(marker).event?.id,
        'event-1',
      );
    });

    test('a list-cache entry is not treated as hydrated', () async {
      final harness = _Harness();
      final marker = _marker(subjectType: 'event', subjectId: 'event-1');
      harness.selectedMarkerId = marker.id;
      // Present in the provider from a list page, but never detail-loaded.
      harness.cachedEvents['event-1'] = _event();

      final hydrated = await harness.coordinator.hydrate(marker);

      expect(hydrated, isTrue);
      expect(harness.fetchedEventIds, <String>['event-1']);
    });

    test('skips the request once the id was detail-loaded', () async {
      final harness = _Harness();
      final marker = _marker(subjectType: 'event', subjectId: 'event-1');
      harness.selectedMarkerId = marker.id;
      harness.cachedEvents['event-1'] = _event();
      harness.hydratedEventIds.add('event-1');

      final hydrated = await harness.coordinator.hydrate(marker);

      expect(hydrated, isFalse);
      expect(harness.fetchedEventIds, isEmpty);
      expect(harness.rebuilds, 0);
    });

    test('de-duplicates concurrent requests for the same subject', () async {
      final harness = _Harness();
      final completer = Completer<KubusEvent?>();
      harness.pendingEventFetch = completer;
      final first = _marker(
        id: 'marker-1',
        subjectType: 'event',
        subjectId: 'event-1',
      );
      final second = _marker(
        id: 'marker-2',
        subjectType: 'event',
        subjectId: 'event-1',
      );
      harness.selectedMarkerId = second.id;

      final futures = <Future<bool>>[
        harness.coordinator.hydrate(first),
        harness.coordinator.hydrate(second),
      ];
      expect(harness.coordinator.inFlightCount, 1);
      completer.complete(_event());
      final results = await Future.wait(futures);

      expect(results, <bool>[true, true]);
      expect(harness.fetchedEventIds, <String>['event-1']);
      // Only the still-selected marker asked for a repaint.
      expect(harness.rebuilds, 1);
      expect(harness.coordinator.inFlightCount, 0);
    });

    test('no rebuild when the selection moved on during the request', () async {
      final harness = _Harness();
      final marker = _marker(subjectType: 'event', subjectId: 'event-1');
      harness.selectedMarkerId = 'other-marker';

      await harness.coordinator.hydrate(marker);

      expect(harness.fetchedEventIds, <String>['event-1']);
      expect(harness.rebuilds, 0);
    });

    test('swallows a failing detail request and clears the in-flight slot',
        () async {
      final harness = _Harness()..failExhibitionFetch = true;
      final marker = _marker(
        subjectType: 'exhibition',
        subjectId: 'exhibition-1',
      );
      harness.selectedMarkerId = marker.id;

      final hydrated = await harness.coordinator.hydrate(marker);

      expect(hydrated, isFalse);
      expect(harness.rebuilds, 0);
      expect(harness.coordinator.inFlightCount, 0);

      harness.failExhibitionFetch = false;
      expect(await harness.coordinator.hydrate(marker), isTrue);
      expect(harness.fetchedExhibitionIds.length, 2);
      expect(harness.rebuilds, 1);
    });

    test('hydrates exhibition markers through the exhibition endpoint',
        () async {
      final harness = _Harness();
      final marker = _marker(
        subjectType: 'exhibition',
        subjectId: 'exhibition-1',
      );
      harness.selectedMarkerId = marker.id;

      expect(await harness.coordinator.hydrate(marker), isTrue);
      expect(harness.fetchedExhibitionIds, <String>['exhibition-1']);
      expect(harness.fetchedEventIds, isEmpty);
      expect(
        harness.coordinator.resolveCached(marker).exhibition?.id,
        'exhibition-1',
      );
    });

    test('ignores markers without a linked event or exhibition', () async {
      final harness = _Harness();
      final marker = _marker(subjectType: 'artwork', subjectId: 'art-1');
      harness.selectedMarkerId = marker.id;

      expect(await harness.coordinator.hydrate(marker), isFalse);
      expect(harness.fetchedEventIds, isEmpty);
      expect(harness.fetchedExhibitionIds, isEmpty);
      expect(harness.coordinator.resolveCached(marker).event, isNull);
      expect(harness.coordinator.resolveCached(marker).exhibition, isNull);
    });

    test('ignores markers with a blank subject id', () async {
      final harness = _Harness();
      final marker = _marker(subjectType: 'event', subjectId: '   ');
      harness.selectedMarkerId = marker.id;

      expect(await harness.coordinator.hydrate(marker), isFalse);
      expect(harness.fetchedEventIds, isEmpty);
    });

    test('selectionChanged tolerates a cleared selection', () async {
      final harness = _Harness();

      harness.coordinator.selectionChanged(null);

      expect(harness.fetchedEventIds, isEmpty);
      expect(harness.rebuilds, 0);
    });

    test('stops hydrating and rebuilding after dispose', () async {
      final harness = _Harness();
      final marker = _marker(subjectType: 'event', subjectId: 'event-1');
      harness.selectedMarkerId = marker.id;

      harness.coordinator.dispose();
      harness.coordinator.selectionChanged(marker);
      final hydrated = await harness.coordinator.hydrate(marker);

      expect(hydrated, isFalse);
      expect(harness.fetchedEventIds, isEmpty);
      expect(harness.rebuilds, 0);
    });

    test('does not rebuild when disposed mid-request', () async {
      final harness = _Harness();
      final completer = Completer<KubusEvent?>();
      harness.pendingEventFetch = completer;
      final marker = _marker(subjectType: 'event', subjectId: 'event-1');
      harness.selectedMarkerId = marker.id;

      final pending = harness.coordinator.hydrate(marker);
      harness.coordinator.dispose();
      completer.complete(_event());

      expect(await pending, isTrue);
      expect(harness.rebuilds, 0);
    });
  });
}
