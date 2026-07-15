import 'dart:async';

import 'package:art_kubus/features/map/controller/map_target_coordinator.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

ArtMarker _marker({
  required String id,
  String? artworkId,
  String? subjectId,
  String? subjectType,
  LatLng position = const LatLng(46.0569, 14.5058),
}) {
  return ArtMarker(
    id: id,
    name: id,
    description: '',
    position: position,
    artworkId: artworkId,
    type: ArtMarkerType.artwork,
    metadata: <String, dynamic>{
      if (subjectId != null) 'subjectId': subjectId,
      if (subjectType != null) 'subjectType': subjectType,
    },
    createdAt: DateTime(2024),
    createdBy: 'tester',
  );
}

class _Harness {
  _Harness({
    this.markerById,
    this.markersByArtwork = const <ArtMarker>[],
    this.throwDuringFetch = false,
    this.throwDuringMove = false,
  }) {
    coordinator = MapTargetCoordinator(
      loadedMarkers: () => markers,
      fetchMarkerById: (id) async {
        events.add('fetch-marker:$id');
        if (throwDuringFetch) throw StateError('fetch failed');
        final pending = markerFetchCompleter;
        return pending == null ? markerById : pending.future;
      },
      fetchMarkersByArtwork: (id) async {
        events.add('fetch-artwork:$id');
        return markersByArtwork;
      },
      loadMarkersAround: (position) async {
        events.add('load-around');
      },
      mergeMarkers: (items) {
        events.add('merge');
        for (final marker in items) {
          markers.removeWhere((item) => item.id == marker.id);
          markers.add(marker);
        }
      },
      moveCamera: (position, zoom) async {
        events.add('move');
        if (throwDuringMove) throw StateError('camera failed');
        movedPosition = position;
        movedZoom = zoom;
      },
      selectMarker: (marker) {
        events.add('select:${marker.id}');
        selectedMarker = marker;
      },
      setPinnedMarker: (id) {
        events.add('pin:$id');
        pinnedMarkerId = id;
      },
      showFallback: (_, result) {
        events.add('fallback:${result.name}');
      },
      onTerminal: (_, result) {
        events.add('terminal:${result.name}');
      },
    );
  }

  final ArtMarker? markerById;
  final List<ArtMarker> markersByArtwork;
  final bool throwDuringFetch;
  final bool throwDuringMove;
  final List<ArtMarker> markers = <ArtMarker>[];
  final List<String> events = <String>[];
  Completer<ArtMarker?>? markerFetchCompleter;
  late final MapTargetCoordinator coordinator;
  ArtMarker? selectedMarker;
  LatLng? movedPosition;
  double? movedZoom;
  String? pinnedMarkerId;

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('waits for map and style, then completes only after overlay ack',
      () async {
    final marker = _marker(id: 'm1', artworkId: 'a1');
    final harness = _Harness(markerById: marker)
      ..markerFetchCompleter = Completer<ArtMarker?>();
    final future = harness.coordinator.submit(
      const MapTargetIntent(exactMarkerId: 'm1', artworkId: 'a1'),
    );
    var completed = false;
    future.then((_) => completed = true);

    await harness.settle();
    expect(harness.coordinator.phase, MapTargetPhase.waitingForMap);
    expect(harness.events, isEmpty);

    harness.coordinator.setMapControllerReady(true);
    await harness.settle();
    expect(harness.events, isEmpty);

    harness.coordinator.setStyleReady(true);
    await harness.settle();
    expect(harness.events, <String>['fetch-marker:m1']);
    expect(completed, isFalse);

    harness.markerFetchCompleter!.complete(marker);
    await harness.settle();
    expect(
      harness.events,
      containsAllInOrder(<String>[
        'merge',
        'pin:m1',
        'move',
        'select:m1',
      ]),
    );
    expect(harness.coordinator.phase, MapTargetPhase.waitingForOverlay);
    expect(completed, isFalse);

    harness.coordinator.acknowledgeOverlay('other');
    await harness.settle();
    expect(completed, isFalse);

    harness.coordinator.acknowledgeOverlay('m1');
    expect(await future, MapTargetResult.overlayOpened);
    expect(harness.pinnedMarkerId, 'm1');
  });

  test('pins before camera and uses de-cluster/spiderfy focus zoom', () async {
    final harness = _Harness()..markers.add(_marker(id: 'm1'));
    harness.coordinator.setMapControllerReady(true);
    harness.coordinator.setStyleReady(true);

    final future = harness.coordinator.submit(
      const MapTargetIntent(exactMarkerId: 'm1', minZoom: 14),
    );
    await harness.settle();

    expect(harness.events.indexOf('pin:m1'),
        lessThan(harness.events.indexOf('move')));
    expect(harness.movedZoom, greaterThanOrEqualTo(17));
    harness.coordinator.acknowledgeOverlay('m1');
    expect(await future, MapTargetResult.overlayOpened);
  });

  test('resolves artwork through the authoritative artwork relation', () async {
    final marker = _marker(id: 'linked-marker', artworkId: 'artwork-1');
    final harness = _Harness(markersByArtwork: <ArtMarker>[marker]);
    harness.coordinator.setMapControllerReady(true);
    harness.coordinator.setStyleReady(true);

    final future = harness.coordinator.submit(
      const MapTargetIntent(artworkId: 'artwork-1'),
    );
    await harness.settle();

    expect(harness.selectedMarker?.id, 'linked-marker');
    expect(harness.events, contains('fetch-artwork:artwork-1'));
    harness.coordinator.acknowledgeOverlay('linked-marker');
    expect(await future, MapTargetResult.overlayOpened);
  });

  test('missing marker centers on preferred coordinates without selection',
      () async {
    final harness = _Harness();
    harness.coordinator.setMapControllerReady(true);
    harness.coordinator.setStyleReady(true);
    const position = LatLng(46.1, 14.6);

    final result = await harness.coordinator.submit(
      const MapTargetIntent(
        artworkId: 'missing-artwork',
        preferredPosition: position,
        minZoom: 16,
      ),
    );

    expect(result, MapTargetResult.coordinatesOnly);
    expect(harness.movedPosition, position);
    expect(harness.selectedMarker, isNull);
    expect(harness.events, contains('fallback:coordinatesOnly'));
  });

  test('missing target without coordinates reports not found without moving',
      () async {
    final harness = _Harness();
    harness.coordinator.setMapControllerReady(true);
    harness.coordinator.setStyleReady(true);

    final result = await harness.coordinator.submit(
      const MapTargetIntent(exactMarkerId: 'missing-marker'),
    );

    expect(result, MapTargetResult.notFound);
    expect(harness.movedPosition, isNull);
    expect(harness.events, contains('fallback:notFound'));
  });

  test('supersession and disposal complete outstanding submit futures',
      () async {
    final harness = _Harness();
    final first = harness.coordinator.submit(
      const MapTargetIntent(exactMarkerId: 'first'),
    );
    final second = harness.coordinator.submit(
      const MapTargetIntent(exactMarkerId: 'second'),
    );

    expect(await first, MapTargetResult.superseded);
    harness.coordinator.dispose();
    expect(await second, MapTargetResult.cancelled);
  });

  test('thrown async callbacks fail terminally without hanging', () async {
    final fetchHarness = _Harness(throwDuringFetch: true);
    fetchHarness.coordinator.setMapControllerReady(true);
    fetchHarness.coordinator.setStyleReady(true);
    final fetchResult = await fetchHarness.coordinator.submit(
      const MapTargetIntent(exactMarkerId: 'm1'),
    );
    expect(fetchResult, MapTargetResult.notFound);
    expect(fetchHarness.events, contains('fallback:notFound'));

    final moveHarness = _Harness(throwDuringMove: true)
      ..markers.add(_marker(id: 'm2'));
    moveHarness.coordinator.setMapControllerReady(true);
    moveHarness.coordinator.setStyleReady(true);
    final moveResult = await moveHarness.coordinator.submit(
      const MapTargetIntent(exactMarkerId: 'm2'),
    );
    expect(moveResult, MapTargetResult.notFound);
    expect(moveHarness.pinnedMarkerId, isNull);
    expect(moveHarness.events, contains('fallback:notFound'));
  });

  test('selection dismissal clears a direct-target filter pin', () async {
    final harness = _Harness()..markers.add(_marker(id: 'm1'));
    harness.coordinator.setMapControllerReady(true);
    harness.coordinator.setStyleReady(true);
    final future = harness.coordinator.submit(
      const MapTargetIntent(exactMarkerId: 'm1'),
    );
    await harness.settle();
    harness.coordinator.acknowledgeOverlay('m1');
    await future;
    expect(harness.pinnedMarkerId, 'm1');

    harness.coordinator.selectionChanged(null);
    expect(harness.pinnedMarkerId, isNull);
    expect(harness.events.last, 'pin:null');
  });
}
