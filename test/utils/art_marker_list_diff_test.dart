import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/utils/art_marker_list_diff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

ArtMarker _marker(String id) => ArtMarker(
      id: id,
      name: 'Marker $id',
      description: '',
      position: const LatLng(46.056946, 14.505751),
      type: ArtMarkerType.artwork,
      createdAt: DateTime.utc(2026, 1, 1),
      createdBy: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      ownerWalletAddress: 'owner-wallet',
    );

void main() {
  group('ArtMarkerListDiff.upsertById', () {
    test('merges updates over the current list by id', () {
      final result = ArtMarkerListDiff.upsertById(
        current: <ArtMarker>[_marker('a'), _marker('b')],
        updates: <ArtMarker>[_marker('b'), _marker('c')],
      );

      expect(result.map((m) => m.id), containsAll(<String>['a', 'b', 'c']));
      expect(result, hasLength(3));
    });

    // Both map screens assign this result straight to their `_artMarkers`
    // field and then mutate that field in place when a marker is created or
    // deleted. A fixed-length result therefore turns the next create into an
    // UnsupportedError thrown inside setState.
    test('returns a growable list so callers can add to it', () {
      final result = ArtMarkerListDiff.upsertById(
        current: <ArtMarker>[_marker('a')],
        updates: <ArtMarker>[_marker('b')],
      );

      expect(() => result.add(_marker('c')), returnsNormally);
      expect(result, hasLength(3));
    });

    test('returns a list callers can remove from', () {
      final result = ArtMarkerListDiff.upsertById(
        current: <ArtMarker>[_marker('a'), _marker('b')],
        updates: <ArtMarker>[_marker('c')],
      );

      expect(() => result.removeWhere((m) => m.id == 'b'), returnsNormally);
      expect(result.map((m) => m.id), isNot(contains('b')));
    });

    test('is growable even when updates only replace existing markers', () {
      final result = ArtMarkerListDiff.upsertById(
        current: <ArtMarker>[_marker('a')],
        updates: <ArtMarker>[_marker('a')],
      );

      expect(result, hasLength(1));
      expect(() => result.add(_marker('z')), returnsNormally);
    });

    test('is growable when the current list is empty', () {
      final result = ArtMarkerListDiff.upsertById(
        current: const <ArtMarker>[],
        updates: <ArtMarker>[_marker('a')],
      );

      expect(() => result.add(_marker('b')), returnsNormally);
    });
  });

  group('ArtMarkerListDiff.mergeById', () {
    test('returns a growable list', () {
      final result = ArtMarkerListDiff.mergeById(
        current: <ArtMarker>[_marker('a')],
        next: <ArtMarker>[_marker('a'), _marker('b')],
      );

      expect(() => result.add(_marker('c')), returnsNormally);
    });

    test('returns a growable list when current is empty', () {
      final result = ArtMarkerListDiff.mergeById(
        current: const <ArtMarker>[],
        next: <ArtMarker>[_marker('a')],
      );

      expect(() => result.add(_marker('b')), returnsNormally);
    });

    test('returns a growable list when next is empty', () {
      final result = ArtMarkerListDiff.mergeById(
        current: <ArtMarker>[_marker('a')],
        next: const <ArtMarker>[],
      );

      expect(() => result.add(_marker('b')), returnsNormally);
    });
  });

  // The concrete regression: a deep-link / "Open on Map" target merges markers
  // into the screen's list, and the user then creates a marker.
  test('deep-link merge followed by an in-place create does not throw', () {
    var artMarkers = <ArtMarker>[_marker('loaded-1')];

    artMarkers = ArtMarkerListDiff.upsertById(
      current: artMarkers,
      updates: <ArtMarker>[_marker('deep-link-target')],
    );

    expect(() => artMarkers.add(_marker('newly-created')), returnsNormally);
    expect(artMarkers.map((m) => m.id), contains('newly-created'));
  });
}
